--strict
local Debris = {}

local Default = require(script.Parent.DEFAULT)
local TweenService = game:GetService("TweenService")
--type Normal = {
--	Duration: number?,
--	Audience: Player | { Player }?,
--	Offset: CFrame?,
--}

--type Rising = {
--	Duration: number?,
--	Audience: Player | { Player }?,
--	Offset: CFrame?,
--}

local function CreatePart()
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.Color = Color3.fromRGB(255, 0, 0)
	part.Name = "Visual"
	part.Transparency = 0.75
	part.Size = Vector3.new(4, 4, 6)
	part.Parent = workspace.Effects
	task.delay(3, part.Destroy, part)
	return part
end


local function Raycast(Origin, Direction, Params, Debug)
	local Params = Params
	if not Params then
		Params = RaycastParams.new()
		Params.FilterType = Enum.RaycastFilterType.Include
		Params.FilterDescendantsInstances = { workspace.Organization.Map }
	end

	local Results = workspace:Raycast(Origin, Direction, Params)
	local visualPart

	if Debug then
		visualPart = CreatePart()
		local Distance = (Direction).Magnitude
		visualPart.CFrame = CFrame.new(Origin, Origin + Direction) * CFrame.new(0, 0, -Distance / 2)
		visualPart.Size = Vector3.new(0.2, 0.2, Distance)
	end
	if Results then
		local HitPart = Results.Instance
		if not HitPart then
			return
		end
		if visualPart then
			local newDistance = (Origin - Results.Position).Magnitude
			visualPart.Size = Vector3.new(0.2, 0.2, newDistance)
			visualPart.CFrame = CFrame.new(Origin, Origin + Direction) * CFrame.new(0, 0, -newDistance / 2)
			visualPart.Color = Color3.new(0, 1, 0)
		end
		return Results
	end
	return
end

local function getSpreadDirection(anchorCF: CFrame, spreadAngle: number): Vector3
	local baseDir = anchorCF.UpVector
	local angle = math.rad(spreadAngle)

	local theta = math.random() * 2 * math.pi
	local u = math.random()
	local phi = math.acos(1 - u * (1 - math.cos(angle)))

	local x = math.sin(phi) * math.cos(theta)
	local y = math.cos(phi)
	local z = math.sin(phi) * math.sin(theta)

	local cf = CFrame.lookAt(Vector3.zero, baseDir.Unit)
	return (cf.RightVector * x + cf.LookVector * z + cf.UpVector * y).Unit
end

