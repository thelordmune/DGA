local InputModule = {}
InputModule.__index = InputModule
local self = setmetatable({}, InputModule)

self.LastInput = os.clock()

InputModule.InputBegan = function(_, Client)
	Client.Modules["Movement"].Run(true)
	self.LastInput = os.clock()
end

InputModule.InputEnded = function(_, Client)
	Client.Modules["Movement"].Run(false)
end

InputModule.InputChanged = function()

end

return InputModule
