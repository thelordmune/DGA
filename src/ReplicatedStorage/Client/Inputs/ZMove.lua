local InputModule = {}
InputModule.__index = InputModule
local self = setmetatable({}, InputModule)
local Moves = require(game:GetService("ReplicatedStorage").Modules.Shared.Skills)

self.LastInput = 0
self.InputEndedManually = false

InputModule.InputBegan = function(_, Client)
	self.LastInput = os.clock()
	self.InputEndedManually = false
	local alchemy = Client.Alchemy
	local Skill = Moves[alchemy][script.Name]

	Client.Packets[Skill].send({
		Held = true,
		Air = Client.InAir,
		Duration = 0
	})

	-- Auto-end after 2 seconds
	task.delay(2, function()
		-- Only auto-end if it wasn't manually ended already
		if not self.InputEndedManually then
			InputModule.InputEnded(_, Client)
		end
	end)
end

InputModule.InputEnded = function(_, Client)
    -- Mark as ended so auto-end won't double-send
    if self.InputEndedManually then return end
    self.InputEndedManually = true

    local duration = os.clock() - self.LastInput
    local clampedDuration = math.min(duration, 2)

    local alchemy = Client.Alchemy
    local Skill = Moves[alchemy][script.Name]

    Client.Packets[Skill].send({
        Held = false,
        Air = Client.InAir,
        Duration = clampedDuration
    })
	print('skill fired bro bro ')
end

InputModule.InputChanged = function()

end

return InputModule
