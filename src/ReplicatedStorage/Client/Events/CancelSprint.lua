local EventModule = {}
local Client = require(script.Parent.Parent)
EventModule.__index = EventModule
local self = setmetatable({}, EventModule)

EventModule.EndPoint = function(Player, Data)
	-- Cancel sprint when server tells us to (when performing actions)
	if Client.Running then
		Client.Modules['Movement'].Run(false)
	end

	-- ALSO cancel the running attack timer when performing actions
	-- This prevents sprint + attack from counting toward the 1.5s running attack timer
	if Client["RunAtkDelay"] then
		task.cancel(Client["RunAtkDelay"])
		Client["RunAtkDelay"] = nil
		--print("[CancelSprint] ⏹️ Cancelled running attack timer - actions don't count toward running attack")
	end

	-- Disable running attack immediately
	Client.RunAtk = false

	-- Set sprint lock flag to prevent sprint from restarting until shift is released and pressed again
	-- This prevents holding shift during an action from auto-restarting sprint when action ends
	Client.SprintLocked = true
	--print("[CancelSprint] 🔒 Sprint locked - must release and re-press shift to sprint again")
end

return EventModule

