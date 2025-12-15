local CLEAR_DAMAGE_LOG_ON_MAX_HEALTH = false;

return function(actor: Actor, mainConfig: table)
	local npc = actor:FindFirstChildOfClass("Model")
	if not npc then
		return false
	end

	if mainConfig.Spawning.Despawning.Enabled ~= true then
		return false
	end

	-- Check if NPC has PrimaryPart or HumanoidRootPart
	local rootPart = npc.PrimaryPart or npc:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		--warn(`[teleport_to_spawn] NPC {npc.Name} has no PrimaryPart or HumanoidRootPart`)
		return false
	end

	--task.synchronize()
	--TODO: if obstacles are in the way , switch method to pathfind

	---- print("herdfas")
	mainConfig.TeleportSpawn(rootPart.Position)
	npc:MoveTo(mainConfig.Spawning.SpawnedAt)


	--task.desynchronize()

end