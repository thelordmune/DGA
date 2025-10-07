local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ref = require(ReplicatedStorage.Modules.ECS.jecs_ref)
local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)
local world = require(ReplicatedStorage.Modules.ECS.jecs_world)
local Server = require(game:GetService("ServerScriptService").ServerConfig.Server)
-- local global = require(ReplicatedStorage.Global)
local Player = comps.Player
local Character = comps.Character
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Sift = require(ReplicatedStorage.Modules.Imports.Sift)

-- Animation preloading cache
local PreloadedAnimations = {}
local playerConnections = {}
local ContentProvider = game:GetService("ContentProvider")

-- Function to preload assets for a character
-- local function preloadCharacterAssets(character)
--     print(`[Preload] Starting asset preload for {character.Name}`)
    
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
--     print(`[Preload] Loaded {totalAnimations} animations for {character.Name}`)
    
--     -- Preload sounds and particles
--     local assetsToPreload = {
--         ReplicatedStorage.Assets.Sounds.Combat,
--         ReplicatedStorage.Assets.Particles
--     }
    
--     -- Async preloading to avoid frame drops
--     task.spawn(function()
--         print(`[Preload] Starting async preload for {character.Name}`)
--         local startTime = os.clock()
--         ContentProvider:PreloadAsync(assetsToPreload)
--         print(`[Preload] Finished async preload for {character.Name} in {os.clock() - startTime} seconds`)
--     end)
-- end

-- Initialize physics properties
local function initializePhysics(character)
    print(`[Physics] Initializing physics for {character.Name}`)
    
    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then 
        warn(`[Physics] No HumanoidRootPart found for {character.Name}`)
        return 
    end
    
    print(`[Physics] Waiting for physics properties...`)
    root:GetPropertyChangedSignal("AssemblyLinearVelocity"):Wait()
    root:GetPropertyChangedSignal("AssemblyAngularVelocity"):Wait()
    
    print(`[Physics] Resetting velocities for {character.Name}`)
    root.AssemblyLinearVelocity = Vector3.new()
    root.AssemblyAngularVelocity = Vector3.new()
    
    print(`[Physics] Forcing physics update...`)
    -- RunService.Heartbeat:Wait()
    -- RunService.Stepped:Wait()
    
    print(`[Physics] Physics initialized for {character.Name}`)
end

