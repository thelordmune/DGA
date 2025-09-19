local ReplicatedStorage = game:GetService('ReplicatedStorage')
local ParkourFolder = script.Parent.ParkourAnimations

local AnimationService = {}
AnimationService.__index = AnimationService

function AnimationService.new(Controller)
	local self = setmetatable({}, AnimationService)
	
	local Character: Model = Controller.Character
	local Animator: Animator = Character.Humanoid.Animator
	
	self.Animations = {} do
		for _, Animation: Animation in ParkourFolder:GetChildren() do
			self.Animations[Animation.Name] = Animator:LoadAnimation(Animation)
		end
	end 
	
	return self
end

function AnimationService:Play(Name)
	local Animation: AnimationTrack = self.Animations[Name]
	Animation:Play()
end

function AnimationService:Stop(Name)
	local Animation: AnimationTrack = self.Animations[Name]
	Animation:Stop()
end

function AnimationService:Get(Name)
	local Animation: AnimationTrack = self.Animations[Name]
	return Animation
end

return AnimationService
