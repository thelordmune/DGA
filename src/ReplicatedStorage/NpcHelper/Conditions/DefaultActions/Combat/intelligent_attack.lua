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
    -- For M1, add manual cooldown check to prevent spam
    if skillName == "M1" then
        local lastM1 = mainConfig.States and mainConfig.States.LastM1 or 0
        local m1Cooldown = 1.5 -- Balanced cooldown - not too fast, not too slow

        if os.clock() - lastM1 < m1Cooldown then
            return true -- Still on cooldown
        end
    end

    local onCooldown = Server.Library.CheckCooldown(npc, skillName)

    -- Debug: Print cooldown status for skills (not M1 to avoid spam)
    if onCooldown and skillName ~= "M1" and skillName ~= "M2" and skillName ~= "Critical" then
        local remainingTime = Server.Library.GetCooldownTime(npc, skillName)
        print(string.format("[NPC %s] Skill '%s' on cooldown: %.1fs remaining", npc.Name, skillName, remainingTime))
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
    if weapon == "Spear" then
        table.insert(availableSkills, "Needle Thrust")
        table.insert(availableSkills, "Grand Cleave")
    elseif weapon == "Guns" then
        table.insert(availableSkills, "Shell Piercer")
        table.insert(availableSkills, "Strategist Combination")
    elseif weapon == "Fist" then
        table.insert(availableSkills, "Downslam Kick")
        table.insert(availableSkills, "Axe Kick")
        -- Pincer Impact removed - too complex for NPCs
    end
    
    -- Alchemy skills
    if alchemy then
        -- Basic alchemy (all types)
        table.insert(availableSkills, "Construct")
        table.insert(availableSkills, "Deconstruct")
        table.insert(availableSkills, "AlchemicAssault")
        table.insert(availableSkills, "Stone Lance")

        -- Type-specific alchemy
        if alchemy == "Stone" then
            table.insert(availableSkills, "Cascade")
            table.insert(availableSkills, "Rock Skewer")
        elseif alchemy == "Flame" then
            table.insert(availableSkills, "Cinder")
            table.insert(availableSkills, "Firestorm")
        end
    end

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
    
    -- Distance scoring
    local targetProps = properties.TargetingProperties
    if distance < targetProps.MinRange then
        score = score * 0.3 -- Too close
    elseif distance > targetProps.MaxRange then
        score = score * 0.1 -- Too far
    elseif math.abs(distance - targetProps.OptimalRange) < 3 then
        score = score * 1.5 -- Perfect range!
    elseif distance >= targetProps.MinRange and distance <= targetProps.MaxRange then
        score = score * 1.0 -- In range
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
    -- print("=== INTELLIGENT_ATTACK CALLED ===")

    local npc = actor:FindFirstChildOfClass("Model")
    if not npc then
        -- print("intelligent_attack: No NPC found")
        return false
    end

    local target = mainConfig.getTarget()
    if not target then
        -- print("intelligent_attack:", npc.Name, "- No target found")
        return false
    end

    -- print("intelligent_attack:", npc.Name, "has target:", target.Name)
    
    -- Check if target is valid
    local targetHumanoid = target:FindFirstChild("Humanoid")
    if not targetHumanoid or targetHumanoid.Health <= 0 then
        return false
    end
    
    -- Get distance to target
    local distance = getDistanceToTarget(npc, target)

    -- Check if player is blocking
    local targetActions = target:FindFirstChild("Actions")
    local playerIsBlocking = false
    if targetActions then
        playerIsBlocking = Library.StateCheck(targetActions, "Blocking")
    end

    -- If player is blocking, prioritize Critical or blockbreak skills
    if playerIsBlocking then
        -- Check if we have blockbreak skills available
        local availableSkills = getAvailableSkills(npc, mainConfig)
        for _, skillName in ipairs(availableSkills) do
            local properties = CombatProperties[skillName]
            if properties and properties.SkillType == "Offensive" then
                -- Prefer skills that can break blocks
                if skillName ~= "M1" and skillName ~= "Block" then
                    -- Execute the skill immediately
                    local Combat = Server.Modules.Combat
                    if skillName == "Critical" or skillName == "M2" then
                        Combat.Critical(npc)
                        return true
                    else
                        local success = mainConfig.performAction(skillName)
                        if success then
                            return true
                        end
                    end
                end
            end
        end

        -- Fallback to Critical if no skills available
        local Combat = Server.Modules.Combat
        if not Library.CheckCooldown(npc, "Critical") then
            Combat.Critical(npc)
            return true
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
    -- print("NPC", npc.Name, "using intelligent attack:", bestSkill, "with score:", bestScore, "at distance:", math.floor(distance))

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
        -- Check if NPC is already in an M1 animation (prevent spam)
        local actions = npc:FindFirstChild("Actions")
        if actions and Library.StateCount(actions) then
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
        mainConfig.States.LastSkillUsed = bestSkill
        mainConfig.States.LastAttack = os.clock()
    end

    return success
end

