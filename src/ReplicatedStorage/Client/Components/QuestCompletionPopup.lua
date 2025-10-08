--[[
	Quest Completion Popup Component
	
	Displays quest completion notification with rewards (XP, alignment, items, level up)
	Similar to zone display popup
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage.Modules.Fusion)
local RichText = require(ReplicatedStorage.Modules.RichText)

local Children, scoped, peek = Fusion.Children, Fusion.scoped, Fusion.peek

local TInfo = TweenInfo.new(1.2, Enum.EasingStyle.Circular, Enum.EasingDirection.InOut, 0)
local TInfo2 = TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0)

return function(scope, props: {})
	local questName: string = props.questName or "Quest"
	local experienceGained: number = props.experienceGained or 0
	local alignmentGained: number = props.alignmentGained or 0
	local leveledUp: boolean = props.leveledUp or false
	local newLevel: number = props.newLevel or 1
	local framein: boolean = props.framein
	local parent = props.Parent

	-- Create text labels
	local questTitle = scope:New("TextLabel")({
		Name = "QuestTitle",
		BackgroundTransparency = 1,
		FontFace = Font.new("rbxassetid://16658237174", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
		Position = UDim2.fromScale(0.5, 0.15),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromScale(0.8, 0.2),
		Text = "QUEST COMPLETED",
		TextColor3 = Color3.fromRGB(255, 215, 0), -- Gold
		TextScaled = true,
		TextTransparency = scope:Tween(
			scope:Computed(function(use)
				return if use(framein) then 0 else 1
			end),
			TInfo
		),
	})

	local questNameLabel = scope:New("TextLabel")({
		Name = "QuestName",
		BackgroundTransparency = 1,
		FontFace = Font.new("rbxassetid://12187373327", Enum.FontWeight.Medium, Enum.FontStyle.Normal),
		Position = UDim2.fromScale(0.5, 0.35),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromScale(0.8, 0.15),
		Text = questName,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextScaled = true,
		TextTransparency = scope:Tween(
			scope:Computed(function(use)
				return if use(framein) then 0 else 1
			end),
			TInfo
		),
	})

	-- Rewards section
	local rewardsContainer = scope:New("Frame")({
		Name = "RewardsContainer",
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.5, 0.6),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromScale(0.9, 0.4),
	})

	local rewardsLayout = scope:New("UIListLayout")({
		FillDirection = Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Top,
		Padding = UDim.new(0, 5),
		Parent = rewardsContainer,
	})

	local children = {}

	-- Experience reward
	if experienceGained > 0 then
		table.insert(children, scope:New("TextLabel")({
			Name = "ExperienceReward",
			BackgroundTransparency = 1,
			FontFace = Font.new("rbxassetid://12187373327"),
			Size = UDim2.fromScale(1, 0.25),
			Text = string.format("+%d XP", experienceGained),
			TextColor3 = Color3.fromRGB(100, 200, 255), -- Light blue
			TextScaled = true,
			TextTransparency = scope:Tween(
				scope:Computed(function(use)
					return if use(framein) then 0 else 1
				end),
				TInfo2
			),
		}))
	end

	-- Alignment reward
	if alignmentGained ~= 0 then
		local alignmentColor = alignmentGained > 0 and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(255, 100, 100)
		local alignmentText = alignmentGained > 0 and string.format("+%d Alignment", alignmentGained) or string.format("%d Alignment", alignmentGained)
		
		table.insert(children, scope:New("TextLabel")({
			Name = "AlignmentReward",
			BackgroundTransparency = 1,
			FontFace = Font.new("rbxassetid://12187373327"),
			Size = UDim2.fromScale(1, 0.25),
			Text = alignmentText,
			TextColor3 = alignmentColor,
			TextScaled = true,
			TextTransparency = scope:Tween(
				scope:Computed(function(use)
					return if use(framein) then 0 else 1
				end),
				TInfo2
			),
		}))
	end

	-- Level up notification
	if leveledUp then
		table.insert(children, scope:New("TextLabel")({
			Name = "LevelUp",
			BackgroundTransparency = 1,
			FontFace = Font.new("rbxassetid://16658237174", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
			Size = UDim2.fromScale(1, 0.3),
			Text = string.format("LEVEL UP! → %d", newLevel),
			TextColor3 = Color3.fromRGB(255, 215, 0), -- Gold
			TextScaled = true,
			TextTransparency = scope:Tween(
				scope:Computed(function(use)
					return if use(framein) then 0 else 1
				end),
				TInfo2
			),
		}))
	end

	rewardsContainer[Children] = children

	-- Main frame
	return scope:New("Frame")({
		Name = "QuestCompletionPopup",
		BackgroundColor3 = Color3.fromRGB(20, 20, 20),
		BackgroundTransparency = scope:Tween(
			scope:Computed(function(use)
				return if use(framein) then 0.3 else 1
			end),
			TInfo
		),
		BorderSizePixel = 0,
		Position = scope:Spring(
			scope:Computed(function(use)
				return if use(framein) then UDim2.fromScale(0.5, 0.15) else UDim2.fromScale(0.5, -0.2)
			end),
			18,
			0.4
		),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(400, 250),
		Parent = parent,

		[Children] = {
			scope:New("UICorner")({
				CornerRadius = UDim.new(0, 12),
			}),
			
			scope:New("UIStroke")({
				Color = Color3.fromRGB(255, 215, 0),
				Thickness = 2,
				Transparency = scope:Tween(
					scope:Computed(function(use)
						return if use(framein) then 0.5 else 1
					end),
					TInfo
				),
			}),

			questTitle,
			questNameLabel,
			rewardsContainer,
		},
	})
end

