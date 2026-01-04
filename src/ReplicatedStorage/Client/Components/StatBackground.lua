local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContentProvider = game:GetService("ContentProvider")
local Fusion = require(ReplicatedStorage.Modules.Fusion)

local Children, Computed, Tween =
	Fusion.Children, Fusion.Computed, Fusion.Tween

-- Static background image (frame 75 - middle of the sequence for a nice look)
local STATIC_BACKGROUND_IMAGE = "rbxassetid://115076572240596" -- Frame 75

-- Preload the background image
local preloadComplete = false
task.spawn(function()
	local img = Instance.new("ImageLabel")
	img.Image = STATIC_BACKGROUND_IMAGE
	ContentProvider:PreloadAsync({img})
	img:Destroy()
	preloadComplete = true
end)

local TInfoFade = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

return function(scope, props: {})
	local parent = props.Parent
	local isVisible = props.isVisible -- Optional: reactive value to control visibility/fade

	return scope:New "Frame" {
		Name = "Background",
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = -5,
		Parent = parent,

		[Children] = {
			-- Static background image
			scope:New "ImageLabel" {
				Name = "MainImage",
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				Image = STATIC_BACKGROUND_IMAGE,
				ImageTransparency = if isVisible then scope:Tween(
					scope:Computed(function(use)
						return if use(isVisible) then 0 else 1
					end),
					TInfoFade
				) else 0,
			},
		}
	}
end
