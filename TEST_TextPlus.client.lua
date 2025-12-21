--[[
	Quick test to verify TextPlus is working
	
	Place this in StarterPlayer > StarterPlayerScripts to test
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TextPlus = require(ReplicatedStorage.Modules.Utils.Text)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Wait a bit for game to load
task.wait(3)

---- print("[TextPlus Test] Creating test UI...")

-- Create test UI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "TextPlusTest"
screenGui.Parent = playerGui

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(400, 200)
frame.Position = UDim2.fromScale(0.5, 0.5)
frame.AnchorPoint = Vector2.new(0.5, 0.5)
frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
frame.Parent = screenGui

local textFrame = Instance.new("Frame")
textFrame.Size = UDim2.fromScale(0.9, 0.9)
textFrame.Position = UDim2.fromScale(0.05, 0.05)
textFrame.BackgroundTransparency = 1
textFrame.Parent = frame

---- print("[TextPlus Test] Rendering text...")

-- Render text with TextPlus
local success, err = pcall(function()
	TextPlus.Create(textFrame, "Hello from TextPlus! This is a test.", {
		Font = Font.new("rbxasset://fonts/families/Sarpanch.json"),
		Size = 24,
		Color = Color3.fromRGB(255, 255, 255),
		XAlignment = "Center",
		YAlignment = "Center",
	})
end)

if success then
	---- print("[TextPlus Test] ✅ Text rendered successfully!")
	---- print("[TextPlus Test] Children in textFrame:", #textFrame:GetChildren())
	
	-- List all children
	for i, child in textFrame:GetChildren() do
		---- print("[TextPlus Test] Child", i, ":", child.Name, child.ClassName)
	end
else
	warn("[TextPlus Test] ❌ Failed to render text:", err)
end

-- Close after 10 seconds
task.wait(10)
screenGui:Destroy()
---- print("[TextPlus Test] Test complete, UI destroyed")

