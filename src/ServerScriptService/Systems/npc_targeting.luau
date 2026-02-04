--!strict


local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local world = require(ReplicatedStorage.Modules.ECS.jecs_world)
local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)
local StateManager = require(ReplicatedStorage.Modules.ECS.StateManager)
local Jecs = require(ReplicatedStorage.Modules.Imports.jecs)

local GRID_SIZE = 50 -- 50 stud voxels
local playerGrid = {} -- [Vector3] = {Model}

-- OPTIMIZED: :without(comps.Dead) excludes dead NPCs at archetype level (no per-entity check needed)
local combatNPCQuery = world:query(
	comps.Character,
	comps.CombatNPC,
	comps.NPCCombatState,
	comps.NPCConfig,
	comps.Hitbox
):without(comps.Dead):cached()

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

-- OPTIMIZED: Use ECS DamageHistory component instead of Damage_Log folder
local function hasBeenAttacked(entity: number, character: Model): (boolean, Model?)
	-- Check ECS DamageHistory component first (preferred)
	local damageHistory = world:get(entity, comps.DamageHistory)
	if damageHistory and damageHistory.lastDamageTime > 0 then
		-- Check if damage was recent (within 10 seconds)
		local now = os.clock()
		if now - damageHistory.lastDamageTime < 10 then
			return true, damageHistory.lastAttacker
		end
	end

	-- Fallback: Check legacy Damage_Log folder for backwards compatibility
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

-- PERFORMANCE: Removed debug variables and debug queries that were creating unnecessary overhead
local function updateTargeting(_dt: number)
	local now = os.clock()
	if now - lastUpdate < UPDATE_INTERVAL then
		return
	end
	lastUpdate = now

	getAllPlayers()

	for entity, character, _, combatState, config, hitbox in combatNPCQuery do
		local attacked, attacker = hasBeenAttacked(entity, character)

		if attacked then
			-- Wanderers should never become aggressive - they only run away
			local isWanderer = character.Name:match("Wanderer")

			if not isWanderer and not combatState.isAggressive then
				-- OPTIMIZED: In-place mutation instead of world:set()
				-- These are internal state changes, not network-synced
				combatState.isAggressive = true
				combatState.isPassive = false
				combatState.hasBeenAttacked = true

				config.captureDistance = math.max(config.captureDistance, 120)
				config.letGoDistance = math.max(config.letGoDistance, 150)
				-- No world:set() needed - components are mutated in-place
			end

			-- Wanderers don't target attackers - they just run away (handled by behavior tree)
			if not isWanderer and attacker and attacker:IsA("Model") and attacker:FindFirstChild("Humanoid") then
				world:set(entity, comps.NPCTarget, attacker)
				continue
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
						world:remove(entity, comps.NPCTarget)
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
	run = function(_world: Jecs.World, dt: number)
		updateTargeting(dt)
	end,

	settings = {
		phase = "Heartbeat",
		depends_on = {},
		server_only = true
	}
}
