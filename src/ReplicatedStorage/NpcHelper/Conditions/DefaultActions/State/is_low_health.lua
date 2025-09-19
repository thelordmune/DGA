return function(actor: Actor, mainConfig: table)
	local npc = actor:FindFirstChildOfClass("Model")
	if not npc then 
		return false
	end

	local root,humanoid = npc:FindFirstChild("HumanoidRootPart"),npc:FindFirstChild("Humanoid")
	if not root or not humanoid then
		return false
	end	
	
	--humanoid:Move(Vector3.zero)
	
	if humanoid.Health <= (humanoid.MaxHealth * mainConfig.EnemyDetection.RunAway.RunHp) then
		return true
	end	
	
	return false
end