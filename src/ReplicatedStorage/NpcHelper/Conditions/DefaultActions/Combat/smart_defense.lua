--[[
    Smart Defense System for NPCs
    
    Analyzes what the player is doing and reacts appropriately:
    - Parry: Quick attacks (M1 combos, fast skills)
    - Block: Heavy attacks (M2, Critical, blockbreak skills)
    - Dodge: AOE attacks, unblockable attacks
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Library = require(ReplicatedStorage.Modules.Library)

-- Get Server from main VM
local function getServer()
    local Server = require(ServerScriptService.ServerConfig.Server)
    if _G.ServerModules then
        Server.Modules = _G.ServerModules
    end
    return Server
end

local Server = getServer()

-- Helper to get what action the player is performing
local function getPlayerAction(target)
    local actions = target:FindFirstChild("Actions")
    if not actions or not actions:IsA("StringValue") then
        return nil
    end
    
    -- Decode the actions JSON
    local success, decodedActions = pcall(function()
        return game:GetService("HttpService"):JSONDecode(actions.Value)
    end)
    
    if not success or type(decodedActions) ~= "table" then
        return nil
    end
    
    -- Return the first action found (most recent)
    return decodedActions[1]
end

-- Determine the best defensive response based on player's action
local function getBestDefense(playerAction, distance)
    if not playerAction then
        return nil
    end
    
    -- Check for M1 attacks (M11, M12, M13, M14)
    if string.match(playerAction, "^M1%d$") then
        -- M1 attacks are fast and can be parried
        if distance < 8 then
            return "Parry"
        else
            return nil -- Too far to react
        end
    end

    -- Check for M2 attacks (Critical)
    if playerAction == "M2" then
        -- M2 attacks are heavier, better to block
        if distance < 12 then
            return "Block"
        else
            return nil
        end
    end

    -- Check for Running Attack
    if playerAction == "RunningAttack" then
        -- Running attacks are fast, parry them
        if distance < 10 then
            return "Parry"
        else
            return nil
        end
    end
    
    -- Check for blocking state
    if playerAction == "Blocking" then
        -- Player is blocking, don't defend
        return nil
    end
    
    -- Check for specific skills that should be dodged (AOE attacks)
    local dodgeSkills = {
        "Firestorm",           -- Flame alchemy AOE
        "Cascade",             -- Stone alchemy AOE
        "Grand Cleave",        -- Spear AOE
        "Strategist Combination", -- Guns AOE
    }

    for _, skill in ipairs(dodgeSkills) do
        if playerAction == skill then
            if distance < 15 then
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
        "Axe Kick",            -- Fist kick
    }

    for _, skill in ipairs(blockSkills) do
        if playerAction == skill then
            if distance < 12 then
                return "Block"
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
        return false
    end
    
    if defenseType == "Parry" then
        -- Attempt parry (quick block release)
        print("NPC", npc.Name, "attempting PARRY")
        Combat.AttemptParry(npc)
        return true
        
    elseif defenseType == "Block" then
        -- Hold block
        print("NPC", npc.Name, "BLOCKING")
        Combat.HandleBlockInput(npc, true)
        
        -- Release block after a short duration
        task.delay(0.5, function()
            Combat.HandleBlockInput(npc, false)
        end)
        return true
        
    elseif defenseType == "Dodge" then
        -- Perform dodge (if NPC has dodge capability)
        print("NPC", npc.Name, "attempting DODGE")

        -- Get a random dodge direction
        local dodgeDirections = {
            Vector3.new(1, 0, 0),   -- Right
            Vector3.new(-1, 0, 0),  -- Left
            Vector3.new(0, 0, -1),  -- Back
        }

        local randomDirection = dodgeDirections[math.random(1, #dodgeDirections)]

        -- Manually apply dodge for NPCs (since Dodge.EndPoint expects a Player)
        local Entity = Server.Modules.Entities.Get(npc)
        if Entity and Entity.Character then
            -- Add dodge IFrame
            if Entity.Character:FindFirstChild("IFrames") then
                Library.AddState(Entity.Character.IFrames, "Dodge")
                task.delay(0.3, function()
                    Library.RemoveState(Entity.Character.IFrames, "Dodge")
                end)
            end

            -- Play dodge VFX
            Server.Visuals.Ranged(npc.HumanoidRootPart.Position, 300, {
                Module = "Base",
                Function = "DashFX",
                Arguments = {npc, randomDirection}
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
        return false
    end
    
    -- Determine best defense
    local defenseType = getBestDefense(playerAction, distance)
    if not defenseType then
        return false
    end
    
    -- Check cooldown for defensive actions
    local lastDefense = mainConfig.States.LastDefense or 0
    local defenseCooldown = 2.0 -- Don't spam defenses
    
    if os.clock() - lastDefense < defenseCooldown then
        return false
    end
    
    -- Execute the defense
    local success = executeDefense(npc, defenseType, mainConfig)
    
    if success then
        mainConfig.States.LastDefense = os.clock()
        print("NPC", npc.Name, "reacted to", playerAction, "with", defenseType)
    end
    
    return success
end

