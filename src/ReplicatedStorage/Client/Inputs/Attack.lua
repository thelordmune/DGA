local InputBuffer = require(script.Parent.Parent.InputBuffer)

local InputModule = {}
InputModule.__index = InputModule
local self = setmetatable({}, InputModule)

self.Clicks = 0
self.LastInput = os.clock()
self.MouseInputCD = false
self.AttackHeld = false -- Track if attack button is being held

-- Attack Type enum for optimized packet serialization (string -> uint8)
local AttackTypeEnum = {
	Normal = 0,
	Running = 1,
	None = 2,
}

-- Helper to check if attack can be performed
local function canAttack(Client)
	-- Check stuns
	if Client.Library.StateCount(Client.Character, "Stuns") then
		return false
	end

	-- Check for blocking actions (exclude Running/Sprinting as those shouldn't block attacks)
	local actionStates = Client.Library.GetAllStates(Client.Character, "Actions") or {}
	for _, action in ipairs(actionStates) do
		if action ~= "Running" and action ~= "Sprinting" and action ~= "Dodge" and action ~= "Dashing" and action ~= "Dodging" and action ~= "DodgeRecovery" then
			return false
		end
	end

	return true
end

-- Helper to perform the actual attack
local function performAttack(Client)
	if table.find(Client.CurrentInput, "Block") then
		Client.Packets.Parry.send()
		return
	end

	-- M1 cancels dash (stops velocity + animation, then attacks)
	if Client.Dodging then
		Client.Modules['Movement'].CancelDash()
	end

	-- Stop running if currently running (any M1 while running stops the run)
	-- Use _Running flag for reliable check (bypasses ECS timing issues)
	if Client._Running then
		Client.Modules['Movement'].Run(false)
	end
	Client.Attacking = true
	Client.Packets.Attack.send({Type = AttackTypeEnum.Normal, Held = true, Air = Client.InAir})
end

InputModule.InputBegan = function(_, Client)
	self.AttackHeld = true

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

	-- Check if we can attack now
	if canAttack(Client) then
		-- Can attack immediately
		performAttack(Client)
	else
		-- Buffer the attack - will execute when free
		InputBuffer.Buffer(InputBuffer.InputType.Attack, Client)
	end
end

InputModule.InputEnded = function(_, Client)
	self.AttackHeld = false
	Client.Attacking = false
	-- Release buffered attack if any
	InputBuffer.Release(InputBuffer.InputType.Attack)
	Client.Packets.Attack.send({Type = AttackTypeEnum.None, Held = false, Air = false})
end

InputModule.InputChanged = function()

end

return InputModule
