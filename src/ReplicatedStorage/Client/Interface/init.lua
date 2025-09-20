local Interface = {}; local Client = require(script.Parent);
Interface.__index = Interface;
local self = setmetatable({}, Interface);

Interface.Modules = {};
for _, Module in next, script:GetChildren() do
	if Module:IsA("ModuleScript") then
		self.Modules[Module.Name] = require(Module);
	end
end

Interface.UpdateStats = function(Stat: string, Value: number, Max: number)
	if self.Modules["Stats"][Stat] then
		self.Modules["Stats"][Stat](Value, Max);
	end	
end

Interface.Check = function()
	self.Modules["Stats"].Check();
end

Interface.LoadHotbar = function()
	self.Modules["Stats"].Hotbar("Initiate");
end

Interface.Party = function()
	self.Modules["Stats"].Party();
end

Interface.Hotbar = function()
	self.Modules["Stats"].Hotbar("Update");
end

return Interface
