
local pathFindingService = game:GetService("PathfindingService")

local raycastParams: RaycastParams do
	raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Include
	raycastParams.FilterDescendantsInstances = {workspace.World.Map}
end


local function visualizePath(waypoints: {PathWaypoint}, currentWaypoint: number?, time: number?)
	currentWaypoint = currentWaypoint or 1
	time = time or 1/60

	local model = Instance.new("Model")

	for index, waypoint in next, waypoints do
		local isCurrent = index == currentWaypoint
		local nextWaypoint = waypoints[index+1]

		local visualizerPart = Instance.new("Part")
		visualizerPart.Anchored = true
		visualizerPart.CanCollide = false
		visualizerPart.Transparency = 1
		visualizerPart.CFrame = nextWaypoint and CFrame.lookAt(waypoint.Position, nextWaypoint.Position) or CFrame.new(waypoint.Position)
		visualizerPart.Parent = model

		local handle = Instance.new("ConeHandleAdornment")
		handle.Color3 = isCurrent and Color3.new(0, 1, 0) or Color3.new(1, 0, 0)
		handle.Visible = true
		handle.Adornee = visualizerPart
		handle.Parent = visualizerPart

	end

	model.Parent = workspace

	task.delay(time, function()
		model:Destroy()
	end)

end

return function(npc: Model, mainConfig, target: Model | Vector3)
	local root,humanoid = npc:FindFirstChild("HumanoidRootPart"),npc:FindFirstChild("Humanoid")
	if not root 
		or not humanoid 
	then
		return false
	end

	if mainConfig.Pathfinding.IsRunning then 
		return "RUNNING"
	end

	--task.synchronize()

	local goalPosition: Vector3 = Vector3.zero
	if typeof(target) == "Vector3" then
		goalPosition = target
	else
		local goalPosition = if typeof(target) == "Instance" 
			then target:GetPivot().Position else target 
		local startPosition = npc:GetPivot().Position



		mainConfig.Pathfinding.IsRunning = true 

		local entitySize = npc:GetExtentsSize()

		task.spawn(function()
			local currentIndex = 0;
			local terminated = false;
			local path = pathFindingService:CreatePath({
				AgentRadius = entitySize.Z;
				AgentHeight = entitySize.Y;
				WaypointSpacing = 2;
				AgentCanJump = true;
			})


			path:ComputeAsync(startPosition,goalPosition)

			local wayPoints = path:GetWaypoints()
			local blockedConnection; blockedConnection = path.Blocked:Connect(function(waypointIndex)
				---- print("its blocked")
				if waypointIndex >= currentIndex then
					humanoid.Jump = true

					blockedConnection:Disconnect(); blockedConnection = nil
					terminated = true

				end
			end)

			for i,waypoint in wayPoints do
				currentIndex = i
				--visualizePath(wayPoints, currentIndex, 1)


				while npc.Parent and not terminated and humanoid.Health > 0 and mainConfig.Pathfinding.PathState == "Pathfind" do
					--humanoid:MoveTo(waypoint.Position)


					local difference = (waypoint.Position - npc:GetPivot().Position)
					-- Apply movement directly
					humanoid:Move(difference.Unit)

					if waypoint.Action == Enum.PathWaypointAction.Jump then
						humanoid.Jump = true
					end

					local currentPosition = root.Position
					if (currentPosition - Vector3.new(
						waypoint.Position.X,
						currentPosition.Y,
						waypoint.Position.Z)).Magnitude <= 1 then
						break
					end

					task.wait()
				end

			end

			if blockedConnection then 
				blockedConnection:Disconnect();
			end
			path:Destroy()
			path = nil;
			mainConfig.Pathfinding.IsRunning = false
		end)

	end

	--task.desynchronize()
	return true
end