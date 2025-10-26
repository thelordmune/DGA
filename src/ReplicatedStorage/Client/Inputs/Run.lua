local InputModule = {}
InputModule.__index = InputModule
local self = setmetatable({}, InputModule)

self.LastInput = os.clock()

InputModule.InputBegan = function(_, Client)
	print("[Run Input] Key pressed - attempting to start running")
	Client.Modules["Movement"].Run(true)
	self.LastInput = os.clock()
end

InputModule.InputEnded = function(_, Client)
	print("[Run Input] Key released - attempting to stop running")
	Client.Modules["Movement"].Run(false)
end

InputModule.InputChanged = function()

end

return InputModule
