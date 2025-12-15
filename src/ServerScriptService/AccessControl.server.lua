--!strict
-- Main Game Access Control
-- Prevents players from joining the main game directly (must come from main menu)
-- Exception: Studio testing is always allowed

local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local MAIN_MENU_PLACE_ID = 134137392851607
local MAIN_GAME_PLACE_ID = 138824307106116 -- 138824307106116

-- Check if we're in Studio
local isStudio = RunService:IsStudio()

--print("[AccessControl] Initialized")
--print("[AccessControl] Studio mode:", isStudio)
--print("[AccessControl] Main Menu Place ID:", MAIN_MENU_PLACE_ID)
--print("[AccessControl] Main Game Place ID:", MAIN_GAME_PLACE_ID)

-- Track players who are being teleported (to avoid double-teleport)
local teleportingPlayers = {}

local function redirectToMainMenu(player: Player, reason: string)
	if teleportingPlayers[player.UserId] then
		-- Already being teleported, don't do it again
		return
	end
	
	teleportingPlayers[player.UserId] = true
	
	warn(`[AccessControl] Redirecting {player.Name} to main menu: {reason}`)
	
	-- Create a message GUI to show the player why they're being redirected
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "RedirectGui"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	frame.BackgroundTransparency = 0
	frame.Parent = screenGui
	
	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.fromScale(0.8, 0.2)
	textLabel.Position = UDim2.fromScale(0.1, 0.4)
	textLabel.BackgroundTransparency = 1
	textLabel.Text = "Please join from the Main Menu"
	textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	textLabel.TextScaled = true
	textLabel.Font = Enum.Font.GothamBold
	textLabel.Parent = frame
	
	local subText = Instance.new("TextLabel")
	subText.Size = UDim2.fromScale(0.8, 0.1)
	subText.Position = UDim2.fromScale(0.1, 0.6)
	subText.BackgroundTransparency = 1
	subText.Text = "Redirecting..."
	subText.TextColor3 = Color3.fromRGB(200, 200, 200)
	subText.TextScaled = true
	subText.Font = Enum.Font.Gotham
	subText.Parent = frame
	
	screenGui.Parent = player:WaitForChild("PlayerGui")
	
	-- Wait a moment for the GUI to show
	task.wait(1)
	
	-- Teleport to main menu
	local teleportOptions = Instance.new("TeleportOptions")
	teleportOptions.ShouldReserveServer = false
	
	local success, errorMessage = pcall(function()
		TeleportService:TeleportAsync(MAIN_MENU_PLACE_ID, {player}, teleportOptions)
	end)
	
	if not success then
		warn(`[AccessControl] Failed to redirect {player.Name} to main menu:`, errorMessage)
		-- Kick as fallback
		player:Kick("Please join from the Main Menu place.")
	end
end

local function checkPlayerAccess(player: Player)
	-- Always allow in Studio
	if isStudio then
		--print(`[AccessControl] {player.Name} allowed (Studio mode)`)
		return true
	end
	
	-- Get teleport data to check where they came from
	local joinData = player:GetJoinData()
	local teleportData = joinData.TeleportData
	
	-- Check if player was teleported
	if joinData.SourcePlaceId then
		--print(`[AccessControl] {player.Name} joined from place:`, joinData.SourcePlaceId)
		
		-- Allow if they came from the main menu
		if joinData.SourcePlaceId == MAIN_MENU_PLACE_ID then
			--print(`[AccessControl] {player.Name} allowed (came from main menu)`)
			return true
		end
		
		-- Allow if they came from the same game (server hop, etc.)
		if joinData.SourcePlaceId == MAIN_GAME_PLACE_ID then
			--print(`[AccessControl] {player.Name} allowed (came from same place)`)
			return true
		end
	end
	
	-- If we get here, they either:
	-- 1. Joined directly (no SourcePlaceId)
	-- 2. Came from a different place
	--print(`[AccessControl] {player.Name} denied (direct join or invalid source)`)
	return false
end

-- Check each player as they join
Players.PlayerAdded:Connect(function(player)
	--print(`[AccessControl] Player joining: {player.Name}`)
	
	-- Small delay to ensure join data is available
	task.wait(0.1)
	
	local hasAccess = checkPlayerAccess(player)
	
	if not hasAccess then
		redirectToMainMenu(player, "Direct join not allowed")
	end
end)

-- Check existing players (in case script loads after players join)
for _, player in Players:GetPlayers() do
	task.spawn(function()
		local hasAccess = checkPlayerAccess(player)
		if not hasAccess then
			redirectToMainMenu(player, "Direct join not allowed")
		end
	end)
end

--print("[AccessControl] Ready")

