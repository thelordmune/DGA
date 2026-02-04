local NetworkModule = {}; local Server = require(script.Parent.Parent);
NetworkModule.__index = NetworkModule

local Replicated = game:GetService("ReplicatedStorage")
local Library = require(Replicated.Modules.Library)
local Packets = require(Replicated.Modules.Packets)
local Visuals = require(Replicated.Modules.Visuals)
local StateManager = require(Replicated.Modules.ECS.StateManager)

local self = setmetatable({}, NetworkModule)

NetworkModule.EndPoint = function(Player, Data)
	local Character: Model = Player.Character

	if Data.Remove then
		if StateManager.StateCheck(Character, "Speeds", "FlashSpeedSet50") then
			StateManager.RemoveState(Character, "Speeds", "FlashSpeedSet50")
			Visuals.FireAllClients({Module = "Base", Function = "RemoveFlashStep", Arguments = {Character}})

		end
	else
		if not Character or StateManager.StateCount(Character, "Actions") or StateManager.StateCheck(Character, "Speeds", "FlashSpeedSet50") or StateManager.StateCount(Character, "Stuns") then return end
		if not Character:FindFirstChild("Energy") or Character.Energy.Value < 15 then return end

		Character.Energy.Value -= 15;

		StateManager.TimedState(Character, "Speeds", "FlashSpeedSet50", 1)
		
		Library.PlaySound(Character,Replicated.Assets.SFX.Movement.Flashstep)
		local Sound = Library.PlaySound(Character,Replicated.Assets.SFX.Movement.FlashstepLoop)
		Sound.Name = "FlashstepLoop"
		Visuals.Ranged(Character.HumanoidRootPart.Position,300,{Module = "Base", Function = "FlashStep", Arguments = {Character}})	
	end
	
	
end

return NetworkModule;