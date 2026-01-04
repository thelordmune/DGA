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
local VFXCleanup = require(ReplicatedStorage.Modules.Utils.VFXCleanup)

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

   -- print(`[DeathCorpse] Created corpse for {character.Name} at {deathPosition}`)
end

local function setupDeathHandler(character: Model)
    -- Disconnect old connections if they exist
    if deathConnections[character] then
        for _, conn in deathConnections[character] do
            if conn then conn:Disconnect() end
        end
        deathConnections[character] = nil
    end

    local humanoid = character:WaitForChild("Humanoid", 5)
    if not humanoid then return end

    deathConnections[character] = {}

    -- Function to handle death (shared between CustomDeath and health check)
    local function handleDeath()
        -- Prevent duplicate death handling
        if character:GetAttribute("DeathHandled") then return end
        character:SetAttribute("DeathHandled", true)

       -- print(`[DeathCorpse] {character.Name} died (custom death system), creating corpse...`)

        -- Get death position
        local rootPart = character:FindFirstChild("HumanoidRootPart")
        local deathPosition = rootPart and rootPart.Position or Vector3.zero

        -- CLEANUP ALL VFX ON DEATH
        VFXCleanup.CleanupCharacter(character)
        VFXCleanup.DisableCharacterParticles(character)
       -- print(`[DeathCorpse] Cleaned up VFX for {character.Name}`)

        -- Enable ragdoll
        if not character:FindFirstChild("Ragdoll") then
            Ragdoll:Enable(character)
        end

        -- Actually kill the character by setting health to 0
        -- This triggers Roblox's death system (respawn for players, cleanup for NPCs)
        if humanoid then
            humanoid.Health = 0
        end

        -- Create corpse clone
        task.delay(0.1, function()
            createCorpse(character, deathPosition)
        end)

        -- Clean up all connections
        if deathConnections[character] then
            for _, conn in deathConnections[character] do
                if conn then conn:Disconnect() end
            end
            deathConnections[character] = nil
        end
    end

    -- Listen for CustomDeath BindableEvent (fired by Damage.lua when health <= 1)
    local customDeathEvent = character:FindFirstChild("CustomDeath")
    if customDeathEvent then
        table.insert(deathConnections[character], customDeathEvent.Event:Connect(handleDeath))
    end

    -- Also listen for CustomDeath being added (in case it's created after setup)
    table.insert(deathConnections[character], character.ChildAdded:Connect(function(child)
        if child.Name == "CustomDeath" and child:IsA("BindableEvent") then
            child.Event:Connect(handleDeath)
        end
    end))

    -- Listen for health reaching 1 (death threshold) as backup
    table.insert(deathConnections[character], humanoid.HealthChanged:Connect(function(health)
        if health <= 1 and character.Parent then
            -- Check if marked as dead by Damage.lua
            if character:GetAttribute("IsDead") then
                handleDeath()
            end
        end
    end))

    -- Fallback: Also listen for Humanoid.Died in case Roblox death somehow triggers
    -- (shouldn't happen with 1 HP threshold, but good for safety)
    table.insert(deathConnections[character], humanoid.Died:Connect(function()
        handleDeath()
    end))
end

local initialized = false

local function setupCharacterDeathHandler(character)
    if character:IsDescendantOf(workspace.World.Live) and not character:GetAttribute("NotActualRig") then
        setupDeathHandler(character)
       -- print(`[DeathCorpse] Set up death handler for {character.Name}`)
    end
end

local function init()
    if initialized then return end
    initialized = true

    -- Wait for workspace to be ready
    task.wait(1)

    -- Setup death handlers for all existing NPC characters
    for _, character in CollectionService:GetTagged("Humanoids") do
        setupCharacterDeathHandler(character)
    end

    -- Setup death handlers for all existing player characters
    for _, character in CollectionService:GetTagged("Players") do
        setupCharacterDeathHandler(character)
    end

    -- Setup death handlers for new NPC characters as they're added
    CollectionService:GetInstanceAddedSignal("Humanoids"):Connect(function(character)
        setupCharacterDeathHandler(character)
    end)

    -- Setup death handlers for new player characters as they're added
    CollectionService:GetInstanceAddedSignal("Players"):Connect(function(character)
        setupCharacterDeathHandler(character)
    end)

   -- print("[DeathCorpse] ✅ Death corpse system initialized")
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

