local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Library = require(ReplicatedStorage.Modules.Library)

local InputModule = {}
InputModule.__index = InputModule
local self = setmetatable({}, InputModule)

self.LastInput = os.clock()
self.BlockAnimation = nil

InputModule.InputBegan = function(_, Client)
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
	self.LastInput = os.clock()
end

InputModule.InputEnded = function(_, Client)
	-- Stop block animation immediately on client
	if self.BlockAnimation then
		self.BlockAnimation:Stop(0.1)
		self.BlockAnimation = nil
	end

	-- Send to server
	Client.Packets.Block.send({Held = false});
end

InputModule.InputChanged = function()

end

return InputModule
