return function(actor: Actor, mainConfig: table, skillType: string)
	local target = mainConfig.getTarget()
	local stateFolder = mainConfig.getState(target)
	
	local stateInstance = stateFolder:FindFirstChild("Attacking")

	if not stateInstance then 
		return false 
	end
	
	local SkillData = mainConfig.getSkillData(stateInstance.Value)
	--if true then
	--	return false
	--end
	

	return SkillData[skillType] == true
end