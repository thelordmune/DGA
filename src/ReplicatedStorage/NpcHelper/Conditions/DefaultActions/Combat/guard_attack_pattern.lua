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
local Library = require(ReplicatedStorage.Modules.Library)

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

-- Helper function to check if target is attacking
local function isTargetAttacking(target)
    local actions = target:FindFirstChild("Actions")
    if not actions then
        return false
    end
    
    local Library = require(ReplicatedStorage.Modules.Library)
    return Library.StateCheck(actions, "Attacking")
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
        -- If in defensive too long and target close, go aggressive
        if timeInState > 2.0 and distance < 10 then
            return GuardPatterns.COUNTER
        end
        
    elseif currentState == GuardPatterns.COUNTER then
        -- After counter, apply pressure
        if timeInState > 0.8 then
            return GuardPatterns.PRESSURE
        end
        
    elseif currentState == GuardPatterns.PRESSURE then
        -- After pressure, use special or reset
        if pattern.ComboCount >= 2 then
            return GuardPatterns.SPECIAL
        end
        if timeInState > 1.5 then
            return GuardPatterns.RESET
        end
        
    elseif currentState == GuardPatterns.SPECIAL then
        -- After special, reset to defensive
        if timeInState > 1.0 then
            return GuardPatterns.RESET
        end
        
    elseif currentState == GuardPatterns.RESET then
        -- Return to defensive after brief reset
        if timeInState > 0.5 then
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
        local m1Cooldown = 1.5 -- Balanced cooldown

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
            local m1Cooldown = 1.5 -- Balanced cooldown

            if os.clock() - lastM1 >= m1Cooldown and not isSkillOnCooldown(npc, "M1") then
                skillToUse = "M1"
                mainConfig.GuardPattern.LastM1 = os.clock()
            end
        end
        mainConfig.GuardPattern.ComboCount = (mainConfig.GuardPattern.ComboCount or 0) + 1

    elseif currentState == GuardPatterns.SPECIAL then
        -- Use weapon-specific special skill
        if weapon == "Spear" then
            if not isSkillOnCooldown(npc, "Grand Cleave") and distance < 10 then
                skillToUse = "Grand Cleave"
            elseif not isSkillOnCooldown(npc, "Needle Thrust") and distance < 15 then
                skillToUse = "Needle Thrust"
            end
        elseif weapon == "Guns" then
            if not isSkillOnCooldown(npc, "Shell Piercer") and distance > 10 then
                skillToUse = "Shell Piercer"
            elseif not isSkillOnCooldown(npc, "Strategist Combination") and distance < 20 then
                skillToUse = "Strategist Combination"
            end
        elseif weapon == "Fist" then
            if not isSkillOnCooldown(npc, "Axe Kick") and distance < 8 then
                skillToUse = "Axe Kick"
            elseif not isSkillOnCooldown(npc, "Downslam Kick") and distance < 8 then
                skillToUse = "Downslam Kick"
            end
        end

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
        -- -- print("Guard", npc.Name, "using pattern:", currentState, "skill:", skillToUse)

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
            local actions = npc:FindFirstChild("Actions")
            if actions and Library.StateCount(actions) then
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
    -- print("=== GUARD_ATTACK_PATTERN CALLED ===")

    local npc = actor:FindFirstChildOfClass("Model")
    if not npc then
        -- print("guard_attack_pattern: No NPC found")
        return false
    end

    -- Only use this for guards
    local isGuard = npc.Name:find("Guard") ~= nil
    if not isGuard then
        -- print("guard_attack_pattern:", npc.Name, "is not a guard")
        return false
    end

    -- Only use pattern when aggressive
    if not (mainConfig.States and mainConfig.States.AggressiveMode) then
        -- print("Guard", npc.Name, "not in aggressive mode, skipping attack pattern")
        return false
    end

    -- print("Guard", npc.Name, "executing attack pattern - AggressiveMode:", mainConfig.States.AggressiveMode)

    -- Ensure guard has a weapon equipped
    local weapon = npc:GetAttribute("Weapon")
    local equipped = npc:GetAttribute("Equipped")

    if not weapon or weapon == "Fist" then
        -- Set a weapon from the weapon list if available
        if mainConfig.Weapons and mainConfig.Weapons.WeaponList and #mainConfig.Weapons.WeaponList > 0 then
            weapon = mainConfig.Weapons.WeaponList[math.random(1, #mainConfig.Weapons.WeaponList)]
            npc:SetAttribute("Weapon", weapon)
            -- print("Guard", npc.Name, "assigned weapon:", weapon)
        end
    end

    if not equipped and weapon and weapon ~= "Fist" then
        -- Equip the weapon using the same system as players
        local EquipModule = Server.Modules.Network and Server.Modules.Network.Equip
        if not EquipModule then
            warn("Network.Equip module not loaded!")
            return false
        end

        -- print("Guard", npc.Name, "equipping weapon:", weapon)
        EquipModule.EquipWeapon(npc, weapon, true) -- Skip animation
        -- print("Guard", npc.Name, "equipped attribute after equip:", npc:GetAttribute("Equipped"))
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
        -- print("Guard", npc.Name, "transitioning from", mainConfig.GuardPattern.CurrentState, "to", nextState)
        mainConfig.GuardPattern.CurrentState = nextState
        mainConfig.GuardPattern.StateStartTime = os.clock()
    end
    
    -- Execute action for current state
    return executePatternAction(mainConfig, npc, target, distance, mainConfig.GuardPattern.CurrentState)
end

