return function(actor: Actor, mainConfig: table, state: string)
	local npc = actor:FindFirstChildOfClass("Model")


	return mainConfig.hasState(npc,state)
end