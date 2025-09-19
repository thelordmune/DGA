local AnimationController = {}
local Client = script.Parent -- This will be the NPC model
AnimationController.__index = AnimationController
local self = setmetatable({}, AnimationController)
local Defaults = require(game.ReplicatedStorage.Client.Animate.Cache)
local MetaData = require(game.ReplicatedStorage.Modules.MetaData)

-- Wait for humanoid to exist
local Humanoid = Client:WaitForChild("Humanoid")
local Animator = Humanoid:WaitForChild("Animator")

AnimationController.LastCall = 0
AnimationController.FrameCount = 0

AnimationController.CurrentAnimation = ""
AnimationController.CurrentTrack = nil
AnimationController.CurrentInstance = nil
AnimationController.CurrentSpeed = 1.0
AnimationController.Connections = {}

AnimationController.FreeFallTime = 0
AnimationController.JumpAnimTime = 0
AnimationController.JumpAnimDuration = 0.316
AnimationController.FallTransitionTime = 0.1

AnimationController.KillCache = {
	"Dead",
	"GettingUp",
	"FallingDown",
	"Seated",
	"PlatformStanding",
}

AnimationController.Cache = {}
AnimationController.Pose = "Standing"
AnimationController.Listeners = {}

local Methods = {}
local function Disconnect(Table)
	for _, Connection: RBXScriptConnection in next, Table do
		Connection:Disconnect()
	end
end

AnimationController.AddToConfig = function(Name, Weight, ID)
    if self.Cache[Name] then
        -- If this is the currently playing animation, stop it first
        if self.CurrentAnimation == Name and self.CurrentTrack then
            self.CurrentTrack:Stop(0.1)
            self.CurrentTrack:Destroy()
            self.CurrentTrack = nil
            self.CurrentAnimation = ""
            self.CurrentInstance = nil
        end

        if self.Cache[Name].Animation then
            self.Cache[Name].Animation:Destroy()
        end

        Disconnect(self.Cache[Name].Connections)
        self.Cache[Name].Connections = {}

        self.Cache[Name].Animation = Instance.new("Animation")
        self.Cache[Name].Animation.Name = Name
        self.Cache[Name].Animation.AnimationId = ("rbxassetid://%d"):format(ID)
        self.Cache[Name].Weight = Weight

        -- If we just updated the idle animation and we should be idling, restart it
        if Name == "Idling" and self.Pose == "Standing" then
            task.wait(0.1) -- Small delay to ensure the new animation is ready
            self.PlayAnimation("Idling", 0.1)
        end
    end
end

AnimationController.SetupConfig = function(Name, Data)
	self.Cache[Name] = {}
	self.Cache[Name].Connections = {}

	self.Cache[Name].Animation = Instance.new("Animation")
	self.Cache[Name].Animation.Name = Name
	self.Cache[Name].Animation.AnimationId = ("rbxassetid://%d"):format(Data.ID)
	self.Cache[Name].Weight = Data.Weight
end

AnimationController.ResetConfig = function(Name)
	if self.Cache[Name] ~= nil then
		Disconnect(self.Cache[Name].Connections)
		if self.Cache[Name].Animation then
			self.Cache[Name].Animation:Destroy()
		end

		self.SetupConfig(Name, Defaults[Name])
	end
end

AnimationController.StopAllAnimations = function()
	local OldAnim = self.CurrentAnimation

	self.CurrentAnimation = ""
	self.CurrentInstance = nil

	if self.Connections and #self.Connections > 0 then
		for _, Connection: RBXScriptConnection in next, self.Connections do
			Connection:Disconnect()
		end

		self.Connections = {}
	end

	if self.CurrentLeft ~= nil then
		self.CurrentLeft:Disconnect()
		self.CurrentLeft = nil
	end
	if self.CurrentRight ~= nil then
		self.CurrentRight:Disconnect()
		self.CurrentRight = nil
	end

	if self.CurrentTrack ~= nil then
		self.CurrentTrack:Stop()
		self.CurrentTrack:Destroy()
		self.CurrentTrack = nil
	end

	return OldAnim
end

AnimationController.SetAnimationSpeed = function(Speed: number)
	if Speed ~= self.CurrentSpeed then
		self.CurrentSpeed = Speed
		self.CurrentTrack:AdjustSpeed(self.CurrentSpeed)
	end
end

AnimationController.CurrentLeft = nil
AnimationController.CurrentRight = nil
AnimationController.PlayAnimation = function(Animation, Transition)
    local Anim = self.Cache[Animation].Animation
    local Weight = self.Cache[Animation].Weight

    if Anim ~= self.CurrentInstance then
        self.CurrentSpeed = 1.0

        -- Always stop and destroy the current track when switching animations
        if self.CurrentTrack ~= nil then
            self.CurrentTrack:Stop(Transition)
            self.CurrentTrack:Destroy()
            self.CurrentTrack = nil
        end

        -- Clear current animation state
        self.CurrentAnimation = ""
        self.CurrentInstance = nil

        print(Anim.Name)

        if typeof(Anim) == "table" then
            print(table.unpack(Anim))
        end

        self.CurrentTrack = Client.Humanoid:LoadAnimation(Anim)
        self.CurrentTrack.Priority = Enum.AnimationPriority.Core
        self.CurrentTrack:Play(Transition)

        self.CurrentAnimation = Animation
        self.CurrentInstance = Anim

        -- Clear existing connections
        if self.CurrentLeft ~= nil then
            self.CurrentLeft:Disconnect()
            self.CurrentLeft = nil
        end
        if self.CurrentRight ~= nil then
            self.CurrentRight:Disconnect()
            self.CurrentRight = nil
        end

        -- Set up walking sound connections
        if Animation == "Walking" then
            self.CurrentLeft = self.CurrentTrack:GetMarkerReachedSignal("Left"):Connect(function()
                if
                    Client.InAir
                    or Client.Dashing
                    or not Client.Humanoid
                    or Client.Sliding
                    or Client:GetAttribute("Ragdolled")
                then
                    return
                end
                Client.Modules["Sounds"].Step(Client.Humanoid.FloorMaterial)
            end)

            self.CurrentRight = self.CurrentTrack:GetMarkerReachedSignal("Right"):Connect(function()
                if
                    Client.InAir
                    or Client.Dashing
                    or not Client.Humanoid
                    or Client.Sliding
                    or Client:GetAttribute("Ragdolled")
                then
                    return
                end
                Client.Modules["Sounds"].Step(Client.Humanoid.FloorMaterial)
            end)
        end
    end
