--[[
	Death Screen Module

	Handles death visual effects:
	- Ragdolls player on death (before respawn)
	- Shows black screen with killer name, FMA-themed tip, and image
	- Fades elements out before transitioning to white
	- Fades back to normal when respawned
]]

local DeathScreen = {}
local CSystem = require(script.Parent)
local ClientConfig = require(script.Parent.ClientConfig)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = CSystem.Service.TweenService
local Players = CSystem.Service.Players
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Fusion = require(ReplicatedStorage.Modules.Fusion)
local scoped = Fusion.scoped

-- Configuration
local RAGDOLL_DURATION = ClientConfig.DeathScreen.RAGDOLL_DURATION
local FADE_TO_BLACK_TIME = ClientConfig.DeathScreen.FADE_TO_BLACK_TIME
local HOLD_BLACK_TIME = ClientConfig.DeathScreen.HOLD_BLACK_TIME
local CONTENT_FADE_OUT_TIME = ClientConfig.DeathScreen.CONTENT_FADE_OUT_TIME
local FADE_TO_WHITE_TIME = ClientConfig.DeathScreen.FADE_TO_WHITE_TIME
local HOLD_WHITE_TIME = ClientConfig.DeathScreen.HOLD_WHITE_TIME
local FADE_FROM_WHITE_TIME = ClientConfig.DeathScreen.FADE_FROM_WHITE_TIME
local IMAGE_ROTATION_SPEED = ClientConfig.DeathScreen.IMAGE_ROTATION_SPEED

-- Base colors
local TITLE_BASE_COLOR = Color3.fromRGB(200, 50, 50) -- Red
local TIP_BASE_COLOR = Color3.fromRGB(180, 180, 180) -- Gray

-- Death image asset
local DEATH_IMAGE_ID = ClientConfig.DeathScreen.DEATH_IMAGE_ID

-- FMA-themed death tips
local DEATH_TIPS = {
	"The truth within truth is the path to understanding.",
	"Equivalent Exchange: To obtain, something of equal value must be lost.",
	"A lesson without pain is meaningless.",
	"Endure and survive. That's what alchemy teaches us.",
	"Even when our eyes are closed, there's a whole world out there.",
	"Stand up and walk. Keep moving forward.",
	"Humankind cannot gain anything without first giving something in return.",
	"The world isn't perfect, but it's there for us.",
	"A heart made fullmetal cannot be broken easily.",
	"Water: 35 liters. Carbon: 20 kg. Ammonia: 4 liters. Lime: 1.5 kg. Phosphorus: 800 g...",
	"One is all, all is one.",
	"There's no such thing as a painless lesson.",
	"The power of one man doesn't amount to much.",
	"Even your faults are part of who you are.",
	"Laws exist to be bent, but principles should never break.",
	"A dog of the military must follow orders.",
	"An alchemist must be willing to sacrifice.",
	"Pride comes before the fall.",
	"The Gate demands its toll.",
	"Nothing's perfect. The world's not perfect. But it's there for us, trying the best it can.",
}

-- UI Elements
local screenGui = nil
local deathOverlay = nil
local currentDeathConnection = nil
local currentScope = nil

