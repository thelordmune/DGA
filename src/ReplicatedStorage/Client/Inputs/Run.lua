local InputModule = {}
InputModule.__index = InputModule
local self = setmetatable({}, InputModule)

self.LastInput = os.clock()
self.ShiftHeld = false -- Track if shift key is being held

InputModule.InputBegan = function(_, Client)
	self.ShiftHeld = true

	-- Check if sprint is locked (from CancelSprint packet)
	if Client.SprintLocked then
		print("[Run Input] 🔒 Sprint is locked - ignoring shift press until released first")
		return
	end

	-- print("[Run Input] ⌨️ Shift key pressed - calling Movement.Run(true)")
	Client.Modules["Movement"].Run(true)
	self.LastInput = os.clock()
end

InputModule.InputEnded = function(_, Client)
	self.ShiftHeld = false

	-- Clear sprint lock when shift is released
	if Client.SprintLocked then
		Client.SprintLocked = false
		print("[Run Input] 🔓 Sprint unlocked - shift was released")
	end

	-- print("[Run Input] ⌨️ Shift key released - calling Movement.Run(false)")
	Client.Modules["Movement"].Run(false)
end

InputModule.InputChanged = function()

end

-- Expose function to check if shift is held
InputModule.IsShiftHeld = function()
	return self.ShiftHeld
end

return InputModule
