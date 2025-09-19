local NetworkModule = {}; local Server = require(script.Parent.Parent);
NetworkModule.__index = NetworkModule

local Replicated = game:GetService("ReplicatedStorage")
local Library = require(Replicated.Modules.Library)
local Packets = require(Replicated.Modules.Packets)
local Visuals = require(Replicated.Modules.Visuals)

local self = setmetatable({}, NetworkModule)

NetworkModule.EndPoint = function(Player, Data)
	local Character: Model = Player.Character
	
	local Character = Player.Character

	if not Character or not Character:GetAttribute("Equipped") then return end
	
	local PlayerObject = Server.Modules["Players"].Get(Player)

	if PlayerObject  then
		if Character:GetAttribute("Feint") and not Library.CheckCooldown(Character,"Feint") then
			Library.SetCooldown(Character,"Feint",1.5)
			Library.TimedState(Character.Stuns,"FeintStun",0)
		end	
	end
	
end

return NetworkModule;