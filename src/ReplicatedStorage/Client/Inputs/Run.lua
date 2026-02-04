local InputModule = {}
InputModule.__index = InputModule
local self = setmetatable({}, InputModule)

self.LastInput = os.clock()
self.ShiftHeld = false -- Track if shift key is being held
self.BufferConnection = nil -- Track buffer heartbeat connection

-- Input buffer window (seconds) - sprint uses longer buffer since it's a hold action
local SPRINT_BUFFER_WINDOW = 0.5 -- 500ms buffer window (matches InputBuffer)

InputModule.InputBegan = function(_, Client)
	self.ShiftHeld = true

	-- Check if sprint is locked (from CancelSprint packet)
	if Client.SprintLocked then
		return
	end

	-- Helper to check for blocking actions (excludes Running, Sprinting, Dodging, DodgeRecovery)
	local function hasBlockingActions()
		local actionStates = Client.Library.GetAllStates(Client.Character, "Actions") or {}
		for _, action in ipairs(actionStates) do
			if action ~= "Running" and action ~= "Sprinting" and action ~= "Dodging" and action ~= "DodgeRecovery" then
				return true
			end
		end
		return false
	end

	-- Helper to check if can sprint
	local function canSprint()
		return not Client.Library.StateCount(Client.Character, "Stuns")
			and not hasBlockingActions()
			and not Client.Dodging
			and not Client.Sliding
			and not Client.WallRunning
			and not Client.LedgeClimbing
	end

	-- Try to start sprinting immediately
	if canSprint() then
		-- Can sprint immediately
		Client.Modules["Movement"].Run(true)
		self.LastInput = os.clock()
	else
		-- Buffer the sprint attempt - will try again while shift is held
		local bufferStart = os.clock()
		local sprintActivated = false -- Deduplication flag

		-- Clean up any existing buffer connection
		if self.BufferConnection then
			self.BufferConnection:Disconnect()
			self.BufferConnection = nil
		end

		-- Check every frame while shift is held to see if we can start sprinting
		self.BufferConnection = game:GetService("RunService").Heartbeat:Connect(function()
			local timeSinceBuffer = os.clock() - bufferStart

			-- If buffer window expired or shift was released, stop checking
			if timeSinceBuffer > SPRINT_BUFFER_WINDOW or not self.ShiftHeld then
				if self.BufferConnection then
					self.BufferConnection:Disconnect()
					self.BufferConnection = nil
				end
				return
			end

			-- Check if we can sprint now
			if canSprint() and self.ShiftHeld and not sprintActivated then
				sprintActivated = true -- Prevent duplicate activation
				Client.Modules["Movement"].Run(true)
				self.LastInput = os.clock()
				if self.BufferConnection then
					self.BufferConnection:Disconnect()
					self.BufferConnection = nil
				end
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
