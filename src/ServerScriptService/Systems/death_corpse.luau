--[[
    Death Corpse System (ECS-Driven)

    When a player or NPC dies:
    1. ECS queries for entities with Dead tag
    2. Ragdolls the character
    3. Creates a corpse clone at the death location
    4. Despawns the corpse after 50 seconds
    5. Clears DeathInfo component after processing
]]

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Ragdoll = require(ReplicatedStorage.Modules.Utils.Ragdoll)
local VFXCleanup = require(ReplicatedStorage.Modules.Utils.VFXCleanup)
local DeathSignals = require(ReplicatedStorage.Modules.Signals.DeathSignals)

-- ECS imports for Dead tag monitoring
local world = require(ReplicatedStorage.Modules.ECS.jecs_world)
local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)
local tags = require(ReplicatedStorage.Modules.ECS.jecs_tags)
local jecsRef = require(ReplicatedStorage.Modules.ECS.jecs_ref)

local CORPSE_LIFETIME = 50 -- Seconds before corpse despawns

-- Chrono unregistration for wanderer NPCs on death/ragdoll
-- When ragdolled, let Roblox physics take over instead of Chrono interpolation
local function unregisterFromChrono(character: Model)
	local chronoId = character:GetAttribute("ChronoId")
	if chronoId then
		local success, err = pcall(function()
			local Chrono = require(ReplicatedStorage.Modules.Chrono)
			if Chrono and Chrono.NpcRegistry then
				Chrono.NpcRegistry.UnRegister(chronoId)
				character:SetAttribute("ChronoId", nil)
				print(`[DeathCorpse] Unregistered {character.Name} from Chrono (ID: {chronoId}) - ragdoll physics takeover`)
			end
		end)
		if not success then
			warn(`[DeathCorpse] Failed to unregister from Chrono: {err}`)
		end
	end
