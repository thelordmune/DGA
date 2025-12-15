return function(actor: Actor, mainConfig: table, studs: number)
	local npc = actor:FindFirstChildOfClass("Model")
	local target = mainConfig.getTarget()

	if not target then
		-- ---- print("enemy_within_range:", npc and npc.Name or "Unknown", "- No target found")
		return false
	end

	local targetCFrame = mainConfig.getTargetCFrame()
	local npcCFrame = mainConfig.getNpcCFrame()

	if not targetCFrame or not npcCFrame then
		-- ---- print("enemy_within_range:", npc and npc.Name or "Unknown", "- Missing CFrame data")
		return false
	end

	local distance = (targetCFrame.Position - npcCFrame.Position).Magnitude
	local inRange = distance < studs

	-- ---- print("enemy_within_range:", npc and npc.Name or "Unknown", "- Distance:", math.floor(distance), "Range:", studs, "InRange:", inRange)

	if inRange then
		return true
	end
	return false
end