-- Get a random FMA tip
local function getRandomTip()
	return DEATH_TIPS[math.random(1, #DEATH_TIPS)]
end

-- Get the name of the last attacker
local function getLastAttackerName(character)
	if not character then return nil end

	local damageLog = character:FindFirstChild("Damage_Log")
	if not damageLog then return nil end

	-- Get the most recent attack record
	local records = damageLog:GetChildren()
	if #records == 0 then return nil end

	-- Sort by name (which contains timestamp)
	table.sort(records, function(a, b)
		return a.Name > b.Name
	end)

	local latestRecord = records[1]
	if latestRecord and latestRecord:IsA("ObjectValue") and latestRecord.Value then
		local attackerModel = latestRecord.Value
		if attackerModel and attackerModel:IsA("Model") then
			-- Check if it's an NPC with a display name
			local displayName = attackerModel:GetAttribute("DisplayName")
			if displayName then
				return displayName
			end
			return attackerModel.Name
		end
	end

	return nil
end

-- Create and animate death content
local function createDeathContent(parent, killerName, tip)
	local scope = scoped(Fusion)
	local Children = Fusion.Children

	-- Flash state for UIGradient animation
	local titleFlash = scope:Value(false)
	local tipFlash = scope:Value(false)

	-- Create the title text
	local titleText = killerName and ("Killed by " .. killerName) or "You Died"

	-- Main container
	local container = scope:New "Frame" {
		Name = "DeathContent",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromScale(0, 0),
		Parent = parent,

		[Children] = {
			-- "You Died" or "Killed by [Name]" text
			scope:New "TextLabel" {
				Name = "TitleLabel",
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.32),
				Size = UDim2.fromOffset(500, 50),
				Text = titleText,
				TextColor3 = TITLE_BASE_COLOR,
				TextSize = 36,
				FontFace = Font.new("rbxasset://fonts/families/Sarpanch.json", Enum.FontWeight.Bold),
				TextTransparency = scope:Value(1), -- Start invisible, will fade in

				[Children] = {
					-- UIGradient for flash effect (like HotbarButton)
					scope:New "UIGradient" {
						Name = "FlashGradient",
						Rotation = 0,
						Color = scope:Spring(
							scope:Computed(function(use)
								if use(titleFlash) then
									-- Flash: silver/white highlight sweeping across
									return ColorSequence.new({
										ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
										ColorSequenceKeypoint.new(0.5, Color3.fromRGB(220, 220, 255)),
										ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
									})
								else
									-- Base: red tint
									return ColorSequence.new({
										ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
										ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
									})
								end
							end),
							30, -- Speed
							0.8 -- Damping
						),
					},
				},
			},

			-- Death image in the center
			scope:New "ImageLabel" {
				Name = "DeathImage",
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(50, 50), -- Start small
				Image = DEATH_IMAGE_ID,
				ImageTransparency = scope:Value(1), -- Start invisible
				ImageColor3 = Color3.fromRGB(200, 50, 50), -- Reddish tint
				Rotation = scope:Value(0),
			},

			-- Tip text
			scope:New "TextLabel" {
				Name = "TipLabel",
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.72),
				Size = UDim2.fromOffset(600, 60),
				Text = '"' .. tip .. '"',
				TextColor3 = TIP_BASE_COLOR,
				TextSize = 18,
				FontFace = Font.new("rbxasset://fonts/families/Sarpanch.json", Enum.FontWeight.Regular),
				TextWrapped = true,
				TextTransparency = scope:Value(1), -- Start invisible, will fade in

				[Children] = {
					-- UIGradient for flash effect
					scope:New "UIGradient" {
						Name = "FlashGradient",
						Rotation = 0,
						Color = scope:Spring(
							scope:Computed(function(use)
								if use(tipFlash) then
									-- Flash: silver/white highlight
									return ColorSequence.new({
										ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
										ColorSequenceKeypoint.new(0.5, Color3.fromRGB(220, 220, 255)),
										ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
									})
								else
									-- Base: normal
									return ColorSequence.new({
										ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
										ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
									})
								end
							end),
							30,
							0.8
						),
					},
				},
			},
		},
	}

	-- Get references to created elements
	local titleLabel = container:FindFirstChild("TitleLabel")
	local deathImage = container:FindFirstChild("DeathImage")
	local tipLabel = container:FindFirstChild("TipLabel")

	-- Image rotation connection
	local imageRotationConnection = RunService.RenderStepped:Connect(function(deltaTime)
		if deathImage and deathImage.Parent and deathImage.ImageTransparency < 1 then
			deathImage.Rotation = deathImage.Rotation + (IMAGE_ROTATION_SPEED * deltaTime)
		end
	end)

	-- Flash loop connection (toggles flash on/off repeatedly)
	local flashConnection = nil
	local flashEnabled = false

	local function startFlashLoop()
		if flashConnection then return end
		flashEnabled = true

		flashConnection = task.spawn(function()
			while flashEnabled do
				-- Flash on
				titleFlash:set(true)
				tipFlash:set(true)
				task.wait(0.15)
				-- Flash off
				titleFlash:set(false)
				tipFlash:set(false)
				task.wait(0.35)
			end
		end)
	end

	local function stopFlashLoop()
		flashEnabled = false
		titleFlash:set(false)
		tipFlash:set(false)
	end

	-- Animate in
	task.spawn(function()
		-- Fade in title
		local titleTween = TweenService:Create(titleLabel, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			TextTransparency = 0
		})
		titleTween:Play()

		-- Fade in death image with scale
		task.delay(0.2, function()
			local imageTween = TweenService:Create(deathImage, TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Size = UDim2.fromOffset(200, 200),
				ImageTransparency = 0.1,
			})
			imageTween:Play()
		end)

		-- Fade in tip
		task.delay(0.4, function()
			local tipTween = TweenService:Create(tipLabel, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				TextTransparency = 0
			})
			tipTween:Play()
			tipTween.Completed:Wait()

			-- Start flash loop after text is fully visible
			startFlashLoop()
		end)
	end)

	return scope, container, titleLabel, tipLabel, deathImage, imageRotationConnection, stopFlashLoop
end

