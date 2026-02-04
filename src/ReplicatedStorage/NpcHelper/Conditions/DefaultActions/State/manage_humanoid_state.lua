local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StateManager = require(ReplicatedStorage.Modules.ECS.StateManager)

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

	-- Update auto-rotate check using ECS StateManager
	humanoid.AutoRotate = not (
		npc:FindFirstChild("ragdoll")
			or StateManager.StateCheck(npc, "Stuns", "Stunned")
			or StateManager.StateCheck(npc, "Stuns", "Unconscious")
			or StateManager.StateCheck(npc, "Stuns", "NoRotation")
			or npc:FindFirstChild("CantMove") or
			humanoid:GetState() == Enum.HumanoidStateType.Dead
	)

	local actions = {
		{
			condition = function()
				return StateManager.StateCheck(npc, "Stuns", "LockedMovement")
					or StateManager.StateCheck(npc, "Stuns", "Unconscious")
					or StateManager.StateCheck(npc, "Stuns", "Knocked")
			end,
			action = function()
				humanoid.WalkSpeed = 0
				humanoid.JumpPower = 0
			end
		},
		{
			condition = function()
				return StateManager.StateCheck(npc, "Stuns", "Stunned")
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
				return StateManager.StateCheck(npc, "Stuns", "ToSpeed") or StateManager.StateCheck(npc, "Stuns", "NoJump")
			end,
			action = function()
				humanoid.WalkSpeed = StateManager.StateCheck(npc, "Stuns", "ToSpeed") and mainConfig.HumanoidDefaults.WalkSpeed or humanoid.WalkSpeed
				humanoid.JumpPower = StateManager.StateCheck(npc, "Stuns", "NoJump") and 0 or humanoid.JumpPower
			end
		},
		{
			condition = function()
				-- Sprinting check using ECS StateManager
				return StateManager.StateCheck(npc, "Stuns", "Sprinting") or mainConfig.Run.IsRunning
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