local MetaData = {};
MetaData.__index = MetaData;
local self = setmetatable({}, MetaData);
if not game.Loaded then game.Loaded:Wait() end;

MetaData.Cache = {}

-- Load modules into cache
for _, Module in next, script:GetChildren() do
	MetaData.Cache[Module.Name] = require(Module);
end

-- Set metatable on the existing table
setmetatable(MetaData.Cache, {
	__index = function(_, index)
		print("a")
		return nil
	end,

	__newindex = function(_, index)
		warn(("New MetaData Added: %s"):format(index));
	end,
})


MetaData.RequestData = function(Name: string)
	return MetaData.Cache[Name]
end

return MetaData