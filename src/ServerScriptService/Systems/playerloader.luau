local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RefManager = require(ReplicatedStorage.Modules.ECS.jecs_ref_manager)
local ref = RefManager.player -- Use player-specific ref system
local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)
local world = require(ReplicatedStorage.Modules.ECS.jecs_world)
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
--     -- print(`[Preload] Starting asset preload for {character.Name}`)
    
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
--     -- print(`[Preload] Loaded {totalAnimations} animations for {character.Name}`)
    
--     -- Preload sounds and particles
--     local assetsToPreload = {
--         ReplicatedStorage.Assets.Sounds.Combat,
--         ReplicatedStorage.Assets.Particles
--     }
    
--     -- Async preloading to avoid frame drops
--     task.spawn(function()
--         -- print(`[Preload] Starting async preload for {character.Name}`)
--         local startTime = os.clock()
--         ContentProvider:PreloadAsync(assetsToPreload)
--         -- print(`[Preload] Finished async preload for {character.Name} in {os.clock() - startTime} seconds`)
--     end)
-- end

-- Initialize physics properties
local function initializePhysics(character)
    -- print(`[Physics] Initializing physics for {character.Name}`)
    
    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then 
        warn(`[Physics] No HumanoidRootPart found for {character.Name}`)
        return 
    end
    
    -- print(`[Physics] Waiting for physics properties...`)
    root:GetPropertyChangedSignal("AssemblyLinearVelocity"):Wait()
    root:GetPropertyChangedSignal("AssemblyAngularVelocity"):Wait()
    
    -- print(`[Physics] Resetting velocities for {character.Name}`)
    root.AssemblyLinearVelocity = Vector3.new()
    root.AssemblyAngularVelocity = Vector3.new()
    
    -- print(`[Physics] Forcing physics update...`)
    -- RunService.Heartbeat:Wait()
    -- RunService.Stepped:Wait()
    
    -- print(`[Physics] Physics initialized for {character.Name}`)
end

