local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StateManager = require(ReplicatedStorage.Modules.ECS.StateManager)

return function(actor: Actor, mainConfig: table, skillType: string)
	local target = mainConfig.getTarget()
	if not target then
		return false
	end

	-- Check if target is attacking using ECS StateManager
	local allActions = StateManager.GetAllStates(target, "Actions")
	if #allActions == 0 then
		return false
	end

	-- Get the first action (current attack)
	local currentAction = allActions[1]
	if not currentAction then
		return false
	end

	-- Check if skill data exists for this action
	local SkillData = mainConfig.getSkillData and mainConfig.getSkillData(currentAction)
	if not SkillData then
		return false
	end

	return SkillData[skillType] == true
end