local InputModule = {}
InputModule.__index = InputModule
local self = setmetatable({}, InputModule)

self.LastInput = os.clock()
self.ShiftHeld = false -- Track if shift key is being held
self.BufferedSprintAttempt = nil -- Track buffered sprint attempt

-- Input buffer window (seconds) - allows shift to be pressed slightly before other keys are released
local SPRINT_BUFFER_WINDOW = math.huge

InputModule.InputBegan = function(_, Client)
	self.ShiftHeld = true

	-- Check if sprint is locked (from CancelSprint packet)
	if Client.SprintLocked then
		print("[Run Input] 🔒 Sprint is locked - ignoring shift press until released first")
		return
	end

	-- Try to start sprinting immediately
	local canSprint = not Client.Library.StateCount(Client.Stuns) and not Client.Library.StateCount(Client.Actions)

	if canSprint then
		-- Can sprint immediately
		Client.Modules["Movement"].Run(true)
		self.LastInput = os.clock()
	else
		-- Buffer the sprint attempt - will try again shortly
		print("[Run Input] 🔄 Sprint buffered - waiting for states to clear")
		self.BufferedSprintAttempt = os.clock()

		-- Check every frame for a short window to see if we can start sprinting
		local checkConnection
		checkConnection = game:GetService("RunService").Heartbeat:Connect(function()
			local timeSinceBuffer = os.clock() - self.BufferedSprintAttempt

			-- If buffer window expired or shift was released, stop checking
			if timeSinceBuffer > SPRINT_BUFFER_WINDOW or not self.ShiftHeld then
				checkConnection:Disconnect()
				self.BufferedSprintAttempt = nil
				return
			end

			-- Check if we can sprint now
			local nowCanSprint = not Client.Library.StateCount(Client.Stuns) and not Client.Library.StateCount(Client.Actions)
			if nowCanSprint and self.ShiftHeld then
				print("[Run Input] ✅ Buffered sprint activated!")
				Client.Modules["Movement"].Run(true)
				self.LastInput = os.clock()
				self.BufferedSprintAttempt = nil
				checkConnection:Disconnect()
			end
		end)
	end
end

InputModule.InputEnded = function(_, Client)
	self.ShiftHeld = false
	self.BufferedSprintAttempt = nil -- Clear buffer when shift is released

	-- Clear sprint lock when shift is released
	if Client.SprintLocked then
		Client.SprintLocked = false
		print("[Run Input] 🔓 Sprint unlocked - shift was released")
	end

	---- print("[Run Input] ⌨️ Shift key released - calling Movement.Run(false)")
	Client.Modules["Movement"].Run(false)
end

InputModule.InputChanged = function()

end

-- Expose function to check if shift is held
InputModule.IsShiftHeld = function()
	return self.ShiftHeld
end

return InputModule
