--!strict
--[[
    NPC Targeting System (ECS)
    
    Handles:
    - Enemy detection (CaptureDistance)
    - Target acquisition
    - Target loss (LetGoDistance)
    - Aggressive mode (when attacked)
    - Passive mode
    - Has been attacked tracking
    
    Runs at ~15 Hz
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")

local world = require(ReplicatedStorage.Modules.ECS.jecs_world)
local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)
local RefManager = require(ReplicatedStorage.Modules.ECS.jecs_ref_manager)
local StateManager = require(ReplicatedStorage.Modules.ECS.StateManager)

-- Cache queries
local combatNPCQuery = world:query(comps.Character, comps.CombatNPC, comps.NPCCombatState, comps.NPCConfig, comps.Hitbox)

-- Throttle to ~15 Hz
local lastUpdate = 0
local UPDATE_INTERVAL = 0.067

-- Get all players in workspace
local function getAllPlayers(): {Model}
	local players = {}
	for _, player in Players:GetPlayers() do
		if player.Character and player.Character:FindFirstChild("Humanoid") and player.Character.Humanoid.Health > 0 then
			table.insert(players, player.Character)
		end
	end
	return players
end

-- Check if NPC has been attacked
local function hasBeenAttacked(character: Model): (boolean, Model?)
	-- Check Damage_Log
	local damageLog = character:FindFirstChild("Damage_Log")
	if damageLog and #damageLog:GetChildren() > 0 then
		local recentAttack = damageLog:GetChildren()[#damageLog:GetChildren()]
		if recentAttack and recentAttack.Value then
			return true, recentAttack.Value
		end
		return true, nil
	end
	
	-- Check IFrames for attack states
	if StateManager.StateCheck(character, "IFrames", "RecentlyAttacked") or
	   StateManager.StateCheck(character, "IFrames", "Damaged") then
		return true, nil
	end
	
	return false, nil
end

-- Find closest valid target
local function findClosestTarget(npcPos: Vector3, captureDistance: number, currentTarget: Model?): Model?
	local players = getAllPlayers()
	local closestPlayer = nil
	local closestDistance = captureDistance
	
	for _, player in players do
		local playerRoot = player:FindFirstChild("HumanoidRootPart")
		if playerRoot then
			local distance = (playerRoot.Position - npcPos).Magnitude
			if distance < closestDistance then
				closestDistance = distance
				closestPlayer = player
			end
		end
	end
	
	return closestPlayer
end

-- Main system function
return function(dt: number)
	local now = os.clock()
	if now - lastUpdate < UPDATE_INTERVAL then
		return
	end
	lastUpdate = now
	
	for entity, character, _, combatState, config, hitbox in combatNPCQuery do
		-- Check if has been attacked
		local attacked, attacker = hasBeenAttacked(character)
		
		if attacked then
			-- Enter aggressive mode
			if not combatState.isAggressive then
				combatState.isAggressive = true
				combatState.isPassive = false
				combatState.hasBeenAttacked = true
				
				-- Increase detection ranges
				config.captureDistance = math.max(config.captureDistance, 120)
				config.letGoDistance = math.max(config.letGoDistance, 150)
				
				world:set(entity, comps.NPCCombatState, combatState)
				world:set(entity, comps.NPCConfig, config)
			end
			
			-- Set attacker as target if found
			if attacker and attacker:IsA("Model") and attacker:FindFirstChild("Humanoid") then
				world:set(entity, comps.NPCTarget, attacker)
				continue
			end
		end
		
		-- Get current target
		local currentTarget = nil
		if world:has(entity, comps.NPCTarget) then
			currentTarget = world:get(entity, comps.NPCTarget)
		end
		
		-- Validate current target
		if currentTarget then
			if not currentTarget.Parent or not currentTarget:FindFirstChild("Humanoid") then
				-- Target invalid
				world:remove(entity, comps.NPCTarget)
				currentTarget = nil
			else
				local targetRoot = currentTarget:FindFirstChild("HumanoidRootPart")
				local targetHum = currentTarget:FindFirstChild("Humanoid")
				
				if targetRoot and targetHum then
					local distance = (targetRoot.Position - hitbox.Position).Magnitude
					
					-- Check if target died or too far
					if targetHum.Health <= 0 then
						world:remove(entity, comps.NPPCTarget)
						currentTarget = nil
					elseif distance > config.letGoDistance then
						world:remove(entity, comps.NPCTarget)
						currentTarget = nil
					end
				else
					world:remove(entity, comps.NPCTarget)
					currentTarget = nil
				end
			end
		end
		
		-- Find new target if none
		if not currentTarget then
			-- Skip if passive and not attacked
			if combatState.isPassive and not combatState.hasBeenAttacked then
				continue
			end
			
			local newTarget = findClosestTarget(hitbox.Position, config.captureDistance, currentTarget)
			if newTarget then
				world:set(entity, comps.NPCTarget, newTarget)
			end
		end
	end
end

