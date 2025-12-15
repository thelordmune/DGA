return function(actor: Actor, mainConfig: table, skill: string)
	------ print("Performing attack!")
	return mainConfig.performAction(skill)
end