local function processPlayer(world, player)
    -- print(`[PlayerLoader] Processing player: {player.Name}`)

    if ref.get("player", player) then
        -- Entity already exists, skip
        return
    end

    -- print(`[PlayerLoader] Creating entity for {player.Name}`)
    local ent = world:entity()
    ref.define("player", player, ent)
    local e = ref.get("player", player)
    world:set(e, Player, player)
    -- print(`[PlayerLoader] Player joined: {player.Name} (Entity: {e})`)

    -- Sync entity ID to client so client and server use the same entity
    -- print(`[PlayerLoader] Syncing entity ID {e} to client for {player.Name}`)
    Bridges.ECSClient:Fire(player, {
        Module = "EntitySync",
        Action = "SetPlayerEntity",
        EntityId = e
    })

    -- Cleanup old connections
    if playerConnections[player] then
        -- print(`[PlayerLoader] Cleaning up old connection for {player.Name}`)
        playerConnections[player]:Disconnect()
        playerConnections[player] = nil
    end

    -- print(`[PlayerLoader] Setting up CharacterAdded connection for {player.Name}`)
    playerConnections[player] = player.CharacterAdded:Connect(function(initialRig)
    -- Debug the initial state
    -- print(`[Character] Initial spawn - Name: {initialRig.Name}, Parent: {initialRig.Parent and initialRig.Parent:GetFullName() or "nil"}`)

    -- Wait for character to stabilize (detect if it gets respawned)
    local startTime = os.clock()
    local MAX_WAIT_TIME = 60
    local STABLE_WAIT = 5 -- Wait 5 seconds to see if character gets destroyed/respawned
    local checkInterval = 0.1
    local checksPerformed = 0
    local maxChecks = STABLE_WAIT / checkInterval

    -- print(`[Character] Monitoring character stability for {player.Name} (checking every {checkInterval}s for {STABLE_WAIT}s)...`)

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
            -- print(`[Character] New character detected for {player.Name}: {newCharacter.Name}`)

            currentRig = newCharacter
            rigChanged = true

            -- Reset the check counter to monitor the new character
            checksPerformed = 0
            -- print(`[Character] Restarting stability monitoring for new character...`)
        elseif checksPerformed % 10 == 0 then
            -- Progress update every second
            -- print(`[Character] Stability check {checksPerformed}/{maxChecks} - Character still exists`)
        end
    end

    -- print(`[Character] ✅ Character stabilized after {STABLE_WAIT}s for {player.Name}`)
    local rig = currentRig

    -- Track ancestry changes
    local ancestryConnection
    ancestryConnection = rig.AncestryChanged:Connect(function(child, newParent)
        -- print(`[Character] Parent changed for {rig.Name}: {newParent and newParent:GetFullName() or "nil"}`)
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
            -- print(`[Character] Stable check {stableCount}/{STABLE_CHECKS} in workspace.World.Live`)

            if stableCount >= STABLE_CHECKS then
                break
            end
        else
            stableCount = 0
            -- print(`[Character] Currently in: {rig.Parent:GetFullName()}`)
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
        -- print("[Debug] Current contents of workspace.World.Live:")
        for _, child in ipairs(workspace.World.Live:GetChildren()) do
            -- print(`- {child:GetFullName()}`)
        end

        return
    end

            -- print(`[Character] Starting initialization for {rig.Name}`)

            -- Load appearance AFTER character has stabilized
            -- This ensures clothing is applied to the final character, not a temporary one
            local Server = require(game:GetService("ServerScriptService").ServerConfig.Server)
            local Appearance = require(game:GetService("ServerScriptService").ServerConfig.Server.Entities.Appearance)
            print(`[PlayerLoader] 🎨 Loading appearance for {player.Name} after character stabilization`)
            Appearance.Load(player)

            -- Preload assets before initial state

            -- local Entity = Server.Modules["Entities"].Get(Character)
	        -- if not Entity then return end

            -- print(`[Character] Retrieved player data for {player.Name}`)

            -- Initialize all components
            -- print(`[Character] Setting ECS components for {rig.Name}`)
            world:set(e, Character, rig)
            world:set(e, comps.Health, {current = 175, max = 175, new = 175, old = 175, tick = 0.5, tickspeed = 0.1})
            world:set(e, comps.Energy, {current = 100, max = 100, new = 100, old = 100, tick = 0.5, tickspeed = 0.1})
            world:set(e, comps.Combat, { weapon = "Fist", equipped = false, animation = "Fist" })
            world:set(e, comps.Attacking, {duration = 0, value = false})
            world:set(e, comps.Stun, {duration = 0, value = false})
            world:set(e, comps.NoRotate, {duration = 0, value = false})
            world:set(e, comps.Dashing, false)
            world:set(e, comps.Blocking, {duration = 0, value = false})
            world:set(e, comps.Carrying, {target = nil, value = false})
            world:set(e, comps.BeingGripped, false)
            world:set(e, comps.BeingCarried, false)
            world:set(e, comps.DeathLocation, CFrame.new(0,0,0))
            world:set(e, comps.Knocked, {duration = 0, value = false})
            world:set(e, comps.IFrame, {duration = 0, value = false})
            world:set(e, comps.Sprinting, false)
            world:set(e, comps.Ragdoll, {duration = 0, value = false})
            world:set(e, comps.CantMove, {duration = 0, value = false})
            world:set(e, comps.Dead, false)
            world:set(e, comps.Weapon, {name = "Fist", type = "Fist"}) 
            world:set(e, comps.Swing, 1)
            world:set(e, comps.WallRunning, false)
            world:set(e, comps.Sliding, false)
            world:set(e, comps.NoJump, {duration = 0, value = false})
            world:set(e, comps.ToSpeed, 0)
            world:set(e, comps.KeysLogged, 1)
            world:set(e, comps.Light, {duration = 0, value = false})
            world:set(e, comps.NoDash, {duration = 0, value = false})
            world:set(e, comps.LastHit, 0)
            world:set(e, comps.CritCD, {duration = 0, value = false})
            world:set(e, comps.Heavy, {duration = 0, value = false})

            -- Initialize leveling components with saved data
            local LevelingManager = require(ReplicatedStorage.Modules.Utils.LevelingManager)
            local Global = require(ReplicatedStorage.Modules.Shared.Global)
            local playerData = Global.GetData(player)
            LevelingManager.initialize(e, playerData)
            -- print(`[Character] Initialized leveling components for {player.Name} - Level: {playerData and playerData.Level or 1}, XP: {playerData and playerData.Experience or 0}`)
            world:set(e, comps.IgnoreParry, {duration = 0, value = false})
            world:set(e, comps.NoHurt, {duration = 0, value = false})
            world:set(e, comps.Damage, 0)
            world:set(e, comps.ParryTick, {duration = 0, value = false})
            world:set(e, comps.ParryStun, {duration = 0, value = false})
            world:set(e, comps.InAir, false)
            world:set(e, comps.Utility, {duration = 0, value = false})
            world:set(e, comps.Victim, nil)
            world:set(e, comps.Action, {duration = 0, value = false})
            world:set(e, comps.BlockBar, {Value = 0, MaxValue = 100})  -- Start at 0, increases to 100 when blocking hits
            world:set(e, comps.BBRegen, {value = false, duration = 0})
            world:set(e, comps.BlockBroken, false)
            world:set(e, comps.Adrenaline, {value = 0, comboHits = 0}) -- Initialize adrenaline system
            world:set(e, comps.Armor, {duration = 0, armortype = "None", value = false})
            world:set(e, comps.QDC, {duration = 0, value = false})
            world:set(e, comps.NoRagdoll, false)
            world:set(e, comps.InCombat, false)
            world:set(e, comps.CustomOst, false)
            world:set(e, comps.Locked, {duration = 0, value = false})
            world:set(e, comps.Special, false)
            world:set(e, comps.Attack, {type = "None", name = "None"})
            world:set(e, comps.Inventory, {items = {}, maxSlots = 50})
            world:set(e, comps.Hotbar, {slots = {}, activeSlot = 1})

            -- print(`[Character] Finished initializing {rig.Name} for {player.Name}`)

            -- Notify client that all components are ready
            -- print(`[Character] Notifying client that entity {e} is fully initialized`)
            Bridges.ECSClient:Fire(player, {
                Module = "EntitySync",
                Action = "EntityReady",
                EntityId = e
            })

            -- Mark components as ready - this signals to systems that they can start processing this entity
            world:set(e, comps.ComponentsReady, true)
            print(`[PlayerLoader] ✅ All components initialized for {player.Name} (Entity: {e})`)

            -- Sync initial adrenaline value to client
            task.defer(function()
                -- Give the client a moment to initialize UI
                task.wait(0.5)
                Bridges.UpdateAdrenaline:Fire(player, { adrenaline = 0 })
            end)

            -- Give weapon skills AFTER components are initialized
            -- Use task.defer to ensure all components are fully set before giving skills
            task.defer(function()
                -- print(`[Character] 🎯 Starting weapon skills setup for {player.Name}`)
                local InventorySetup = require(ReplicatedStorage.Modules.Utils.InventorySetup)

                -- Wait for weapon attribute to be set (with timeout)
                local weapon = player:GetAttribute("Weapon")
                -- print(`[Character] 🔍 Initial weapon check for {player.Name}: {weapon or "nil"}`)

                local maxWaitTime = 5 -- Maximum 5 seconds to wait
                local waitStartTime = os.clock()
                local attempts = 0

                while not weapon and (os.clock() - waitStartTime) < maxWaitTime do
                    task.wait(0.1)
                    weapon = player:GetAttribute("Weapon")
                    attempts = attempts + 1
                    if attempts % 10 == 0 then
                        -- print(`[Character] ⏳ Still waiting for weapon attribute for {player.Name} (attempt {attempts})`)
                    end
                end

                if weapon then
                    -- print(`[Character] ✅ Weapon found for {player.Name}: {weapon}`)
                    -- print(`[Character] 🎁 Giving weapon skills - Entity: {e}, Weapon: {weapon}, Player: {player.Name}`)

                    local success, err = pcall(function()
                        InventorySetup.GiveWeaponSkills(e, weapon, player)
                    end)

                    if success then
                        -- print(`[Character] ✅ Successfully gave weapon skills to {player.Name}`)
                    else
                        warn(`[Character] ❌ ERROR giving weapon skills to {player.Name}:`, err)
                    end
                else
                    warn(`[Character] ⚠️ No weapon attribute found for {player.Name} after {maxWaitTime} seconds - defaulting to Fist`)
                    -- Default to Fist if no weapon attribute is set
                    weapon = "Fist"
                    player:SetAttribute("Weapon", weapon)
                    -- print(`[Character] 🔧 Set default weapon to Fist for {player.Name}`)

                    local success, err = pcall(function()
                        InventorySetup.GiveWeaponSkills(e, weapon, player)
                    end)

                    if success then
                        -- print(`[Character] ✅ Successfully gave default weapon skills to {player.Name}`)
                    else
                        warn(`[Character] ❌ ERROR giving default weapon skills to {player.Name}:`, err)
                    end
                end
            end)

            -- print(`[Character] Preloading assets for {rig.Name}`)
            -- preloadCharacterAssets(rig)
            
            -- print(`[Character] Initializing physics for {rig.Name}`)
            -- initializePhysics(rig)
            -- cleanup()
        end)

        -- Initialize existing character
        if player.Character and player.Character:IsDescendantOf(workspace) then
            -- print(`[PlayerLoader] Player {player.Name} has existing character, initializing`)
            playerConnections[player]._signal:Fire(player.Character)
        else
            -- print(`[PlayerLoader] Player {player.Name} has no existing character`)
        end
end

-- Track which players have been processed to avoid duplicate processing
local processedPlayers = {}

return {
    run = function(world)
        -- Heartbeat phase: Check all players every frame, but only process new ones
        for _, player in ipairs(Players:GetPlayers()) do
            if not processedPlayers[player] then
                processedPlayers[player] = true
                processPlayer(world, player)
            end
        end
    end,

    cleanup = function(world, player)
        -- print(`[Cleanup] Cleaning up resources for {player.Name}`)

        -- Remove from processed players tracking
        processedPlayers[player] = nil

        -- Disconnect character connection
        if playerConnections[player] then
            playerConnections[player]:Disconnect()
            playerConnections[player] = nil
            -- print(`[Cleanup] Disconnected CharacterAdded for {player.Name}`)
        end

        -- Clean up entity reference
        local entity = ref.get("player", player)
        if entity then
            -- print(`[Cleanup] Removing entity {entity} for {player.Name}`)
            -- Note: Don't delete the entity, just remove the reference
            -- The entity will be cleaned up by the ECS system
        end
    end,

    settings = {
        phase = "Heartbeat",  -- Use Heartbeat to catch players that joined before ECS started
        depends_on = {},
        server_only = true
    }
}