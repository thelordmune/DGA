--[[
    Smart Defense System for NPCs
    
    Analyzes what the player is doing and reacts appropriately:
    - Parry: Quick attacks (M1 combos, fast skills)
    - Block: Heavy attacks (M2, Critical, blockbreak skills)
    - Dodge: AOE attacks, unblockable attacks
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StateManager = require(ReplicatedStorage.Modules.ECS.StateManager)

-- Get Server from main VM
local function getServer()
    local Server = require(ServerScriptService.ServerConfig.Server)
    if _G.ServerModules then
        Server.Modules = _G.ServerModules
    end
    return Server
end

local Server = getServer()

-- Helper to get what action the player is performing using ECS StateManager
local function getPlayerAction(target)
    local allActions = StateManager.GetAllStates(target, "Actions")
    -- Return the first action found (most recent)
    return allActions[1]
end

-- Determine the best defensive response based on player's action
local function getBestDefense(playerAction, distance)
    if not playerAction then
        return nil
    end

    -- Check for M1 attacks (M11, M12, M13, M14)
    -- M1 states are stored as "M11", "M12", "M13", "M14" in Actions
    if string.match(playerAction, "^M1") then
        -- M1 attacks - prefer parrying for aggressive counter-play
        if distance < 12 then
            -- 40% chance to parry, 45% chance to block, 15% no defense (much more reactive!)
            local roll = math.random()
            if roll < 0.40 then
                return "Parry"
            elseif roll < 0.85 then
                return "Block"
            else
                return nil
            end
        else
            return nil -- Too far to react
        end
    end

    -- Check for M2 attacks (Critical)
    if playerAction == "M2" then
        -- M2 attacks are heavier, prefer blocking but can parry
        if distance < 14 then
            -- 60% block, 25% parry, 15% no defense
            local roll = math.random()
            if roll < 0.60 then
                return "Block"
            elseif roll < 0.85 then
                return "Parry"
            else
                return nil
            end
        else
            return nil
        end
    end

    -- Check for Running Attack
    if playerAction == "RunningAttack" then
        -- Running attacks - prefer parrying for counter-attack
        if distance < 12 then
            -- 50% parry, 35% block, 15% no defense
            local roll = math.random()
            if roll < 0.50 then
                return "Parry"
            elseif roll < 0.85 then
                return "Block"
            else
                return nil
            end
        else
            return nil
        end
    end
    
    -- Check for blocking state - this is handled separately in intelligent_attack
    if playerAction == "Blocking" then
        -- Player is blocking, smart_defense doesn't handle this
        -- intelligent_attack will use Critical or skills to break block
        return nil
    end
    
    -- Check for specific skills that should be dodged (AOE attacks)
    local dodgeSkills = {
        "Firestorm",           -- Flame alchemy AOE
        "Cascade",             -- Stone alchemy AOE
        "Grand Cleave",        -- Spear AOE
        "Strategist Combination", -- Guns AOE
        "Ground Decay",        -- Stone alchemy expanding craters
        "Branch",              -- Stone alchemy converging paths
        "Dempsey Roll",        -- Boxing multi-hit
    }

    for _, skill in ipairs(dodgeSkills) do
        if playerAction == skill then
            -- Dodge AOE attacks 70% of the time (very reactive to AOE!)
            if distance < 18 and math.random() < 0.7 then
                return "Dodge"
            else
                return nil
            end
        end
    end

    -- Check for skills that should be blocked (single target heavy attacks)
    local blockSkills = {
        "Needle Thrust",       -- Spear thrust
        "Shell Piercer",       -- Guns pierce
        "Downslam Kick",       -- Fist slam
        "Axe Kick",            -- Fist kick (guard break!)
        "Pincer Impact",       -- Fist combo finisher
        "Gazelle Punch",       -- Boxing heavy
        "Stone Lance",         -- Stone alchemy spike
        "Rock Skewer",         -- Stone alchemy ground attack
        "Cinder",              -- Flame alchemy ranged
    }

    for _, skill in ipairs(blockSkills) do
        if playerAction == skill then
            -- Block heavy skills 60% of the time, parry 20% of the time
            if distance < 14 then
                local roll = math.random()
                if roll < 0.60 then
                    return "Block"
                elseif roll < 0.80 then
                    return "Parry"
                else
                    return nil
                end
            else
                return nil
            end
        end
    end

    -- Check for skills that should be parried (fast attacks)
    local parrySkills = {
        "Jab Rush",            -- Boxing fast jabs
        "Rising Wind",         -- Brawler uppercut
        "Deconstruct",         -- Alchemy projectile
        "AlchemicAssault",     -- Alchemy combo
    }

    for _, skill in ipairs(parrySkills) do
        if playerAction == skill then
            -- Parry fast skills 50% of the time, block 30% of the time
            if distance < 12 then
                local roll = math.random()
                if roll < 0.50 then
                    return "Parry"
                elseif roll < 0.80 then
                    return "Block"
                else
                    return nil
                end
            else
                return nil
            end
        end
    end
    
    -- Default: no specific defense needed
    return nil
end

-- Execute the defensive action
local function executeDefense(npc, defenseType, mainConfig)
    local Combat = Server.Modules.Combat
    if not Combat then
        warn("[Smart Defense] Combat module not found!")
        return false
    end

    if defenseType == "Parry" then
        -- Attempt parry (quick block release)
        if not Combat.AttemptParry then
            return false
        end

        Combat.AttemptParry(npc)

        -- Set flag for immediate counter-attack after parry
        mainConfig.States.JustParried = true
        mainConfig.States.ParryTime = os.clock()

        return true

    elseif defenseType == "Block" then
        -- Hold block using NPC blocking system (not player system)
        if not mainConfig.InitiateBlock then
            return false
        end

        mainConfig.InitiateBlock(true)

        -- Release block after a short duration
        task.delay(0.5, function()
            -- Only release if NPC still exists and isn't stunned/guard broken
            if npc and npc.Parent and mainConfig.InitiateBlock then
                -- Don't release block if guard broken or stunned using ECS StateManager
                if not StateManager.StateCheck(npc, "Stuns", "BlockBreakStun")
                    and not StateManager.StateCheck(npc, "Stuns", "GuardbreakStun") then
                    mainConfig.InitiateBlock(false)
                end
            end
        end)
        return true

    elseif defenseType == "Dodge" then
        -- Perform dodge (if NPC has dodge capability)
        local npcRoot = npc:FindFirstChild("HumanoidRootPart")
        if not npcRoot then
            return false
        end

        -- Get a random dodge direction relative to NPC's orientation
        local dodgeDirections = {
            {name = "Right", vector = npcRoot.CFrame.RightVector},
            {name = "Left", vector = -npcRoot.CFrame.RightVector},
            {name = "Back", vector = -npcRoot.CFrame.LookVector},
        }

        local randomDodge = dodgeDirections[math.random(1, #dodgeDirections)]
        local dodgeVector = randomDodge.vector
        local dodgeDirection = randomDodge.name

        -- Manually apply dodge for NPCs (since Dodge.EndPoint expects a Player)
        local Entity = Server.Modules.Entities.Get(npc)
        if Entity and Entity.Character then
            -- Add dodge IFrame
            StateManager.AddState(Entity.Character, "IFrames", "Dodge")
            task.delay(0.5, function()
                StateManager.RemoveState(Entity.Character, "IFrames", "Dodge")
            end)

            -- Create smooth velocity for dodge (match player dodge system exactly)
            local TweenService = game:GetService("TweenService")
            local Speed = 135  -- Match player dodge speed
            local Duration = 0.5  -- Match player dodge duration

            -- Clean up any existing dodge velocities
            for _, bodyMover in pairs(npcRoot:GetChildren()) do
                if bodyMover.Name == "NPCDodge" then
                    bodyMover:Destroy()
                end
            end

            local Velocity = Instance.new("LinearVelocity")
            Velocity.Name = "NPCDodge"
            Velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
            Velocity.ForceLimitMode = Enum.ForceLimitMode.PerAxis
            Velocity.ForceLimitsEnabled = true
            Velocity.MaxAxesForce = Vector3.new(100000, 0, 100000)  -- Match player force
            Velocity.VectorVelocity = dodgeVector * Speed

            -- Create attachment if it doesn't exist
            local attachment = npcRoot:FindFirstChild("RootAttachment")
            if not attachment then
                attachment = Instance.new("Attachment")
                attachment.Name = "RootAttachment"
                attachment.Parent = npcRoot
            end

            Velocity.Attachment0 = attachment
            Velocity.RelativeTo = Enum.ActuatorRelativeTo.World
            Velocity.Parent = npcRoot

            -- Create smooth deceleration tween - gradually slow down instead of stopping abruptly
            local SlowdownSpeed = Speed * 0.15  -- End at 15% of original speed for smooth transition
            local DashTween = TweenService:Create(
                Velocity,
                TweenInfo.new(Duration, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
                {VectorVelocity = dodgeVector * SlowdownSpeed}
            )
            DashTween:Play()

            -- Final cleanup - remove velocity completely after tween
            DashTween.Completed:Connect(function()
                if Velocity and Velocity.Parent then
                    Velocity:Destroy()
                end
            end)

            -- Play dodge VFX
            Server.Visuals.Ranged(npcRoot.Position, 300, {
                Module = "Base",
                Function = "DashFX",
                Arguments = {npc, dodgeDirection}
            })

            return true
        end

        return false
    end
    
    return false
end

-- Main smart defense function
return function(actor: Actor, mainConfig: table)
    local npc = actor:FindFirstChildOfClass("Model")
    if not npc then
        return false
    end

    -- Only use smart defense when aggressive
    if not (mainConfig.States and mainConfig.States.AggressiveMode) then
        return false
    end
    
    local target = mainConfig.getTarget()
    if not target then
        return false
    end
    
    -- Get distance to target
    local npcRoot = npc:FindFirstChild("HumanoidRootPart")
    local targetRoot = target:FindFirstChild("HumanoidRootPart")
    
    if not npcRoot or not targetRoot then
        return false
    end
    
    local distance = (targetRoot.Position - npcRoot.Position).Magnitude
    
    -- Get what the player is doing
    local playerAction = getPlayerAction(target)
    if not playerAction then
        -- ---- print("[Smart Defense]", npc.Name, "- No player action detected")
        return false
    end

    -- Determine best defense
    local defenseType = getBestDefense(playerAction, distance)
    if not defenseType then
        return false
    end

    -- Check global action cooldown to prevent NPCs from doing multiple actions at once
    local lastAction = mainConfig.States.LastAction or 0
    local globalActionCooldown = 0.3 -- 300ms minimum between ANY actions (attack, block, parry, dodge)

    if os.clock() - lastAction < globalActionCooldown then
        return false
    end

    -- Check cooldown for defensive actions
    local lastDefense = mainConfig.States.LastDefense or 0
    local defenseCooldown = 0.5 -- Very short cooldown - react to every attack!

    if os.clock() - lastDefense < defenseCooldown then
        return false
    end

    -- Execute the defense
    local success = executeDefense(npc, defenseType, mainConfig)

    if success then
        -- Track global action time to prevent simultaneous actions
        mainConfig.States.LastAction = os.clock()
        mainConfig.States.LastDefense = os.clock()
    end

    return success
end

