--!strict
--[[
	BodyMoverService

	Centralized body mover management for characters.
	Extracted from Library.lua for better code organization.

	Responsibilities:
	- Removing body movers from characters
	- Clearing residual velocities
	- Character physics cleanup
]]

local BodyMoverService = {}

-- Body mover class names to check
local BODY_MOVER_CLASSES = {
	"BodyVelocity",
	"BodyPosition",
	"BodyGyro",
	"BodyAngularVelocity",
	"LinearVelocity",
	"AngularVelocity",
	"AlignPosition",
	"AlignOrientation",
}

--[[
	Remove all body movers from a character to prevent flinging
	@param Char Model - The character model
	@return number - Number of body movers removed
]]
function BodyMoverService.RemoveAllBodyMovers(Char: Model): number
	if not Char then return 0 end

	local moversRemoved = 0

	-- Check all descendants for body movers
	for _, descendant in Char:GetDescendants() do
		for _, className in BODY_MOVER_CLASSES do
			if descendant:IsA(className) then
				descendant:Destroy()
				moversRemoved = moversRemoved + 1
				break
			end
		end
	end

	-- Clear residual velocity from HumanoidRootPart
	local rootPart = Char:FindFirstChild("HumanoidRootPart")
	if rootPart and rootPart:IsA("BasePart") then
		rootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
		rootPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
	end

	return moversRemoved
end

--[[
	Remove body movers with a specific name from a character
	@param Char Model - The character model
	@param Name string - The name of body movers to remove
	@return number - Number of body movers removed
]]
function BodyMoverService.RemoveBodyMoversByName(Char: Model, Name: string): number
	if not Char then return 0 end

	local moversRemoved = 0

	for _, descendant in Char:GetDescendants() do
		if descendant.Name == Name then
			for _, className in BODY_MOVER_CLASSES do
				if descendant:IsA(className) then
					descendant:Destroy()
					moversRemoved = moversRemoved + 1
					break
				end
			end
		end
	end

	return moversRemoved
end

--[[
	Clear residual velocities from a character's root part
	@param Char Model - The character model
]]
function BodyMoverService.ClearVelocities(Char: Model)
	if not Char then return end

	local rootPart = Char:FindFirstChild("HumanoidRootPart")
	if rootPart and rootPart:IsA("BasePart") then
		rootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
		rootPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
	end
end

--[[
	Check if a character has any active body movers
	@param Char Model - The character model
	@return boolean - True if character has body movers
]]
function BodyMoverService.HasBodyMovers(Char: Model): boolean
	if not Char then return false end

	for _, descendant in Char:GetDescendants() do
		for _, className in BODY_MOVER_CLASSES do
			if descendant:IsA(className) then
				return true
			end
		end
	end

	return false
end

--[[
	Get all body movers on a character
	@param Char Model - The character model
	@return {Instance} - Array of body mover instances
]]
function BodyMoverService.GetBodyMovers(Char: Model): {Instance}
	if not Char then return {} end

	local movers = {}

	for _, descendant in Char:GetDescendants() do
		for _, className in BODY_MOVER_CLASSES do
			if descendant:IsA(className) then
				table.insert(movers, descendant)
				break
			end
		end
	end

	return movers
end

return BodyMoverService
