return function(actor: Actor, mainConfig: table, studs: number)
	if (mainConfig.getTargetCFrame().Position - mainConfig.getNpcCFrame().Position).Magnitude < studs then
		return true
	end
	return false
end