--[[
	AccessoryManager

	Handles welding accessories (like prosthetic arms) to characters using
	Motor6D welds with Par (parent), Part0, and Part1 attributes.

	Accessory Structure:
	- Accessory Model
	  - Main Part (with Motor6D child named "Weld")
	    - Weld (Motor6D)
	      - Par attribute: string (name of parent part in character)
	      - Part0 attribute: string (name of Part0 in character)
	      - Part1 attribute: string (name of Part1, usually the accessory itself)

	Usage:
	AccessoryManager.WeldAccessory(character, accessoryModel)
	AccessoryManager.RemoveAccessory(character, accessoryName)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")

local AccessoryManager = {}

-- Find the Motor6D weld in an accessory model
local function findAccessoryWeld(accessoryModel: Model): Motor6D?
	-- First check direct children
	for _, child in accessoryModel:GetDescendants() do
		if child:IsA("Motor6D") and child.Name == "Weld" then
			return child
		end
	end
	return nil
end

-- Get the main part of an accessory (the part with the weld)
local function getAccessoryMainPart(accessoryModel: Model): BasePart?
	local weld = findAccessoryWeld(accessoryModel)
	if weld and weld.Parent and weld.Parent:IsA("BasePart") then
		return weld.Parent
	end
	-- Fallback: try to find PrimaryPart or first BasePart
	if accessoryModel.PrimaryPart then
		return accessoryModel.PrimaryPart
	end
	for _, child in accessoryModel:GetChildren() do
		if child:IsA("BasePart") then
			return child
		end
	end
	return nil
end

--[[
	Welds an accessory to a character using the accessory's Motor6D weld attributes.

	@param character Model - The character to weld the accessory to
	@param accessoryModel Model - The accessory model to weld (will be cloned)
	@return boolean - Whether the welding was successful
]]
function AccessoryManager.WeldAccessory(character: Model, accessoryModel: Model): boolean
	if not character or not accessoryModel then
		warn("[AccessoryManager] Invalid character or accessory model")
		return false
	end

	-- Clone the accessory
	local accessory = accessoryModel:Clone()

	-- Find the weld in the accessory
	local weld = findAccessoryWeld(accessory)
	if not weld then
		warn("[AccessoryManager] No Motor6D weld found in accessory:", accessoryModel.Name)
		accessory:Destroy()
		return false
	end

	-- Get weld configuration from attributes
	local parentPartName = weld:GetAttribute("Par")
	local part0Name = weld:GetAttribute("Part0")
	local part1Name = weld:GetAttribute("Part1")

	if not parentPartName then
		warn("[AccessoryManager] No 'Par' attribute on weld for accessory:", accessoryModel.Name)
		accessory:Destroy()
		return false
	end

	-- Find the parent part in character
	local parentPart = character:FindFirstChild(parentPartName)
	if not parentPart then
		warn("[AccessoryManager] Parent part not found in character:", parentPartName)
		accessory:Destroy()
		return false
	end

	-- Parent the accessory to the character part
	accessory.Parent = parentPart

	-- Configure the Motor6D
	if part0Name then
		local part0 = character:FindFirstChild(part0Name)
		if part0 then
			weld.Part0 = part0
		else
			warn("[AccessoryManager] Part0 not found in character:", part0Name)
		end
	end

	if part1Name then
		-- Part1 is usually the accessory's main part itself
		if part1Name == "Self" or part1Name == "self" then
			-- Special case: weld to the accessory's main part
			local mainPart = getAccessoryMainPart(accessory)
			if mainPart then
				weld.Part1 = mainPart
			end
		else
			-- Look for Part1 in the accessory first, then in character
			local part1 = accessory:FindFirstChild(part1Name) or character:FindFirstChild(part1Name)
			if part1 then
				weld.Part1 = part1
			else
				warn("[AccessoryManager] Part1 not found:", part1Name)
			end
		end
	else
		-- Default: weld to the accessory's main part
		local mainPart = getAccessoryMainPart(accessory)
		if mainPart then
			weld.Part1 = mainPart
		end
	end

	-- Mark the accessory as equipped
	accessory:SetAttribute("AccessoryEquipped", true)
	accessory:SetAttribute("AccessoryName", accessoryModel.Name)

	print("[AccessoryManager] Successfully welded accessory:", accessoryModel.Name, "to", character.Name)
	return true
end

--[[
	Welds an accessory from ServerStorage to a character.

	@param character Model - The character to weld the accessory to
	@param accessoryPath string - Path to accessory in ServerStorage.Assets.Models.Accessories
	@return boolean - Whether the welding was successful
]]
function AccessoryManager.WeldAccessoryFromStorage(character: Model, accessoryName: string): boolean
	if not RunService:IsServer() then
		warn("[AccessoryManager] WeldAccessoryFromStorage can only be called on server")
		return false
	end

	local accessoriesFolder = ServerStorage:FindFirstChild("Assets")
	if accessoriesFolder then
		accessoriesFolder = accessoriesFolder:FindFirstChild("Models")
		if accessoriesFolder then
			accessoriesFolder = accessoriesFolder:FindFirstChild("Accessories")
		end
	end

	if not accessoriesFolder then
		warn("[AccessoryManager] Accessories folder not found in ServerStorage.Assets.Models.Accessories")
		return false
	end

	local accessoryModel = accessoriesFolder:FindFirstChild(accessoryName)
	if not accessoryModel then
		warn("[AccessoryManager] Accessory not found:", accessoryName)
		return false
	end

	return AccessoryManager.WeldAccessory(character, accessoryModel)
end

--[[
	Removes an accessory from a character by name.

	@param character Model - The character to remove the accessory from
	@param accessoryName string - The name of the accessory to remove
	@return boolean - Whether the removal was successful
]]
function AccessoryManager.RemoveAccessory(character: Model, accessoryName: string): boolean
	if not character then
		return false
	end

	-- Search for the accessory in all character parts
	for _, part in character:GetDescendants() do
		if part:GetAttribute("AccessoryEquipped") and part:GetAttribute("AccessoryName") == accessoryName then
			part:Destroy()
			print("[AccessoryManager] Removed accessory:", accessoryName, "from", character.Name)
			return true
		end
	end

	-- Also check by direct name
	for _, part in character:GetDescendants() do
		if part.Name == accessoryName and part:GetAttribute("AccessoryEquipped") then
			part:Destroy()
			print("[AccessoryManager] Removed accessory:", accessoryName, "from", character.Name)
			return true
		end
	end

	return false
end

--[[
	Removes all accessories from a character.

	@param character Model - The character to remove accessories from
	@return number - Number of accessories removed
]]
function AccessoryManager.RemoveAllAccessories(character: Model): number
	if not character then
		return 0
	end

	local count = 0
	local toRemove = {}

	for _, part in character:GetDescendants() do
		if part:GetAttribute("AccessoryEquipped") then
			table.insert(toRemove, part)
		end
	end

	for _, part in toRemove do
		part:Destroy()
		count += 1
	end

	if count > 0 then
		print("[AccessoryManager] Removed", count, "accessories from", character.Name)
	end

	return count
end

--[[
	Gets a list of all equipped accessories on a character.

	@param character Model - The character to check
	@return {string} - Array of accessory names
]]
function AccessoryManager.GetEquippedAccessories(character: Model): {string}
	if not character then
		return {}
	end

	local accessories = {}
	for _, part in character:GetDescendants() do
		if part:GetAttribute("AccessoryEquipped") then
			local name = part:GetAttribute("AccessoryName") or part.Name
			table.insert(accessories, name)
		end
	end

	return accessories
end

--[[
	Checks if a character has a specific accessory equipped.

	@param character Model - The character to check
	@param accessoryName string - The name of the accessory to check for
	@return boolean - Whether the accessory is equipped
]]
function AccessoryManager.HasAccessory(character: Model, accessoryName: string): boolean
	if not character then
		return false
	end

	for _, part in character:GetDescendants() do
		if part:GetAttribute("AccessoryEquipped") then
			local name = part:GetAttribute("AccessoryName") or part.Name
			if name == accessoryName then
				return true
			end
		end
	end

	return false
end

return AccessoryManager
