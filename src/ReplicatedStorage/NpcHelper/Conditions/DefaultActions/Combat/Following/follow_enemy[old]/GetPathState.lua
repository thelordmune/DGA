--!strict
local raycastParams: RaycastParams do
	raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Include
	raycastParams.FilterDescendantsInstances = {workspace.World.Map}
end


type PathState = "Direct" | "Pathfind" 

return function(npc,mainConfig): PathState
	local target = mainConfig.getTarget()
	
	local ownPosition: Vector3 = npc:GetPivot().Position;
	local targetPosition: Vector3 = target:GetPivot().Position;

	local direction = (targetPosition - ownPosition).Unit * mainConfig.EnemyDetection.MaxCastDistance
	
	local rayResult = workspace:Raycast(ownPosition, direction, raycastParams)
	if not rayResult then
		return	`Direct`
	end
	
	local hitPart = rayResult.Instance
	------ print(`{hitPart.Name} || {hitPart.Parent.Name}`)

	
	local ToRot = (targetPosition - ownPosition).Magnitude
	local ToInstance = (rayResult.Position - ownPosition).Magnitude
	if ToInstance > ToRot or ToRot - ToInstance < 5 then
		return `Direct`
	end
	
	if hitPart:IsDescendantOf(target) or hitPart:IsDescendantOf(npc) then
		return `Direct`
	end

	return `Pathfind`
end