-- Fade out death content before white transition
local function fadeOutDeathContent(container, titleLabel, tipLabel, deathImage, rotationConnection, stopFlashLoop)
	-- Stop flash loop first
	if stopFlashLoop then
		stopFlashLoop()
	end

	local tweenInfo = TweenInfo.new(CONTENT_FADE_OUT_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

	-- Fade out title text
	if titleLabel then
		TweenService:Create(titleLabel, tweenInfo, { TextTransparency = 1 }):Play()
	end

	-- Fade out tip text
	if tipLabel then
		TweenService:Create(tipLabel, tweenInfo, { TextTransparency = 1 }):Play()
	end

	-- Fade out death image with shrink
	if deathImage then
		TweenService:Create(deathImage, tweenInfo, {
			ImageTransparency = 1,
			Size = UDim2.fromOffset(50, 50),
		}):Play()
	end

	task.wait(CONTENT_FADE_OUT_TIME)

	-- Stop the rotation after fade out
	if rotationConnection then
		rotationConnection:Disconnect()
	end
end

-- Create death screen UI
local function createUI()
	if screenGui then return end

	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "DeathScreen"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.DisplayOrder = 1000
	screenGui.Enabled = false
	screenGui.Parent = playerGui

	deathOverlay = Instance.new("Frame")
	deathOverlay.Name = "Overlay"
	deathOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	deathOverlay.BackgroundTransparency = 1
	deathOverlay.Size = UDim2.fromScale(1, 1)
	deathOverlay.BorderSizePixel = 0
	deathOverlay.Parent = screenGui
end

-- Ragdoll the character (client-side visual)
local function ragdollCharacter(character: Model)
	if not character then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	humanoid.PlatformStand = true
	humanoid.AutoRotate = false

	if humanoid.RigType == Enum.HumanoidRigType.R15 then
		humanoid.HipHeight = 0
	end

	local hrp = character:FindFirstChild("HumanoidRootPart")
	if hrp then
		hrp.AssemblyLinearVelocity = Vector3.new(0, -10, 0)
	end
end

-- Play death sequence
local function playDeathSequence(character: Model)
	if not screenGui then createUI() end
	screenGui.Enabled = true

	-- Get killer name before ragdolling (Damage_Log may be cleaned up)
	local killerName = getLastAttackerName(character)
	local tip = getRandomTip()

	ragdollCharacter(character)
	task.wait(RAGDOLL_DURATION * 0.5)

	deathOverlay.BackgroundTransparency = 1
	deathOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)

	-- Fade to black
	local fadeToBlack = TweenService:Create(deathOverlay, TweenInfo.new(FADE_TO_BLACK_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		BackgroundTransparency = 0
	})
	fadeToBlack:Play()
	fadeToBlack.Completed:Wait()

	-- Create death content (killer name, image, tip)
	local scope, container, titleLabel, tipLabel, deathImage, rotationConnection, stopFlashLoop = createDeathContent(deathOverlay, killerName, tip)
	currentScope = scope

	-- Hold black screen with death info
	task.wait(HOLD_BLACK_TIME)

	-- Fade out the death content before transitioning to white
	fadeOutDeathContent(container, titleLabel, tipLabel, deathImage, rotationConnection, stopFlashLoop)

	-- Clean up content
	if container then
		container:Destroy()
	end
	if currentScope then
		currentScope:doCleanup()
		currentScope = nil
	end

	-- Fade to white
	local fadeToWhite = TweenService:Create(deathOverlay, TweenInfo.new(FADE_TO_WHITE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	})
	fadeToWhite:Play()
	fadeToWhite.Completed:Wait()

	task.wait(HOLD_WHITE_TIME)
end

-- Play respawn sequence
local function playRespawnSequence()
	if not screenGui or not screenGui.Enabled then return end

	deathOverlay.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	deathOverlay.BackgroundTransparency = 0

	task.wait(0.7)

	local fadeFromWhite = TweenService:Create(deathOverlay, TweenInfo.new(FADE_FROM_WHITE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 1
	})
	fadeFromWhite:Play()
	fadeFromWhite.Completed:Wait()

	screenGui.Enabled = false
end

-- Setup character death handling
local function setupCharacter(character: Model)
	if currentDeathConnection then
		currentDeathConnection:Disconnect()
		currentDeathConnection = nil
	end

	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid then return end

	currentDeathConnection = humanoid.Died:Connect(function()
		playDeathSequence(character)
	end)
end

-- Initialize
task.spawn(function()
	createUI()

	player.CharacterAdded:Connect(function(character)
		playRespawnSequence()
		setupCharacter(character)
	end)

	if player.Character then
		setupCharacter(player.Character)
	end
end)

return DeathScreen
