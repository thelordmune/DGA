--[[
	TextPlus Module Demonstration
	
	This demonstrates how to use the TextPlus module from ReplicatedStorage.Modules.Utils.Text
	
	TextPlus is an advanced text rendering library that provides:
	- Custom fonts support
	- Advanced text styling (stroke, shadow, rotation)
	- Precise character spacing control
	- Dynamic text scaling
	- Better performance than default Roblox text
	
	Documentation: https://alexxander.gitbook.io/TextPlus
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextPlus = require(ReplicatedStorage.Modules.Utils.Text)

-- Example 1: Basic Text Rendering
local function basicExample(parentFrame)
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromOffset(400, 100)
	frame.Position = UDim2.fromOffset(50, 50)
	frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	frame.Parent = parentFrame
	
	-- Create simple text
	TextPlus.Create(frame, "Hello, World!", {
		Size = 24,
		Color = Color3.fromRGB(255, 255, 255),
		XAlignment = "Center",
		YAlignment = "Center"
	})
	
	return frame
end

-- Example 2: Styled Text with Stroke and Shadow
local function styledExample(parentFrame)
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromOffset(400, 100)
	frame.Position = UDim2.fromOffset(50, 170)
	frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	frame.Parent = parentFrame
	
	-- Create text with stroke and shadow
	TextPlus.Create(frame, "Styled Text!", {
		Size = 32,
		Color = Color3.fromRGB(255, 200, 50),
		
		-- Stroke (outline)
		StrokeSize = 3,
		StrokeColor = Color3.fromRGB(0, 0, 0),
		StrokeTransparency = 0,
		
		-- Shadow
		ShadowOffset = Vector2.new(2, 2),
		ShadowColor = Color3.fromRGB(0, 0, 0),
		ShadowTransparency = 0.5,
		
		XAlignment = "Center",
		YAlignment = "Center"
	})
	
	return frame
end

-- Example 3: Custom Character Spacing (Fixes the spacing issue!)
local function spacingExample(parentFrame)
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromOffset(400, 100)
	frame.Position = UDim2.fromOffset(50, 290)
	frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	frame.Parent = parentFrame
	
	-- Create text with custom character spacing
	TextPlus.Create(frame, "Perfect Spacing!", {
		Size = 28,
		Color = Color3.fromRGB(100, 200, 255),
		
		-- Control character spacing (1 = normal, <1 = tighter, >1 = wider)
		CharacterSpacing = 1.0,
		
		-- Control line height
		LineHeight = 1.2,
		
		XAlignment = "Center",
		YAlignment = "Center"
	})
	
	return frame
end

-- Example 4: Multi-line Text with Alignment
local function multilineExample(parentFrame)
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromOffset(400, 150)
	frame.Position = UDim2.fromOffset(50, 410)
	frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	frame.Parent = parentFrame
	
	local longText = "This is a longer text that will wrap across multiple lines. TextPlus handles this beautifully!"
	
	TextPlus.Create(frame, longText, {
		Size = 18,
		Color = Color3.fromRGB(255, 255, 255),
		
		-- Line spacing
		LineHeight = 1.5,
		CharacterSpacing = 1.0,
		
		-- Alignment
		XAlignment = "Left",
		YAlignment = "Top"
	})
	
	return frame
end

-- Example 5: Dynamic Text (Updates when frame resizes)
local function dynamicExample(parentFrame)
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromOffset(400, 100)
	frame.Position = UDim2.fromOffset(50, 580)
	frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	frame.Parent = parentFrame
	
	-- Dynamic text automatically re-renders when frame size changes
	TextPlus.Create(frame, "Dynamic Text!", {
		Size = 24,
		Color = Color3.fromRGB(150, 255, 150),
		Dynamic = true, -- Enable dynamic resizing
		XAlignment = "Center",
		YAlignment = "Center"
	})
	
	-- Animate the frame size to demonstrate dynamic text
	task.spawn(function()
		while frame.Parent do
			frame.Size = UDim2.fromOffset(400, 100)
			task.wait(2)
			frame.Size = UDim2.fromOffset(300, 80)
			task.wait(2)
		end
	end)
	
	return frame
end

-- Example 6: Updating Text
local function updatingExample(parentFrame)
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromOffset(400, 100)
	frame.Position = UDim2.fromOffset(500, 50)
	frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	frame.Parent = parentFrame
	
	-- Create initial text
	TextPlus.Create(frame, "Click to update!", {
		Size = 20,
		Color = Color3.fromRGB(255, 255, 255),
		XAlignment = "Center",
		YAlignment = "Center"
	})
	
	-- Update text on click
	local button = Instance.new("TextButton")
	button.Size = UDim2.fromScale(1, 1)
	button.BackgroundTransparency = 1
	button.Text = ""
	button.Parent = frame
	
	local counter = 0
	button.Activated:Connect(function()
		counter += 1
		-- Update the text (merges with existing options)
		TextPlus.Create(frame, "Clicked " .. counter .. " times!", {
			Color = Color3.fromHSV(counter / 10 % 1, 1, 1) -- Rainbow color
		})
	end)
	
	return frame
end

-- Example 7: Rotated Text
local function rotatedExample(parentFrame)
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromOffset(400, 100)
	frame.Position = UDim2.fromOffset(500, 170)
	frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	frame.Parent = parentFrame
	
	TextPlus.Create(frame, "Rotated!", {
		Size = 28,
		Color = Color3.fromRGB(255, 100, 255),
		Rotation = 15, -- Rotation in degrees
		XAlignment = "Center",
		YAlignment = "Center"
	})
	
	return frame
end

-- Example 8: Getting Text Information
local function infoExample(parentFrame)
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromOffset(400, 100)
	frame.Position = UDim2.fromOffset(500, 290)
	frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	frame.Parent = parentFrame
	
	TextPlus.Create(frame, "Text Info", {
		Size = 24,
		Color = Color3.fromRGB(255, 255, 255),
		XAlignment = "Center",
		YAlignment = "Center"
	})
	
	-- Get information about the rendered text
	local text = TextPlus.GetText(frame)
	local options = TextPlus.GetOptions(frame)
	local bounds = TextPlus.GetBounds(frame)
	
	---- print("Text:", text)
	---- print("Font Size:", options.Size)
	---- print("Text Bounds:", bounds)
	
	return frame
end

-- Example 9: Clearing Text
local function clearExample(parentFrame)
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromOffset(400, 100)
	frame.Position = UDim2.fromOffset(500, 410)
	frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	frame.Parent = parentFrame
	
	TextPlus.Create(frame, "This will disappear!", {
		Size = 20,
		Color = Color3.fromRGB(255, 100, 100),
		XAlignment = "Center",
		YAlignment = "Center"
	})
	
	-- Clear text after 3 seconds
	task.delay(3, function()
		TextPlus.Clear(frame)
		---- print("Text cleared!")
	end)
	
	return frame
end

-- Main Demo Function
local function runDemo()
	-- Create a ScreenGui for the demo
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "TextPlusDemo"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = game.Players.LocalPlayer:WaitForChild("PlayerGui")
	
	-- Create a scrolling frame to hold all examples
	local scrollFrame = Instance.new("ScrollingFrame")
	scrollFrame.Size = UDim2.fromScale(1, 1)
	scrollFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	scrollFrame.BorderSizePixel = 0
	scrollFrame.CanvasSize = UDim2.fromOffset(1000, 700)
	scrollFrame.Parent = screenGui
	
	-- Run all examples
	basicExample(scrollFrame)
	styledExample(scrollFrame)
	spacingExample(scrollFrame)
	multilineExample(scrollFrame)
	dynamicExample(scrollFrame)
	updatingExample(scrollFrame)
	rotatedExample(scrollFrame)
	infoExample(scrollFrame)
	clearExample(scrollFrame)
	
	---- print("TextPlus Demo loaded! Check your screen.")
end

-- Run the demo
return runDemo

