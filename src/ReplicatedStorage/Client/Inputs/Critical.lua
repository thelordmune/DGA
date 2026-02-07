local InputModule = {}
InputModule.__index = InputModule
local self = setmetatable({}, InputModule)

self.LastInput = os.clock()

InputModule.InputBegan = function(_, Client)
	Client.Packets.Critical.send({Held = true, State = Client.InAir})
	self.LastInput = os.clock()
end

InputModule.InputEnded = function(_, Client)
	Client.Packets.Critical.send({Held = false})
end

InputModule.InputChanged = function()

end

return InputModule
