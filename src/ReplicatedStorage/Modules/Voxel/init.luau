local destructionSchedule = {} -- Keeps track of parts and their destruction timers
local TagName = "Destroyable" --Name of Attribute that module will check parts for
local RandomColors = false -- Will make every part a random color. Set this to true if you want a visual representation of how the parts are being divided.
local Visualizer = false -- Will make hitboxes visible when set to true
local miniumCubeSize = 5 --Default Minimum possible size that divided cubes can be.
local voxelFolder = workspace --Where the voxels are stored. Workspace by default.
local AutoStartMoveable = false --Toggle this to true if you want your moveable hitboxes to activate automatically without having to use :Start()
local PartCacheEnabled = true --Enables PartCache. This significantly improves performance so I reccommend keeping it on.
local VoxBreaker = {}

local rs = game:GetService("RunService")

local cache
local PartFolder

if PartCacheEnabled then
	local PC = require(script.PartCache)

	PartFolder = Instance.new("Folder")
	PartFolder.Name = "PartCache" .. tostring(math.random(1, 5))
	PartFolder.Parent = workspace

	local TemplatePart = Instance.new("Part")
	TemplatePart.Anchored = true
	cache = PC.new(TemplatePart, 3000, PartFolder)
	cache.ExpansionSize = 30
	TemplatePart:Destroy()
end

local function Destroy(part: Instance, timeToDestroy)
	-- If the part is already scheduled for destruction, cancel the previous timer
	if destructionSchedule[part] then
		task.cancel(destructionSchedule[part])
	end

	-- Schedule a new destruction timer
	destructionSchedule[part] = task.delay(timeToDestroy, function()
		if part and part.Parent then
			if PartCacheEnabled then
				if part:IsA("Model") then
					for i, v in pairs(part:GetChildren()) do
						if table.find(cache.InUse, v) then
							for i, child in pairs(v:GetChildren()) do
								child:Destroy()
							end
							cache:ReturnPart(v)
							v.Parent = PartFolder
						end
					end
				end
			end
			task.spawn(function()
				part:AddTag("Destroying")
				task.wait(0.1)
				part:Destroy()
			end)
		end
		destructionSchedule[part] = nil -- Remove the part from the schedule once it's destroyed
	end)
end

local function CopyProperties(PartOne: Part, PartTwo: Part)
	PartTwo.Anchored = PartOne.Anchored
	PartTwo.Transparency = PartOne.Transparency
	PartTwo.CanCollide = PartOne.CanCollide
	PartTwo.CanQuery = PartOne.CanQuery
	PartTwo.CanTouch = PartOne.CanTouch
	PartTwo.CastShadow = PartOne.CastShadow
	PartTwo.CFrame = PartOne.CFrame
	PartTwo.Color = PartOne.Color
	PartTwo.Name = PartOne.Name
	PartTwo.Size = PartOne.Size
	PartTwo.Material = PartOne.Material
	PartTwo.CollisionGroup = PartOne.CollisionGroup
	PartTwo.MaterialVariant = PartOne.MaterialVariant
	PartTwo.BottomSurface = PartOne.BottomSurface
	PartTwo.TopSurface = PartOne.TopSurface
	PartTwo.RightSurface = PartOne.RightSurface
	PartTwo.LeftSurface = PartOne.LeftSurface
	PartTwo.BackSurface = PartOne.BackSurface
	PartTwo.FrontSurface = PartOne.FrontSurface

	-- Handle Shape property for regular Parts only
	if PartOne:IsA("Part") and PartTwo:IsA("Part") then
		PartTwo.Shape = PartOne.Shape
	elseif PartTwo:IsA("Part") then
		-- If copying from MeshPart to Part, use default Block shape
		PartTwo.Shape = Enum.PartType.Block
	end

	-- Copy MeshPart-specific properties if both are MeshParts
	if PartOne:IsA("MeshPart") and PartTwo:IsA("MeshPart") then
		PartTwo.MeshId = PartOne.MeshId
		PartTwo.TextureID = PartOne.TextureID
	end

	-- Note: When copying from MeshPart to regular Part (common with PartCache),
	-- we lose the mesh but keep all other visual properties like Material and Color

	PartTwo:SetAttribute(TagName, PartOne:GetAttribute(TagName))

	for i, v in PartOne:GetChildren() do
		-- Skip SurfaceAppearance if target is not a MeshPart
		if v:IsA("SurfaceAppearance") and not PartTwo:IsA("MeshPart") then
			continue -- SurfaceAppearance can only be parented to MeshParts
		end

		-- Skip other incompatible objects for regular Parts
		if not PartTwo:IsA("MeshPart") and (v:IsA("SpecialMesh") or v:IsA("FileMesh")) then
			continue -- These are MeshPart-specific
		end

		local clone = v:Clone()
		clone.Parent = PartTwo
	end
