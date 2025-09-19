local ServerStorage = game:GetService("ServerStorage")
local Replicated = game:GetService("ReplicatedStorage")
local Server 
local Utilities = require(Replicated.Modules.Utilities)
local Library = require(Replicated.Modules.Library)
local Packets = require(Replicated.Modules.Packets)
local Visuals = require(Replicated.Modules.Visuals)
local WeaponStats = require(ServerStorage.Stats._Weapons)

local NetworkModule = {}; local Server = require(script.Parent.Parent);
NetworkModule.__index = NetworkModule
local self = setmetatable({}, NetworkModule)

NetworkModule.EndPoint = function(Player, Data)
	local Character = Player.Character
	
	if not Character or not Character:GetAttribute("Equipped") then return end
	
	local PlayerObject = Server.Modules["Players"].Get(Player)
	
	if PlayerObject and PlayerObject.Keys then
		PlayerObject.Keys["Attack"] = Data.Held
			
		if Data.Held then
			Server.Modules.Combat["Critical"](Character)
		end
	end
end

return NetworkModule;