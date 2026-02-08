local NetworkModule = {}; local Server = require(script.Parent.Parent);
NetworkModule.__index = NetworkModule

local Replicated = game:GetService("ReplicatedStorage")
local Library = require(Replicated.Modules.Library)
local Visuals = require(Replicated.Modules.Visuals)
local StateManager = require(Replicated.Modules.ECS.StateManager)

NetworkModule.EndPoint = function(Player, Data)
	local Character = Player.Character
	if not Character then return end

	local Root = Character:FindFirstChild("HumanoidRootPart")
	if not Root then return end

	-- Only allow feint if the player is currently in an M1 attack
	local allActions = StateManager.GetAllStates(Character, "Actions")
	local inM1 = false
	for _, action in ipairs(allActions) do
		if string.sub(action, 1, 2) == "M1" then
			inM1 = true
			break
		end
	end

	if not inM1 then return end

	-- Apply a brief FeintStun - this triggers the M1's stun listener
	-- which sets Cancel = true, stopping the attack before the hit frame
	Library.ApplyStun(Character, "FeintStun", 0.15)

	-- Add a brief recovery so the player can't instantly M1 again
	StateManager.TimedState(Character, "Actions", "FeintRecovery", 0.3)

	-- White highlight flash VFX
	Visuals.Ranged(Root.Position, 300, {Module = "Base", Function = "FeintFlash", Arguments = {Character}})
end

return NetworkModule