end

local function partCanSubdivide(part: Part) --Checks if part is rectangular.
	local Threshold = 1.5 -- How much of a difference there can be between the largest axis and the smallest axis

	local largest = math.max(part.Size.X, part.Size.Y, part.Size.Z) --Largest Axis
	local smallest = math.min(part.Size.X, part.Size.Y, part.Size.Z) -- Smallest Axis

	if smallest == part.Size.X then
		smallest = math.min(part.Size.Y, part.Size.Z)
	elseif smallest == part.Size.Y then
		smallest = math.min(part.Size.X, part.Size.Z)
	elseif smallest == part.Size.Z then
		smallest = math.min(part.Size.X, part.Size.Y)
	end

	return largest >= Threshold * smallest
	--Returns true if part is rectangular.
	--Part is rectangular if the largest axis is at least 1.5x bigger than the smallest axis
end

local function getLargestAxis(part: Part) --Returns Largest Axis of Part size
	return math.max(part.Size.X, part.Size.Y, part.Size.Z)
end

local function CutPartinHalf(block: Part, TimeToReset: number) --Cuts part into two evenly shaped pieces.
	local partTable: { Part } = {} --Table of parts to be returned
	local bipolarVectorSet = {} --Offset on where to place halves

	local X = block.Size.X
	local Y = block.Size.Y
	local Z = block.Size.Z

	if getLargestAxis(block) == X then --Changes offset vectors depending on what the largest axis is.
		X /= 2

		bipolarVectorSet = {
			Vector3.new(1, 0, 0),
			Vector3.new(-1, 0, 0),
		}
	elseif getLargestAxis(block) == Y then
		Y /= 2

		bipolarVectorSet = {
			Vector3.new(0, 1, 0),
			Vector3.new(0, -1, 0),
		}
	elseif getLargestAxis(block) == Z then
		Z /= 2

		bipolarVectorSet = {
			Vector3.new(0, 0, 1),
			Vector3.new(0, 0, -1),
		}
	end

	local model

	if block.Parent:IsA("Model") and block.Parent:GetAttribute("VoxelHolder") then
		model = block.Parent
	else
		model = Instance.new("Model")
		model.Name = "VoxelHolder"
		model.Parent = voxelFolder
		model:SetAttribute("VoxelHolder", true)
	end

	if TimeToReset and TimeToReset >= 0 then
		Destroy(model, TimeToReset)
	end

	local halfSize = Vector3.new(X, Y, Z)

	for _, offsetVector in pairs(bipolarVectorSet) do
		local clone
		if PartCacheEnabled then
			clone = cache:GetPart()
			CopyProperties(block, clone)
		else
			clone = block:Clone()
		end

		if RandomColors then
			clone.Color = Color3.fromRGB(math.random(1, 255), math.random(1, 255), math.random(1, 255))
		end

		clone.Parent = model
		clone.Size = halfSize
		clone.CFrame += block.CFrame:VectorToWorldSpace((halfSize / 2.0) * offsetVector)
		table.insert(partTable, clone)
	end

	if block:GetAttribute("Transparency") == nil then
		block:SetAttribute("Transparency", block.Transparency)
		block:SetAttribute("Collide", block.CanCollide)
		block:SetAttribute("Query", block.CanQuery)
	end

	block.Transparency = 1
	block.CanCollide = false
	block.CanQuery = false
	block:SetAttribute(TagName, false)

	for i, v in block:GetChildren() do
		task.spawn(function()
			if v:IsA("SurfaceGui") then
				local enabled = v.Enabled
				v.Enabled = false
				repeat
					rs.Heartbeat:Wait()

				until model:HasTag("Destroying")
				v.Enabled = enabled
			elseif v:IsA("Decal") then
				local transparency = v.Transparency
				v.Transparency = 1
				repeat
					rs.Heartbeat:Wait()

				until model:HasTag("Destroying")
				v.Transparency = transparency
			elseif v:IsA("Texture") then
				if v and v.Transparency then
					local transparency = v.Transparency
					v.Transparency = 1
					repeat
						rs.Heartbeat:Wait()
					until model and model:HasTag("Destroying")
					v.Transparency = transparency
				end
			end
		end)
	end

	task.spawn(function()
		if TimeToReset >= 0 then
			repeat
				rs.Heartbeat:Wait()

			until model:HasTag("Destroying")

			if block:GetAttribute("Transparency") then
				block.Transparency = block:GetAttribute("Transparency")
			end
			if block:GetAttribute("CanQuery") then
				block.CanQuery = block:GetAttribute("Query")
			end
			if block:GetAttribute("Collide") then
				block.CanCollide = block:GetAttribute("Collide")
			end

			block:SetAttribute(TagName, true)
		end
	end)

	if block.Parent and block.Parent:IsA("Model") and block.Parent:GetAttribute("VoxelHolder") then
		if PartCacheEnabled then
			for i, v in pairs(block:GetChildren()) do
				v:Destroy()
			end
			for name, value in block:GetAttributes() do
				block:SetAttribute(name, nil)
			end
			cache:ReturnPart(block)
			block.Parent = PartFolder
		else
			block:Destroy()
		end
	end

	return partTable -- Returns a table containing the two halves
