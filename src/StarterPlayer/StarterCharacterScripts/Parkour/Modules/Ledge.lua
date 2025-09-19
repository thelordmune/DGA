-- // services
local RunService = game:GetService('RunService')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local UIS = game:GetService('UserInputService')
local Player = game.Players.LocalPlayer

-- // variables
local Utils = script.Parent.Parent.Util
local Camera = workspace.CurrentCamera

-- // requires
local Maid = require(Utils.Maid)
local Raycast = require(Utils.Raycast)
local PlayerModule = require(Player:WaitForChild('PlayerScripts'):WaitForChild('PlayerModule'))

local Controls = PlayerModule:GetControls()

local Ledge = {}
Ledge.__index = Ledge

function Ledge.new(Parkour)
	local self = setmetatable({}, Ledge)
	self.Parent = Parkour
	self.Cleaner = Maid.new()

	self.Character = self.Parent.Character
	self.LedgeClimbing = false
	self.ClimbSpeed = 10

	return self
end

function Ledge:_raycast(Args)
	Args.Params = self.Parent.Params
	Args.Duration = 0.05
	return Raycast(Args)
end

function Ledge:_stopClimbing()
	local RootPart: BasePart = self.Character.HumanoidRootPart
	local Humanoid: Humanoid = self.Character.Humanoid
	local AnimationService = self.Parent.AnimationService

	self.Parent.Busy = false
	self.LedgeClimbing = false
	Humanoid.AutoRotate = true

	self.Cleaner:Destroy()

	AnimationService:Stop('Ledge')
	AnimationService:Stop('Shimmy Left')
	AnimationService:Stop('Shimmy Right')
end

function Ledge:_vault()
	self:_stopClimbing()

	if not UIS:IsKeyDown(Enum.KeyCode.S) then
		self.Character.HumanoidRootPart.AssemblyLinearVelocity = Vector3.yAxis * 50
		self.Parent.AnimationService:Play('Vault')
	end
end

function Ledge:Start()
	if self.Parent.Busy and not self.LedgeClimbing then
		return
	end

	local RootPart: BasePart = self.Character.HumanoidRootPart
	local Humanoid: Humanoid = self.Character.Humanoid
	local AnimationService = self.Parent.AnimationService


	if self.LedgeClimbing then		
		self:_vault()
		return
	end

	self.Detection = RunService.Heartbeat:Connect(function()
		local ForwardDetection = self:_raycast({
			Start = RootPart.Position,
			Direction = RootPart.CFrame.LookVector * 3,
		})

		if not ForwardDetection or ForwardDetection and ForwardDetection.Normal.Y ~= 0 then
			return
		end

		local Height = Vector3.yAxis * (RootPart.Size.Y * 0.5 + self.Character.Head.Size.Y + 2)
		local Start = ForwardDetection.Position + ForwardDetection.Normal
		local Direction = Vector3.yAxis * Height

		local UpwardDetection = self:_raycast({
			Start = Start,
			Direction = Direction,
		})

		if UpwardDetection then
			return
		end

		Start = Start + Direction
		Direction = -ForwardDetection.Normal * 1.5

		local ForwardDetection2 = self:_raycast({
			Start = Start,
			Direction = Direction,
		})

		if ForwardDetection2 then
			return
		end

		Start = Start + Direction
		Direction = -Vector3.yAxis * Height

		local DownwardDetection = self:_raycast({
			Start = Start,
			Direction =  Direction,
		})

		if not DownwardDetection then
			return
		end

		if self.Detection then
			self:_climbStart(ForwardDetection, DownwardDetection)
		end
	end)
end

