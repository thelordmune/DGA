--[[
	Jail System Module

	Handles the client-side jail experience:
	- Shows countdown timer when jailed
	- Disables all abilities/moves while in jail
	- Handles release when timer expires
]]

local JailSystem = {}
local CSystem = require(script.Parent)

local TweenService = CSystem.Service.TweenService
local RunService = CSystem.Service.RunService
local Players = CSystem.Service.Players
local ReplicatedStorage = CSystem.Service.ReplicatedStorage

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Bridges = require(ReplicatedStorage.Modules.Bridges)

-- State
local isJailed = false
local jailEndTime = 0
local jailUI = nil

-- Create jail UI
local function createJailUI()
	if jailUI then
		jailUI:Destroy()
	end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "JailUI"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.DisplayOrder = 200
	screenGui.Parent = playerGui

	local overlay = Instance.new("Frame")
	overlay.Name = "Overlay"
	overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	overlay.BackgroundTransparency = 0.7
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BorderSizePixel = 0
	overlay.Parent = screenGui

	local container = Instance.new("Frame")
	container.Name = "Container"
	container.BackgroundTransparency = 1
	container.AnchorPoint = Vector2.new(0.5, 0.5)
	container.Position = UDim2.fromScale(0.5, 0.5)
	container.Size = UDim2.fromOffset(400, 200)
	container.Parent = screenGui

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0, 50)
	title.Position = UDim2.fromOffset(0, 0)
	title.Text = "IMPRISONED"
	title.TextColor3 = Color3.fromRGB(255, 50, 50)
	title.TextSize = 48
	title.Font = Enum.Font.Antique
	title.TextStrokeTransparency = 0
	title.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	title.Parent = container

	local timer = Instance.new("TextLabel")
	timer.Name = "Timer"
	timer.BackgroundTransparency = 1
	timer.Size = UDim2.new(1, 0, 0, 60)
	timer.Position = UDim2.fromOffset(0, 60)
	timer.Text = "0:00"
	timer.TextColor3 = Color3.fromRGB(255, 255, 255)
	timer.TextSize = 72
	timer.Font = Enum.Font.Code
	timer.TextStrokeTransparency = 0
	timer.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	timer.Parent = container

	local reason = Instance.new("TextLabel")
	reason.Name = "Reason"
	reason.BackgroundTransparency = 1
	reason.Size = UDim2.new(1, 0, 0, 30)
	reason.Position = UDim2.fromOffset(0, 140)
	reason.Text = "You have been arrested for your crimes."
	reason.TextColor3 = Color3.fromRGB(200, 200, 200)
	reason.TextSize = 18
	reason.Font = Enum.Font.Gotham
	reason.TextWrapped = true
	reason.Parent = container

	jailUI = screenGui
	return {
		screenGui = screenGui,
		timer = timer,
		reason = reason,
	}
end

local function formatTime(seconds: number): string
	local mins = math.floor(seconds / 60)
	local secs = math.floor(seconds % 60)
	return string.format("%d:%02d", mins, secs)
end

local function disableAbilities()
	_G.PlayerJailed = true
	local character = player.Character
	if character then
		character:SetAttribute("CanAttack", false)
		character:SetAttribute("CanDash", false)
		character:SetAttribute("CanUseAbility", false)
		character:SetAttribute("Jailed", true)
	end
end

local function enableAbilities()
	_G.PlayerJailed = false
	local character = player.Character
	if character then
		character:SetAttribute("CanAttack", true)
		character:SetAttribute("CanDash", true)
		character:SetAttribute("CanUseAbility", true)
		character:SetAttribute("Jailed", false)
	end
end

local function endJail()
	if not isJailed then return end
	isJailed = false

	if jailUI then
		local overlay = jailUI:FindFirstChild("Overlay")
		if overlay then
			local fadeOut = TweenService:Create(overlay, TweenInfo.new(1), {
				BackgroundTransparency = 1
			})
			fadeOut:Play()
			fadeOut.Completed:Wait()
		end
		jailUI:Destroy()
		jailUI = nil
	end

	enableAbilities()

	local releaseGui = Instance.new("ScreenGui")
	releaseGui.Name = "ReleaseMessage"
	releaseGui.ResetOnSpawn = false
	releaseGui.Parent = playerGui

	local message = Instance.new("TextLabel")
	message.BackgroundTransparency = 1
	message.Size = UDim2.fromScale(1, 0.2)
	message.Position = UDim2.fromScale(0, 0.4)
	message.Text = "You have been released."
	message.TextColor3 = Color3.fromRGB(100, 255, 100)
	message.TextSize = 36
	message.Font = Enum.Font.Antique
	message.TextStrokeTransparency = 0
	message.Parent = releaseGui

	task.delay(2, function()
		local fade = TweenService:Create(message, TweenInfo.new(1), {
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		})
		fade:Play()
		fade.Completed:Wait()
		releaseGui:Destroy()
	end)
end

local function startJail(duration: number, reasonText: string?)
	if isJailed then return end
	isJailed = true

	jailEndTime = os.clock() + duration

	local ui = createJailUI()
	if reasonText then
		ui.reason.Text = reasonText
	end

	disableAbilities()

	local connection
	connection = RunService.Heartbeat:Connect(function()
		local remaining = jailEndTime - os.clock()

		if remaining <= 0 then
			connection:Disconnect()
			endJail()
		else
			ui.timer.Text = formatTime(remaining)
		end
	end)
end

-- Initialize
task.spawn(function()
	Bridges.JailPlayer:Connect(function(data)
		if data.duration and data.duration > 0 then
			startJail(data.duration, data.reason)
		end
	end)

	player.CharacterAdded:Connect(function()
		if isJailed then
			disableAbilities()
		end
	end)
end)

return JailSystem
