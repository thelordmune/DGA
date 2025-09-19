local InputModule = {}
InputModule.__index = InputModule
local self = setmetatable({}, InputModule)

self.LastInput = os.clock()

InputModule.InputBegan = function(_, Client)
	Client.Packets.Block.send({Held = true})
	self.LastInput = os.clock()
end

InputModule.InputEnded = function(_, Client)
	Client.Packets.Block.send({Held = false});
end

InputModule.InputChanged = function()

end

return InputModule
