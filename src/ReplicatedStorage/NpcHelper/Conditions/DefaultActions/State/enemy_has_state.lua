return function(actor: Actor, mainConfig: table, state: string, value: any)
	local target = mainConfig.getTarget()
	
	--if true then
	--	return false
	--end
	
	

	return mainConfig.hasState(target, state, value)
end