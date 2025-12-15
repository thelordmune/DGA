--[[
	Hitbox Debug Toggle (F2 Key)
	
	Toggles hitbox visualization for all moves.
	When enabled, all hitboxes will be shown as red transparent parts.
]]

local InputModule = {}
InputModule.__index = InputModule
local self = setmetatable({}, InputModule)

local Replicated = game:GetService("ReplicatedStorage")
local DebugFlags = require(Replicated.Modules.DebugFlags)

-- UI notification function
local function showNotification(message: string, color: Color3)
	local Players = game:GetService("Players")
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	
	-- Create notification
	local notification = Instance.new("ScreenGui")
	notification.Name = "HitboxDebugNotification"
	notification.ResetOnSpawn = false
	notification.Parent = playerGui
	
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(0, 300, 0, 50)
	frame.Position = UDim2.new(0.5, -150, 0.1, 0)
	frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	frame.BorderSizePixel = 0
	frame.Parent = notification
	
	local uiCorner = Instance.new("UICorner")
	uiCorner.CornerRadius = UDim.new(0, 8)
	uiCorner.Parent = frame
	
	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.new(1, 0, 1, 0)
	textLabel.BackgroundTransparency = 1
	textLabel.Text = message
	textLabel.TextColor3 = color
	textLabel.TextSize = 18
	textLabel.Font = Enum.Font.GothamBold
	textLabel.Parent = frame
	
	-- Fade out and destroy
	task.delay(2, function()
		notification:Destroy()
	end)
end

InputModule.InputBegan = function(_, Client)
	-- Toggle hitbox visualization
	DebugFlags.VisualizeHitboxes = not DebugFlags.VisualizeHitboxes

	-- Send to server
	Client.Packets.HitboxDebug.send({
		Enabled = DebugFlags.VisualizeHitboxes
	})

	if DebugFlags.VisualizeHitboxes then
		showNotification("🔴 Hitbox Visualization: ENABLED", Color3.fromRGB(255, 100, 100))
		print("[Hitbox Debug] Hitbox visualization ENABLED")
	else
		showNotification("⚫ Hitbox Visualization: DISABLED", Color3.fromRGB(150, 150, 150))
		print("[Hitbox Debug] Hitbox visualization DISABLED")
	end
end

InputModule.InputEnded = function(_, Client)
	-- Nothing to do on release
end

InputModule.InputChanged = function()
	-- Nothing to do on change
end

return InputModule