end

local function GetTableMode(Table: { Part })
	if #Table >= 1 then
		local Dictionary = {}
		for _, V in ipairs(Table) do
			local Value = V.Size
			Dictionary[Value] = if Dictionary[Value] then Dictionary[Value] + 1 else 1
		end
		local Array = {}
		for Key, Value in pairs(Dictionary) do
			table.insert(Array, { Key, Value })
		end
		table.sort(Array, function(Left, Right)
			return Left[2] > Right[2]
		end)
		return Array[1][1]
	end
end

local function DivideBlock(block: Part, MinimumVoxelSize: number, Parent: Instance, TimeToReset: number) --Divides part into evenly shaped cubes.
	--MinimumvVoxelSize Parameter is used to describe the minimum possible size that the parts can be divided. To avoid confusion, this is not the size that the parts will be divided into, but rather the minimum allowed
	--You CANNOT change the size of the resulting parts. They are dependent on the size of the original part.

	local partTable: { Part } = {} -- Table of parts to be returned
	local minimum = MinimumVoxelSize or miniumCubeSize

	if block.Size.X > minimum or block.Size.Y > minimum or block.Size.Z > minimum then
		if partCanSubdivide(block) then --If part is rectangular then it is cut in half, otherwise it is divided into cubes.
			partTable = CutPartinHalf(block, TimeToReset)
		else
			local model
			if block.Parent and block.Parent:IsA("Model") and block.Parent:GetAttribute("VoxelHolder") then
				model = block.Parent
			else
				model = Instance.new("Model")
				model.Name = "VoxelHolder"
				model.Parent = voxelFolder
				model:SetAttribute("VoxelHolder", true)
			end

			if TimeToReset and TimeToReset >= 0 then
				Destroy(model, TimeToReset)
			end

			local Threshold = 1.5 -- How much of a difference there can be between the largest axis and the smallest axis

			local largest = math.max(block.Size.X, block.Size.Y, block.Size.Z) --Largest Axis
			local smallest = math.min(block.Size.X, block.Size.Y, block.Size.Z) -- Smallest Axis

			if smallest == block.Size.Y and smallest * Threshold <= largest then
				local bipolarVectorSet = {}

				local X = block.Size.X
				local Y = block.Size.Y
				local Z = block.Size.Z

				X /= 2
				Z /= 2
				bipolarVectorSet = { --Offset Vectors
					Vector3.new(-1, 0, 1),
					Vector3.new(1, 0, -1),
					Vector3.new(1, 0, 1),
					Vector3.new(-1, 0, -1),
				}

				local halfSize = Vector3.new(X, Y, Z)

				for _, offsetVector in pairs(bipolarVectorSet) do
					local clone
					if PartCacheEnabled then
						clone = cache:GetPart()
						CopyProperties(block, clone)
					else
						clone = block:Clone()
					end
					clone:SetAttribute("Voxel", true)
					if RandomColors then
						clone.Color = Color3.fromRGB(math.random(1, 255), math.random(1, 255), math.random(1, 255))
					end

					clone.Parent = Parent or model
					clone.Size = halfSize
					clone.CFrame += block.CFrame:VectorToWorldSpace((halfSize / 2.0) * offsetVector)
					table.insert(partTable, clone)
				end
			elseif smallest == block.Size.X and smallest * Threshold <= largest then
				local bipolarVectorSet = {}

				local X = block.Size.X
				local Y = block.Size.Y
				local Z = block.Size.Z

				Y /= 2
				Z /= 2
				bipolarVectorSet = { --Offset Vectors
					Vector3.new(0, -1, 1),
					Vector3.new(0, 1, 1),
					Vector3.new(0, -1, -1),
					Vector3.new(0, 1, -1),
				}

				local halfSize = Vector3.new(X, Y, Z)

				for _, offsetVector in pairs(bipolarVectorSet) do
					local clone
					if PartCacheEnabled then
						clone = cache:GetPart()
						CopyProperties(block, clone)
					else
						clone = block:Clone()
					end
					clone:SetAttribute("Voxel", true)
					if RandomColors then
						clone.Color = Color3.fromRGB(math.random(1, 255), math.random(1, 255), math.random(1, 255))
					end

					clone.Parent = Parent or model
					clone.Size = halfSize
					clone.CFrame += block.CFrame:VectorToWorldSpace((halfSize / 2.0) * offsetVector)
					table.insert(partTable, clone)
				end
			elseif smallest == block.Size.Z and smallest * Threshold <= largest then
				local bipolarVectorSet = {}

				local X = block.Size.X
				local Y = block.Size.Y
				local Z = block.Size.Z

				X /= 2
				Y /= 2
				bipolarVectorSet = { --Offset Vectors
					Vector3.new(1, -1, 0),
					Vector3.new(1, 1, 0),
					Vector3.new(-1, -1, 0),
					Vector3.new(-1, 1, 0),
				}

				local halfSize = Vector3.new(X, Y, Z)

				for _, offsetVector in pairs(bipolarVectorSet) do
					local clone
					if PartCacheEnabled then
						clone = cache:GetPart()
						CopyProperties(block, clone)
					else
						clone = block:Clone()
					end
					clone:SetAttribute("Voxel", true)
					if RandomColors then
						clone.Color = Color3.fromRGB(math.random(1, 255), math.random(1, 255), math.random(1, 255))
					end

					clone.Parent = Parent or model
					clone.Size = halfSize
					clone.CFrame += block.CFrame:VectorToWorldSpace((halfSize / 2.0) * offsetVector)
					table.insert(partTable, clone)
				end
			else
				local bipolarVectorSet = { --Offset Vectors
					Vector3.new(1, 1, 1),
					Vector3.new(1, 1, -1),
					Vector3.new(1, -1, 1),
					Vector3.new(1, -1, -1),
					Vector3.new(-1, 1, 1),
					Vector3.new(-1, 1, -1),
					Vector3.new(-1, -1, 1),
					Vector3.new(-1, -1, -1),
				}

				local halfSize = block.Size / 2.0

				for _, offsetVector in pairs(bipolarVectorSet) do
					local clone
					if PartCacheEnabled then
						clone = cache:GetPart()
						CopyProperties(block, clone)
					else
						clone = block:Clone()
					end
					if RandomColors then
						clone.Color = Color3.fromRGB(math.random(1, 255), math.random(1, 255), math.random(1, 255))
					end
					clone.Parent = Parent or model
					clone.Size = halfSize
					clone.CFrame += block.CFrame:VectorToWorldSpace((halfSize / 2.0) * offsetVector)
					table.insert(partTable, clone)
				end
			end

			if block.Parent and block.Parent:IsA("Model") and block.Parent:GetAttribute("VoxelHolder") then
				if PartCacheEnabled then
					for i, v in pairs(block:GetChildren()) do
						v:Destroy()
					end
					for name, value in block:GetAttributes() do
						block:SetAttribute(name, nil)
					end
					cache:ReturnPart(block)
					block.Parent = PartFolder
				else
					block:Destroy()
				end
			else
				if block:GetAttribute("Transparency") == nil then
					block:SetAttribute("Transparency", block.Transparency)
					block:SetAttribute("Collide", block.CanCollide)
					block:SetAttribute("Query", block.CanQuery)
				end

				block.Transparency = 1
				block.CanCollide = false
				block.CanQuery = false
				block:SetAttribute(TagName, false)

				for i, v in block:GetChildren() do
					task.spawn(function()
						if v:IsA("SurfaceGui") then
							local enabled = v.Enabled
							v.Enabled = false
							repeat
								rs.Heartbeat:Wait()

							until model:HasTag("Destroying")
							v.Enabled = enabled
						elseif v:IsA("Decal") then
							local transparency = v.Transparency
							v.Transparency = 1
							repeat
								rs.Heartbeat:Wait()

							until model:HasTag("Destroying")
							v.Transparency = transparency
						elseif v:IsA("Texture") then
							local transparency = v.Transparency
							v.Transparency = 1
							repeat
								task.wait()

							until model:HasTag("Destroying")
							v.Transparency = transparency
						end
					end)
				end

				task.spawn(function()
					if TimeToReset >= 0 then
						repeat
							rs.Heartbeat:Wait()

						until model:HasTag("Destroying")

						if block:GetAttribute("Transparency") then
							block.Transparency = block:GetAttribute("Transparency")
						end
						if block:GetAttribute("CanQuery") then
							block.CanQuery = block:GetAttribute("Query")
						end
						if block:GetAttribute("Collide") then
							block.CanCollide = block:GetAttribute("Collide")
						end

						block:SetAttribute(TagName, true)
					end
				end)
			end
		end
	elseif block.Parent:GetAttribute("VoxelHolder") == nil and block:GetAttribute("Voxel") == nil then
		if block:GetAttribute("Transparency") then
			block.Transparency = block:GetAttribute("Transparency")
		end
		if block:GetAttribute("CanQuery") then
			block.CanQuery = block:GetAttribute("Query")
		end
		if block:GetAttribute("Collide") then
			block.CanCollide = block:GetAttribute("Collide")
		end

		local clone
		if PartCacheEnabled then
			clone = cache:GetPart()
			CopyProperties(block, clone)
		else
			clone = block:Clone()
		end
		clone.Parent = block.Parent
		if TimeToReset and TimeToReset >= 0 then
			Destroy(clone, TimeToReset)
		end

		block.Transparency = 1
		block.CanCollide = false
		block.CanQuery = false
		block:SetAttribute(TagName, false)

		for i, v in block:GetChildren() do
			task.spawn(function()
				if v:IsA("SurfaceGui") then
					local enabled = v.Enabled
					v.Enabled = false
					task.wait(TimeToReset)
					v.Enabled = enabled
				elseif v:IsA("Decal") then
					local transparency = v.Transparency
					v.Transparency = 1
					task.wait(TimeToReset)
					v.Transparency = transparency
				elseif v:IsA("Texture") then
					if v then
						local transparency = v.Transparency
						if transparency then
							v.Transparency = 1
							task.wait(TimeToReset)
							v.Transparency = transparency
						end
					end
				end
			end)
		end

		task.spawn(function()
			task.wait(TimeToReset)

			if block:GetAttribute("Transparency") then
				block.Transparency = block:GetAttribute("Transparency")
			end
			if block:GetAttribute("CanQuery") then
				block.CanQuery = block:GetAttribute("Query")
			end
			if block:GetAttribute("Collide") then
				block.CanCollide = block:GetAttribute("Collide")
			end

			block:SetAttribute(TagName, true)
		end)
	end

	return partTable --Returns resulting parts
