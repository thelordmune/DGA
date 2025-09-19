local InputModule = {}
InputModule.__index = InputModule
local self = setmetatable({}, InputModule)

self.LastInput = os.clock()

InputModule.InputBegan = function(_, Client)
	if Client.Dodging then
		Client.Modules["Movement"].DodgeCancel();
		
	elseif Client.Character and Client.Character:GetAttribute("Feint") and not Client.Library.CheckCooldown(Client.Character, "Feint") then
		Client.Packets.Feint.send({})
	end

	self.LastInput = os.clock()
end

InputModule.InputEnded = function(_, Client)
	
end

InputModule.InputChanged = function()

end

return InputModule