end

AnimationController.PlayRawAnimation = function(Animation, Transition, Priority)
	local Anim = self.Cache[Animation].Animation
	local Weight = self.Cache[Animation].Weight

	if Anim ~= self.CurrentInstance then
		local Track = Client.Humanoid:LoadAnimation(Anim)
		Track.Priority = Priority
		Track:Play(Transition)
	end
end

AnimationController.Listeners["Move"] = function()
	local Speed = Client.Humanoid.MoveDirection.Magnitude

	if Speed > 0 then
		self.PlayAnimation("Walking", 0.1)
		self.Pose = "Running"
	else
		self.PlayAnimation("Idling", 0.1)
		self.Pose = "Standing"
	end
end

AnimationController.Listeners["Died"] = function()
	self.Pose = "Dead"
end

AnimationController.Listeners["Jumping"] = function()
	self.PlayAnimation("Jumping", 0.1)
	self.JumpAnimTime = self.JumpAnimDuration
	self.Pose = "Jumping"
end

AnimationController.Listeners["Freefall"] = function()
	self.FreeFallTime = os.clock()
	self.Pose = "FreeFall"

	if self.JumpAnimTime <= 0 then
		self.PlayAnimation("Falling", self.FallTransitionTime)
	end
end

AnimationController.Listeners["Swimming"] = function()
	local Speed = Client.Humanoid.MoveDirection.Magnitude

	if Speed > 0 then
		self.Pose = "Running"
	else
		self.Pose = "Standing"
	end
end

AnimationController.Listeners["Landed"] = function()
	if self.FreeFallTime ~= 0 and (os.clock() - self.FreeFallTime >= 1) then
		self.PlayRawAnimation("Landing", 0.1, Enum.AnimationPriority.Idle)
		self.Pose = "Landing"
		self.FreeFallTime = 0
	end
end

AnimationController.Listeners["GettingUp"] = function()
	self.Pose = "GettingUp"
end

AnimationController.Listeners["PlatformStanding"] = function()
	self.Pose = "PlatformStanding"
end

AnimationController.Listeners["FallingDown"] = function()
	self.Pose = "FallingDown"
end

AnimationController.Listeners["Seated"] = function()
	self.Pose = "Seated"
end

AnimationController.Init = function()
    for Name, Table in next, Defaults do
        task.spawn(self.SetupConfig, Name, Table)
    end
    
    -- Stop any existing animations
    for _, Track: AnimationTrack in next, Animator:GetPlayingAnimationTracks() do
        Track:Stop(0)
        Track:Destroy()
    end

    -- Set up weapon-specific idle animation
    local weaponName = Client:GetAttribute("Weapon")
    local isEquipped = Client:GetAttribute("Equipped")
    
    if weaponName and weaponName ~= "Fist" then
        local weaponData = MetaData.RequestData(weaponName)
        if weaponData then
            if isEquipped and weaponData.EquippedIdle then
                self.AddToConfig("Idling", 10, weaponData.EquippedIdle)
            elseif not isEquipped and weaponData.UnequippedIdle then
                self.AddToConfig("Idling", 10, weaponData.UnequippedIdle)
            elseif weaponData.Idle then
                self.AddToConfig("Idling", 10, weaponData.Idle)
            end
        end
    end

    self.PlayAnimation("Idling", 0.1)
    self.Pose = "Standing"
    self.FrameCount = 0

    -- Connect humanoid events
    Humanoid.Running:Connect(self.Listeners["Move"])
    Humanoid.StateChanged:Connect(function(_, State: Enum.HumanoidStateType)
        if not Client or not Humanoid then
            return
        end
        if AnimationController.Listeners[State.Name] then
            AnimationController.Listeners[State.Name]()
        end
    end)
    
    -- Listen for weapon/equipped attribute changes
    Client:GetAttributeChangedSignal("Equipped"):Connect(function()
        local currentWeapon = Client:GetAttribute("Weapon")
        local equipped = Client:GetAttribute("Equipped")
        
        if currentWeapon and currentWeapon ~= "Fist" then
            local weaponData = MetaData.RequestData(currentWeapon)
            if weaponData then
                if equipped and weaponData.EquippedIdle then
                    self.AddToConfig("Idling", 10, weaponData.EquippedIdle)
                elseif not equipped and weaponData.UnequippedIdle then
                    self.AddToConfig("Idling", 10, weaponData.UnequippedIdle)
                elseif weaponData.Idle then
                    self.AddToConfig("Idling", 10, weaponData.Idle)
                end
            end
        end
    end)
end

-- Initialize when script runs
AnimationController.Init()

return AnimationController
