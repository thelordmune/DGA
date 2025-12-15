--[[
	UI Toggle (F1 Key)

	Toggles visibility of all UI elements including:
	- HUD/Hotbar
	- Notifications
	- Quest Tracker
	- Leaderboard
	- Inventory
]]

local InputModule = {}
InputModule.__index = InputModule
local self = setmetatable({}, InputModule)

local Players = game:GetService("Players")
local player = Players.LocalPlayer

-- State to track UI visibility
local uiVisible = true
local hiddenGuis = {} -- Track which GUIs we hid

-- Function to toggle all UI elements
local function toggleUI(Client)
	uiVisible = not uiVisible

	local playerGui = player:WaitForChild("PlayerGui")

	if not uiVisible then
		-- Hiding UI - store which ones were enabled before hiding
		hiddenGuis = {}
		for _, gui in pairs(playerGui:GetChildren()) do
			if gui:IsA("ScreenGui") and gui.Enabled then
				table.insert(hiddenGuis, gui)
				gui.Enabled = false
			end
		end
		print("[UI Toggle] UI elements hidden (F1)")
	else
		-- Showing UI - only re-enable the ones we hid
		for _, gui in pairs(hiddenGuis) do
			if gui and gui.Parent then
				gui.Enabled = true
			end
		end
		hiddenGuis = {}
		print("[UI Toggle] UI elements shown (F1)")
	end
end

InputModule.InputBegan = function(_, Client)
	toggleUI(Client)
end

InputModule.InputEnded = function(_, Client)
	-- Nothing to do on release
end

InputModule.InputChanged = function()
	-- Nothing to do on change
end

return InputModule
