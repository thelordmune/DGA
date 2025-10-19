local Pathfinding = require(script.Parent.Pathfinding)
local raycastParams: RaycastParams do
	raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = {workspace.World.Live.Mobs,workspace.World.Visuals}
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
end


type PathState = "Direct" | "Pathfind" 

return function(npc,mainConfig): PathState
	local target: Model = mainConfig.getTarget()

	if not npc or not target then
		return false
	end

	local Root,Hum = npc:FindFirstChild("HumanoidRootPart"),npc:FindFirstChild("Humanoid")
	if not Root or not Hum then
		return false
	end

	local PathState: PathState = ""

	local typ = typeof(target)
	local TargetPosition = (typ == "Vector3" and target) or (target:IsA("Model") and target:GetPivot().Position)
	local RootPos = Root.Position
	local Direction = (TargetPosition-RootPos)
	local UnitVector = Direction.Unit
	local Mag = Direction.Magnitude + 1;
	local results = workspace:Raycast(RootPos,UnitVector * Mag,raycastParams)
	local Pass = 1;
	if results ~= nil and results.Position ~= nil then
		local Difference = (results.Position-(RootPos+(UnitVector * Mag))).Magnitude
		if Difference > 5 then
			Pass = 2;
		end
	end
	local AiFolder: Folder = mainConfig.getMimic()
	if Hum.FloorMaterial ~= Enum.Material.Air and Hum.FloorMaterial ~= nil and Pass ~= AiFolder.PathState.Value then
		--task.synchronize()
		AiFolder.StateId.Value = math.random(1,9999);
		AiFolder.PathState.Value = Pass;
		--task.desynchronize()
		if Pass == 2 then 
			PathState = "Pathfind"
			Pathfinding(npc, mainConfig, target, mainConfig.getMimic())
		end
	end
	if Pass == 1 then
		-- print("yo yo?")
		PathState = "Direct"
	end

	return PathState
end


----!strict
--local raycastParams: RaycastParams do
--	raycastParams = RaycastParams.new()
--	raycastParams.FilterType = Enum.RaycastFilterType.Include
--	raycastParams.FilterDescendantsInstances = {workspace.World.Map}
--end


--type PathState = "Direct" | "Pathfind" 

--return function(npc,mainConfig): PathState
--	local target = mainConfig.getTarget()

--	local ownPosition: Vector3 = npc:GetPivot().Position;
--	local targetPosition: Vector3 = target:GetPivot().Position;

--	local direction = (targetPosition - ownPosition).Unit * mainConfig.EnemyDetection.MaxCastDistance


--	local PathState: PathState = "Pathfind"




--	if (ownPosition - targetPosition).Magnitude > 4 then 
--		local rayResult = workspace:Raycast(ownPosition, direction, raycastParams)

--		if not rayResult then
--			PathState = `Direct`

--		end


--	end



--	--local hitPart = rayResult.Instance
--	------ print(`{hitPart.Name} || {hitPart.Parent.Name}`)




--	--if hitPart:IsDescendantOf(target) or hitPart:IsDescendantOf(npc) then
--	--	return `Direct`
--	--end

--	return PathState
--end