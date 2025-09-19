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
			print("holding")
			Server.Modules.Combat["HandleBlockInput"](Character,true)
		else
			print("let go")
			Server.Modules.Combat["HandleBlockInput"](Character,false)
		end
	end

end

return NetworkModule;