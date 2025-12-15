--strict
local Craters = {}

local Default = require(script.Parent.DEFAULT)

function Craters.Orbit(AnchorPoint, Settings, State)
	if not AnchorPoint then
		return
	end
	Settings = State.MergeTables(Settings, Default.Orbit)

	local CurrentSplit = 1
	local Parts = {}
	---- print(Settings.Size)

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
			return
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


local function CreatePart()
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.Color = Color3.fromRGB(255, 0, 0)
	part.Name = "Visual"
	part.Transparency = 0.75
	part.Size = Vector3.new(4, 4, 6)
	part.Parent = workspace.World.Visuals
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
				local localOffset = Vector3.new(
					math.cos(math.rad(angle)) * PartDistance,
					0,
					math.sin(math.rad(angle)) * PartDistance
				)
				local worldOffset = surfaceAlignedCFrame:VectorToWorldSpace(localOffset)
				castCF = CFrame.new(MidPosition + worldOffset)
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

			local Result = Raycast(castCF.Position, rayDirection, State.effect_params, false)
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
				StoredFrame = CFrame.lookAt(Result.Position, midpos - Result.Normal) * CFrame.Angles(math.rad(-20), 0, 0)
			end

			local Part = State.CreatePart(Result)
			State.Destroy(Part, Settings.LifeTime + Settings.PartCount)
			Part.Position = Result.Position
			Part.CFrame = StoredFrame
			Part.Size = ((Vector3.new(25 / 15, 10 / 15, 20 / 15) * PartDistance) / (PartsPerLayer * 0.25))
				* Settings.SizeMultiplier

			-- Override material and material variant if provided in settings
			if Settings.Material then
				Part.Material = Settings.Material
			end
			if Settings.MaterialVariant then
				Part.MaterialVariant = Settings.MaterialVariant
			end

			-- Adjust position offset based on surface normal
			if surfaceNormal then
				Part.Position = Part.Position - (Result.Normal * (Part.Size.Y / 3))
			else
				Part.Position += Vector3.new(0, -Part.Size.Y / 3, 0)
			end

			StoredFrame = Part.CFrame
			Part.Parent = State.DebrisFolder
			Parts[#Parts + 1] = Part

			State.ApplyMode(Part, Settings.LifeCycle.Entrance.Type, Settings.LifeCycle.Entrance, {Goal = {CFrame = StoredFrame}, midpos = Result.Position, Result = Result})
		end
	end

	task.wait(Settings.LifeTime)
	for Index = 1, #Parts do
		State.ApplyMode(Parts[Index], Settings.LifeCycle.Exit.Type, Settings.LifeCycle.Exit)
		task.wait(State.randInt(Settings.ExitIterationDelay[1], Settings.ExitIterationDelay[2]))
	end
end

return Craters