end

local function GetTouchingParts(part: BasePart, Params: OverlapParams) --Used to get all the parts within a part.
	local results = {}
	local touching
	if Params then
		touching = workspace:GetPartsInPart(part, Params)
	else
		touching = workspace:GetPartsInPart(part)
	end

	for i, v in pairs(touching) do
		if v:IsA("Part") then
			if v:GetAttribute(TagName) == true then
				table.insert(results, v)
			end
		end
	end
	return results --Returns a table of all eligible parts touching the specified part
end

function VoxBreaker:VoxelizePart(Part: Part, DesiredParts: number, TimeToReset: number)
    local parts = {Part}
    local iterations = 0
    local maxIterations = 10  -- Safety limit
    
    -- Calculate how many times we need to divide to reach the desired part count
    -- Each division roughly multiplies part count by 2 (for CutPartinHalf) or more (for other divisions)
    while #parts < DesiredParts and iterations < maxIterations do
        iterations = iterations + 1
        local newParts = {}
        
        for _, part in ipairs(parts) do
            if #parts + #newParts < DesiredParts * 1.2 then  -- Don't overshoot too much
                local divided = DivideBlock(part, 0, nil, TimeToReset)  -- 0 min size to force division
                for _, p in ipairs(divided) do
                    table.insert(newParts, p)
                end
            else
                table.insert(newParts, part)
            end
        end
        
        parts = newParts
    end
    
    return parts