function Debris.Rising(AnchorPoint: CFrame, Settings: Normal, State: {})
	if not AnchorPoint then
		return
	end
	Settings = State.MergeTables(Settings, Default.Rising)

	local CurrentSplit = 1
	local Parts = {}

	for _ = 1, Settings.PartCount do
		local RandomSize = Vector3.new(
			State.randInt(Settings.Size[1], Settings.Size[2]),
			State.randInt(Settings.Size[1], Settings.Size[2]),
			State.randInt(Settings.Size[1], Settings.Size[2])
		)
		local Offset = if Settings.Radius
			then AnchorPoint * CFrame.new(
				State.randInt(-Settings.Radius, Settings.Radius),
				0,
				State.randInt(-Settings.Radius, Settings.Radius)
			)
			else AnchorPoint

		local Raycast =
			workspace:Raycast(Offset.Position, -Offset.UpVector * Settings.RaycastLength, State.effect_params)
		if not Raycast then
			continue -- Skip this part, don't abort entire debris batch
		end

		local Part = State.CreatePart(Raycast, true)
		State.Destroy(Part, Settings.LifeTime + 3)
		Part.Size = RandomSize
		Part.Anchored = false
		Part.Parent = State.DebrisFolder
		Parts[#Parts + 1] = Part
		State.ApplyMode(Part, Settings.LifeCycle.Entrance.Type, Settings.LifeCycle.Entrance)

		local Direction = if Settings.Radius then Offset.UpVector else getSpreadDirection(Offset, Settings.SpreadAngle)

		local Velocity = Instance.new("LinearVelocity")
		task.delay(Settings.LifeTime, Velocity.Destroy, Velocity)
		Velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
		Velocity.ForceLimitMode = Enum.ForceLimitMode.PerAxis
		Velocity.ForceLimitsEnabled = true
		Velocity.MaxAxesForce = Vector3.new(4e4, 4e4, 4e4)
		Velocity.VectorVelocity = Direction * Settings.Force
		Velocity.Attachment0 = Part.Attachment
		Velocity.RelativeTo = Enum.ActuatorRelativeTo.World
		Velocity.Parent = Part

		TweenService:Create(Velocity, Settings.Info, { VectorVelocity = Vector3.zero }):Play()

		local AngularVelocity = Instance.new("AngularVelocity")
		task.delay(Settings.LifeTime, AngularVelocity.Destroy, AngularVelocity)
		AngularVelocity.AngularVelocity = Vector3.new(
			State.randInt(-Settings.RotationalForce[1], Settings.RotationalForce[2]),
			State.randInt(-Settings.RotationalForce[1], Settings.RotationalForce[2]),
			State.randInt(-Settings.RotationalForce[1], Settings.RotationalForce[2])
		) * 0.15
		AngularVelocity.MaxTorque = 200
		AngularVelocity.Attachment0 = Part.Attachment
		AngularVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
		AngularVelocity.Parent = Part

		task.wait(Settings.IterationDelay)
	end
end

function Debris.Normal(AnchorPoint: CFrame, Settings: Rising, State: {})
	if not AnchorPoint then
		return
	end
	Settings = State.MergeTables(Settings, Default.Normal)

	local CurrentSplit = 1
	local Parts = {}

	-- Check if AnchorPoint is actually PathData from Forward crater
	local isPathData = typeof(AnchorPoint) == "table" and AnchorPoint.DirectionCFrame ~= nil
	local surfaceAlignedCFrame = nil
	local surfaceNormal = Settings.Normal
	local anchorPosition

	if isPathData then
		-- Use PathData for rectangular area
		surfaceAlignedCFrame = AnchorPoint.DirectionCFrame
		anchorPosition = AnchorPoint.StartPosition
	else
		-- Normal circular area logic
		anchorPosition = AnchorPoint.Position

		if surfaceNormal then
			-- Create a coordinate system aligned with the surface normal
			local upVector = surfaceNormal.Unit
			local rightVector = upVector:Cross(Vector3.new(1, 0, 0))
			if rightVector.Magnitude < 0.1 then
				rightVector = upVector:Cross(Vector3.new(0, 0, 1))
			end
			rightVector = rightVector.Unit
			local forwardVector = rightVector:Cross(upVector).Unit

			surfaceAlignedCFrame = CFrame.fromMatrix(anchorPosition, rightVector, upVector, forwardVector)
		end
	end

	for _ = 1, Settings.PartCount do
		local RandomSize = Vector3.new(
			State.randInt(Settings.Size[1], Settings.Size[2]),
			State.randInt(Settings.Size[1], Settings.Size[2]),
			State.randInt(Settings.Size[1], Settings.Size[2])
		)

		local Offset, rayDirection

		if surfaceAlignedCFrame then
			local localOffset

			if isPathData then
				-- Rectangular area for Forward crater
				local maxWidth = AnchorPoint.MaxWidth
				local length = AnchorPoint.Length
				localOffset = Vector3.new(
					State.randInt(-maxWidth, maxWidth),  -- Width (left to right)
					0,
					State.randInt(0, -length)  -- Length (forward along path)
				)
			else
				-- Circular area for normal craters
				localOffset = Vector3.new(
					State.randInt(-Settings.Radius, Settings.Radius),
					0,
					State.randInt(-Settings.Radius, Settings.Radius)
				)
			end

			local worldOffset = surfaceAlignedCFrame:VectorToWorldSpace(localOffset)
			Offset = CFrame.new(anchorPosition + worldOffset)
			rayDirection = -surfaceNormal * Settings.RaycastLength
		else
			-- Original flat ground logic
			Offset = AnchorPoint * CFrame.new(
				State.randInt(-Settings.Radius, Settings.Radius),
				0,
				State.randInt(-Settings.Radius, Settings.Radius)
			)

			rayDirection = -Offset.UpVector * Settings.RaycastLength
		end

		local Raycast = Raycast(Offset.Position, rayDirection, State.effect_params, false)
		if not Raycast then
			continue -- Skip this part, don't abort entire debris batch
		end

		local Part = State.CreatePart(Raycast, true)
		State.Destroy(Part, Settings.LifeTime + 3)
		Part.Size = RandomSize
		Part.CFrame *= CFrame.new(0, Part.Size.Y / 2, 0)
		Part.Anchored = false
		Part.Parent = State.DebrisFolder
		Parts[#Parts + 1] = Part
		State.ApplyMode(Part, Settings.LifeCycle.Entrance.Type, Settings.LifeCycle.Entrance)

		-- Calculate velocity direction based on surface normal
		local velocityDirection
		if surfaceNormal then
			-- Create debris velocity in the direction of the surface normal with spread
			local spreadX = State.randInt(-Settings.Spread[1], Settings.Spread[2])
			local spreadZ = State.randInt(-Settings.Spread[1], Settings.Spread[2])
			local upForce = State.randInt(Settings.UpForce[1], Settings.UpForce[2])

			-- Transform spread to surface-aligned coordinate system
			local localVelocity = Vector3.new(spreadX, upForce * 10, spreadZ)
			velocityDirection = surfaceAlignedCFrame:VectorToWorldSpace(localVelocity) * 5
		else
			-- Original flat ground velocity
			velocityDirection = Vector3.new(
				State.randInt(-Settings.Spread[1], Settings.Spread[2]),
				(State.randInt(Settings.UpForce[1], Settings.UpForce[2]) * 10),
				State.randInt(-Settings.Spread[1], Settings.Spread[2])
			) * 5
		end

		local Velocity = Instance.new("LinearVelocity")
		task.delay(0.25, Velocity.Destroy, Velocity)
		Velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
		Velocity.ForceLimitMode = Enum.ForceLimitMode.PerAxis
		Velocity.ForceLimitsEnabled = true
		Velocity.MaxAxesForce = Vector3.new(1000, 4e4, 1000)
		Velocity.VectorVelocity = velocityDirection
		Velocity.Attachment0 = Part.Attachment
		Velocity.RelativeTo = Enum.ActuatorRelativeTo.World
		Velocity.Parent = Part

		local AngularVelocity = Instance.new("AngularVelocity")
		task.delay(0.1, AngularVelocity.Destroy, AngularVelocity)
		AngularVelocity.AngularVelocity = Vector3.new(
			State.randInt(-Settings.RotationalForce[1], Settings.RotationalForce[2]),
			State.randInt(-Settings.RotationalForce[1], Settings.RotationalForce[2]),
			State.randInt(-Settings.RotationalForce[1], Settings.RotationalForce[2])
		) * 0.5
		AngularVelocity.MaxTorque = 200
		AngularVelocity.Attachment0 = Part.Attachment
		AngularVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
		AngularVelocity.Parent = Part

		task.wait(Settings.IterationDelay)
	end

	task.wait(Settings.LifeTime)
	for Index = 1, #Parts do
		State.ApplyMode(Parts[Index], Settings.LifeCycle.Exit.Type, Settings.LifeCycle.Exit)
		task.wait(Settings.IterationDelay)
	end
end


return Debris
