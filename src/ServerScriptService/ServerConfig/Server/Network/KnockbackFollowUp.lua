local NetworkModule = {}; local Server = require(script.Parent.Parent);
NetworkModule.__index = NetworkModule

NetworkModule.EndPoint = function(Player, Data)
	local Character = Player.Character
	if not Character then return end

	Server.Modules.Combat["KnockbackFollowUp"](Character)
end

return NetworkModule
