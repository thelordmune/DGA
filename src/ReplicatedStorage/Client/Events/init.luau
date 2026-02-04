local Events = {}; local Client = require(script.Parent);
Events.__index = Events;
local self = setmetatable({}, Events)


for _, Module in next, script:GetChildren() do
	if Module:IsA("ModuleScript") and not Module:HasTag("NetworkBlacklist") then
		local Required = require(Module);

		-- Check if this module has an EndPoint function (is a packet handler)
		if Required.EndPoint and typeof(Required.EndPoint) == "function" then
			-- Check if the packet exists
			if Client.Packets[Module.Name] then
				Client.Packets[Module.Name].listen(function(Data, Player)
					Required.EndPoint(Player, Data)
				end)
			else
				warn(`[Events] Packet '{Module.Name}' does not exist - skipping listener setup`)
			end
		end
		-- Modules without EndPoint (like Bvel, VFX) register their own listeners internally
	end
end

return Events
