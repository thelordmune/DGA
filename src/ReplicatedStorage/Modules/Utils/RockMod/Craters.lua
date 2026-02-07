--strict
local Craters = {}

local Default = require(script.Parent.DEFAULT)

function Craters.Orbit(AnchorPoint, Settings, State)
	if not AnchorPoint then
		return
	end
	Settings = State.MergeTables(Settings, Default.Orbit)

	local Parts = {}

	local Offsets = State.CircleMath(AnchorPoint, Settings.Radius, Settings.PartCount)
	for i = 1, math.floor(#Offsets * Settings.CircleFraction + 0.5) - 1 do
		local RandomBlockSize = State.randInt(Settings.Size[1], Settings.Size[2])
		local RandomSize = vector.create(RandomBlockSize, RandomBlockSize, RandomBlockSize)

		local Raycast = workspace:Raycast(
			Offsets[i],
			-CFrame.new(Offsets[i]).UpVector * Settings.RaycastLength,
			State.effect_params
		)
		if not Raycast then
			continue -- Skip this part, don't abort entire crater
		end

		local Part = State.CreatePart(Raycast)
		State.Destroy(Part, Settings.LifeTime + 3)
		Part.Size = RandomSize
		Part.CFrame = CFrame.lookAt(Part.Position, Vector3.new(AnchorPoint.X, 0, AnchorPoint.Z))
		Part.Parent = State.DebrisFolder
		Parts[#Parts + 1] = Part

		--local CFrameTo = CFrame.lookAt(Part.Position, Vector3.new(AnchorPoint.X, 0, AnchorPoint.Z)) * CFrame.new(0, State.randInt(Settings.Height[1], Settings.Height[2]), State.randInt(Settings.PartOffset[1], Settings.PartOffset[2])) * CFrame.fromEulerAnglesXYZ(math.rad(State.randInt(Settings.Angle[1], Settings.Angle[2])),math.rad(State.randInt(Settings.Tilt[1], Settings.Tilt[2])),0)

		State.ApplyMode(Part, Settings.LifeCycle.Entrance.Type, Settings.LifeCycle.Entrance)
		task.wait(Settings.IterationDelay)
	end

	task.wait(Settings.LifeTime)
	for Index = 1, #Parts do
		State.ApplyMode(Parts[Index], Settings.LifeCycle.Exit.Type, Settings.LifeCycle.Exit)
		task.wait(Settings.IterationDelay)
	end
end

local lerp = function (a, b, x)
	return a + (b - a) * x
end
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

function Craters.Crater(AnchorPoint, Settings, State)
	if not AnchorPoint then
		return
	end
	Settings = State.MergeTables(Settings, Default.Crater)

	local MidPosition = AnchorPoint.Position

	local NumOfLayers = State.randInt(Settings.Layers[1], Settings.Layers[2])

	local PartsPerLayer = math.round(Settings.PartCount / NumOfLayers)
	local Parts = {}

	-- If we have a surface normal, create a coordinate system aligned with it
	local surfaceNormal = Settings.Normal
	local surfaceAlignedCFrame = nil

	if surfaceNormal then
		-- Create a coordinate system aligned with the surface normal
		local upVector = surfaceNormal.Unit
		local rightVector = upVector:Cross(Vector3.new(1, 0, 0))
		if rightVector.Magnitude < 0.1 then
			rightVector = upVector:Cross(Vector3.new(0, 0, 1))
		end
		rightVector = rightVector.Unit
		local forwardVector = rightVector:Cross(upVector).Unit

		surfaceAlignedCFrame = CFrame.fromMatrix(MidPosition, rightVector, upVector, forwardVector)
	end

	for _ = 1, NumOfLayers, 1 do
		local angle = math.random(-360, 360)
		local increments = 360 / PartsPerLayer
		for _ = 1, PartsPerLayer, 1 do
			local PartDistance = State.randInt(Settings.Distance[1], Settings.Distance[2])

			local castCF, rayDirection

			if surfaceAlignedCFrame then
				-- Use surface-aligned coordinate system for positioning
				local localOffset =
					Vector3.new(math.cos(math.rad(angle)) * PartDistance, 0, math.sin(math.rad(angle)) * PartDistance)
				local worldOffset = surfaceAlignedCFrame:VectorToWorldSpace(localOffset)
				-- Raise cast origin above the surface so the downward raycast hits the ground
				local raiseOffset = surfaceNormal * 5
				castCF = CFrame.new(MidPosition + worldOffset + raiseOffset)
				rayDirection = -surfaceNormal * Settings.RaycastLength
			else
				-- Original flat ground logic
				castCF = CFrame.lookAt(AnchorPoint.Position, AnchorPoint.Position - Vector3.new(0, -10, 0))
					* CFrame.Angles(0, 0, math.rad(angle))
					* CFrame.new(-PartDistance, 0, 0)
				local midpos = Vector3.new(MidPosition.X, castCF.Position.Y, MidPosition.Z)
				local lookatmid = CFrame.lookAt(castCF.Position, midpos)
				rayDirection = -lookatmid.UpVector * Settings.RaycastLength
			end

			angle += increments

			local Result = Raycast(castCF.Position, rayDirection, Settings.RaycastParams or State.effect_params, false)
			if not Result then
				continue -- Skip this part instead of returning entirely
			end

			local StoredFrame
			if surfaceNormal then
				-- Calculate direction from part to crater center
				local toCenterDirection = (MidPosition - Result.Position).Unit

				-- Create a tilted orientation that leans towards the center
				-- Start with surface normal as up vector
				local partUpVector = Result.Normal

				-- Calculate the right vector perpendicular to both the surface normal and the to-center direction
				local partRightVector = partUpVector:Cross(toCenterDirection)
				if partRightVector.Magnitude < 0.1 then
					-- Fallback if vectors are parallel
					partRightVector = partUpVector:Cross(Vector3.new(1, 0, 0))
					if partRightVector.Magnitude < 0.1 then
						partRightVector = partUpVector:Cross(Vector3.new(0, 0, 1))
					end
				end
				partRightVector = partRightVector.Unit

				-- Recalculate forward vector to be perpendicular to up and right
				local partForwardVector = partRightVector:Cross(partUpVector).Unit

				-- Create base orientation
				StoredFrame = CFrame.fromMatrix(Result.Position, partRightVector, partUpVector, partForwardVector)

				-- Tilt 20 degrees towards the center by rotating around the right vector
				StoredFrame = StoredFrame * CFrame.Angles(math.rad(20), 0, 0)
			else
				-- Original flat ground alignment
				local midpos = Vector3.new(MidPosition.X, Result.Position.Y, MidPosition.Z)
				StoredFrame = CFrame.lookAt(Result.Position, midpos - Result.Normal)
					* CFrame.Angles(math.rad(-20), 0, 0)
			end

			local Part = State.CreatePart(Result)
			State.Destroy(Part, 20)
			Part.Position = Result.Position
			Part.CFrame = StoredFrame
			Part.Size = ((Vector3.new(25 / 15, 10 / 15, 20 / 15) * PartDistance) / (PartsPerLayer * 0.25))
				* Settings.SizeMultiplier

			-- Adjust position offset based on surface normal
			if surfaceNormal then
				Part.Position = Part.Position - (Result.Normal * (Part.Size.Y / 3))
			else
				Part.Position += Vector3.new(0, -Part.Size.Y / 3, 0)
			end

			StoredFrame = Part.CFrame
			Part.Parent = State.DebrisFolder
			Parts[#Parts + 1] = Part

			State.ApplyMode(
				Part,
				Settings.LifeCycle.Entrance.Type,
				Settings.LifeCycle.Entrance,
				{ Goal = { CFrame = StoredFrame }, midpos = AnchorPoint.Position, Result = Result }
			)
		end
	end

	task.wait(Settings.LifeTime)
	for Index = 1, #Parts do
		State.ApplyMode(Parts[Index], Settings.LifeCycle.Exit.Type, Settings.LifeCycle.Exit)
		task.wait(State.randInt(Settings.ExitIterationDelay[1], Settings.ExitIterationDelay[2]))
	end
	--State.DestroyBatch(Parts)
end



function Craters.Forward(AnchorPoint, Settings, State)
	print("[RockMod.Forward] Called with AnchorPoint:", AnchorPoint)
	if not AnchorPoint then
		print("[RockMod.Forward] ERROR: AnchorPoint is nil!")
		return
	end
	Settings = State.MergeTables(Settings, Default.Forward or {})
	print("[RockMod.Forward] Settings merged, Direction:", Settings.Direction, "Length:", Settings.Length)

	local MidPosition = AnchorPoint.Position
	local Direction = Settings.Direction
	local Length = Settings.Length
	local StepSize = Settings.StepSize
	local DistanceRange = Settings.Distance
	local ScaleFactor = Settings.ScaleFactor
	local BaseSize = Settings.BaseSize
	local Rotation = Settings.Rotation
	local surfaceNormal = Settings.Normal

	local Parts = {}
	local CurrentSize = BaseSize

	-- Store path dimensions for debris placement
	local PathData = {
		StartPosition = MidPosition,
		Direction = Direction,
		Length = Length,
		MaxWidth = 0, -- Will track the maximum width reached
		DirectionCFrame = nil, -- Will store the direction CFrame
	}

	-- Create direction CFrame
	local directionCFrame
	if surfaceNormal then
		-- Align with surface normal
		local upVector = surfaceNormal.Unit
		local forwardVector = Direction.Unit
		local rightVector = forwardVector:Cross(upVector)
		if rightVector.Magnitude < 0.1 then
			rightVector = upVector:Cross(Vector3.new(1, 0, 0))
			if rightVector.Magnitude < 0.1 then
				rightVector = upVector:Cross(Vector3.new(0, 0, 1))
			end
		end
		rightVector = rightVector.Unit
		forwardVector = upVector:Cross(rightVector).Unit

		directionCFrame = CFrame.fromMatrix(MidPosition, rightVector, upVector, forwardVector)
	else
		-- Flat ground logic
		directionCFrame = CFrame.lookAt(MidPosition, MidPosition + Direction)
	end

	-- Store direction CFrame for debris
	PathData.DirectionCFrame = directionCFrame

	-- Track when part creation is complete
	local creationComplete = false

	-- Create forward path
	task.spawn(function()
		local success, err = pcall(function()
			local partsCreated = 0
			local raycastsMissed = 0
			print("[RockMod.Forward] Starting part creation loop, Length:", Length, "StepSize:", StepSize)
			for step = 0, Length, StepSize do
				local progress = step / Length

				-- Scale distance based on progress (grows more dramatically as path extends)
				local minDistance = DistanceRange[1] * (1 + progress * (ScaleFactor - 1) * Length / StepSize)
				local maxDistance = DistanceRange[2] * (1 + progress * (ScaleFactor - 1) * Length / StepSize)
				local currentDistance = State.randInt(minDistance, maxDistance)

				-- Track maximum width for debris placement
				if currentDistance > PathData.MaxWidth then
					PathData.MaxWidth = currentDistance
				end

				-- Calculate center position along the path
				local centerOffset = directionCFrame:VectorToWorldSpace(Vector3.new(0, 0, -step))
				local centerPos = MidPosition + centerOffset

				-- Create left and right parts
				for side = -1, 1, 2 do -- -1 for left, 1 for right
					local sideOffset = directionCFrame:VectorToWorldSpace(Vector3.new(side * currentDistance, 0, -step))
					-- Raise cast position above ground to ensure raycast hits the surface
					-- Add offset in the surface normal direction (or up if no normal)
					local raiseOffset = surfaceNormal and (surfaceNormal * 5) or Vector3.new(0, 5, 0)
					local castPosition = MidPosition + sideOffset + raiseOffset

					-- Raycast down
					local rayDirection
					if surfaceNormal then
						rayDirection = -surfaceNormal * Settings.RaycastLength
					else
						rayDirection = Vector3.new(0, -Settings.RaycastLength, 0)
					end

					local Result = Raycast(castPosition, rayDirection, State.effect_params, false)
					if Result then
						partsCreated = partsCreated + 1
						local StoredFrame

						-- Each rock randomly picks a tilt value from the Rotation table
						-- If the random value is 0, lay flat; otherwise tilt towards center
						local tiltAngle = 0
						if typeof(Rotation) == "table" then
							tiltAngle = State.randInt(Rotation[1], Rotation[2])
						end

						if tiltAngle ~= 0 then
							-- Angled towards center
							local toCenterDirection = (centerPos - Result.Position).Unit
							local partUpVector = Result.Normal

							-- Create right vector perpendicular to both
							local partRightVector = partUpVector:Cross(toCenterDirection)
							if partRightVector.Magnitude < 0.1 then
								partRightVector = partUpVector:Cross(Vector3.new(1, 0, 0))
								if partRightVector.Magnitude < 0.1 then
									partRightVector = partUpVector:Cross(Vector3.new(0, 0, 1))
								end
							end
							partRightVector = partRightVector.Unit

							local partForwardVector = partRightVector:Cross(partUpVector).Unit

							-- Create base orientation pointing towards center
							StoredFrame = CFrame.fromMatrix(Result.Position, partRightVector, partUpVector, partForwardVector)

							-- Apply the random tilt angle towards center
							StoredFrame = StoredFrame * CFrame.Angles(math.rad(tiltAngle), 0, 0)
						else
							-- Lay flat on the surface
							StoredFrame = CFrame.new(Result.Position, Result.Position + Result.Normal)

							-- Apply random rotation around the Y axis for variety
							local flatRotation = math.rad(State.randInt(0, 360))
							StoredFrame = StoredFrame * CFrame.Angles(0, flatRotation, 0)

							-- Slight random tilt for natural look
							local tiltX = math.rad(State.randInt(-5, 5))
							local tiltZ = math.rad(State.randInt(-5, 5))
							StoredFrame = StoredFrame * CFrame.Angles(tiltX, 0, tiltZ)
						end

						-- Create part
						local Part = State.CreatePart(Result)
						State.Destroy(Part, 10)
						Part.Position = Result.Position
						Part.CFrame = StoredFrame

						-- Scale size based on progress
						local scaledSize = CurrentSize
						Part.Size = Vector3.new(scaledSize, scaledSize * 0.4, scaledSize * 0.8)

						-- Adjust position offset
						Part.Position = Part.Position - (Result.Normal * (Part.Size.Y / 3))

						StoredFrame = Part.CFrame
						Part.Parent = State.DebrisFolder
						Parts[#Parts + 1] = Part

						State.ApplyMode(
							Part,
							Settings.LifeCycle.Entrance.Type,
							Settings.LifeCycle.Entrance,
							{ Goal = { CFrame = StoredFrame }, midpos = centerPos, Result = Result }
						)
					else
						raycastsMissed = raycastsMissed + 1
					end
				end
				CurrentSize = CurrentSize * ScaleFactor

				if Settings.IterationDelay then
					task.wait(Settings.IterationDelay)
				end
			end
			print("[RockMod.Forward] Loop complete. Parts created:", partsCreated, "Raycasts missed:", raycastsMissed)
		end)

		if not success then
			warn("[RockMod] Error in Forward crater creation: " .. tostring(err))
		end

		creationComplete = true
	end)

	task.delay(Settings.LifeTime, function()
		-- Wait for part creation to complete before running exit animations
		local waitStart = os.clock()
		while not creationComplete and (os.clock() - waitStart) < 2 do
			task.wait()
		end

		for Index = 1, #Parts do
			State.ApplyMode(Parts[Index], Settings.LifeCycle.Exit.Type, Settings.LifeCycle.Exit)
			if Settings.IterationDelay then
				task.wait(Settings.IterationDelay)
			end
		end
	end)

	return PathData
end

function Craters.Path(AnchorPoint, Settings, State)
	if not AnchorPoint then
		return
	end
	Settings = State.MergeTables(Settings, Default.Path or {})

	-- Check if AnchorPoint is an Instance (Part/Attachment/etc)
	local isInstance = typeof(AnchorPoint) == "Instance"
	local anchorInstance = if isInstance then AnchorPoint else nil

	local DistanceRange = Settings.Distance
	local PartSize = Settings.PartSize
	local Rotation = Settings.Rotation
	local surfaceNormal = Settings.Normal
	local LifeTime = Settings.LifeTime

	local Parts = {}
	local Active = true
	local StartTime = os.clock()

	-- Get initial position
	local initialPosition = if isInstance then AnchorPoint.Position else AnchorPoint.Position

	-- Store path dimensions for debris placement (ExtraData)
	local ExtraData = {
		StartPosition = initialPosition,
		MaxWidth = DistanceRange[2], -- Use max distance as radius
		DirectionCFrame = nil,
		Stop = nil, -- Will store the cancel function
	}

	-- Get current position and orientation (updates if Instance is moving/rotating)
	local MidPosition, currentCFrame
	if isInstance then
		if anchorInstance:IsA("BasePart") then
			MidPosition = anchorInstance.Position
			currentCFrame = anchorInstance.CFrame
		else
			MidPosition = anchorInstance.Position
			currentCFrame = CFrame.new(MidPosition)
		end
	else
		MidPosition = AnchorPoint.Position
		currentCFrame = AnchorPoint
	end

	-- Recalculate direction CFrame based on current orientation
	local directionCFrame
	if surfaceNormal then
		local upVector = surfaceNormal.Unit
		local forwardVector = currentCFrame.LookVector
		local rightVector = forwardVector:Cross(upVector)
		if rightVector.Magnitude < 0.1 then
			rightVector = upVector:Cross(Vector3.new(1, 0, 0))
			if rightVector.Magnitude < 0.1 then
				rightVector = upVector:Cross(Vector3.new(0, 0, 1))
			end
		end
		rightVector = rightVector.Unit
		forwardVector = upVector:Cross(rightVector).Unit

		directionCFrame = CFrame.fromMatrix(MidPosition, rightVector, upVector, forwardVector)
	else
		-- Use the Instance's LookVector for orientation
		directionCFrame = currentCFrame
	end

	-- Random distance from center
	local currentDistance = State.randInt(DistanceRange[1], DistanceRange[2])

	-- Create left and right parts (like Forward does)
	for side = -1, 1, 2 do -- -1 for left, 1 for right
		-- Use RightVector (X axis) for left/right placement based on LookVector
		local sideOffset = directionCFrame:VectorToWorldSpace(Vector3.new(side * currentDistance, 0, 0))
		local castPosition = MidPosition + sideOffset

		-- Raycast down
		local rayDirection
		if surfaceNormal then
			rayDirection = -surfaceNormal * Settings.RaycastLength
		else
			rayDirection = Vector3.new(0, -Settings.RaycastLength, 0)
		end

		local Result = Raycast(castPosition, rayDirection, State.effect_params, false)
		if Result then
			local StoredFrame

			-- Each rock randomly picks a tilt value from the Rotation table
			local tiltAngle = 0
			if typeof(Rotation) == "table" then
				tiltAngle = State.randInt(Rotation[1], Rotation[2])
			end

			if tiltAngle ~= 0 then
				-- Angled towards center (like Forward)
				local toCenterDirection = (MidPosition - Result.Position).Unit
				local partUpVector = Result.Normal

				-- Create right vector perpendicular to both
				local partRightVector = partUpVector:Cross(toCenterDirection)
				if partRightVector.Magnitude < 0.1 then
					partRightVector = partUpVector:Cross(Vector3.new(1, 0, 0))
					if partRightVector.Magnitude < 0.1 then
						partRightVector = partUpVector:Cross(Vector3.new(0, 0, 1))
					end
				end
				partRightVector = partRightVector.Unit

				local partForwardVector = partRightVector:Cross(partUpVector).Unit

				-- Create base orientation
				StoredFrame = CFrame.fromMatrix(Result.Position, partRightVector, partUpVector, partForwardVector)

				-- Apply tilt
				StoredFrame = StoredFrame * CFrame.Angles(math.rad(tiltAngle), 0, 0)

				-- Apply random rotation around the Y axis for variety
				local flatRotation = math.rad(State.randInt(0, 360))
				StoredFrame = StoredFrame * CFrame.Angles(0, flatRotation, 0)

				-- Slight random tilt for natural look
				local tiltX = math.rad(State.randInt(-5, 5))
				local tiltZ = math.rad(State.randInt(-5, 5))
				StoredFrame = StoredFrame * CFrame.Angles(tiltX, 0, tiltZ)
			else
				-- Lay flat on surface
				StoredFrame = CFrame.new(Result.Position, Result.Position + Result.Normal)

				-- Apply random rotation around the Y axis for variety
				local flatRotation = math.rad(State.randInt(0, 360))
				StoredFrame = StoredFrame * CFrame.Angles(0, flatRotation, 0)

				-- Slight random tilt for natural look
				local tiltX = math.rad(State.randInt(-5, 5))
				local tiltZ = math.rad(State.randInt(-5, 5))
				StoredFrame = StoredFrame * CFrame.Angles(tiltX, 0, tiltZ)
			end

			-- Create part with consistent size (no scaling)
			local Part = State.CreatePart(Result)
			State.Destroy(Part, Settings.PartLifeTime + 1)
			Part.Position = Result.Position
			Part.CFrame = StoredFrame

			-- Use consistent size
			Part.Size = Vector3.new(PartSize, PartSize * 0.4, PartSize * 0.8)

			-- Adjust position offset
			Part.Position = Part.Position - (Result.Normal * (Part.Size.Y / 3))

			StoredFrame = Part.CFrame
			Part.Parent = State.DebrisFolder
			Parts[#Parts + 1] = Part

			State.ApplyMode(
				Part,
				Settings.LifeCycle.Entrance.Type,
				Settings.LifeCycle.Entrance,
				{ Goal = { CFrame = StoredFrame }, midpos = MidPosition, Result = Result }
			)

			task.delay(Settings.PartLifeTime, function()
				State.ApplyMode(Part, Settings.LifeCycle.Exit.Type, Settings.LifeCycle.Exit)
			end)
		end
	end


	-- Add cancel function to ExtraData
	ExtraData.Stop = function()
		Active = false
	end

	return ExtraData
end


return Craters
