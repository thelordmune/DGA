local Interface = {}; local Client = require(script.Parent);
Interface.__index = Interface;
local self = setmetatable({}, Interface);

Interface.Modules = {};
-- print("[Interface] Loading modules from Interface folder...")
for _, Module in next, script:GetChildren() do
	if Module:IsA("ModuleScript") then
		-- print(`[Interface] Loading module: {Module.Name}`)
		self.Modules[Module.Name] = require(Module);
		-- print(`[Interface] ✅ Loaded: {Module.Name}`)
	end
end
-- print(`[Interface] Total modules loaded: {#self.Modules}`)

Interface.UpdateStats = function(Stat: string, Value: number, Max: number)
	if self.Modules["Stats"][Stat] then
		self.Modules["Stats"][Stat](Value, Max);
	end	
end

Interface.Check = function()
	self.Modules["Stats"].Check();
end

Interface.Party = function()
	self.Modules["Stats"].Party();
end

-- Initialize Hotbar
Interface.InitializeHotbar = function(character, entity)
	-- print("[Interface] InitializeHotbar called")
	-- print(`[Interface] Stats module: {self.Modules["Stats"]}`)
	-- print(`[Interface] InitializeHotbar function: {self.Modules["Stats"] and self.Modules["Stats"].InitializeHotbar}`)

	if self.Modules["Stats"] and self.Modules["Stats"].InitializeHotbar then
		-- print("[Interface] ✅ Calling Stats.InitializeHotbar...")
		return self.Modules["Stats"].InitializeHotbar(character, entity)
	else
		-- print("❌ Stats module or InitializeHotbar not found!")
		-- print(`[Interface] Stats module exists: {self.Modules["Stats"] ~= nil}`)
		if self.Modules["Stats"] then
			-- print(`[Interface] Stats functions: {self.Modules["Stats"]}`)
		end
	end
end

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
