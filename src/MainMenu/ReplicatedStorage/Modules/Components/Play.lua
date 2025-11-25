local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage.Modules.Fusion)
local Players = game:GetService("Players")
local plr = Players.LocalPlayer
local RichText = require(ReplicatedStorage.Modules.RichText)

local Children, scoped, peek, out, OnEvent, OnChange = Fusion.Children, Fusion.scoped, Fusion.peek, Fusion.Out, Fusion.OnEvent, Fusion.OnChange

local TInfo = TweenInfo.new(.2, Enum.EasingStyle.Circular, Enum.EasingDirection.Out, 0)
local TInfo2 = TweenInfo.new(1.1, Enum.EasingStyle.Circular, Enum.EasingDirection.Out, 0)

return function(scope: any, props: {})
	local parent = props.Parent
	local started = props.Started
	local clicked = props.Clicked
	local dialogue = props.Dialogue

	local isHovering = scope:Value(false)


	local text = scope:New "TextLabel" {
		Parent = parent,
		Name = "TextLabel",
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		FontFace = Font.new(
			"rbxasset://fonts/families/SourceSansPro.json",
			Enum.FontWeight.Bold,
			Enum.FontStyle.Normal
		),
		Position = UDim2.fromOffset(446, 199),
		-- FIXED: Changed from UDim2.fromScale(5.045, 0.5) which was 5x the parent width!
		Size = UDim2.fromOffset(800, 200), -- Reasonable fixed size
		AutomaticSize = Enum.AutomaticSize.XY, -- Let it grow with content
		Text = "",
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextSize = 14,
		TextWrapped = true, -- Enable text wrapping
		TextXAlignment = Enum.TextXAlignment.Left, -- Align text to left
		TextYAlignment = Enum.TextYAlignment.Top, -- Align text to top
	}

	scope:Computed(function(use)
		return if use(clicked :: boolean) then RichText.AnimateText(peek(dialogue), text, 0.05, Enum.Font.SourceSans, "fade diverge", 1, 14) else RichText.ClearText(text) and ""
	end)

	return scope:New "TextButton" {
		Parent = parent,
		Name = "Play",
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		FontFace = Font.new(
			"rbxasset://fonts/families/Nunito.json",
			Enum.FontWeight.Bold,
			Enum.FontStyle.Normal
		),
		Position = scope:Spring(
			scope:Computed(function(use)
				return if use(started) then UDim2.fromScale(0.021, 0.591) else UDim2.fromScale(0.021, -0.591)
			end),
			10,
			.8
		),
		Size = scope:Tween(
			scope:Computed(function(use)
				return if use(isHovering) then UDim2.fromOffset(250, 60) else UDim2.fromOffset(200, 50)
			end),
			TInfo
		),
		Text = "PLAY",
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextScaled = true,
		TextSize = 14,
		TextWrapped = true,
		ZIndex = 0,
		[OnEvent "Activated"] = function(_, numclicks)
			started:set(false)
			script.Click:Play()
		end,

		[OnEvent "MouseEnter"] = function()
			isHovering:set(true)
			script.Hover:Play()
		end,

		[OnEvent "MouseLeave"] = function()
			isHovering:set(false)
		end,

		[Children] = {
			text
		}

	}
end

