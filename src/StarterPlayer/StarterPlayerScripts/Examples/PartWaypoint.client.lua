--[[
	Part Waypoint Script
	
	Place this script inside any part in the workspace to automatically
	create a waypoint marker on it when the player spawns.
	
	Configuration:
	- Set attributes on the part to customize the waypoint:
		- WaypointLabel (string): Custom label text
		- WaypointColor (Color3): Marker color
		- WaypointHeight (number): Height offset above part
		- WaypointDistance (number): Max visibility distance
	
	Example:
	1. Create a part in workspace
	2. Place this script inside the part
	3. Set part attributes (optional):
		- WaypointLabel = "Treasure Location"
		- WaypointHeight = 10
		- WaypointDistance = 1000
	4. The waypoint will appear when you spawn
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local script = script
local part = script.Parent

-- Validate that this script is inside a part
if not part:IsA("BasePart") and not part:IsA("Model") then
	warn("[PartWaypoint] This script must be placed inside a BasePart or Model!")
	return
end

-- Wait for character to load
if not player.Character then
	player.CharacterAdded:Wait()
end
task.wait(2) -- Wait for QuestMarkers system to initialize

-- Get the QuestMarkers module
local QuestMarkers = require(ReplicatedStorage.Client.QuestMarkers)

-- Read configuration from part attributes
local label = part:GetAttribute("WaypointLabel") or part.Name
local color = part:GetAttribute("WaypointColor") or Color3.fromRGB(255, 255, 255)
local heightOffset = part:GetAttribute("WaypointHeight") or 5
local maxDistance = part:GetAttribute("WaypointDistance") or 500

-- Create the waypoint
local markerKey = QuestMarkers.CreateWaypoint(part, label, {
	color = color,
	heightOffset = heightOffset,
	maxDistance = maxDistance,
})

if markerKey then
	print(`[PartWaypoint] ✅ Created waypoint for {part.Name}: {markerKey}`)
else
	warn(`[PartWaypoint] ❌ Failed to create waypoint for {part.Name}`)
end

-- Clean up when part is destroyed
part.Destroying:Connect(function()
	if markerKey then
		QuestMarkers.RemoveWaypoint(markerKey)
		print(`[PartWaypoint] 🗑️ Removed waypoint for {part.Name}`)
	end
end)

