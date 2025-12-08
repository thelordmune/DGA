--!strict


local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")

local world = require(ReplicatedStorage.Modules.ECS.jecs_world)
local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)
local RefManager = require(ReplicatedStorage.Modules.ECS.jecs_ref_manager)
local StateManager = require(ReplicatedStorage.Modules.ECS.StateManager)
local Jecs = require(ReplicatedStorage.Modules.Imports.jecs)

local GRID_SIZE = 50 -- 50 stud voxels
local playerGrid = {} -- [Vector3] = {Model}

local combatNPCQuery = world:query(
	comps.Character,
	comps.CombatNPC,
	comps.NPCCombatState,
	comps.NPCConfig,
	comps.Hitbox
):cached()

local lastUpdate = 0
local UPDATE_INTERVAL = 0.05

local cachedPlayers: {Model} = {}
local lastPlayerCacheTime = 0
local PLAYER_CACHE_INTERVAL = 0.5

local function getVoxelKey(position: Vector3): Vector3
	return Vector3.new(
		math.floor(position.X / GRID_SIZE) * GRID_SIZE,
		0,
		math.floor(position.Z / GRID_SIZE) * GRID_SIZE
	)
end

local function updatePlayerGrid()
	playerGrid = {}

	for _, player in cachedPlayers do
		local hrp = player:FindFirstChild("HumanoidRootPart")
		if hrp then
			local key = getVoxelKey(hrp.Position)
			if not playerGrid[key] then
				playerGrid[key] = {}
			end
			table.insert(playerGrid[key], player)
		end
	end
end

local function getNearbyPlayers(position: Vector3, radius: number): {Model}
	local nearby = {}
	local centerKey = getVoxelKey(position)

	for x = -1, 1 do
		for z = -1, 1 do
			local offset = Vector3.new(x * GRID_SIZE, 0, z * GRID_SIZE)
			local checkKey = centerKey + offset

			if playerGrid[checkKey] then
				for _, player in playerGrid[checkKey] do
					table.insert(nearby, player)
				end
			end
		end
	end

	return nearby
end

local function getAllPlayers(): {Model}
	local now = os.clock()
	if now - lastPlayerCacheTime < PLAYER_CACHE_INTERVAL then
		return cachedPlayers
	end

	cachedPlayers = {}
	for _, player in Players:GetPlayers() do
		if player.Character and player.Character:FindFirstChild("Humanoid") and player.Character.Humanoid.Health > 0 then
			table.insert(cachedPlayers, player.Character)
		end
	end

	updatePlayerGrid()

	lastPlayerCacheTime = now
	return cachedPlayers
end

local function hasBeenAttacked(character: Model): (boolean, Model?)
	local damageLog = character:FindFirstChild("Damage_Log")
	if damageLog and #damageLog:GetChildren() > 0 then
		local recentAttack = damageLog:GetChildren()[#damageLog:GetChildren()]
		if recentAttack and recentAttack.Value then
			return true, recentAttack.Value
		end
		return true, nil
	end
	
	if StateManager.StateCheck(character, "IFrames", "RecentlyAttacked") or
	   StateManager.StateCheck(character, "IFrames", "Damaged") then
		return true, nil
	end
	
	return false, nil
end

local function findClosestTarget(npcPos: Vector3, captureDistance: number, currentTarget: Model?): Model?
	local nearbyPlayers = getNearbyPlayers(npcPos, captureDistance)
	local closestPlayer = nil
	local closestDistance = captureDistance

	for _, player in nearbyPlayers do
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

local hasLoggedTargeting = false
local frameCount = 0

local function updateTargeting(dt: number)
	local now = os.clock()
	if now - lastUpdate < UPDATE_INTERVAL then
		return
	end
	lastUpdate = now
	frameCount += 1

	local guardCount = 0
	local guardsInQuery = 0
	for entity, character in world:query(comps.Character, comps.CombatNPC) do
		if character.Name:match("Guard") then
			guardCount += 1
		end
	end

	for entity, character, _, combatState, config, hitbox in combatNPCQuery do
		if character.Name:match("Guard") then
			guardsInQuery += 1
		end
	end

	if not hasLoggedTargeting or frameCount % 60 == 0 then

		if guardCount > 0 and guardsInQuery == 0 then

			for entity, character in world:query(comps.Character, comps.CombatNPC) do
				if character.Name:match("Guard") then

				end
			end
		end

		if not hasLoggedTargeting then
			hasLoggedTargeting = true
		end
	end

	getAllPlayers()

	for entity, character, _, combatState, config, hitbox in combatNPCQuery do
		if character.Name:match("Guard") then
		end

		local attacked, attacker = hasBeenAttacked(character)

		if character.Name:match("Guard") then
			local damageLog = character:FindFirstChild("Damage_Log")
			if damageLog then
			end
		end

		if attacked then
			-- Wanderers should never become aggressive - they only run away
			local isWanderer = character.Name:match("Wanderer")

			if not isWanderer and not combatState.isAggressive then
				combatState.isAggressive = true
				combatState.isPassive = false
				combatState.hasBeenAttacked = true

				config.captureDistance = math.max(config.captureDistance, 120)
				config.letGoDistance = math.max(config.letGoDistance, 150)

				world:set(entity, comps.NPCCombatState, combatState)
				world:set(entity, comps.NPCConfig, config)

			end

			-- Wanderers don't target attackers - they just run away (handled by behavior tree)
			if not isWanderer and attacker and attacker:IsA("Model") and attacker:FindFirstChild("Humanoid") then

				world:set(entity, comps.NPCTarget, attacker)


				if world:has(entity, comps.NPCTarget) then
					local target = world:get(entity, comps.NPCTarget)

				else

				end
				continue
			else

			end
		end
		
		local currentTarget = nil
		if world:has(entity, comps.NPCTarget) then
			currentTarget = world:get(entity, comps.NPCTarget)
		end
		
		if currentTarget then
			if not currentTarget.Parent or not currentTarget:FindFirstChild("Humanoid") then
				world:remove(entity, comps.NPCTarget)
				currentTarget = nil
			else
				local targetRoot = currentTarget:FindFirstChild("HumanoidRootPart")
				local targetHum = currentTarget:FindFirstChild("Humanoid")
				
				if targetRoot and targetHum then
					local distance = (targetRoot.Position - hitbox.Position).Magnitude
					
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
		
		if not currentTarget then
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


return {
	run = function(world: Jecs.World, dt: number)
		updateTargeting(dt)
	end,

	settings = {
		phase = "Heartbeat",
		depends_on = {},
		server_only = true
	}
}
