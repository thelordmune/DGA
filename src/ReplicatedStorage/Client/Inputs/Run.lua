local InputModule = {}
InputModule.__index = InputModule
local self = setmetatable({}, InputModule)

self.LastInput = os.clock()

InputModule.InputBegan = function(_, Client)
	-- print("[Run Input] ⌨️ Shift key pressed - calling Movement.Run(true)")
	Client.Modules["Movement"].Run(true)
	self.LastInput = os.clock()
end

InputModule.InputEnded = function(_, Client)
	-- print("[Run Input] ⌨️ Shift key released - calling Movement.Run(false)")
	Client.Modules["Movement"].Run(false)
end

InputModule.InputChanged = function()

end

return InputModule
