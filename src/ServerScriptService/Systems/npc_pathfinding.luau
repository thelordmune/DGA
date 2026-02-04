--!strict
--[[
    NPC Pathfinding System (ECS)
    
    Handles pathfinding when NPCs are blocked by obstacles.
    Uses PathfindingService with:
    - Path caching per NPC
    - Waypoint following
    - Jump detection
    - Path recomputation (every 0.5s)
    
    Runs at ~20 Hz
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PathfindingService = game:GetService("PathfindingService")

local world = require(ReplicatedStorage.Modules.ECS.jecs_world)
local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)
local EntityCleanup = require(ReplicatedStorage.Modules.ECS.entity_cleanup)
local StateManager = require(ReplicatedStorage.Modules.ECS.StateManager)
local Jecs = require(ReplicatedStorage.Modules.Imports.jecs)

-- Cache queries
-- OPTIMIZED: :without(comps.Dead) excludes dead NPCs at archetype level
local pathfindingQuery = world:query(
    comps.Character,
    comps.CombatNPC,
    comps.NPCTarget,
    comps.NPCPathfinding,
    comps.Hitbox,
    comps.Locomotion,
    comps.NPCConfig
):without(comps.Dead):cached()

-- Path cache (entity -> Path)
local pathCache = {}

-- OPTIMIZED: Cache obstacle check results to reduce raycasts
local obstacleCheckCache = {} -- [entity] = {blocked, timestamp, distance}
local OBSTACLE_CHECK_CACHE_TIME = 0.1 -- Cache for 100ms
local CACHE_CLEANUP_INTERVAL = 5 -- Cleanup stale cache entries every 5 seconds
local lastCacheCleanup = 0

-- OPTIMIZED: Throttle to 10 Hz (was running every frame)
local PATHFINDING_HZ = 10
local PATHFINDING_TICK = 1 / PATHFINDING_HZ
local pathfindingAcc = 0

-- Raycast params for obstacle detection
local raycastParams = RaycastParams.new()
raycastParams.FilterDescendantsInstances = {workspace.World.Visuals, workspace.World.Live}
raycastParams.FilterType = Enum.RaycastFilterType.Exclude

-- Check if path is blocked (OPTIMIZED: with caching)
local function isPathBlocked(entity: number, startPos: Vector3, endPos: Vector3, now: number): boolean
	-- Check cache first
	local cached = obstacleCheckCache[entity]
	if cached and (now - cached.timestamp) < OBSTACLE_CHECK_CACHE_TIME then
		local currentDistance = (endPos - startPos).Magnitude
		-- Reuse cached result if distance hasn't changed much
		if math.abs(currentDistance - cached.distance) < 5 then
			return cached.blocked
		end
	end
	local direction = (endPos - startPos)
	local distance = direction.Magnitude
	
	if distance < 2 then return false end
	
	local result = workspace:Raycast(startPos, direction.Unit * (distance + 1), raycastParams)
	local blocked = false
	if result and result.Position then
		local hitDistance = (result.Position - startPos).Magnitude
		if hitDistance < (distance - 2) then
			blocked = true
		end
	end

	-- Cache the result
	obstacleCheckCache[entity] = {
		blocked = blocked,
		timestamp = now,
		distance = distance
	}

	return blocked
end

-- Get or create path for entity
local function getPath(entity: number): Path
	if not pathCache[entity] then
		pathCache[entity] = PathfindingService:CreatePath({
			AgentRadius = 2,
			AgentHeight = 5,
			AgentCanJump = true,
			AgentJumpHeight = 10,
			AgentMaxSlope = 45,
			WaypointSpacing = 4,
		})
	end
	return pathCache[entity]
end

-- Main system function
local function updatePathfinding(dt: number)
	-- OPTIMIZED: Throttle to 10 Hz (was running every frame ~60 Hz)
	pathfindingAcc += dt
	if pathfindingAcc < PATHFINDING_TICK then
		return
	end
	pathfindingAcc = 0

	local now = os.clock()

	-- Periodic cleanup of stale cache entries to prevent memory leaks
	if now - lastCacheCleanup > CACHE_CLEANUP_INTERVAL then
		lastCacheCleanup = now
		for entity in pairs(obstacleCheckCache) do
			if not world:exists(entity) then
				obstacleCheckCache[entity] = nil
				pathCache[entity] = nil
			end
		end
		for entity in pairs(pathCache) do
			if not world:exists(entity) then
				pathCache[entity] = nil
			end
		end
	end

	for entity, character, _, target, pathfinding, hitbox, loco, config in pathfindingQuery do
		if not target or not target:IsDescendantOf(workspace) then
			-- In-place mutation (no world:set needed)
			pathfinding.isActive = false
			continue
		end
		
		local humanoid = character:FindFirstChild("Humanoid")
		if not humanoid then continue end
		
		-- Don't pathfind during actions
		if StateManager.StateCount(character, "Actions") then
			continue
		end
		
		local targetRoot = target:FindFirstChild("HumanoidRootPart")
		if not targetRoot then continue end

		-- Check if path is blocked (OPTIMIZED: with caching)
		local blocked = isPathBlocked(entity, hitbox.Position, targetRoot.Position, now)
		
		if not blocked then
			-- Path is clear - disable pathfinding (in-place mutation)
			pathfinding.isActive = false
			pathfinding.pathState = "Direct"
			continue
		end
		
		-- Path is blocked - use pathfinding
		pathfinding.isActive = true
		pathfinding.pathState = "Pathfind"


		-- Recompute path every 0.5s (now already defined above)
		if not pathfinding.waypoints or (now - pathfinding.lastRecomputeTime) > 0.5 then
			local path = getPath(entity)
			
			local success, errorMsg = pcall(function()
				path:ComputeAsync(hitbox.Position, targetRoot.Position)
			end)
			
			if success and path.Status == Enum.PathStatus.Success then
				pathfinding.waypoints = path:GetWaypoints()
				pathfinding.currentWaypointIndex = 1
				pathfinding.lastRecomputeTime = now
			else
				-- Pathfinding failed - fall back to direct movement (in-place mutation)
				pathfinding.isActive = false
				pathfinding.pathState = "Direct"
				continue
			end
		end
		
		-- Follow waypoints
		if pathfinding.waypoints and #pathfinding.waypoints > 0 then
			local currentWaypoint = pathfinding.waypoints[pathfinding.currentWaypointIndex]

			if currentWaypoint then
				-- Calculate direction toward waypoint
				local direction = (currentWaypoint.Position - hitbox.Position)
				local direction2D = Vector3.new(direction.X, 0, direction.Z)

				if direction2D.Magnitude > 0.001 then
					direction2D = direction2D.Unit
				else
					direction2D = Vector3.zero
				end

				-- Update Locomotion with change detection (in-place mutation)
				local dirChanged = (loco.dir - direction2D).Magnitude > 0.001
				local speedChanged = math.abs(loco.speed - config.runSpeed) > 0.1
				if dirChanged or speedChanged then
					loco.dir = direction2D
					loco.speed = config.runSpeed -- Always run when pathfinding
				end

				-- Jump if needed
				if currentWaypoint.Action == Enum.PathWaypointAction.Jump then
					humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
				end

				-- Check if reached waypoint
				local distance = (currentWaypoint.Position - hitbox.Position).Magnitude
				if distance < 4 then
					pathfinding.currentWaypointIndex += 1

					-- Reached end of path
					if pathfinding.currentWaypointIndex > #pathfinding.waypoints then
						pathfinding.isActive = false
						pathfinding.pathState = "Direct"
						pathfinding.waypoints = nil
					end
				end
			end
		end
		-- pathfinding is mutated in-place, no world:set needed
	end
end

-- Cleanup when entity is removed (prevents memory leak from cache tables)
local function cleanup(entity: number)
	obstacleCheckCache[entity] = nil
	pathCache[entity] = nil
end

-- Register cleanup callback for centralized entity cleanup
EntityCleanup.register("npc_pathfinding_ecs", cleanup)

return {
	run = function(world: Jecs.World, dt: number)
		updatePathfinding(dt)
	end,

	settings = {
		phase = "Heartbeat",
		depends_on = {},
		server_only = true
	}
}
