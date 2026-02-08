local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RefManager = require(ReplicatedStorage.Modules.ECS.jecs_ref_manager)
local ref = RefManager.player -- Use player-specific ref system
local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)
local world = require(ReplicatedStorage.Modules.ECS.jecs_world)
local tags = require(ReplicatedStorage.Modules.ECS.jecs_tags)
local EntityCleanup = require(ReplicatedStorage.Modules.ECS.entity_cleanup)
local JecsBatch = require(ReplicatedStorage.Modules.ECS.jecs_batch)
local Server = require(game:GetService("ServerScriptService").ServerConfig.Server)
local Bridges = require(ReplicatedStorage.Modules.Bridges)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- local global = require(ReplicatedStorage.Global)
local Player = comps.Player
local Character = comps.Character

local Sift = require(ReplicatedStorage.Modules.Imports.Sift)

-- Animation preloading cache
local PreloadedAnimations = {}
local playerConnections = {}
local ContentProvider = game:GetService("ContentProvider")

-- Function to preload assets for a character
-- local function preloadCharacterAssets(character)
--     ---- print(`[Preload] Starting asset preload for {character.Name}`)
    
--     local humanoid = character:FindFirstChildOfClass("Humanoid")
--     if not humanoid then 
--         warn(`[Preload] No humanoid found for {character.Name}`)
--         return 
--     end
    
--     local animator = humanoid:FindFirstChildOfClass("Animator")
--     if not animator then 
--         warn(`[Preload] No animator found for {character.Name}`)
--         return 
--     end
    
--     -- Preload common animations
--     local animationFolder = ReplicatedStorage.Assets.Animations
--     local animationsToPreload = {
--         animationFolder.Combat.Stuns.Base,
--         animationFolder.Combat.Stuns.Parry,
--         animationFolder.Combat.Fist,
--         animationFolder.Player.Global.Alchemy,
--         animationFolder.Movements.Dashes,
--         animationFolder.Movements.Runs,
--     }
    
--     local totalAnimations = 0
--     for _, folder in ipairs(animationsToPreload) do
--         for _, anim in ipairs(folder:GetChildren()) do
--             if anim:IsA("Animation") then
--                 totalAnimations += 1
--                 local track = animator:LoadAnimation(anim)
--                 PreloadedAnimations[anim.Name] = track
--             end
--         end
--     end
--     ---- print(`[Preload] Loaded {totalAnimations} animations for {character.Name}`)
    
--     -- Preload sounds and particles
--     local assetsToPreload = {
--         ReplicatedStorage.Assets.Sounds.Combat,
--         ReplicatedStorage.Assets.Particles
--     }
    
--     -- Async preloading to avoid frame drops
--     task.spawn(function()
--         ---- print(`[Preload] Starting async preload for {character.Name}`)
--         local startTime = os.clock()
--         ContentProvider:PreloadAsync(assetsToPreload)
--         ---- print(`[Preload] Finished async preload for {character.Name} in {os.clock() - startTime} seconds`)
--     end)
-- end

-- Initialize physics properties
local function initializePhysics(character)
    ---- print(`[Physics] Initializing physics for {character.Name}`)
    
    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then 
        warn(`[Physics] No HumanoidRootPart found for {character.Name}`)
        return 
    end
    
    ---- print(`[Physics] Waiting for physics properties...`)
    root:GetPropertyChangedSignal("AssemblyLinearVelocity"):Wait()
    root:GetPropertyChangedSignal("AssemblyAngularVelocity"):Wait()
    
    ---- print(`[Physics] Resetting velocities for {character.Name}`)
    root.AssemblyLinearVelocity = Vector3.new()
    root.AssemblyAngularVelocity = Vector3.new()
    
    ---- print(`[Physics] Forcing physics update...`)
    -- RunService.Heartbeat:Wait()
    -- RunService.Stepped:Wait()
    
    ---- print(`[Physics] Physics initialized for {character.Name}`)
end

