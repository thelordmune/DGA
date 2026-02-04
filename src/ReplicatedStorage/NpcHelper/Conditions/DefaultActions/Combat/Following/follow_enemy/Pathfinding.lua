local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StateManager = require(ReplicatedStorage.Modules.ECS.StateManager)

local MapParams = RaycastParams.new()
MapParams.FilterDescendantsInstances = {workspace.World.Map}
MapParams.FilterType = Enum.RaycastFilterType.Include;

-- Cache paths per NPC to avoid recreating them constantly
local PathCache = {}

-- Track active pathfinding threads to prevent spawning multiple threads for the same NPC
local ActiveThreads = {}

return function(npc: Model, mainConfig, target: Model | Vector3, Folder)
	local root,humanoid = npc:FindFirstChild("HumanoidRootPart"),npc:FindFirstChild("Humanoid")
	if not root
		or not humanoid
	then
		return false
	end

	-- Skip wanderer NPCs - ECS handles their movement
	local ECSBridge = require(game.ReplicatedStorage.NpcHelper.ECSBridge)
	if ECSBridge.isWandererNPC(npc) then
		return false
	end

	-- Don't pathfind during attacks to prevent stuttering using ECS StateManager
	if StateManager.StateCheck(npc, "Actions", "Attacking") then
		return false
	end

	-- CRITICAL FIX: Don't spawn a new thread if one is already running for this NPC
	-- This prevents memory leak from spawning 60 threads per second
	if ActiveThreads[npc] then
		return true -- Return true to indicate pathfinding is active
	end

	local StateId = Folder.StateId.Value
	local typ = typeof(target)
	local Root,Hum = npc:FindFirstChild("HumanoidRootPart"),npc:FindFirstChild("Humanoid")
	local blockedconnect

	-- Reuse or create path for this NPC
	local Path = PathCache[npc]
	if not Path then
		Path = PathfindingService:CreatePath({
			AgentRadius = 2,
			AgentHeight = 5,
			AgentCanJump = true,
			AgentJumpHeight = 10,
			AgentMaxSlope = 45,
			WaypointSpacing = 4,
		})
		PathCache[npc] = Path
	end

	-- Mark this NPC as having an active pathfinding thread
	ActiveThreads[npc] = true

	task.spawn(function()
		local lastRecomputeTime = 0
		local RECOMPUTE_INTERVAL = 0.5 -- Only recompute path every 0.5 seconds instead of 0.15

		while Folder.StateId.Value == StateId and Folder.PathState.Value == 2 and Root ~= nil do
			local Position = (typ == "Vector3" and target) or (target:IsA("Model") and target:GetPivot().Position)
			local RootPos = Root.Position

			if (RootPos-Position).Magnitude <= 3 then
				break
			end

			-- Don't pathfind during attacks to prevent stuttering using ECS StateManager
			if StateManager.StateCheck(npc, "Actions", "Attacking") then
				task.wait(0.1)
				continue
			end

			-- Only recompute path at intervals, not every frame
			local currentTime = os.clock()
			if currentTime - lastRecomputeTime < RECOMPUTE_INTERVAL then
				task.wait(0.1)
				continue
			end
			lastRecomputeTime = currentTime

			local terminated = false;
			Path:ComputeAsync(RootPos,Position)
			local Way_Points = Path:GetWaypoints()
			local cur_index = 0;

			-- Clean up old blocked connection
			if blockedconnect then
				blockedconnect:Disconnect()
				blockedconnect = nil
			end

			blockedconnect = Path.Blocked:Connect(function(waypointindex)
				if waypointindex >= cur_index then
					if blockedconnect then
						blockedconnect:Disconnect()
						blockedconnect = nil
					end
					terminated = true;
				end
			end)

			for i,v in Way_Points do
				if (Folder.StateId.Value ~= StateId or Folder.PathState.Value ~= 2 or Root == nil or terminated) then
					break
				end;
				if i == 1 then continue end; --skip first waypoint
				cur_index = i

				-- Use Humanoid:Move() instead of MoveTo() to prevent conflicts with other movement systems
				local Started = os.clock()
				local waypointReached = false

				while not waypointReached and (Folder.StateId.Value == StateId and Folder.PathState.Value == 2 and Root ~= nil and not terminated) do
					-- Don't move during attacks to prevent stuttering using ECS StateManager
					if StateManager.StateCheck(npc, "Actions", "Attacking") then
						task.wait(0.1)
						break
					end

					local currentPos = Root.Position
					local waypointPos = Vector3.new(v.Position.X, currentPos.Y, v.Position.Z) -- Ignore Y for distance check
					local direction = (waypointPos - currentPos).Unit

					-- Use Humanoid:Move() for smooth pathfinding that doesn't conflict with other systems
					Hum:Move(direction)

					if v.Action == Enum.PathWaypointAction.Jump then
						Hum.Jump = true;
					end

					-- Check if we've reached the waypoint (horizontal distance only)
					if (currentPos - waypointPos).Magnitude <= 2 then
						waypointReached = true
					end

					-- Timeout if stuck
					if os.clock() - Started > 3 then
						terminated = true
						break
					end

					task.wait()
				end
			end
			task.wait(0.1) -- Reduced from 0.15 to 0.1 for slightly more responsive pathfinding
		end

		-- Stop movement when pathfinding ends
		if Hum then
			Hum:Move(Vector3.new(0, 0, 0))
		end

		-- Clean up blocked connection
		if blockedconnect ~= nil then
			blockedconnect:Disconnect()
			blockedconnect = nil;
		end

		-- CRITICAL: Mark thread as inactive so new pathfinding can start
		ActiveThreads[npc] = nil

		-- Clean up path cache when NPC is removed
		if not npc or not npc.Parent then
			if PathCache[npc] then
				if PathCache[npc].Destroy then
					PathCache[npc]:Destroy()
				end
				PathCache[npc] = nil
			end
		end
	end)

	return true
end