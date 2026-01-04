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

-- Escape state
local isEscaping = false
local escapeUI = nil
local alarmSound = nil
local strobeConnection = nil
local zoneConnection = nil
local escapeStartZone = nil
local escapeEndTime = 0
local escapePointLight = nil

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
	title.Font = Enum.Font.Sarpanch
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
		-- Note: "Jailed" attribute is set by the server and replicates to client
	end
end

local function enableAbilities()
	_G.PlayerJailed = false
	local character = player.Character
	if character then
		character:SetAttribute("CanAttack", true)
		character:SetAttribute("CanDash", true)
		character:SetAttribute("CanUseAbility", true)
		-- Note: "Jailed" attribute is cleared by the server
	end
end

local function endJail(skipReleaseMessage: boolean?)
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

	-- Skip release message if escaped (to prevent overlap with escape success message)
	if skipReleaseMessage then return end

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
	message.Font = Enum.Font.Sarpanch
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

-- ============================================
-- ESCAPE SYSTEM
-- ============================================

-- Create escape UI with red strobe and alarm
local function createEscapeUI()
	if escapeUI then
		escapeUI:Destroy()
	end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "EscapeUI"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.DisplayOrder = 250 -- Above jail UI
	screenGui.Parent = playerGui

	-- Escape message container
	local messageContainer = Instance.new("Frame")
	messageContainer.Name = "MessageContainer"
	messageContainer.BackgroundTransparency = 1
	messageContainer.AnchorPoint = Vector2.new(0.5, 0)
	messageContainer.Position = UDim2.fromScale(0.5, 0.1)
	messageContainer.Size = UDim2.fromOffset(800, 100)
	messageContainer.ZIndex = 10
	messageContainer.Parent = screenGui

	-- Escape message text
	local escapeMessage = Instance.new("TextLabel")
	escapeMessage.Name = "EscapeMessage"
	escapeMessage.BackgroundTransparency = 1
	escapeMessage.Size = UDim2.fromScale(1, 1)
	escapeMessage.Text = "A PRISONER HAS ESCAPED"
	escapeMessage.TextColor3 = Color3.fromRGB(255, 50, 50)
	escapeMessage.TextSize = 56
	escapeMessage.Font = Enum.Font.Sarpanch
	escapeMessage.TextStrokeTransparency = 0
	escapeMessage.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	escapeMessage.TextWrapped = true
	escapeMessage.Parent = messageContainer

	-- Quest objective text
	local questText = Instance.new("TextLabel")
	questText.Name = "QuestText"
	questText.BackgroundTransparency = 1
	questText.AnchorPoint = Vector2.new(0.5, 0)
	questText.Position = UDim2.new(0.5, 0, 0, 70)
	questText.Size = UDim2.fromOffset(600, 40)
	questText.Text = "ESCAPE - Leave Central Command HQ"
	questText.TextColor3 = Color3.fromRGB(255, 200, 100)
	questText.TextSize = 28
	questText.Font = Enum.Font.GothamBold
	questText.TextStrokeTransparency = 0.3
	questText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	questText.Parent = messageContainer

	-- Timer display
	local timerText = Instance.new("TextLabel")
	timerText.Name = "TimerText"
	timerText.BackgroundTransparency = 1
	timerText.AnchorPoint = Vector2.new(0.5, 0)
	timerText.Position = UDim2.new(0.5, 0, 0, 110)
	timerText.Size = UDim2.fromOffset(200, 50)
	timerText.Text = "1:00"
	timerText.TextColor3 = Color3.fromRGB(255, 100, 100)
	timerText.TextSize = 48
	timerText.Font = Enum.Font.Code
	timerText.TextStrokeTransparency = 0
	timerText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	timerText.Parent = messageContainer

	escapeUI = screenGui

	return {
		screenGui = screenGui,
		escapeMessage = escapeMessage,
		questText = questText,
		timerText = timerText,
	}
end

