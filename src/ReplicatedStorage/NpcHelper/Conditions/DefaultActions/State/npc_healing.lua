local CLEAR_DAMAGE_LOG_ON_MAX_HEALTH = false;

return function(actor: Actor, mainConfig: table)
	--print("we here fsafsdf")

	local npc = actor:FindFirstChildOfClass("Model")
	if not npc then 
		return false
	end

	local humanoid = npc:FindFirstChild("Humanoid")
	if not humanoid then 
		return false 
	end
	
	if humanoid.Health >= humanoid.MaxHealth then 
		return false
	end
	
	
	local healSettings = mainConfig.Setting.Heal
	if os.clock() - mainConfig.Setting.LastStunned < healSettings.CooldownFromStun then
		return false
	end
	
	if os.clock() - healSettings.LastHealed < healSettings.HealEvery then
		return false
	end
	
	--task.synchronize()
	healSettings.LastHealed = os.clock()
	humanoid.Health += humanoid.MaxHealth * healSettings.AddAmount
	
	if CLEAR_DAMAGE_LOG_ON_MAX_HEALTH then
		if humanoid.Health >= humanoid.MaxHealth then
			local damageLog = npc:FindFirstChild("Damage_Log")
			local _ = damageLog and damageLog:ClearAllChildren()
		end
	end
	
	
	--task.desynchronize()
end