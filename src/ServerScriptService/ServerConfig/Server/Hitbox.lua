local Hitbox = {}
local Server = require(script.Parent)
Hitbox.__index = Hitbox
local self = setmetatable({}, Hitbox)

-- Modified to check for entities, walls, and destructible objects
function CheckValidTarget(TargetPart, Entity)
	local Valid = false

	-- Check if it's a character/entity
	if TargetPart ~= nil and TargetPart.Parent ~= nil then
		-- Check for regular entities
		if TargetPart.Parent:FindFirstChild("Humanoid") then
			local TargetCharacter = TargetPart.Parent
			if TargetCharacter:IsDescendantOf(workspace.World.Live) and TargetCharacter ~= Entity then
				Valid = true
			end

			-- Check for alchemy walls (parts with the special attribute)
		elseif TargetPart.Name:find("AbilityWall_") and TargetPart:GetAttribute("Id") then
			print("youre attempting to attack a wall")
			Valid = true

			-- Check for destructible objects (barrels, trees, etc.)
			-- IMPORTANT: Only allow destruction if the part is in Map or Transmutables folder
			-- This prevents character accessories (hair, hats) from being destroyed
		elseif TargetPart:GetAttribute("Destroyable") == true then
			-- Check if part is in the Map folder or Transmutables folder
			local isInMap = TargetPart:IsDescendantOf(workspace.Map or workspace.Transmutables)
			local isInTransmutables = workspace:FindFirstChild("Transmutables") and TargetPart:IsDescendantOf(workspace.Transmutables)

			if isInMap or isInTransmutables then
				print("youre attempting to attack a destructible object:", TargetPart.Name)
				Valid = true
			else
				-- Part has Destroyable attribute but is not in Map/Transmutables (probably a character accessory)
				-- Do NOT mark as valid target
				Valid = false
			end
		end
	end

	return Valid
end

local function ExtrapolateMovingCFrame(Base: BasePart): CFrame
	local LinearVel = Base.AssemblyLinearVelocity
	local LinearExtrapVel = Vector3.new(LinearVel.X, LinearVel.Y / 2, LinearVel.Z) / 4
	local Decay = (1 + (0.185 * LinearExtrapVel.Magnitude) ^ 8)

	local ApplyDecay = function(Axis: number)
		return (math.abs(Axis / Decay) > math.abs(Axis / 2) and (Axis / Decay) or (Axis / 2))
	end

	return Base.CFrame + Vector3.new(ApplyDecay(LinearExtrapVel.X), LinearExtrapVel.Y, ApplyDecay(LinearExtrapVel.Z)),
		LinearVel.Magnitude
end

Hitbox.SpatialQuery = function(Entity: Model, BoxSize: Vector3, BoxCFrame: CFrame, Visualize: boolean?)
	local PotentialTargets = {}

	-- First check for entities (characters/NPCs)
	local EntityParams = OverlapParams.new()
	EntityParams.FilterDescendantsInstances = { workspace.World.Live }
	EntityParams.FilterType = Enum.RaycastFilterType.Include
	EntityParams.CollisionGroup = "Default"

	-- Then check for walls (in Transmutables folder)
	local WallParams = OverlapParams.new()
	WallParams.FilterDescendantsInstances = { workspace.Transmutables }
	WallParams.FilterType = Enum.RaycastFilterType.Include
	WallParams.CollisionGroup = "Default"

	-- NOTE: Removed destructible objects from regular hitbox queries
	-- Destructibles should only be destroyed by specific attacks (like environmental damage)
	-- Regular combat (M1, M2, skills) should NOT destroy barrels, crates, etc.

	-- Combine results from all queries
	local HitParts = workspace:GetPartBoundsInBox(BoxCFrame, BoxSize, EntityParams)
	local WallParts = workspace:GetPartBoundsInBox(BoxCFrame, BoxSize, WallParams)

	-- Merge wall parts into hit parts
	for _, part in ipairs(WallParts) do
		table.insert(HitParts, part)
	end

	-- Create a visualizer part
	if Visualize then
		local VisualizerPart = Instance.new("Part")
		VisualizerPart.Anchored = true
		VisualizerPart.CanCollide = false
		VisualizerPart.Transparency = 0.5
		VisualizerPart.Color = Color3.new(1, 0, 0)
		VisualizerPart.Size = BoxSize
		VisualizerPart.CFrame = BoxCFrame
		VisualizerPart.Parent = workspace.World.Visuals
		task.delay(0.5, function()
			VisualizerPart:Destroy()
		end)
	end

	for _, HitPart in HitParts do
		if CheckValidTarget(HitPart, Entity) then
			-- For entities, store the parent (character)
			-- For walls, store the part itself
			local target = HitPart.Parent:FindFirstChild("Humanoid") and HitPart.Parent or HitPart
			if not table.find(PotentialTargets, target) then
				table.insert(PotentialTargets, target)
			end
		end
	end

	-- Remove the visualizer part after a short delay

	return PotentialTargets
end

-- Additional function specifically for wall detection
Hitbox.CheckWallCollision = function(Origin: Vector3, Direction: Vector3, Range: number)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = { workspace.Transmutables }
	raycastParams.FilterType = Enum.RaycastFilterType.Include
	raycastParams.CollisionGroup = "Default"

	local raycastResult = workspace:Raycast(Origin, Direction * Range, raycastParams)
	if raycastResult then
		local hitPart = raycastResult.Instance
		if hitPart.Name:find("AbilityWall_") and hitPart:GetAttribute("Id") then
			return hitPart, raycastResult.Position
		end
	end

	return nil
end

return Hitbox