-- Start the escape sequence (red strobe + alarm)
local function startEscapeEffects(timeLimit: number?, _originalJailTime: number?)
	if isEscaping then return end
	isEscaping = true

	-- Store escape parameters for UI display
	local escapeTimeLimit = timeLimit or 60
	escapeEndTime = os.clock() + escapeTimeLimit

	-- Disable all music during escape
	_G.JailEscapeActive = true

	-- Hide the normal jail UI timer (but keep overlay for effect)
	if jailUI then
		local container = jailUI:FindFirstChild("Container")
		if container then
			container.Visible = false
		end
	end

	-- Create escape UI
	local ui = createEscapeUI()

	-- Start alarm sound (fade in, looped)
	local SFX = ReplicatedStorage:FindFirstChild("Assets")
	if SFX then
		SFX = SFX:FindFirstChild("SFX")
		if SFX then
			local MISC = SFX:FindFirstChild("MISC")
			if MISC then
				local jailAlarmTemplate = MISC:FindFirstChild("JailAlarm")
				if jailAlarmTemplate then
					alarmSound = jailAlarmTemplate:Clone()
					alarmSound.Parent = playerGui
					alarmSound.Volume = 0
					alarmSound.Looped = true
					alarmSound:Play()

					-- Fade in alarm over 2 seconds
					local fadeIn = TweenService:Create(alarmSound, TweenInfo.new(2), {
						Volume = 0.8
					})
					fadeIn:Play()
				end
			end
		end
	end

	-- Monitor zone changes for escape detection
	escapeStartZone = workspace:GetAttribute("CurrentZone") or "Central Command HQ"
	zoneConnection = workspace:GetAttributeChangedSignal("CurrentZone"):Connect(function()
		local newZone = workspace:GetAttribute("CurrentZone")
		if newZone and newZone ~= escapeStartZone and newZone ~= "" then
			-- Player escaped! Notify server
			Bridges.JailEscape:Fire({
				action = "player_escaped",
				fromZone = escapeStartZone,
				toZone = newZone,
			})
			-- Stop escape effects (will be confirmed by server response)
		end
	end)

	-- Create red point light on player character
	local character = player.Character
	if character then
		local hrp = character:FindFirstChild("HumanoidRootPart")
		if hrp then
			-- Remove any existing escape light
			local existingLight = hrp:FindFirstChild("EscapeLight")
			if existingLight then
				existingLight:Destroy()
			end

			-- Create pulsing red point light
			escapePointLight = Instance.new("PointLight")
			escapePointLight.Name = "EscapeLight"
			escapePointLight.Color = Color3.fromRGB(255, 50, 50)
			escapePointLight.Brightness = 3
			escapePointLight.Range = 20
			escapePointLight.Shadows = true
			escapePointLight.Parent = hrp
		end
	end

	-- Start escape timer and point light pulse
	local pulseSpeed = 0.5 -- Seconds per pulse cycle
	strobeConnection = RunService.Heartbeat:Connect(function()
		if not escapeUI or not escapeUI.Parent then
			if strobeConnection then
				strobeConnection:Disconnect()
				strobeConnection = nil
			end
			return
		end

		-- Pulse the point light
		if escapePointLight and escapePointLight.Parent then
			local time = os.clock()
			local pulse = (math.sin(time * (math.pi * 2 / pulseSpeed)) + 1) / 2
			escapePointLight.Brightness = 2 + (pulse * 3) -- Range: 2 to 5
			escapePointLight.Range = 15 + (pulse * 10) -- Range: 15 to 25
		end

		-- Update escape timer
		local messageContainer = escapeUI:FindFirstChild("MessageContainer")
		if messageContainer then
			local timerText = messageContainer:FindFirstChild("TimerText")
			if timerText then
				local remaining = math.max(0, escapeEndTime - os.clock())
				local mins = math.floor(remaining / 60)
				local secs = math.floor(remaining % 60)
				timerText.Text = string.format("%d:%02d", mins, secs)

				-- Change color when time is running low
				if remaining <= 10 then
					timerText.TextColor3 = Color3.fromRGB(255, 50, 50)
				elseif remaining <= 30 then
					timerText.TextColor3 = Color3.fromRGB(255, 150, 50)
				else
					timerText.TextColor3 = Color3.fromRGB(255, 100, 100)
				end
			end
		end
	end)

	-- Animate escape message (pulsing)
	task.spawn(function()
		while isEscaping and escapeUI and escapeUI.Parent do
			local messageContainer = escapeUI:FindFirstChild("MessageContainer")
			if messageContainer then
				local escapeMessage = messageContainer:FindFirstChild("EscapeMessage")
				if escapeMessage then
					-- Pulse the text
					local pulseOut = TweenService:Create(escapeMessage, TweenInfo.new(0.5), {
						TextTransparency = 0.3,
					})
					pulseOut:Play()
					pulseOut.Completed:Wait()

					if not isEscaping then break end

					local pulseIn = TweenService:Create(escapeMessage, TweenInfo.new(0.5), {
						TextTransparency = 0,
					})
					pulseIn:Play()
					pulseIn.Completed:Wait()
				end
			end
			task.wait(0.1)
		end
	end)
end

