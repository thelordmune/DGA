local InputModule = {}
InputModule.__index = InputModule
local self = setmetatable({}, InputModule)

self.LastInput = os.clock()

InputModule.InputBegan = function(_, Client)
	Client.Modules["Movement"].Dodge()
end

InputModule.InputEnded = function(_, Client)
	
end

InputModule.InputChanged = function()

end

return InputModule