end

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

    -- OPTIMIZED: Single GetDescendants() loop for scripts, parts setup, and fade caching
    local fadeableParts = {}
    for _, descendant in corpse:GetDescendants() do
        -- Remove scripts from corpse
        if descendant:IsA("Script") or descendant:IsA("LocalScript") then
            descendant:Destroy()
        -- Set corpse parts to non-collidable with characters but collidable with world
        elseif descendant:IsA("BasePart") then
            descendant.CollisionGroup = "CharactersOff"
            descendant.CanCollide = true
            descendant.Anchored = false
            -- Cache for fade-out
            table.insert(fadeableParts, {part = descendant, originalTransparency = descendant.Transparency})
        elseif descendant:IsA("Decal") then
            -- Cache decals for fade-out too
            table.insert(fadeableParts, {part = descendant, originalTransparency = descendant.Transparency})
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

    -- Fade out and destroy after lifetime (using fadeableParts cached above)
    task.delay(CORPSE_LIFETIME - 5, function()
        if not corpse or not corpse.Parent then return end

        -- Fade out over 5 seconds using cached parts
        for i = 0, 1, 0.05 do
            if not corpse or not corpse.Parent then break end
            for _, data in fadeableParts do
                if data.part and data.part.Parent then
                    data.part.Transparency = data.originalTransparency + (1 - data.originalTransparency) * i
                end
            end
            task.wait(0.1)
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

    -- IMPORTANT: Set BreakJointsOnDeath to false immediately on setup
    -- This prevents body parts from separating when the character dies
    humanoid.BreakJointsOnDeath = false

    -- CRITICAL FIX: Set RequiresNeck to false immediately on setup
    -- This prevents the humanoid from dying when moved/reparented (e.g., by Chrono)
    -- because Roblox checks neck joint integrity and kills humanoids with broken necks
    humanoid.RequiresNeck = false

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

        -- CRITICAL: Prevent Roblox from breaking joints on death (causes fragmentation)
        -- Must be set BEFORE health = 0
        if humanoid then
            humanoid.BreakJointsOnDeath = false
            humanoid.RequiresNeck = false
        end

        -- Unregister from Chrono BEFORE enabling ragdoll
        -- This lets Roblox physics take over for the death animation
        unregisterFromChrono(character)

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

    -- Listen for DeathSignals.OnDeath (fired by Damage.lua when health <= 1)
    -- Filter to only respond to deaths for this specific character
    local deathDisconnect = DeathSignals.OnDeath:connect(function(deadCharacter)
        if deadCharacter == character then
            warn(`[DeathCorpse] 🔴 DEATH SIGNAL received for {character.Name}`)
            handleDeath()
        end
    end)
    table.insert(deathConnections[character], {Disconnect = deathDisconnect})

    -- Listen for health reaching 1 (death threshold) as backup
    table.insert(deathConnections[character], humanoid.HealthChanged:Connect(function(health)
        if health <= 1 and character.Parent then
            -- Check if marked as dead by Damage.lua
            if character:GetAttribute("IsDead") then
                warn(`[DeathCorpse] 🔴 HEALTH<=1 + IsDead for {character.Name}, health={health}`)
                handleDeath()
            end
        end
    end))

    -- Fallback: Also listen for Humanoid.Died in case Roblox death somehow triggers
    -- (shouldn't happen with 1 HP threshold, but good for safety)
    table.insert(deathConnections[character], humanoid.Died:Connect(function()
        warn(`[DeathCorpse] 🔴 HUMANOID.DIED fired for {character.Name}`)
        warn(`[DeathCorpse]   Health: {humanoid.Health}, MaxHealth: {humanoid.MaxHealth}`)
        warn(`[DeathCorpse]   IsDead: {character:GetAttribute("IsDead")}`)
        warn(debug.traceback())
        handleDeath()
    end))
end

local initialized = false

local function setupCharacterDeathHandler(character)
    if character:IsDescendantOf(workspace.World.Live) and not character:GetAttribute("NotActualRig") then
        -- DEBUG: Log when death handler is set up
        local isWanderer = character.Name:lower():find("wanderer") ~= nil or character.Name:find("Bandit") ~= nil
        if isWanderer then
            warn(`[DeathCorpse] 🟡 Setting up death handler for WANDERER: {character.Name}`)
        end
        setupDeathHandler(character)
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

-- Track entities that have been processed by ECS death system
local processedDeaths = {}

-- Cached query for dead entities with Character component
local deadQuery = world:query(tags.Dead, comps.Character):cached()

-- ECS-driven death processing: query entities with Dead tag
local function processECSDeaths()
    for entity, _, characterModel in deadQuery:iter() do
        -- Skip if already processed
        if processedDeaths[entity] then continue end

        local model = characterModel
        if not model or not model.Parent then continue end

        local humanoid = model:FindFirstChild("Humanoid")
        if not humanoid then continue end

        -- ECS says dead but humanoid still alive - sync them
        if humanoid.Health > 0 then
            -- Prevent duplicate death handling
            if model:GetAttribute("DeathHandled") then
                processedDeaths[entity] = true
                continue
            end
            model:SetAttribute("DeathHandled", true)

            -- Get death position
            local rootPart = model:FindFirstChild("HumanoidRootPart")
            local deathPosition = rootPart and rootPart.Position or Vector3.zero

            -- CLEANUP ALL VFX ON DEATH
            pcall(function()
                VFXCleanup.CleanupCharacter(model)
                VFXCleanup.DisableCharacterParticles(model)
            end)

            -- CRITICAL: Prevent Roblox from breaking joints on death
            humanoid.BreakJointsOnDeath = false
            humanoid.RequiresNeck = false

            -- Unregister from Chrono BEFORE enabling ragdoll
            unregisterFromChrono(model)

            -- Enable ragdoll
            if not model:FindFirstChild("Ragdoll") then
                pcall(function() Ragdoll:Enable(model) end)
            end

            -- Actually kill the character by setting health to 0
            humanoid.Health = 0

            -- Create corpse clone
            task.delay(0.1, function()
                createCorpse(model, deathPosition)
            end)
        end

        -- Remove DeathInfo after processing (cleanup)
        if world:has(entity, comps.DeathInfo) then
            world:remove(entity, comps.DeathInfo)
        end

        -- BUG 5.1 FIX: Comprehensive NPC component cleanup on death
        -- Remove all NPC-specific components to prevent stale state
        if world:has(entity, comps.NPCCombatState) then
            world:remove(entity, comps.NPCCombatState)
        end
        if world:has(entity, comps.NPCTarget) then
            world:remove(entity, comps.NPCTarget)
        end
        if world:has(entity, comps.Locomotion) then
            world:remove(entity, comps.Locomotion)
        end
        if world:has(entity, comps.NPCWander) then
            world:remove(entity, comps.NPCWander)
        end
        if world:has(entity, comps.NPCDefense) then
            world:remove(entity, comps.NPCDefense)
        end
        -- Remove any active action states
        if world:has(entity, comps.StateActions) then
            world:remove(entity, comps.StateActions)
        end
        if world:has(entity, comps.StateStuns) then
            world:remove(entity, comps.StateStuns)
        end
        if world:has(entity, comps.StateIFrames) then
            world:remove(entity, comps.StateIFrames)
        end

        processedDeaths[entity] = true
    end
end

-- Clear Dead tag on respawn (called by playerloader)
local function onRespawn(player)
    local entity = jecsRef.get("player", player)
    if entity and world:has(entity, tags.Dead) then
        world:remove(entity, tags.Dead)
        processedDeaths[entity] = nil
    end
end

-- ECS system format
return {
    run = function(_, deltaTime)
        -- Initialize on first run (for signal-based fallback)
        if not initialized then
            init()
        end

        -- Process ECS-driven deaths
        processECSDeaths()
    end,
    settings = {
        phase = "Heartbeat",
        paused = false,
        server_only = true
    },
    -- Export for playerloader to call on respawn
    onRespawn = onRespawn,
    clearProcessed = function(entity)
        processedDeaths[entity] = nil
    end
}

