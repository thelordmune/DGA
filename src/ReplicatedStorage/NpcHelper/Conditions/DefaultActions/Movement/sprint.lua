
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
	---- print("go on nd sprint")
	mainConfig.InitiateRun(true)
	
	
	return true
end
