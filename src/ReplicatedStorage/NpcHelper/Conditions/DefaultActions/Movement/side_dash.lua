
return function(actor: Actor, mainConfig: table)
	------ print("Moving to target...")



	local npc_states = mainConfig.getState()

	if not npc_states then
		return false
	end

	if not mainConfig.getTarget() then
		return
	end


	------ print("true")
	mainConfig.InitiateBlock(true)
	return true
end