return {
    run = function(world, player)
        print(`[PlayerLoader] Processing player: {player.Name}`)
        
        if ref.get("player", player) then 
            print(`[PlayerLoader] {player.Name} already has an entity, skipping`)
            return 
        end
        
        print(`[PlayerLoader] Creating entity for {player.Name}`)
        local ent = world:entity()
        ref.define("player", player, ent)
        local e = ref.get("player", player)
        world:set(e, Player, player)
        print(`[PlayerLoader] Player joined: {player.Name} (Entity: {e})`)

        -- Cleanup old connections
        if playerConnections[player] then
            print(`[PlayerLoader] Cleaning up old connection for {player.Name}`)
            playerConnections[player]:Disconnect()
            playerConnections[player] = nil
        end

        print(`[PlayerLoader] Setting up CharacterAdded connection for {player.Name}`)
playerConnections[player] = player.CharacterAdded:Connect(function(rig)
    -- Debug the initial state
    print(`[Character] Initial state - Name: {rig.Name}, Parent: {rig.Parent and rig.Parent:GetFullName() or "nil"}`)
    
    -- Track ancestry changes
    local ancestryConnection
    ancestryConnection = rig.AncestryChanged:Connect(function(child, newParent)
        print(`[Character] Parent changed for {rig.Name}: {newParent and newParent:GetFullName() or "nil"}`)
    end)

    -- Wait for stable location in Entities
    local startTime = os.clock()
    local MAX_WAIT_TIME = 60 -- Increased timeout to 60 seconds
    local STABLE_CHECKS = 5 -- Need 5 consecutive stable checks
    
    local stableCount = 0
    local lastValidParent = rig.Parent
    
    while os.clock() - startTime < MAX_WAIT_TIME do
        -- Check if character still exists
        if not rig or not rig.Parent then
            warn(`[Character] {rig and rig.Name or "Character"} was destroyed during initialization`)
            break
        end
        
        -- Check current location
        if rig:IsDescendantOf(workspace.World.Live) then
            stableCount = stableCount + 1
            print(`[Character] Stable check {stableCount}/{STABLE_CHECKS} in Entities`)
            
            if stableCount >= STABLE_CHECKS then
                break
            end
        else
            stableCount = 0
            print(`[Character] Currently in: {rig.Parent:GetFullName()}`)
        end
        
        task.wait(0.5) -- Longer wait between checks
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
        warn(`[Character] ERROR: {rig.Name} never stabilized in Entities (final location: {rig.Parent:GetFullName()})`)
        
        -- Debug output of the Entities folder contents
        print("[Debug] Current contents of workspace.Entities:")
        for _, child in ipairs(workspace.World.Live:GetChildren()) do
            print(`- {child:GetFullName()}`)
        end
        
        return
    end
            
            print(`[Character] Starting initialization for {rig.Name}`)
            
            -- Preload assets before initial state

            -- local Entity = Server.Modules["Entities"].Get(Character)
	        -- if not Entity then return end
            
            print(`[Character] Retrieved player data for {player.Name}`)

            -- Initialize all components
            print(`[Character] Setting ECS components for {rig.Name}`)
            world:set(e, Character, rig)
            world:set(e, comps.Health, {current = 175, max = 175, tick = 0.5, tickspeed = 0.1})
            world:set(e, comps.Energy, {current = 100, tick = 0.5, tickspeed = 0.1})
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
            world:set(e, comps.IgnoreParry, {duration = 0, value = false})
            world:set(e, comps.NoHurt, {duration = 0, value = false})
            world:set(e, comps.Damage, 0)
            world:set(e, comps.ParryTick, {duration = 0, value = false})
            world:set(e, comps.ParryStun, {duration = 0, value = false})
            world:set(e, comps.InAir, false)
            world:set(e, comps.Utility, {duration = 0, value = false})
            world:set(e, comps.Victim, nil)
            world:set(e, comps.Action, {duration = 0, value = false})
            world:set(e, comps.BlockBar, {Value = 100, MaxValue = 100})
            world:set(e, comps.BBRegen, {value = false, duration = 0})
            world:set(e, comps.BlockBroken, false)
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

            print(`[Character] Finished initializing {rig.Name} for {player.Name}`)

            -- Give weapon skills AFTER components are initialized
            -- Use task.defer to ensure all components are fully set before giving skills
            task.defer(function()
                print(`[Character] 🎯 Starting weapon skills setup for {player.Name}`)
                local InventorySetup = require(ReplicatedStorage.Modules.Utils.InventorySetup)

                -- Wait for weapon attribute to be set (with timeout)
                local weapon = player:GetAttribute("Weapon")
                print(`[Character] 🔍 Initial weapon check for {player.Name}: {weapon or "nil"}`)

                local maxWaitTime = 5 -- Maximum 5 seconds to wait
                local waitStartTime = os.clock()
                local attempts = 0

                while not weapon and (os.clock() - waitStartTime) < maxWaitTime do
                    task.wait(0.1)
                    weapon = player:GetAttribute("Weapon")
                    attempts = attempts + 1
                    if attempts % 10 == 0 then
                        print(`[Character] ⏳ Still waiting for weapon attribute for {player.Name} (attempt {attempts})`)
                    end
                end

                if weapon then
                    print(`[Character] ✅ Weapon found for {player.Name}: {weapon}`)
                    print(`[Character] 🎁 Giving weapon skills - Entity: {e}, Weapon: {weapon}, Player: {player.Name}`)

                    local success, err = pcall(function()
                        InventorySetup.GiveWeaponSkills(e, weapon, player)
                    end)

                    if success then
                        print(`[Character] ✅ Successfully gave weapon skills to {player.Name}`)
                    else
                        warn(`[Character] ❌ ERROR giving weapon skills to {player.Name}:`, err)
                    end
                else
                    warn(`[Character] ⚠️ No weapon attribute found for {player.Name} after {maxWaitTime} seconds - defaulting to Fist`)
                    -- Default to Fist if no weapon attribute is set
                    weapon = "Fist"
                    player:SetAttribute("Weapon", weapon)
                    print(`[Character] 🔧 Set default weapon to Fist for {player.Name}`)

                    local success, err = pcall(function()
                        InventorySetup.GiveWeaponSkills(e, weapon, player)
                    end)

                    if success then
                        print(`[Character] ✅ Successfully gave default weapon skills to {player.Name}`)
                    else
                        warn(`[Character] ❌ ERROR giving default weapon skills to {player.Name}:`, err)
                    end
                end
            end)

            print(`[Character] Preloading assets for {rig.Name}`)
            -- preloadCharacterAssets(rig)
            
            print(`[Character] Initializing physics for {rig.Name}`)
            -- initializePhysics(rig)
            -- cleanup()
        end)
        
        -- Initialize existing character
        if player.Character and player.Character:IsDescendantOf(workspace) then
            print(`[PlayerLoader] Player {player.Name} has existing character, initializing`)
            playerConnections[player]._signal:Fire(player.Character)
        else
            print(`[PlayerLoader] Player {player.Name} has no existing character`)
        end
    end,
    
    cleanup = function(world, player)
        print(`[Cleanup] Cleaning up resources for {player.Name}`)
        if playerConnections[player] then
            playerConnections[player]:Disconnect()
            playerConnections[player] = nil
            print(`[Cleanup] Disconnected CharacterAdded for {player.Name}`)
        end
    end,
    
    settings = {
        phase = "PlayerAdded",  -- Changed from Heartbeat to PlayerAdded to properly receive player events
        depends_on = {},
        server_only = true
    }
}