end

function VoxBreaker:CreateHitbox(
	Size: Vector3 | string,
	Cframe: CFrame,
	Shape: Enum.PartType | MeshPart,
	MinimumVoxelSize: number,
	TimeToReset: number,
	Params: OverlapParams
) --Creates one hitbox which divides any applicable parts that are touching it.
	--If the TimeToReset parameter is less than 0, then the parts will not reset.

	local DefaultSize = Vector3.new(1, 1, 1) -- Default Hitbox Size
	local DefaultShape = Enum.PartType.Block -- Default Shape of hitbox
	local DefaultTimeToReset = 50 --Default time in seconds it takes for divided parts to reset

	local size = Size or DefaultSize
	local shape = Shape or DefaultShape
	local minimum = MinimumVoxelSize or miniumCubeSize
	local timetoreset = TimeToReset or DefaultTimeToReset

	local partTable: { Part } = {} --Table of parts to be returned

	local part

	if typeof(Shape) == "Instance" then
		part = Shape:Clone()
	else
		part = Instance.new("Part") --Creating the hitbox
	end

	Destroy(part, 0.5) --Destroys hitbox in 0.5 seconds

	part.Size = Size or DefaultSize
	part.CFrame = Cframe or CFrame.new(0, 0, 0)
	part.Anchored = true
	part.Transparency = 0.6
	if Shape and typeof(Shape) ~= "Instance" then
		part.Shape = Shape
	end
	part.CanCollide = false
	part.Material = Enum.Material.Neon
	part.Color = Color3.fromRGB(255, 0, 0)

	if MinimumVoxelSize == "Relative" then
		local ratio = 1 / 3
		local largest = getLargestAxis(part)
		minimum = largest * ratio
	end

	if Visualizer then
		part.Parent = game.Workspace
	end

	repeat
		local check = true

		partTable = GetTouchingParts(part, Params)

		for i, v in pairs(partTable) do
			if v:IsA("Part") and v:GetAttribute(TagName) then
				if
					math.floor(v.Size.X) > minimum
					or math.floor(v.Size.Y) > minimum
					or math.floor(v.Size.Z) > minimum
				then
					check = false
				end
			else
				table.remove(partTable, i)
			end
		end

		if check == false then
			for i, v in pairs(partTable) do
				if v:IsA("Part") and v:GetAttribute(TagName) then
					DivideBlock(v, minimum, nil, timetoreset)
				end
			end
		end

	until check == true

	if PartCacheEnabled then
		local mode = GetTableMode(partTable)
		for i, v in pairs(partTable) do
			v.Size = mode
		end
	end

	return partTable --Returns all parts touching the hitbox
end

return VoxBreaker
