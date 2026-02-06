local ServerStorage = game:GetService("ServerStorage")
local Replicated = game:GetService("ReplicatedStorage")
local Utilities = require(Replicated.Modules.Utilities)
local Library = require(Replicated.Modules.Library)
local Packets = require(Replicated.Modules.Packets)
local Visuals = require(Replicated.Modules.Visuals)
local WeaponStats = require(ServerStorage.Stats._Weapons)

local NetworkModule = {}; local Server = require(script.Parent.Parent);
NetworkModule.__index = NetworkModule
local self = setmetatable({}, NetworkModule)

-- Attack Type enum decoder: uint8 -> string
local EnumToType = {
	[0] = "Normal",
	[1] = "Running",
	[2] = "None",
}

NetworkModule.EndPoint = function(Player, Data)
	local Character = Player.Character

	if not Character or not Character:GetAttribute("Equipped") then return end

	local PlayerObject = Server.Modules["Players"].Get(Player)

	-- Decode uint8 Type to string
	local AttackType = EnumToType[Data.Type] or "None"

	if PlayerObject and PlayerObject.Keys then
		PlayerObject.Keys["Attack"] = Data.Held

		if Data.Held then
			if AttackType == "None" then return end;

			Server.Modules.Combat["Light"](Character, Data.Air)
		end
	end
end

return NetworkModule;