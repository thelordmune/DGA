local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Library = require(ReplicatedStorage.Modules.Library)
local StateManager = require(ReplicatedStorage.Modules.ECS.StateManager)
local InputBuffer = require(script.Parent.Parent.InputBuffer)

local InputModule = {}
InputModule.__index = InputModule
local self = setmetatable({}, InputModule)

self.LastInput = os.clock()
self.BlockAnimation = nil
self.BlockHeld = false -- Track if block button is being held

-- Stuns that prevent blocking
local BLOCKING_STUNS = {
	"BlockBreakStun",
	"BlockBreakCooldown",
	"ParryKnockback",
	"ParryStun",
	"Ragdolled",
	"KnockbackStun",
	"PostureBreakStun",
}

-- Helper to check if block can be performed
local function canBlock(Client)
	if not Client.Character then return false end

	for _, stunName in ipairs(BLOCKING_STUNS) do
		if StateManager.StateCheck(Client.Character, "Stuns", stunName) then
			return false
		end
	end

	return true
end

-- Helper to perform the actual block
local function performBlock(Client)
	-- Play block animation immediately on client for responsiveness
	-- Server will validate and set states
	if Client.Character and Client.Character:GetAttribute("Equipped") then
		local Weapon = Client.Character:GetAttribute("Weapon") or "Fist"
		local BlockAnim = ReplicatedStorage.Assets.Animations.Weapons[Weapon]:FindFirstChild("Block")

		if BlockAnim then
			self.BlockAnimation = Library.PlayAnimation(Client.Character, BlockAnim)
			if self.BlockAnimation then
				self.BlockAnimation.Priority = Enum.AnimationPriority.Action2
			end
		end
	end

	-- Send to server for validation and state management
	Client.Packets.Block.send({Held = true})
end

InputModule.InputBegan = function(_, Client)
	self.BlockHeld = true
	self.LastInput = os.clock()

	-- Check if we can block now
	if canBlock(Client) then
		-- Can block immediately
		performBlock(Client)
	else
		-- Buffer the block - will execute when free
		InputBuffer.Buffer(InputBuffer.InputType.Block, Client)
	end
end

InputModule.InputEnded = function(_, Client)
	self.BlockHeld = false
	-- Release buffered block if any
	InputBuffer.Release(InputBuffer.InputType.Block)

	-- Stop block animation immediately on client
	if self.BlockAnimation then
		self.BlockAnimation:Stop(0.1)
		self.BlockAnimation = nil
	end

	-- Also stop any block animation started by InputBuffer
	if InputBuffer._currentBlockAnimation then
		InputBuffer._currentBlockAnimation:Stop(0.1)
		InputBuffer._currentBlockAnimation = nil
	end

	-- Send to server
	Client.Packets.Block.send({Held = false});
end

InputModule.InputChanged = function()

end

return InputModule
