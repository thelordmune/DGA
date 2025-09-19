-- // services
local UIS = game:GetService('UserInputService')

-- // variables

-- // requires
local AnimationService = require(script.AnimationService)

local Parkour = {}
Parkour.__index = Parkour

function Parkour.new()
	local self = setmetatable({}, Parkour)
	
	self.Player = game.Players.LocalPlayer
	self.Character = self.Player.Character or self.Player.CharacterAdded:Wait()
	self.AnimationService = AnimationService.new(self)
	
	local Params = RaycastParams.new()
	Params.FilterDescendantsInstances = {workspace.World.Visuals, self.Character}
	Params.FilterType = Enum.RaycastFilterType.Exclude
	
	self.Params = Params
	self.Busy = false

	self.Modules = {}
	local ButtonsToActivate = {}
	for _, Module: ModuleScript in script.Modules:GetChildren() do
		self.Modules[Module.Name] = require(Module).new(self)
		
		
		if not ButtonsToActivate[Module:GetAttribute('ActivateKey')] then
			ButtonsToActivate[Module:GetAttribute('ActivateKey')] = {}
		end
		
		table.insert(ButtonsToActivate[Module:GetAttribute('ActivateKey')], self.Modules[Module.Name])
	end
	
	UIS.InputBegan:Connect(function(key, gpe)
		if gpe then
			return
		end
		
		local KeyName = key.KeyCode.Name
		local Activate = ButtonsToActivate[KeyName]
		
		if Activate then
			for _, Module in Activate do
				Module:Start()
			end
		end
	end)
	
	UIS.InputEnded:Connect(function(key, gpe)
		if gpe then
			return
		end

		local KeyName = key.KeyCode.Name
		local Activate = ButtonsToActivate[KeyName]

		if Activate then
			for _, Module in Activate do
				Module:End()
			end
		end
	end)

	return self
end

return Parkour
