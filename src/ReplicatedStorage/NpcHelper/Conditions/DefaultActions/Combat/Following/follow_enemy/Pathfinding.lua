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
	local FinishedId = math.random(1,9999)
	local Conn: RBXScriptConnection; Conn = Hum.MoveToFinished:Connect(function(reached)
		if reached == true then
			FinishedId = math.random(1,9999)
		end
	end)
	task.spawn(function()
		while Folder.StateId.Value == StateId and Folder.PathState.Value == 2 and Root ~= nil do
			local Position = (typ == "Vector3" and target) or (target:IsA("Model") and target:GetPivot().Position)
			local RootPos = Root.Position

			if (RootPos-Position).Magnitude <= 2 then
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
				local Continue = false;
				Hum:MoveTo(v.Position)
				local CurId = FinishedId
				local Started = os.clock()
				repeat 
					local Time = Hum.WalkSpeed/16*2
					if v.Action == Enum.PathWaypointAction.Jump then
						Hum.Jump = true;
					end
					if os.clock()-Started >= Time then
						terminated = true;
					end    
					task.wait() 
				until Folder.StateId.Value ~= StateId or Folder.PathState.Value ~= 2 or Root == nil or CurId ~= FinishedId
			end
			task.wait(.15)
		end
		if Conn then
			Conn:Disconnect()
			Conn = nil;
		end
		if blockedconnect ~= nil then
			blockedconnect:Disconnect()
			blockedconnect = nil;
		end
	end)
	--task.desynchronize()
end