local function processPlayer(world, player)
    ---- print(`[PlayerLoader] Processing player: {player.Name}`)

    if ref.get("player", player) then
        -- Entity already exists, skip
        return
    end

    ---- print(`[PlayerLoader] Creating entity for {player.Name}`)
    local ent = world:entity()
    ref.define("player", player, ent)
    local e = ref.get("player", player)

    -- OPTIMIZATION: Batch initialize Player and state components in single archetype move
    -- CRITICAL: State components MUST be initialized early for cached queries in state_sync.luau
    -- Previously: 7 world:set() calls = 7 archetype moves
    -- Now: 1 JecsBatch.setMany() call = 1 archetype move (86% reduction)
    JecsBatch.setMany(e, {
        {Player, player},
        {comps.StateActions, {}},
        {comps.StateStuns, {}},
        {comps.StateIFrames, {}},
        {comps.StateSpeeds, {}},
        {comps.StateFrames, {}},
        {comps.StateStatus, {}},
    })
    print(`[PlayerLoader] Player joined: {player.Name} (Entity: {e}) - State components initialized`)

    -- Sync entity ID to client so client and server use the same entity
    -- Use task.defer to give the client time to set up its listener
    -- Also send multiple times with delays to ensure delivery
    task.defer(function()
        -- Wait a short moment for client to initialize
        task.wait(0.1)
        print(`[PlayerLoader] Syncing entity ID {e} to client for {player.Name} (attempt 1)`)
        Bridges.ECSClient:Fire(player, {
            Module = "EntitySync",
            Action = "SetPlayerEntity",
            EntityId = e
        })

        -- Send again after a longer delay as backup
        task.wait(0.5)
        print(`[PlayerLoader] Syncing entity ID {e} to client for {player.Name} (attempt 2)`)
        Bridges.ECSClient:Fire(player, {
            Module = "EntitySync",
            Action = "SetPlayerEntity",
            EntityId = e
        })
    end)

    -- Cleanup old connections
    if playerConnections[player] then
        ---- print(`[PlayerLoader] Cleaning up old connection for {player.Name}`)
        playerConnections[player]:Disconnect()
        playerConnections[player] = nil
    end

    -- Define the character handler as a named function so it can be called
    -- both by CharacterAdded event and manually for existing characters
    local function handleCharacterAdded(initialRig)
    -- Debug the initial state
    print(`[Character] ✅ CharacterAdded fired! Initial spawn - Name: {initialRig.Name}, Parent: {initialRig.Parent and initialRig.Parent:GetFullName() or "nil"}`)

    -- Wait for character to stabilize (detect if it gets respawned)
    local startTime = os.clock()
    local MAX_WAIT_TIME = 30
    local STABLE_WAIT = 0.5 -- Wait 0.5 seconds to see if character gets destroyed/respawned
    local checkInterval = 0.1
    local checksPerformed = 0
    local maxChecks = STABLE_WAIT / checkInterval

    ---- print(`[Character] Monitoring character stability for {player.Name} (checking every {checkInterval}s for {STABLE_WAIT}s)...`)

    -- Monitor the character during the stabilization period
    local currentRig = initialRig
    local rigChanged = false

    while checksPerformed < maxChecks do
        task.wait(checkInterval)
        checksPerformed = checksPerformed + 1

        -- Check if the original character was destroyed OR if player.Character changed
        if not currentRig or not currentRig.Parent or player.Character ~= currentRig then
            if player.Character ~= currentRig then
                warn(`[Character] player.Character changed at check {checksPerformed}/{maxChecks}`)
            else
                warn(`[Character] Character destroyed at check {checksPerformed}/{maxChecks}`)
            end

            -- Wait for the NEW character to spawn
            local newCharacter = player.Character or player.CharacterAdded:Wait()
            ---- print(`[Character] New character detected for {player.Name}: {newCharacter.Name}`)

            currentRig = newCharacter
            rigChanged = true

            -- Reset the check counter to monitor the new character
            checksPerformed = 0
            ---- print(`[Character] Restarting stability monitoring for new character...`)
        elseif checksPerformed % 10 == 0 then
            -- Progress update every second
            ---- print(`[Character] Stability check {checksPerformed}/{maxChecks} - Character still exists`)
        end
    end

    ---- print(`[Character] ✅ Character stabilized after {STABLE_WAIT}s for {player.Name}`)
    local rig = currentRig

    -- Track ancestry changes
    local ancestryConnection
    ancestryConnection = rig.AncestryChanged:Connect(function(child, newParent)
        ---- print(`[Character] Parent changed for {rig.Name}: {newParent and newParent:GetFullName() or "nil"}`)
    end)

    -- Wait for stable location in workspace.World.Live
    local STABLE_CHECKS = 3 -- Need 3 consecutive stable checks
    local stableCount = 0

    while os.clock() - startTime < MAX_WAIT_TIME do
        -- Check if character still exists
        if not rig or not rig.Parent then
            warn(`[Character] {rig and rig.Name or "Character"} was destroyed during initialization`)
            if ancestryConnection then
                ancestryConnection:Disconnect()
            end
            return
        end

        -- Check current location
        if rig:IsDescendantOf(workspace.World.Live) then
            stableCount = stableCount + 1
            ---- print(`[Character] Stable check {stableCount}/{STABLE_CHECKS} in workspace.World.Live`)

            if stableCount >= STABLE_CHECKS then
                break
            end
        else
            stableCount = 0
            ---- print(`[Character] Currently in: {rig.Parent:GetFullName()}`)
        end

        task.wait(0.5)
    end

    -- Clean up connection
    if ancestryConnection then
        ancestryConnection:Disconnect()
    end

    -- Final verification
    if not rig or not rig.Parent then
        warn(`[Character] ERROR: {player.Name}'s character was destroyed before initialization completed`)
        return
    end

    if not rig:IsDescendantOf(workspace.World.Live) then
        warn(`[Character] ERROR: {rig.Name} never stabilized in workspace.World.Live (final location: {rig.Parent:GetFullName()})`)

        -- Debug output of the workspace.World.Live folder contents
        ---- print("[Debug] Current contents of workspace.World.Live:")
        for _, child in ipairs(workspace.World.Live:GetChildren()) do
            ---- print(`- {child:GetFullName()}`)
        end

        return
    end

            ---- print(`[Character] Starting initialization for {rig.Name}`)

            -- CRITICAL: Get fresh entity reference - don't rely on closure
            -- The entity `e` from closure might be stale if something went wrong
            local freshEntity = ref.get("player", player)
            if not freshEntity or not world:contains(freshEntity) then
                warn(`[PlayerLoader] Entity missing for {player.Name}, recreating...`)
                -- Entity was somehow deleted - recreate it
                local newEnt = world:entity()
                ref.define("player", player, newEnt)
                freshEntity = newEnt
                world:set(freshEntity, Player, player)
                -- Sync new entity ID to client
                Bridges.ECSClient:Fire(player, {
                    Module = "EntitySync",
                    Action = "SetPlayerEntity",
                    EntityId = freshEntity
                })
            end
            -- Use fresh entity for all subsequent operations
            local e = freshEntity

            -- CLEAR DEAD TAG ON RESPAWN - ECS death system integration
            -- This ensures players can respawn properly after death
            -- Death state is now fully managed by ECS (Dead tag and DeathInfo component)
            -- No more Roblox Attributes for death tracking
            if world:has(e, tags.Dead) then
                world:remove(e, tags.Dead)
                print(`[PlayerLoader] Cleared Dead tag for {player.Name} on respawn`)
            end
            if world:has(e, comps.DeathInfo) then
                world:remove(e, comps.DeathInfo)
            end

            -- Appearance is now loaded directly from Players.lua after character setup
            -- This ensures it loads on first spawn, not just on reset
            local Server = require(game:GetService("ServerScriptService").ServerConfig.Server)
            print(`[PlayerLoader] Character ready for {player.Name}: {rig.Name}, Parent: {rig.Parent:GetFullName()}`)

            -- Preload assets before initial state

            -- local Entity = Server.Modules["Entities"].Get(Character)
	        -- if not Entity then return end

            ---- print(`[Character] Retrieved player data for {player.Name}`)

            -- OPTIMIZATION: Batch initialize all core components in 2 bulk operations
            -- Previously: ~50+ world:set() calls = ~50+ archetype moves
            -- Now: 2 JecsBatch.setMany() calls = 2 archetype moves (96% reduction)
            -- NOTE: State components (StateActions, etc.) already initialized at entity creation

            -- Get player data for leveling (needed for second batch)
            local LevelingManager = require(ReplicatedStorage.Modules.Utils.LevelingManager)
            local Global = require(ReplicatedStorage.Modules.Shared.Global)
            local playerData = Global.GetData(player)

            -- BATCH 1: Core gameplay components (Character through Heavy)
            JecsBatch.setMany(e, {
                {Character, rig},
                {comps.Health, {current = 175, max = 175, new = 175, old = 175, tick = 0.5, tickspeed = 0.1}},
                {comps.Energy, {current = 100, max = 100, new = 100, old = 100, tick = 0.5, tickspeed = 0.1}},
                {comps.Combat, { weapon = "Fist", equipped = false, animation = "Fist" }},
                {comps.Attacking, {duration = 0, value = false}},
                {comps.Stun, {duration = 0, value = false}},
                {comps.NoRotate, {duration = 0, value = false}},
                -- Dashing, BeingGripped, BeingCarried are now tags - only add when active
                {comps.Blocking, {duration = 0, value = false}},
                {comps.Carrying, {target = nil, value = false}},
                {comps.DeathLocation, CFrame.new(0,0,0)},
                {comps.Knocked, {duration = 0, value = false}},
                {comps.IFrame, {duration = 0, value = false}},
                {comps.Sprinting, {value = false}},
                {comps.Ragdoll, {duration = 0, value = false}},
                {comps.CantMove, {duration = 0, value = false}},
                -- Dead, WallRunning are now tags - only add when active
                {comps.Weapon, {name = "Fist", type = "Fist"}},
                {comps.Sliding, {direction = CFrame.new(), value = false}},
                {comps.NoJump, {duration = 0, value = false}},
                {comps.ToSpeed, 0},
                {comps.Light, {duration = 0, value = false}},
                {comps.NoDash, {duration = 0, value = false}},
            })

            -- Initialize leveling components with saved data (uses its own world:set calls)
            LevelingManager.initialize(e, playerData)
            ---- print(`[Character] Initialized leveling components for {player.Name} - Level: {playerData and playerData.Level or 1}, XP: {playerData and playerData.Experience or 0}`)

            -- BATCH 2: Combat and status components
            JecsBatch.setMany(e, {
                {comps.NoHurt, {duration = 0, value = false}},
                {comps.Damage, 0},
                {comps.ParryTick, {duration = 0, value = false}},
                -- InAir, BlockBroken, NoRagdoll, CustomOst, Special are now tags - only add when active
                {comps.Action, {duration = 0, value = false}},
                {comps.BlockBar, {Value = 0, MaxValue = 100}},  -- Start at 0, increases to 100 when blocking hits
                {comps.BBRegen, {value = false, duration = 0}},
                {comps.Armor, {duration = 0, armortype = "None", value = false}},
                {comps.InCombat, {duration = 0, value = false}},
                {comps.Focus, {
                    current = 0, max = 50, decayRate = 0.3,
                    permanentFloor = 0, tempFloor = 0,
                    trainingXP = 0, trainingLevel = 0,
                    inMiniMode = false, inAbsoluteMode = false,
                }},
                {comps.Locked, {duration = 0, value = false}},
                {comps.Attack, {type = "None", name = "None"}},
                {comps.Inventory, {items = {}, maxSlots = 50}},
                {comps.Hotbar, {slots = {}, activeSlot = 1}},
            })

            -- Initialize LimbState from player data (persistent limb loss)
            local LimbManager = require(ReplicatedStorage.Modules.Utils.LimbManager)
            local savedLimbState = playerData and playerData.LimbState
            if savedLimbState then
                -- Use saved limb state
                world:set(e, comps.LimbState, {
                    leftArm = savedLimbState.leftArm ~= false,
                    rightArm = savedLimbState.rightArm ~= false,
                    leftLeg = savedLimbState.leftLeg ~= false,
                    rightLeg = savedLimbState.rightLeg ~= false,
                    bleedingStacks = savedLimbState.bleedingStacks or 0,
                })

                -- Physically sever any limbs that were missing
                for limbName, isAttached in pairs(savedLimbState) do
                    if limbName ~= "bleedingStacks" and isAttached == false then
                        LimbManager.SeverLimb(rig, limbName)
                        print(`[PlayerLoader] Restored severed limb {limbName} for {player.Name}`)
                    end
                end
            else
                -- Default: all limbs attached
                world:set(e, comps.LimbState, LimbManager.GetDefaultLimbState())
            end

            ---- print(`[Character] Finished initializing {rig.Name} for {player.Name}`)

            -- Give starter items to player
            local InventorySetup = require(ReplicatedStorage.Modules.Utils.InventorySetup)
            InventorySetup.giveStarterItems(e)
            print(`[PlayerLoader] ✅ Gave starter items to {player.Name}`)

            -- Notify client that all components are ready
            ---- print(`[Character] Notifying client that entity {e} is fully initialized`)
            Bridges.ECSClient:Fire(player, {
                Module = "EntitySync",
                Action = "EntityReady",
                EntityId = e
            })

            -- Load saved Focus training data before marking ready
            local FocusHandler = require(game:GetService("ServerScriptService").ServerConfig.Server.FocusHandler)
            FocusHandler.LoadTrainingData(player, e)

            -- Mark components as ready - this signals to systems that they can start processing this entity
            world:add(e, comps.ComponentsReady) -- Tag: indicates entity is fully initialized
            print(`[PlayerLoader] ✅ All components initialized for {player.Name} (Entity: {e})`)

            -- Explicitly sync inventory to client after all components are ready
            -- This ensures the client receives inventory even on first spawn
            -- Use task.defer with delay to ensure entity sync has arrived on client first
            task.defer(function()
                -- Wait for entity sync to reach client (sent at 0.1s and 0.6s)
                task.wait(0.3)
                local InventoryManager = require(ReplicatedStorage.Modules.Utils.InventoryManager)
                print(`[PlayerLoader] 🔄 Sending inventory sync to {player.Name}...`)
                InventoryManager.forceSync(e)
                print(`[PlayerLoader] ✅ Forced inventory sync for {player.Name}`)

                -- Send another sync after entity sync backup has been sent
                task.wait(0.5)
                print(`[PlayerLoader] 🔄 Sending backup inventory sync to {player.Name}...`)
                InventoryManager.forceSync(e)
                print(`[PlayerLoader] ✅ Backup inventory sync for {player.Name}`)
            end)

            -- Give weapon skills AFTER components are initialized
            -- Use task.defer to ensure all components are fully set before giving skills
            task.defer(function()
                ---- print(`[Character] 🎯 Starting weapon skills setup for {player.Name}`)
                local InventorySetup = require(ReplicatedStorage.Modules.Utils.InventorySetup)

                -- Wait for weapon attribute to be set (with timeout)
                local weapon = player:GetAttribute("Weapon")
                ---- print(`[Character] 🔍 Initial weapon check for {player.Name}: {weapon or "nil"}`)

                local maxWaitTime = 5 -- Maximum 5 seconds to wait
                local waitStartTime = os.clock()
                local attempts = 0

                while not weapon and (os.clock() - waitStartTime) < maxWaitTime do
                    task.wait(0.1)
                    weapon = player:GetAttribute("Weapon")
                    attempts = attempts + 1
                    if attempts % 10 == 0 then
                        ---- print(`[Character] ⏳ Still waiting for weapon attribute for {player.Name} (attempt {attempts})`)
                    end
                end

                if weapon then
                    ---- print(`[Character] ✅ Weapon found for {player.Name}: {weapon}`)
                    ---- print(`[Character] 🎁 Giving weapon skills - Entity: {e}, Weapon: {weapon}, Player: {player.Name}`)

                    local success, err = pcall(function()
                        InventorySetup.GiveWeaponSkills(e, weapon, player)
                    end)

                    if success then
                        ---- print(`[Character] ✅ Successfully gave weapon skills to {player.Name}`)
                    else
                        warn(`[Character] ❌ ERROR giving weapon skills to {player.Name}:`, err)
                    end
                else
                    warn(`[Character] ⚠️ No weapon attribute found for {player.Name} after {maxWaitTime} seconds - defaulting to Fist`)
                    -- Default to Fist if no weapon attribute is set
                    weapon = "Fist"
                    player:SetAttribute("Weapon", weapon)
                    ---- print(`[Character] 🔧 Set default weapon to Fist for {player.Name}`)

                    local success, err = pcall(function()
                        InventorySetup.GiveWeaponSkills(e, weapon, player)
                    end)

                    if success then
                        ---- print(`[Character] ✅ Successfully gave default weapon skills to {player.Name}`)
                    else
                        warn(`[Character] ❌ ERROR giving default weapon skills to {player.Name}:`, err)
                    end
                end
            end)

            ---- print(`[Character] Preloading assets for {rig.Name}`)
            -- preloadCharacterAssets(rig)

            ---- print(`[Character] Initializing physics for {rig.Name}`)
            -- initializePhysics(rig)
            -- cleanup()
    end -- end of handleCharacterAdded function

    -- Connect the handler to CharacterAdded event
    print(`[PlayerLoader] Setting up CharacterAdded connection for {player.Name}`)
    playerConnections[player] = player.CharacterAdded:Connect(handleCharacterAdded)

    -- Initialize existing character
    -- If player already has a character when we set up the listener,
    -- CharacterAdded won't fire again, so we need to manually trigger it
    if player.Character and player.Character:IsDescendantOf(workspace) then
        print(`[PlayerLoader] Player {player.Name} has existing character - manually triggering handler`)
        task.spawn(handleCharacterAdded, player.Character)
    else
        print(`[PlayerLoader] Player {player.Name} has no existing character - waiting for CharacterAdded`)
    end
