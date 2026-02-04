--[[
    Guard Attack Pattern System

    Guards have specific attack patterns when aggro'd:
    1. Initial Response: Block/Parry if player is attacking
    2. Counter Attack: Quick M1 combo
    3. Special Move: Use weapon skill
    4. Pressure: Continue with M2 or Critical
    5. Reset: Return to defensive stance

    Uses the same Combat system that players use (Combat.Light, Combat.Critical, etc.)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local CombatProperties = require(ReplicatedStorage.Modules.CombatProperties)
local StateManager = require(ReplicatedStorage.Modules.ECS.StateManager)

-- All weapon skills by weapon type (guards can use ALL moves)
local WEAPON_SKILLS = {
	["Spear"] = {
		"Needle Thrust",
		"Grand Cleave",
		"Charged Thrust",
		"Rapid Thrust",
		"WhirlWind",
	},
	["Guns"] = {
		"Shell Piercer",
		"Strategist Combination",
		"Inverse Slide",
		"Tapdance",
		"Hellraiser",
	},
	["Fist"] = {
		"Axe Kick",
		"Downslam Kick",
		"Triple Kick",
		"Pincer Impact",
	},
}

-- Get Server from main VM (Actors have separate module caches, so use _G)
local function getServer()
	local Server = require(ServerScriptService.ServerConfig.Server)
	-- Use _G.ServerModules if available (populated by Start.server.lua in main VM)
	if _G.ServerModules then
		Server.Modules = _G.ServerModules
	end
	return Server
end

local Server = getServer()

-- Guard attack pattern states
local GuardPatterns = {
    DEFENSIVE = "Defensive",      -- Block and wait
    COUNTER = "Counter",           -- Quick counter attack
    PRESSURE = "Pressure",         -- Aggressive follow-up
    SPECIAL = "Special",           -- Use special skill
    RESET = "Reset",               -- Return to defensive
}

-- Helper function to get distance to target
local function getDistanceToTarget(npc, target)
    local npcRoot = npc:FindFirstChild("HumanoidRootPart")
    local targetRoot = target:FindFirstChild("HumanoidRootPart")
    
    if not npcRoot or not targetRoot then
        return math.huge
    end
    
    return (targetRoot.Position - npcRoot.Position).Magnitude
end

-- Helper function to check if target is attacking using ECS StateManager
local function isTargetAttacking(target)
    return StateManager.StateCheck(target, "Actions", "Attacking")
end

-- Helper function to check if skill is on cooldown (uses Library.CheckCooldown like players)
local function isSkillOnCooldown(npc, skillName)
    -- Use the same cooldown check that players use
    return Server.Library.CheckCooldown(npc, skillName)
end

-- Initialize guard pattern state
local function initializeGuardPattern(mainConfig)
    if not mainConfig.GuardPattern then
        mainConfig.GuardPattern = {
            CurrentState = GuardPatterns.DEFENSIVE,
            StateStartTime = os.clock(),
            ComboCount = 0,
            LastPatternReset = os.clock(),
        }
    end
end

-- Get next pattern state based on current state and context
local function getNextPatternState(mainConfig, npc, target, distance)
    local pattern = mainConfig.GuardPattern
    local currentState = pattern.CurrentState
    local timeInState = os.clock() - pattern.StateStartTime
    
    -- Check if target is attacking
    local targetAttacking = isTargetAttacking(target)
    
    -- State machine transitions
    if currentState == GuardPatterns.DEFENSIVE then
        -- If target attacks, counter
        if targetAttacking and distance < 12 then
            return GuardPatterns.COUNTER
        end
        -- If in defensive too long and target close, go aggressive (reduced from 2.0 to 1.0)
        if timeInState > 1.0 and distance < 10 then
            return GuardPatterns.COUNTER
        end

    elseif currentState == GuardPatterns.COUNTER then
        -- After counter, apply pressure (reduced from 0.8 to 0.5)
        if timeInState > 0.5 then
            return GuardPatterns.PRESSURE
        end

    elseif currentState == GuardPatterns.PRESSURE then
        -- After pressure, use special or reset (increased combo requirement from 2 to 3)
        if pattern.ComboCount >= 3 then
            return GuardPatterns.SPECIAL
        end
        if timeInState > 1.2 then -- Reduced from 1.5 to 1.2
            return GuardPatterns.RESET
        end

    elseif currentState == GuardPatterns.SPECIAL then
        -- After special, reset to defensive (reduced from 1.0 to 0.7)
        if timeInState > 0.7 then
            return GuardPatterns.RESET
        end

    elseif currentState == GuardPatterns.RESET then
        -- Return to defensive after brief reset (reduced from 0.5 to 0.3)
        if timeInState > 0.3 then
            return GuardPatterns.DEFENSIVE
        end
    end
    
    return currentState -- No state change
end

-- Execute action based on current pattern state
local function executePatternAction(mainConfig, npc, target, distance, currentState)
    local weapon = npc:GetAttribute("Weapon") or "Fist"
    local skillToUse = nil

    if currentState == GuardPatterns.DEFENSIVE then
        -- Block if target is close and attacking
        if isTargetAttacking(target) and distance < 12 then
            skillToUse = "Block"
        else
            return false -- Wait in defensive stance
        end

    elseif currentState == GuardPatterns.COUNTER then
        -- Quick M1 counter - check both cooldown and manual timing
        local lastM1 = mainConfig.GuardPattern.LastM1 or 0
        local m1Cooldown = 0.8 -- Reduced from 1.5 to 0.8 for more aggressive attacks

        if os.clock() - lastM1 >= m1Cooldown and not isSkillOnCooldown(npc, "M1") then
            skillToUse = "M1"
            mainConfig.GuardPattern.ComboCount = (mainConfig.GuardPattern.ComboCount or 0) + 1
            mainConfig.GuardPattern.LastM1 = os.clock()
        end

    elseif currentState == GuardPatterns.PRESSURE then
        -- Use Critical (M2) for pressure
        if not isSkillOnCooldown(npc, "Critical") and distance < 12 then
            skillToUse = "Critical"
        else
            -- Check M1 cooldown before using as fallback
            local lastM1 = mainConfig.GuardPattern.LastM1 or 0
            local m1Cooldown = 0.8 -- Reduced from 1.5 to 0.8 for more aggressive attacks

            if os.clock() - lastM1 >= m1Cooldown and not isSkillOnCooldown(npc, "M1") then
                skillToUse = "M1"
                mainConfig.GuardPattern.LastM1 = os.clock()
            end
        end
        mainConfig.GuardPattern.ComboCount = (mainConfig.GuardPattern.ComboCount or 0) + 1

    elseif currentState == GuardPatterns.SPECIAL then
        -- Use weapon-specific special skill - guards can use ALL moves for their weapon
        local availableSkills = WEAPON_SKILLS[weapon] or {}

        -- Score each skill based on distance and cooldown
        local bestSkill = nil
        local bestScore = 0

        for _, skillName in ipairs(availableSkills) do
            if not isSkillOnCooldown(npc, skillName) then
                local props = CombatProperties[skillName]
                local score = 1

                if props and props.TargetingProperties then
                    local minRange = props.TargetingProperties.MinRange or 0
                    local maxRange = props.TargetingProperties.MaxRange or 20
                    local optimalRange = props.TargetingProperties.OptimalRange or 10

                    -- Check if in range
                    if distance >= minRange and distance <= maxRange then
                        -- Score based on how close to optimal range
                        local rangeDiff = math.abs(distance - optimalRange)
                        score = math.max(1, 10 - rangeDiff)

                        -- Bonus for priority skills
                        if props.SkillPriority then
                            score = score + (props.SkillPriority * 0.5)
                        end

                        -- Bonus for guard breaks when target is blocking
                        if props.IsGuardBreak and isTargetAttacking(target) then
                            score = score + 5
                        end

                        -- Add randomness for variety
                        score = score + math.random() * 3
                    else
                        score = 0 -- Out of range
                    end
                else
                    -- No props, use distance-based fallback
                    if distance < 15 then
                        score = 5 + math.random() * 3
                    end
                end

                if score > bestScore then
                    bestScore = score
                    bestSkill = skillName
                end
            end
        end

        skillToUse = bestSkill

        -- Fallback to M2 if no special available
        if not skillToUse and not isSkillOnCooldown(npc, "M2") then
            skillToUse = "M2"
        end

    elseif currentState == GuardPatterns.RESET then
        -- Reset combo count and prepare for next cycle
        mainConfig.GuardPattern.ComboCount = 0
        return false -- Don't attack during reset
    end

    -- Execute the skill if one was chosen using the same Combat system players use
    if skillToUse then
        -- -- ---- print("Guard", npc.Name, "using pattern:", currentState, "skill:", skillToUse)

        -- Face the target
        local npcRoot = npc:FindFirstChild("HumanoidRootPart")
        local targetRoot = target:FindFirstChild("HumanoidRootPart")
        if npcRoot and targetRoot then
            local lookDirection = (targetRoot.Position - npcRoot.Position).Unit
            local lookCFrame = CFrame.lookAt(npcRoot.Position, npcRoot.Position + Vector3.new(lookDirection.X, 0, lookDirection.Z))
            npcRoot.CFrame = npcRoot.CFrame:Lerp(lookCFrame, 0.5)
        end

        -- Execute using the same Combat functions that players use
        local Combat = Server.Modules.Combat
        if not Combat then
            warn("Combat module not loaded!")
            return false
        end

        if skillToUse == "M1" then
            -- Check if NPC is already in an M1 animation (prevent spam)
            if StateManager.StateCount(npc, "Actions") then
                -- NPC is already performing an action, don't spam M1
                return false
            end

            Combat.Light(npc)
            return true
        elseif skillToUse == "Critical" then
            Combat.Critical(npc)
            return true
        elseif skillToUse == "Block" then
            Combat.HandleBlockInput(npc, true)
            return true
        else
            -- For weapon skills, use performAction
            return mainConfig.performAction(skillToUse)
        end
    end

    return false
end

-- Main guard attack pattern function
return function(actor: Actor, mainConfig: table)
    -- ---- print("=== GUARD_ATTACK_PATTERN CALLED ===")

    local npc = actor:FindFirstChildOfClass("Model")
    if not npc then
        -- ---- print("guard_attack_pattern: No NPC found")
        return false
    end

    -- Only use this for guards
    local isGuard = npc.Name:find("Guard") ~= nil
    if not isGuard then
        -- ---- print("guard_attack_pattern:", npc.Name, "is not a guard")
        return false
    end

    -- Only use pattern when aggressive
    if not (mainConfig.States and mainConfig.States.AggressiveMode) then
        -- ---- print("Guard", npc.Name, "not in aggressive mode, skipping attack pattern")
        return false
    end

    -- ---- print("Guard", npc.Name, "executing attack pattern - AggressiveMode:", mainConfig.States.AggressiveMode)

    -- Get the guard's weapon (DO NOT reassign - weapon is set at spawn time)
    local weapon = npc:GetAttribute("Weapon") or "Fist"
    local equipped = npc:GetAttribute("Equipped")

    if not equipped and weapon and weapon ~= "Fist" then
        -- Equip the weapon using the same system as players
        local EquipModule = Server.Modules.Network and Server.Modules.Network.Equip
        if not EquipModule then
            warn("Network.Equip module not loaded!")
            return false
        end

        -- ---- print("Guard", npc.Name, "equipping weapon:", weapon)
        EquipModule.EquipWeapon(npc, weapon, true) -- Skip animation
        -- ---- print("Guard", npc.Name, "equipped attribute after equip:", npc:GetAttribute("Equipped"))
    end
    
    local target = mainConfig.getTarget()
    if not target then
        return false
    end
    
    -- Check if target is valid
    local targetHumanoid = target:FindFirstChild("Humanoid")
    if not targetHumanoid or targetHumanoid.Health <= 0 then
        return false
    end
    
    -- Get distance to target
    local distance = getDistanceToTarget(npc, target)
    
    if distance > 25 then
        return false -- Too far for guard pattern
    end
    
    -- Initialize pattern state
    initializeGuardPattern(mainConfig)
    
    -- Get next state
    local nextState = getNextPatternState(mainConfig, npc, target, distance)
    
    -- Update state if changed
    if nextState ~= mainConfig.GuardPattern.CurrentState then
        -- ---- print("Guard", npc.Name, "transitioning from", mainConfig.GuardPattern.CurrentState, "to", nextState)
        mainConfig.GuardPattern.CurrentState = nextState
        mainConfig.GuardPattern.StateStartTime = os.clock()
    end
    
    -- Execute action for current state
    return executePatternAction(mainConfig, npc, target, distance, mainConfig.GuardPattern.CurrentState)
end

