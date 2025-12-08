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
local StateManager = require(ReplicatedStorage.Modules.ECS.StateManager)
local Jecs = require(ReplicatedStorage.Modules.Imports.jecs)

-- Cache queries
local pathfindingQuery = world:query(
    comps.Character,
    comps.CombatNPC,
    comps.NPCTarget,
    comps.NPCPathfinding,
    comps.Hitbox,
    comps.Locomotion,
    comps.NPCConfig
):cached()

-- Path cache (entity -> Path)
local pathCache = {}

-- OPTIMIZED: Cache obstacle check results to reduce raycasts
local obstacleCheckCache = {} -- [entity] = {blocked, timestamp, distance}
local OBSTACLE_CHECK_CACHE_TIME = 0.1 -- Cache for 100ms

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
	for entity, character, _, target, pathfinding, hitbox, loco, config in pathfindingQuery do
		if not target or not target:IsDescendantOf(workspace) then
			pathfinding.isActive = false
			world:set(entity, comps.NPCPathfinding, pathfinding)
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
		local now = os.clock()
		local blocked = isPathBlocked(entity, hitbox.Position, targetRoot.Position, now)
		
		if not blocked then
			-- Path is clear - disable pathfinding
			pathfinding.isActive = false
			pathfinding.pathState = "Direct"
			world:set(entity, comps.NPCPathfinding, pathfinding)
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
				-- Pathfinding failed - fall back to direct movement
				pathfinding.isActive = false
				pathfinding.pathState = "Direct"
				world:set(entity, comps.NPCPathfinding, pathfinding)
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

				-- Update Locomotion component (movement intent) instead of humanoid:Move
				world:set(entity, comps.Locomotion, {
					dir = direction2D,
					speed = config.runSpeed, -- Always run when pathfinding
				})

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
		
		world:set(entity, comps.NPCPathfinding, pathfinding)
	end
end

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