function Ledge:_climbStart(ForwardDetection, DownwardDetection)
	local RootPart: BasePart = self.Character.HumanoidRootPart
	local Humanoid: Humanoid = self.Character.Humanoid
	local AnimationService = self.Parent.AnimationService
	local Height = Vector3.yAxis * (RootPart.Size.Y * 0.5 + self.Character.Head.Size.Y + 2)

	self.Parent.Busy = true
	Humanoid.AutoRotate = false

	self.Detection:Disconnect()
	self.Detection = nil
	self.LedgeClimbing = true

	local BP = Instance.new('BodyPosition')
	BP.Position = ForwardDetection.Position + ForwardDetection.Normal + Vector3.yAxis * (DownwardDetection.Position.Y - ForwardDetection.Position.Y) - Height / 2
	BP.P = 99999
	BP.MaxForce = Vector3.one * 2e9
	BP.Parent = RootPart
	self.Cleaner:AddTask(BP)

	local BG = Instance.new('BodyGyro')
	BG.CFrame = CFrame.new(Vector3.zero, -ForwardDetection.Normal)
	BG.P = 9999
	BG.MaxTorque = Vector3.one * 2e9
	BG.Parent = RootPart
	self.Cleaner:AddTask(BG)

	--self.Parent.Modules['Double Jump'].CanDoubleJump = true
	AnimationService:Play('Ledge')

	local speed = self.ClimbSpeed
	local LedgeClimbingDirection = {
		Left = {
			Animation = 'Shimmy Left',
			Direction = -1
		},
		Right = {
			Animation = 'Shimmy Right',
			Direction = 1
		}
	}

	local function clean()
		AnimationService:Stop('Shimmy Left')
		AnimationService:Stop('Shimmy Right')

		if self.Cleaner.RunService then
			self.Cleaner.RunService:Disconnect()
			self.Cleaner.RunService = nil
		end
	end

	clean()

	local function checkEdge(Start, Direction, Facing)
		local CeilingDetection = self:_raycast({
			Start = Start,
			Direction = Direction,
		})

		if CeilingDetection then
			return
		end

		local DownwardDetection = self:_raycast({
			Start = Start + Direction + Facing,
			Direction = Vector3.yAxis * -Height,
		})

		if not DownwardDetection then
			return
		end

		return DownwardDetection
	end

	local ghostPart = Instance.new('Part')
	ghostPart.CFrame = CFrame.new(ForwardDetection.Position, ForwardDetection.Position - ForwardDetection.Normal)
	ghostPart.Anchored = true
	ghostPart.CanCollide = false
	self.Cleaner:AddTask(ghostPart)
	
	self.Cleaner.RunService = RunService.Heartbeat:Connect(function(dt)
		-- check side

		local MoveVector = Controls:GetMoveVector()
		local Direction = MoveVector.X > 0 and 'Right' or MoveVector.X < 0 and 'Left'
		
		-- check forward
		local climbingDirection = Direction and LedgeClimbingDirection[Direction].Direction or 0
		local Start =  ghostPart.Position + ghostPart.CFrame.RightVector * climbingDirection * dt * self.ClimbSpeed - ghostPart.CFrame.LookVector
		local DirectionVector = ghostPart.CFrame.LookVector * 3

		local ForwardDetection = self:_raycast({
			Start = Start,
			Direction = DirectionVector,
		})

		if not ForwardDetection then
			-- check corner
			local SideDetection = self:_raycast({
				Start = Start + DirectionVector,
				Direction = ghostPart.CFrame.RightVector * -climbingDirection * 3,
			})

			if SideDetection then
				DownwardDetection = checkEdge(SideDetection.Position, Height, -ghostPart.CFrame.RightVector * climbingDirection * 0.25)
				
				if DownwardDetection then
					ghostPart.CFrame = CFrame.new(Vector3.zero, -SideDetection.Normal) + SideDetection.Position + SideDetection.Normal + Vector3.yAxis * (DownwardDetection.Position.Y - SideDetection.Position.Y) - Height / 2
					BG.CFrame = ghostPart.CFrame
					BP.Position = ghostPart.Position
					
					return
				end
			end
			
			self:_vault()
			return
		end

		-- automatically vault when near ground
		local groundDetection = self:_raycast({
			Start = ForwardDetection.Position + ForwardDetection.Normal,
			Direction = Vector3.yAxis * -Height * 2,
		})

		if groundDetection ~= nil then
			self:_vault()
			return
		end

		if not Direction then
			AnimationService:Stop('Shimmy Left')
			AnimationService:Stop('Shimmy Right')
			return
		end

		if not AnimationService:Get('Shimmy '..Direction).IsPlaying then
			AnimationService:Stop('Shimmy '.. (Direction == 'Right' and 'Left' or 'Right'))
			AnimationService:Play('Shimmy '.. Direction)
		end

		local SideDetection = self:_raycast({
			Start = ghostPart.Position,
			Direction = ghostPart.CFrame.RightVector * climbingDirection * 3,
		})

		if SideDetection then
			DownwardDetection = checkEdge(SideDetection.Position, Height, ghostPart.CFrame.RightVector * climbingDirection * 0.25)
			if DownwardDetection then
				ghostPart.CFrame = CFrame.new(Vector3.zero, -SideDetection.Normal) + SideDetection.Position + SideDetection.Normal + Vector3.yAxis * (DownwardDetection.Position.Y - SideDetection.Position.Y) - Height / 2
				BG.CFrame = ghostPart.CFrame
				BP.Position = ghostPart.Position
				return
			end
		end		

		Start = ForwardDetection.Position
		DirectionVector = Height

		DownwardDetection = checkEdge(Start, DirectionVector,  ghostPart.CFrame.LookVector * 0.25)
		if not DownwardDetection then
			return
		end

		ghostPart.Position =  ForwardDetection.Position + ForwardDetection.Normal + Vector3.yAxis * (DownwardDetection.Position.Y - ForwardDetection.Position.Y) - Height / 2
		BP.Position = ghostPart.Position
	end)
end

function Ledge:End()
	if self.Detection then
		
		self.Parent.AnimationService:Stop('Shimmy Left')
		self.Parent.AnimationService:Stop('Shimmy Right')
		
		self.Detection:Disconnect()
		self.Detection = nil

		self.LedgeClimbing = false

		self.Cleaner:Destroy()
	end	
end

return Ledge
