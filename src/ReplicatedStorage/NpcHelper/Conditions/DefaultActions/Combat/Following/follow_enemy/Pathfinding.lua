local PathfindingService = game:GetService("PathfindingService")

local MapParams = RaycastParams.new()
MapParams.FilterDescendantsInstances = {workspace.World.Map}
MapParams.FilterType = Enum.RaycastFilterType.Include;

return function(npc: Model, mainConfig, target: Model | Vector3, Folder)
	local root,humanoid = npc:FindFirstChild("HumanoidRootPart"),npc:FindFirstChild("Humanoid")
	if not root 
		or not humanoid 
	then
		return false
	end
	
	--task.synchronize()
	local StateId = Folder.StateId.Value
	local typ = typeof(target)
	local Root,Hum = npc:FindFirstChild("HumanoidRootPart"),npc:FindFirstChild("Humanoid")
	local Entity_Size = npc:GetExtentsSize()
	local blockedconnect
	local Path = PathfindingService:CreatePath({
		AgentRadius = 2,
		AgentHeight = 5,
		AgentCanJump = true,
		AgentJumpHeight = 10,
		AgentMaxSlope = 45,
		WaypointSpacing = 4,
	})
	task.spawn(function()
		while Folder.StateId.Value == StateId and Folder.PathState.Value == 2 and Root ~= nil do
			local Position = (typ == "Vector3" and target) or (target:IsA("Model") and target:GetPivot().Position)
			local RootPos = Root.Position

			if (RootPos-Position).Magnitude <= 3 then
				break
			end
			local terminated = false;
			Path:ComputeAsync(RootPos,Position)
			local Way_Points = Path:GetWaypoints()
			local cur_index = 0;
			blockedconnect = Path.Blocked:Connect(function(waypointindex)
				if waypointindex >= cur_index then
					blockedconnect:Disconnect()
					terminated = true;
					blockedconnect = nil;
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
			task.wait(.15)
		end

		-- Stop movement when pathfinding ends
		if Hum then
			Hum:Move(Vector3.new(0, 0, 0))
		end

		if blockedconnect ~= nil then
			blockedconnect:Disconnect()
			blockedconnect = nil;
		end
	end)
	--task.desynchronize()
end