-- Stop escape effects (called when player escapes or is recaptured)
local function stopEscapeEffects(escaped: boolean)
	isEscaping = false

	-- Re-enable music after escape ends
	_G.JailEscapeActive = false

	-- Stop zone monitoring
	if zoneConnection then
		zoneConnection:Disconnect()
		zoneConnection = nil
	end
	escapeStartZone = nil

	-- Stop strobe/pulse connection
	if strobeConnection then
		strobeConnection:Disconnect()
		strobeConnection = nil
	end

	-- Remove point light
	if escapePointLight and escapePointLight.Parent then
		escapePointLight:Destroy()
		escapePointLight = nil
	end

	-- Fade out and stop alarm
	if alarmSound then
		local fadeOut = TweenService:Create(alarmSound, TweenInfo.new(1), {
			Volume = 0
		})
		fadeOut:Play()
		fadeOut.Completed:Connect(function()
			alarmSound:Stop()
			alarmSound:Destroy()
			alarmSound = nil
		end)
	end

	-- Fade out escape UI
	if escapeUI then
		task.delay(1.5, function()
			if escapeUI then
				escapeUI:Destroy()
				escapeUI = nil
			end
		end)
	end

	-- Show escape success message if escaped
	if escaped then
		-- End jail status (skip release message to prevent overlap)
		endJail(true)

		local successGui = Instance.new("ScreenGui")
		successGui.Name = "EscapeSuccess"
		successGui.ResetOnSpawn = false
		successGui.Parent = playerGui

		local message = Instance.new("TextLabel")
		message.BackgroundTransparency = 1
		message.Size = UDim2.fromScale(1, 0.2)
		message.Position = UDim2.fromScale(0, 0.4)
		message.Text = "YOU HAVE ESCAPED!"
		message.TextColor3 = Color3.fromRGB(100, 255, 100)
		message.TextSize = 48
		message.Font = Enum.Font.Sarpanch
		message.TextStrokeTransparency = 0
		message.Parent = successGui

		task.delay(3, function()
			local fade = TweenService:Create(message, TweenInfo.new(1), {
				TextTransparency = 1,
				TextStrokeTransparency = 1,
			})
			fade:Play()
			fade.Completed:Wait()
			successGui:Destroy()
		end)
	end
end

-- Handle broadcast message (shown to all players)
local function showBroadcastMessage(escapingPlayerName: string)
	local broadcastGui = Instance.new("ScreenGui")
	broadcastGui.Name = "EscapeBroadcast"
	broadcastGui.ResetOnSpawn = false
	broadcastGui.DisplayOrder = 300
	broadcastGui.Parent = playerGui

	local message = Instance.new("TextLabel")
	message.BackgroundTransparency = 1
	message.Size = UDim2.fromScale(1, 0.15)
	message.Position = UDim2.fromScale(0, 0.05)
	message.Text = "ALERT: A PRISONER HAS ESCAPED"
	message.TextColor3 = Color3.fromRGB(255, 100, 100)
	message.TextSize = 36
	message.Font = Enum.Font.Sarpanch
	message.TextStrokeTransparency = 0
	message.TextStrokeColor3 = Color3.fromRGB(50, 0, 0)
	message.Parent = broadcastGui

	-- Flash effect
	task.spawn(function()
		for i = 1, 3 do
			message.TextTransparency = 0.5
			task.wait(0.2)
			message.TextTransparency = 0
			task.wait(0.2)
		end
	end)

	task.delay(5, function()
		local fade = TweenService:Create(message, TweenInfo.new(1), {
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		})
		fade:Play()
		fade.Completed:Wait()
		broadcastGui:Destroy()
	end)
end

-- Initialize
task.spawn(function()
	Bridges.JailPlayer:Connect(function(data)
		if data.duration and data.duration > 0 then
			startJail(data.duration, data.reason)
		end
	end)

	-- Listen for jail escape events
	Bridges.JailEscape:Connect(function(data)
		if data.action == "start" then
			-- Player is escaping - start effects with time limit
			startEscapeEffects(data.timeLimit, data.originalJailTime)
		elseif data.action == "escaped" then
			-- Player successfully escaped
			stopEscapeEffects(true)
		elseif data.action == "broadcast" then
			-- Another player is escaping - show broadcast
			if data.escapingPlayer ~= player.Name then
				showBroadcastMessage(data.escapingPlayer)
			end
		elseif data.action == "failed" then
			-- Escape failed - time ran out
			stopEscapeEffects(false)
			-- Show failure message
			local failGui = Instance.new("ScreenGui")
			failGui.Name = "EscapeFailed"
			failGui.ResetOnSpawn = false
			failGui.Parent = playerGui

			local message = Instance.new("TextLabel")
			message.BackgroundTransparency = 1
			message.Size = UDim2.fromScale(1, 0.2)
			message.Position = UDim2.fromScale(0, 0.4)
			message.Text = "ESCAPE FAILED!\nYour sentence has been extended."
			message.TextColor3 = Color3.fromRGB(255, 50, 50)
			message.TextSize = 42
			message.Font = Enum.Font.Sarpanch
			message.TextStrokeTransparency = 0
			message.Parent = failGui

			task.delay(4, function()
				local fade = TweenService:Create(message, TweenInfo.new(1), {
					TextTransparency = 1,
					TextStrokeTransparency = 1,
				})
				fade:Play()
				fade.Completed:Wait()
				failGui:Destroy()
			end)
		elseif data.action == "recaptured" then
			-- Player was caught
			stopEscapeEffects(false)
		end
	end)

	player.CharacterAdded:Connect(function()
		if isJailed then
			disableAbilities()
		end
	end)
end)

return JailSystem
