local InputModule = {}
InputModule.__index = InputModule
local self = setmetatable({}, InputModule)

self.Clicks = 0
self.LastInput = os.clock()
self.MouseInputCD = false

InputModule.InputBegan = function(_, Client)
	if table.find(Client.CurrentInput, "Block") then
		Client.Packets.Parry.send()
	end
	
	local Time = os.clock()
	
	if self.Clicks >= 8 then
		self.MouseInputCD = true
		task.delay(.1,function()
			self.MouseInputCD = false
		end)
	end
	
	if Time - self.LastInput >= .1 then
		self.Clicks = 0
		self.LastInput = os.clock()
	end
	
	if self.MouseInputCD then return end
	
	if Client.Library.StateCount(Client.Actions) then
		Client.Packets.Attack.send({Type = "None", Held = true})
	elseif Client.RunAtk and not Client.Library.CheckCooldown(Client.Character, "RunningAttack") then
		Client.Packets.Attack.send({Type = "Running", Held = true})
	else
		-- If running attack is on cooldown, stop running and do normal M1
		if Client.RunAtk and Client.Library.CheckCooldown(Client.Character, "RunningAttack") then
			Client.Modules['Movement'].Run(false)
		end
		Client.Packets.Attack.send({Type = "Normal", Held = true, State = Client.InAir})
	end
end

InputModule.InputEnded = function(_, Client)
	Client.Packets.Attack.send({Type = "None", Held = false})
end

InputModule.InputChanged = function()

end

return InputModule
