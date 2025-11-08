--[[
	Waypoint Marker Example
	
	This script demonstrates how to use the QuestMarkers system to create
	custom waypoint markers on parts in the workspace.
	
	Usage:
	1. Place this script in StarterPlayerScripts or StarterCharacterScripts
	2. Modify the examples below to point to your parts
	3. The markers will automatically appear when you spawn
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local player = Players.LocalPlayer

-- Wait for character to load
if not player.Character then
	player.CharacterAdded:Wait()
end
task.wait(2) -- Wait for QuestMarkers system to initialize

-- Get the QuestMarkers module
local QuestMarkers = require(ReplicatedStorage.Client.QuestMarkers)

-- Example 1: Create a waypoint on a specific part
local function example1()
	-- Find a part in the workspace (replace with your part's path)
	local targetPart = workspace:FindFirstChild("WaypointPart")
	
	if targetPart then
		-- Create a basic waypoint with default settings
		local markerKey = QuestMarkers.CreateWaypoint(targetPart, "Destination")
		print("Created waypoint:", markerKey)
	end
end

-- Example 2: Create a waypoint with custom configuration
local function example2()
	local targetPart = workspace:FindFirstChild("CustomWaypoint")
	
	if targetPart then
		-- Create a waypoint with custom color, icon, and settings
		local markerKey = QuestMarkers.CreateWaypoint(targetPart, "Custom Marker", {
			color = Color3.fromRGB(255, 100, 255), -- Purple
			icon = "rbxassetid://18621831828", -- Star icon
			heightOffset = 10, -- 10 studs above the part
			maxDistance = 1000, -- Visible up to 1000 studs away
		})
		print("Created custom waypoint:", markerKey)
	end
end

-- Example 3: Create a waypoint and remove it after 10 seconds
local function example3()
	local targetPart = workspace:FindFirstChild("TemporaryWaypoint")
	
	if targetPart then
		local markerKey = QuestMarkers.CreateWaypoint(targetPart, "Temporary Marker")
		print("Created temporary waypoint:", markerKey)
		
		-- Remove after 10 seconds
		task.delay(10, function()
			QuestMarkers.RemoveWaypoint(markerKey)
			print("Removed temporary waypoint")
		end)
	end
end

-- Example 4: Create waypoints on multiple parts
local function example4()
	-- Find all parts in a folder
	local waypointsFolder = workspace:FindFirstChild("Waypoints")
	
	if waypointsFolder then
		for _, part in waypointsFolder:GetChildren() do
			if part:IsA("BasePart") then
				QuestMarkers.CreateWaypoint(part, part.Name, {
					color = Color3.fromRGB(100, 200, 255), -- Light blue
					heightOffset = 5,
					maxDistance = 500,
				})
			end
		end
		print("Created waypoints for all parts in Waypoints folder")
	end
end

-- Example 5: Remove a waypoint by passing the part directly
local function example5()
	local targetPart = workspace:FindFirstChild("RemovableWaypoint")
	
	if targetPart then
		-- Create waypoint
		QuestMarkers.CreateWaypoint(targetPart, "Removable")
		
		-- Remove it after 5 seconds by passing the part
		task.delay(5, function()
			QuestMarkers.RemoveWaypoint(targetPart)
			print("Removed waypoint using part reference")
		end)
	end
end

-- Uncomment the examples you want to test:
-- example1()
-- example2()
-- example3()
-- example4()
-- example5()

