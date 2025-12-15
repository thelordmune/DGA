local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Fusion = require(ReplicatedStorage.Modules.Fusion)

local Children, scoped, peek, out, OnEvent, Value, Computed, Tween =
	Fusion.Children, Fusion.scoped, Fusion.peek, Fusion.Out, Fusion.OnEvent, Fusion.Value, Fusion.Computed, Fusion.Tween

local TInfo = TweenInfo.new(0.5, Enum.EasingStyle.Circular, Enum.EasingDirection.InOut, 0, true) -- PingPong for automatic back-and-forth

return function(scope, props: {})
	local scope = scoped(Fusion, {})

	local started = props.started
	local parent = props.Parent

	scope:New("ScrollingFrame")({
		Parent = parent,
		Name = "ScrollingFrame",
		Active = true,
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		ScrollBarImageColor3 = Color3.fromRGB(0, 0, 0),
		ScrollBarImageTransparency = 1,
		Size = UDim2.fromOffset(190, 350),
		Position = scope:Spring(
			scope:Computed(function(use)
				return if use(started) then UDim2.fromScale(0.866, 0.0297) else UDim2.fromScale(1.2, -0.03)
			end),
			5,
			0.8
		),
		ScrollBarThickness = 5,

		[Children] = {
			scope:New("ImageLabel")({
				Name = "Background",
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				Image = "rbxassetid://85774200010476",
				ImageTransparency = 0.25,
				Position = UDim2.fromScale(0.0345, 0),
				SelectionOrder = -3,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 0,

				[Children] = {
					scope:New("UICorner")({
						Name = "UICorner",
					}),
				},
			}),
			scope:New("Folder")({
				Name = "Folder",
				[Children] = {
					[Children] = {
						scope:New("UIListLayout")({
							Name = "UIListLayout",
							SortOrder = Enum.SortOrder.LayoutOrder,
						}),
					},
				},
			}),
		},
	})
	scope:New("ImageLabel")({
		Name = "ImageLabel",
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Image = "rbxassetid://80989206568872",
		Position = scope:Spring(
			scope:Computed(function(use)
				return if use(started) then UDim2.fromScale(0.866, 0.0297) else UDim2.fromScale(1.2, -0.03)
			end),
			5,
			0.8
		),
		ScaleType = Enum.ScaleType.Slice,
		Size = UDim2.fromOffset(190, 350),
		SliceCenter = Rect.new(10, 8, 20, 24),
		Parent = parent,
	})

	-- 	scope:New("Frame")({
	-- 		Name = "Frame",
	-- 		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
	-- 		BackgroundTransparency = 1,
	-- 		BorderColor3 = Color3.fromRGB(0, 0, 0),
	-- 		BorderSizePixel = 0,
	-- 		Position = UDim2.fromScale(0.12, 0.016),
	-- 		Size = UDim2.new(0.77, 0, 0, 891),

	-- 		[Children] = {
	-- 			scope:New("Folder")({
	-- 				Name = "Folder",

	-- 				[Children] = {
	-- 					scope:New("UIListLayout")({
	-- 						Name = "UIListLayout",
	-- 						HorizontalAlignment = Enum.HorizontalAlignment.Center,
	-- 						Padding = UDim.new(0, 5),
	-- 						SortOrder = Enum.SortOrder.LayoutOrder,
	-- 					}),

	-- 					-- Player components will be dynamically added here
	-- 				},
	-- 			}),
	-- 		},
	-- 	}),
	-- },
	-- scope:New("ImageLabel")({
	-- 	Parent = parent,
	-- 	Name = "ImageLabel",
	-- 	BackgroundColor3 = Color3.fromRGB(255, 255, 255),
	-- 	BackgroundTransparency = 1,
	-- 	BorderColor3 = Color3.fromRGB(0, 0, 0),
	-- 	BorderSizePixel = 0,
	-- 	Image = "rbxassetid://122523747392433",
	-- 	-- imagecontent = Content.new(Content),
	-- 	Position = scope:Spring(
	-- 		scope:Computed(function(use)
	-- 			return if use(started) then UDim2.fromScale(0.902, -0.03) else UDim2.fromScale(1.2, -0.03)
	-- 		end),
	-- 		5,
	-- 		0.8
	-- 	),
	-- 	ScaleType = Enum.ScaleType.Slice,
	-- 	Size = UDim2.fromOffset(155, 385),
	-- 	SliceCenter = Rect.new(12, 12, 38, 34),
	-- })
end
