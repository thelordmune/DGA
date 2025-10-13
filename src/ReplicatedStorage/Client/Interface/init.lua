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

-- Expose CooldownDisplay module
Interface.CooldownDisplay = self.Modules["CooldownDisplay"]

-- Initialize Leaderboard
Interface.InitLeaderboard = function()
	if self.Modules["Leaderboard"] and self.Modules["Leaderboard"].new then
		local leaderboard = self.Modules["Leaderboard"].new()
		leaderboard:Initialize()
		return leaderboard
	end
end

-- Initialize Quest Tracker
Interface.InitQuestTracker = function()
	if self.Modules["QuestTracker"] and self.Modules["QuestTracker"].new then
		local questTracker = self.Modules["QuestTracker"].new()
		questTracker:Initialize()
		return questTracker
	end
end

return Interface
