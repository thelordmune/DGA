return function(actor: Actor, mainConfig: table, action: string, repetitions: number)
	---- print("Performing attack!")
	
	for i = 1,repetitions do 
		mainConfig.performAction(action)
	end
	return true
end