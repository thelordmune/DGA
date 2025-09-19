local Events = {}; local Client = require(script.Parent);
Events.__index = Events;
local self = setmetatable({}, Events)


for _, Module in next, script:GetChildren() do
	if Module:IsA("ModuleScript") and not Module:HasTag("NetworkBlacklist") then
		local Required = require(Module);

		Client.Packets[Module.Name].listen(function(Data, Player)
			Required.EndPoint(Player, Data)
		end)
	end
end

return Events