end

-- Track which players have been processed to avoid duplicate processing
local processedPlayers = {}

-- CRITICAL: Set up PlayerRemoving listener to clean up entities when players leave
-- This prevents massive memory leaks in the ECS world
Players.PlayerRemoving:Connect(function(player)
    print(`[PlayerLoader] 🧹 Player {player.Name} leaving - cleaning up ECS entity...`)

    -- Remove from processed players tracking
    processedPlayers[player] = nil

    -- Disconnect character connection
    if playerConnections[player] then
        playerConnections[player]:Disconnect()
        playerConnections[player] = nil
        print(`[PlayerLoader] ✅ Disconnected CharacterAdded for {player.Name}`)
    end

    -- Save Focus training data before entity cleanup
    local entity = ref.get("player", player)
    if entity then
        local focusData = world:get(entity, comps.Focus)
        if focusData and focusData.trainingXP > 0 then
            local FocusHandler = require(game:GetService("ServerScriptService").ServerConfig.Server.FocusHandler)
            FocusHandler.SaveTrainingData(player, focusData)
        end

        print(`[PlayerLoader] 🗑️ Deleting entity {entity} for {player.Name}`)
        -- Clean up all per-entity tracking tables before deleting
        EntityCleanup.cleanup(entity)
        -- Delete entity from world (removes all components)
        if world:contains(entity) then
            world:delete(entity)
        end
        -- Also clean up the ref tracking
        ref.untrack("player", player)
        print(`[PlayerLoader] ✅ Entity deleted for {player.Name}`)
    else
        print(`[PlayerLoader] ⚠️ No entity found for {player.Name}`)
    end
end)

return {
    run = function(_world)
        -- Heartbeat phase: Check all players every frame, but only process new ones
        for _, player in ipairs(Players:GetPlayers()) do
            if not processedPlayers[player] then
                processedPlayers[player] = true
                processPlayer(world, player)
            end
        end
    end,

    cleanup = function(_world, player)
        -- print(`[Cleanup] Cleaning up resources for {player.Name}`)

        -- Remove from processed players tracking
        processedPlayers[player] = nil

        -- Disconnect character connection
        if playerConnections[player] then
            playerConnections[player]:Disconnect()
            playerConnections[player] = nil
            -- print(`[Cleanup] Disconnected CharacterAdded for {player.Name}`)
        end

        -- Clean up entity - MUST delete to prevent memory leaks
        local entity = ref.get("player", player)
        if entity then
            -- print(`[Cleanup] Deleting entity {entity} for {player.Name}`)
            -- Clean up all per-entity tracking tables before deleting
            EntityCleanup.cleanup(entity)
            ref.delete("player", player) -- This calls world:delete internally
        end
    end,

    settings = {
        phase = "Heartbeat",  -- Use Heartbeat to catch players that joined before ECS started
        depends_on = {},
        server_only = true
    }
}