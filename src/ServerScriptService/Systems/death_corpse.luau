--[[
    Death Corpse System
    
    When a player or NPC dies:
    1. Ragdolls the character
    2. Creates a corpse clone at the death location
    3. Despawns the corpse after 50 seconds
]]

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Ragdoll = require(ReplicatedStorage.Modules.Utils.Ragdoll)

local CORPSE_LIFETIME = 50 -- Seconds before corpse despawns

-- Track death connections to prevent duplicates
local deathConnections = {}

local function createCorpse(character: Model, deathPosition: Vector3)
    -- Clone the character to create a corpse
    local success, corpse = pcall(function()
        return character:Clone()
    end)

    if not success or not corpse then
        warn(`[DeathCorpse] Failed to clone character {character.Name}`)
        return
    end

    corpse.Name = character.Name .. "_Corpse"

    -- Remove unnecessary components from corpse
    local humanoid = corpse:FindFirstChild("Humanoid")
    if humanoid then
        humanoid.Health = 0
        humanoid.MaxHealth = 0
        humanoid.BreakJointsOnDeath = false
        humanoid.RequiresNeck = false
    end

    -- Remove state folders and other gameplay components
    for _, child in corpse:GetChildren() do
        if child.Name == "Actions" or child.Name == "Stuns" or child.Name == "IFrames"
            or child.Name == "Speeds" or child.Name == "Frames" or child.Name == "Status"
            or child.Name == "Damage_Log" or child.Name == "Posture" or child.Name == "Ragdoll" then
            child:Destroy()
        end
    end

    -- Remove any tools/weapons
    for _, child in corpse:GetChildren() do
        if child:IsA("Tool") then
            child:Destroy()
        end
    end

    -- Remove scripts from corpse
    for _, descendant in corpse:GetDescendants() do
        if descendant:IsA("Script") or descendant:IsA("LocalScript") then
            descendant:Destroy()
        end
    end

    -- Set corpse to non-collidable with characters but collidable with world
    for _, part in corpse:GetDescendants() do
        if part:IsA("BasePart") then
            part.CollisionGroup = "CharactersOff"
            part.CanCollide = true
            part.Anchored = false
        end
    end

    -- Position the corpse at death location
    local rootPart = corpse:FindFirstChild("HumanoidRootPart")
    if rootPart then
        rootPart.CFrame = CFrame.new(deathPosition)
    end

    -- Parent to workspace (in a corpses folder for organization)
    local corpsesFolder = workspace:FindFirstChild("Corpses")
    if not corpsesFolder then
        corpsesFolder = Instance.new("Folder")
        corpsesFolder.Name = "Corpses"
        corpsesFolder.Parent = workspace
    end

    corpse.Parent = corpsesFolder

    -- Enable ragdoll on the corpse
    if humanoid then
        task.spawn(function()
            Ragdoll:Enable(corpse)
        end)
    end

    -- Fade out and destroy after lifetime
    task.delay(CORPSE_LIFETIME - 5, function()
        if not corpse or not corpse.Parent then return end

        -- Fade out over 5 seconds
        for _, part in corpse:GetDescendants() do
            if part:IsA("BasePart") or part:IsA("Decal") then
                local originalTransparency = part.Transparency
                for i = 0, 1, 0.05 do
                    if corpse and corpse.Parent then
                        part.Transparency = originalTransparency + (1 - originalTransparency) * i
                        task.wait(0.1)
                    else
                        break
                    end
                end
            end
        end
    end)

    -- Destroy corpse after full lifetime
    Debris:AddItem(corpse, CORPSE_LIFETIME)

    print(`[DeathCorpse] Created corpse for {character.Name} at {deathPosition}`)
end

local function setupDeathHandler(character: Model)
    -- Disconnect old connection if it exists
    if deathConnections[character] then
        deathConnections[character]:Disconnect()
        deathConnections[character] = nil
    end
    
    local humanoid = character:WaitForChild("Humanoid", 5)
    if not humanoid then return end
    
    -- Also listen for low health to ragdoll before death (prevents body from falling apart)
    local healthConnection
    healthConnection = humanoid.HealthChanged:Connect(function(health)
        if health <= 0 and character.Parent then
            -- Ragdoll immediately when health reaches 0 (before Died event)
            Ragdoll:Enable(character)

            -- Disconnect health listener
            if healthConnection then
                healthConnection:Disconnect()
                healthConnection = nil
            end
        end
    end)

    deathConnections[character] = humanoid.Died:Connect(function()
        print(`[DeathCorpse] {character.Name} died, creating corpse...`)

        -- Get death position
        local rootPart = character:FindFirstChild("HumanoidRootPart")
        local deathPosition = rootPart and rootPart.Position or Vector3.zero

        -- Ensure ragdoll is enabled (in case HealthChanged didn't fire)
        if not character:FindFirstChild("Ragdoll") then
            Ragdoll:Enable(character)
        end

        -- Create corpse clone
        task.delay(0.1, function()
            createCorpse(character, deathPosition)
        end)

        -- Clean up connections
        if healthConnection then
            healthConnection:Disconnect()
            healthConnection = nil
        end
        if deathConnections[character] then
            deathConnections[character]:Disconnect()
            deathConnections[character] = nil
        end
    end)
end

local initialized = false

local function init()
    if initialized then return end
    initialized = true

    -- Wait for workspace to be ready
    task.wait(1)

    -- Setup death handlers for all existing characters
    for _, character in CollectionService:GetTagged("Humanoids") do
        if character:IsDescendantOf(workspace.World.Live) and not character:GetAttribute("NotActualRig") then
            setupDeathHandler(character)
            print(`[DeathCorpse] Set up death handler for {character.Name}`)
        end
    end

    -- Setup death handlers for new characters as they're added
    CollectionService:GetInstanceAddedSignal("Humanoids"):Connect(function(character)
        if character:IsDescendantOf(workspace.World.Live) and not character:GetAttribute("NotActualRig") then
            setupDeathHandler(character)
            print(`[DeathCorpse] Set up death handler for {character.Name}`)
        end
    end)

    print("[DeathCorpse] ✅ Death corpse system initialized")
end

-- ECS system format
return {
    run = function(world, deltaTime)
        -- Initialize on first run
        if not initialized then
            init()
        end
    end,
    settings = {
        phase = "Heartbeat",
        paused = false,
        server_only = true
    }
}

