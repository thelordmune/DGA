--[[
    Intelligent Attack System for NPCs

    Uses CombatProperties to make smart attack decisions based on:
    - Distance to target
    - Available skills
    - Cooldowns
    - Combat context (aggressive mode, health, etc.)

    Uses the same Combat system that players use (Combat.Light, Combat.Critical, etc.)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local CombatProperties = require(ReplicatedStorage.Modules.CombatProperties)
local StateManager = require(ReplicatedStorage.Modules.ECS.StateManager)
local PlayerStateDetector = require(script.Parent.player_state_detector)

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

-- Helper function to get distance to target
local function getDistanceToTarget(npc, target)
    local npcRoot = npc:FindFirstChild("HumanoidRootPart")
    local targetRoot = target:FindFirstChild("HumanoidRootPart")
    
    if not npcRoot or not targetRoot then
        return math.huge
    end
    
    return (targetRoot.Position - npcRoot.Position).Magnitude
end

-- Helper function to check if skill is on cooldown (uses Library.CheckCooldown like players)
local function isSkillOnCooldown(npc, skillName, mainConfig)
    -- Global action cooldown - prevent NPCs from performing ANY action too frequently
    -- This prevents NPCs from attempting attacks, blocks, and parries in the same frame
    local lastAction = mainConfig.States and mainConfig.States.LastAction or 0
    local globalActionCooldown = 0.3 -- 300ms minimum between ANY actions (attack, block, parry, dodge)

    if os.clock() - lastAction < globalActionCooldown then
        return true -- Global action cooldown still active
    end

    -- Global attack cooldown - prevent NPCs from attacking too frequently
    local lastAttack = mainConfig.States and mainConfig.States.LastAttack or 0
    local globalAttackCooldown = 1.2 -- Reduced from 2.0 to 1.2 for more aggressive guards

    if os.clock() - lastAttack < globalAttackCooldown then
        return true -- Global cooldown still active
    end

    -- For M1, add manual cooldown check to prevent spam
    if skillName == "M1" then
        local lastM1 = mainConfig.States and mainConfig.States.LastM1 or 0
        local m1Cooldown = 2.5 -- Increased from 1.5 to 2.5 seconds

        if os.clock() - lastM1 < m1Cooldown then
            return true -- Still on cooldown
        end
    end

    local onCooldown = Server.Library.CheckCooldown(npc, skillName)

    -- Debug: -- print cooldown status for skills (not M1 to avoid spam)
    if onCooldown and skillName ~= "M1" and skillName ~= "M2" and skillName ~= "Critical" then
        local remainingTime = Server.Library.GetCooldownTime(npc, skillName)
        -- ---- print(string.format("[NPC %s] Skill '%s' on cooldown: %.1fs remaining", npc.Name, skillName, remainingTime))
    end

    return onCooldown
end

-- Helper function to get available skills for NPC
local function getAvailableSkills(npc, mainConfig)
    local availableSkills = {}
    
    -- Get NPC's weapon
    local weapon = npc:GetAttribute("Weapon") or "Fist"
    
    -- Get NPC's alchemy type
    local alchemy = npc:GetAttribute("Alchemy")
    
    -- Always available: Basic combat
    table.insert(availableSkills, "M1")
    table.insert(availableSkills, "M2")
    table.insert(availableSkills, "Critical")
    
    -- Weapon-specific skills
    if weapon == "Fist" then
        table.insert(availableSkills, "Downslam Kick")
        table.insert(availableSkills, "Axe Kick")
        -- Pincer Impact removed - too complex for NPCs
    end

    -- Weapon skills (Spear, Guns) removed - keeping only Fist combat
    -- Alchemy skills removed - Hunter x Hunter Nen system will replace this

    return availableSkills
end

-- Score a skill based on current combat context
local function scoreSkill(skillName, distance, mainConfig, npc, target)
    local properties = CombatProperties[skillName]

    if not properties then
        return 0 -- Unknown skill
    end

    -- Check if on cooldown
    if isSkillOnCooldown(npc, skillName, mainConfig) then
        return 0
    end

    local score = properties.SkillPriority

    -- Distance scoring - STRICT range enforcement
    local targetProps = properties.TargetingProperties
    if distance < targetProps.MinRange then
        return 0 -- Completely reject if too close
    elseif distance > targetProps.MaxRange then
        return 0 -- Completely reject if too far - don't use skills out of range!
    elseif math.abs(distance - targetProps.OptimalRange) < 3 then
        score = score * 1.5 -- Perfect range!
    elseif distance >= targetProps.MinRange and distance <= targetProps.MaxRange then
        score = score * 1.0 -- In range
    end

    -- NEW: React to player states
    local playerBlocking = PlayerStateDetector.IsBlocking(target)
    local playerRagdolled = PlayerStateDetector.IsRagdolled(target)
    local playerHasHyperArmor = PlayerStateDetector.HasHyperArmor(target)

    -- If player is blocking, heavily prioritize guard breaks
    if playerBlocking and properties.IsGuardBreak then
        score = score * 3.0 -- Massive bonus for guard breaks when player is blocking
    elseif playerBlocking and not properties.IsGuardBreak then
        score = score * 0.3 -- Heavily penalize non-guard-break attacks when player is blocking
    end

    -- If player is ragdolled, prioritize combo extenders
    if playerRagdolled and properties.IsComboExtender then
        score = score * 2.5 -- Big bonus for combo extenders on ragdolled targets
    end

    -- If player has hyper armor, avoid using this skill (unless it's ranged or has hyper armor too)
    if playerHasHyperArmor then
        if properties.HasHyperArmor then
            score = score * 1.2 -- Slight bonus for hyper armor vs hyper armor
        elseif properties.RangeType == "Long" or properties.RangeType == "Medium" then
            score = score * 1.0 -- Ranged attacks are fine
        else
            score = score * 0.2 -- Heavily penalize close-range attacks against hyper armor
        end
    end

    -- Aggressive mode bonus for offensive skills
    if mainConfig.States and mainConfig.States.AggressiveMode then
        if properties.SkillType == "Offensive" then
            score = score * 1.3
        end
    end

    -- Low health - prefer defensive or retreating skills
    local npcHumanoid = npc:FindFirstChild("Humanoid")
    if npcHumanoid then
        local healthPercent = npcHumanoid.Health / npcHumanoid.MaxHealth
        if healthPercent < 0.3 then
            if properties.SkillType == "Defensive" then
                score = score * 1.8
            elseif properties.SkillType == "Retreating" then
                score = score * 2.0
            end
        end
    end

    -- Combo context
    local lastSkill = mainConfig.States.LastSkillUsed
    if lastSkill then
        local lastProps = CombatProperties[lastSkill]
        if lastProps and lastProps.ComboProperties.IsComboStarter then
            -- Prefer combo enders after starters
            if properties.ComboProperties.IsComboEnder then
                score = score * 1.4
            end
        end
    end

    -- Range type preference based on distance
    if distance > 20 and properties.RangeType == "Long" then
        score = score * 1.3
    elseif distance > 10 and distance <= 20 and properties.RangeType == "Medium" then
        score = score * 1.2
    elseif distance <= 10 and properties.RangeType == "Close" then
        score = score * 1.2
    end

    return score
end

-- Main intelligent attack function
return function(actor: Actor, mainConfig: table)
    -- -- ---- print("=== INTELLIGENT_ATTACK CALLED ===")

    local npc = actor:FindFirstChildOfClass("Model")
    if not npc then
        -- -- ---- print("intelligent_attack: No NPC found")
        return false
    end

    -- Check if NPC is stunned (prevent attacking while being hit)
    if StateManager.StateCount(npc, "Stuns") then
        return false
    end

    -- Check if NPC is already performing an action
    if StateManager.StateCount(npc, "Actions") then
        return false
    end

    local target = mainConfig.getTarget()
    if not target then
        -- -- ---- print("intelligent_attack:", npc.Name, "- No target found")
        return false
    end

    -- -- ---- print("intelligent_attack:", npc.Name, "has target:", target.Name)

    -- Check if target is valid
    local targetHumanoid = target:FindFirstChild("Humanoid")
    if not targetHumanoid or targetHumanoid.Health <= 0 then
        return false
    end
    
    -- Get distance to target
    local distance = getDistanceToTarget(npc, target)

    -- Don't attack if we're pathfinding (obstacle in the way)
    local AiFolder = mainConfig.getMimic()
    if AiFolder and AiFolder:FindFirstChild("PathState") then
        if AiFolder.PathState.Value == 2 then
            -- Currently pathfinding around an obstacle - don't try to attack
            return false
        end
    end

    -- Check if NPC just parried - immediate counter-attack!
    if mainConfig.States.JustParried and (os.clock() - (mainConfig.States.ParryTime or 0)) < 0.8 then
        mainConfig.States.JustParried = false -- Clear flag

        -- Immediately counter with Critical or best skill
        local Combat = Server.Modules.Combat
        if not Server.Library.CheckCooldown(npc, "Critical") then
            Combat.Critical(npc)
            ---- print("[Intelligent Attack] Counter-attacking with Critical after parry!")
            return true
        else
            -- Use best available skill for counter
            local availableSkills = getAvailableSkills(npc, mainConfig)
            if #availableSkills > 0 then
                local bestSkill = availableSkills[1]
                if bestSkill ~= "M1" and bestSkill ~= "Block" then
                    local success = mainConfig.performAction(bestSkill)
                    if success then
                        ---- print("[Intelligent Attack] Counter-attacking with", bestSkill, "after parry!")
                        return true
                    end
                end
            end
        end
    end

    -- Get available skills
    local availableSkills = getAvailableSkills(npc, mainConfig)

    -- Score all skills
    local bestSkill = nil
    local bestScore = 0

    for _, skillName in ipairs(availableSkills) do
        local score = scoreSkill(skillName, distance, mainConfig, npc, target)

        if score > bestScore then
            bestScore = score
            bestSkill = skillName
        end
    end
    
    -- If no good skill found, return false
    if not bestSkill or bestScore <= 0 then
        return false
    end
    
    -- Execute the best skill using the same Combat system players use
    -- -- ---- print("NPC", npc.Name, "using intelligent attack:", bestSkill, "with score:", bestScore, "at distance:", math.floor(distance))

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
        -- warn("Combat module not loaded!")
        return false
    end

    local success = false

    if bestSkill == "M1" then
        -- Check if NPC is already in an M1 animation (prevent spam) using ECS StateManager
        if StateManager.StateCount(npc, "Actions") then
            -- NPC is already performing an action, don't spam M1
            return false
        end

        Combat.Light(npc)
        success = true
        -- Track M1 usage for cooldown
        if not mainConfig.States then
            mainConfig.States = {}
        end
        mainConfig.States.LastM1 = os.clock()
    elseif bestSkill == "Critical" or bestSkill == "M2" then
        -- Both "Critical" and "M2" refer to the same attack
        Combat.Critical(npc)
        success = true
    elseif bestSkill == "Block" then
        Combat.HandleBlockInput(npc, true)
        success = true
    else
        -- For weapon skills and other abilities, use performAction
        success = mainConfig.performAction(bestSkill)
    end

    if success then
        -- Update last skill used for combo tracking
        if not mainConfig.States then
            mainConfig.States = {}
        end

        -- Track global action time to enforce cooldown between ALL actions (attack, block, parry, dodge)
        mainConfig.States.LastAction = os.clock()

        -- Track global attack time to enforce cooldown between all attacks
        mainConfig.States.LastAttack = os.clock()
        mainConfig.States.LastSkillUsed = bestSkill
    end

    return success
end

