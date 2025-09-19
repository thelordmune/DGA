local Server = require(game:GetService("ServerScriptService").ServerConfig.Server)

local Library = Server.Library -- Replace StateManager with Library

return function(actor: Actor, mainConfig: table)
	local npc = actor:FindFirstChildOfClass("Model")
	if not npc then 
		return false
	end

	local humanoid = npc:FindFirstChild("Humanoid")
	if not humanoid then 
		return false 
	end

	local lastCheck = mainConfig.States.LastStateCheck or 0 
	if os.clock() - lastCheck < 0.15 then
		return true
	end
	mainConfig.States.LastStateCheck = os.clock()

	local npcStates = mainConfig.getState(npc)
	if not npcStates then 
		return false
	end

	-- Update auto-rotate check to use Library
	humanoid.AutoRotate = not (
		npc:FindFirstChild("ragdoll")
			or Library.StateCheck(npcStates, "Stunned")
			or Library.StateCheck(npcStates, "Unconscious") 
			or Library.StateCheck(npcStates, "NoRotation") 
			or npc:FindFirstChild("CantMove") or
			humanoid:GetState() == Enum.HumanoidStateType.Dead
	)

	local actions = {
		{
			condition = function()
				return Library.StateCheck(npcStates, "LockedMovement") 
					or Library.StateCheck(npcStates, "Unconscious") 
					or Library.StateCheck(npcStates, "Knocked")
			end,
			action = function()
				humanoid.WalkSpeed = 0
				humanoid.JumpPower = 0
			end
		},
		{
			condition = function()
				return Library.StateCheck(npcStates, "Stunned")
			end,
			action = function()
				humanoid.WalkSpeed = 3
				humanoid.JumpPower = 0
			end
		},
		{
			condition = function()
				return npc:FindFirstChild("CantMove") or npc:FindFirstChild("ragdoll")
			end,
			action = function()
				humanoid.WalkSpeed = 0
				humanoid.JumpPower = 0
			end
		},
		{
			condition = function()
				-- For value-based states, we need to implement custom handling
				-- This is a placeholder - you'll need to implement proper value checking
				return Library.StateCheck(npcStates, "ToSpeed") or Library.StateCheck(npcStates, "NoJump")
			end,
			action = function()
				-- This needs custom implementation for value-based states
				humanoid.WalkSpeed = Library.StateCheck(npcStates, "ToSpeed") and mainConfig.HumanoidDefaults.WalkSpeed or humanoid.WalkSpeed
				humanoid.JumpPower = Library.StateCheck(npcStates, "NoJump") and 0 or humanoid.JumpPower
			end
		},
		{
			condition = function()
				-- Sprinting check using Library
				return Library.StateCheck(npcStates, "Sprinting") or mainConfig.Run.IsRunning
			end,
			action = function()
				humanoid.WalkSpeed = mainConfig.HumanoidDefaults.RunSpeed
			end
		},
		{
			condition = function()
				return mainConfig.Idle.Idling
			end,
			action = function()
				humanoid.WalkSpeed = mainConfig.HumanoidDefaults.WalkSpeed / 1.45
			end
		},
		{
			condition = function() return true end,
			action = function()
				humanoid.WalkSpeed = mainConfig.HumanoidDefaults.WalkSpeed
				humanoid.JumpPower = mainConfig.HumanoidDefaults.JumpPower
			end
		}
	}

	for _, action in actions do
		if action.condition() then
			action.action()
			break
		end
	end

	return true
end