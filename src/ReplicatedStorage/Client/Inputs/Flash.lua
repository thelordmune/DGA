local InputModule = {}
InputModule.__index = InputModule
local self = setmetatable({}, InputModule)

self.LastInput = os.clock()

InputModule.InputBegan = function(_, Client)
	Client.Packets.Flash.send({Remove = false})
end

InputModule.InputEnded = function(_, Client)
	--Client.Packets.Attack.send({Held = false})
end

InputModule.InputChanged = function()

end

return InputModule
