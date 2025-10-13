return function(actor: Actor, mainConfig: table)
	local npc = mainConfig.getNpc()
	if not npc then
		return false
	end

	local humanoid = npc:FindFirstChild("Humanoid") :: Humanoid
	if not humanoid then
		return false
	end

	local humanoidRootPart = npc:FindFirstChild("HumanoidRootPart") :: BasePart
	if not humanoidRootPart then
		return
	end

	local npc_states = mainConfig.getState()

	if not npc_states then
		--print("here1")
		return false
	end

	--TODO: when add to game framework
	--if to_path.Check(npc) then 
	--return false
	--end

	if not mainConfig.getTarget() then
		--print("here2")
		return
	end

	local runConfig = mainConfig.Run;
	if not runConfig.RunOnFollowing.Enabled then
		--print("here3")
		return false
	end

	--if not humanoidRootPart or humanoidRootPart.AssemblyAngularVelocity.Magnitude <= 5 then
		--return false
	--end

	--if not (humanoid.MoveDirection.Magnitude > 0) then
	--	print("here4")
	--	return false
	--end

	local distance = (mainConfig.getNpcCFrame().Position - mainConfig.getTargetCFrame().Position).Magnitude

	local shouldSprint = if runConfig.RunOnFollowing.AwayOrNear == "Near" then distance <= runConfig.RunOnFollowing.Distance
		else distance >= runConfig.RunOnFollowing.Distance

	if shouldSprint then
		print(`[NPC Sprint] {npc.Name} should sprint - Distance: {math.floor(distance)} studs`)
	end

	return shouldSprint
end
