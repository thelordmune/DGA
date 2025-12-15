--[[
	Leaderboard Manager
	
	Handles the custom leaderboard UI that shows all players in the game.
	Displays player names, titles, and factions.
	Toggles with Period (.) key.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Player = Players.LocalPlayer
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local Fusion = require(ReplicatedStorage.Modules.Fusion)
local Global = require(ReplicatedStorage.Modules.Shared.Global)

local Children, scoped, peek, Value, Computed, Observer = 
	Fusion.Children, Fusion.scoped, Fusion.peek, Fusion.Value, Fusion.Computed, Fusion.Observer

local LeaderboardManager = {}
LeaderboardManager.__index = LeaderboardManager

-- Singleton instance
local instance = nil

function LeaderboardManager.new()
	if instance then
		return instance
	end
	
	local self = setmetatable({}, LeaderboardManager)
	
	-- Fusion scope for managing UI lifecycle
	self.scope = scoped(Fusion, {
		PlayerComponent = require(ReplicatedStorage.Client.Components.Player),
		LeaderboardComponent = require(ReplicatedStorage.Client.Components.Leaderboard)
	})
	
	-- State
	self.isVisible = self.scope:Value(true)
	self.playerData = self.scope:Value({}) -- Array of player data tables
	self.playerComponents = {} -- Track created player UI components
	
	-- UI References
	self.leaderboardGui = nil
	self.playerListContainer = nil
	
	instance = self
	return self
end

function LeaderboardManager:Initialize()
	---- print("[Leaderboard] Initializing...")

	-- Disable default Roblox player list
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
		---- print("[Leaderboard] Disabled default player list")
	end)

	-- Clean up old UI if it exists (for respawns)
	if self.leaderboardGui and self.leaderboardGui.Parent then
		self.leaderboardGui:Destroy()
		self.leaderboardGui = nil
	end

	-- Create the leaderboard UI
	self:CreateUI()

	-- Set up player tracking (only once)
	if not self.playerTrackingSetup then
		self:SetupPlayerTracking()
		self.playerTrackingSetup = true
	end

	-- Set up keybind (only once)
	if not self.keybindSetup then
		self:SetupKeybind()
		self.keybindSetup = true
	end

	---- print("[Leaderboard] Initialized successfully")
end

function LeaderboardManager:CreateUI()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	
	-- Create ScreenGui for leaderboard
	self.leaderboardGui = self.scope:New "ScreenGui" {
		Name = "LeaderboardGui",
		Parent = playerGui,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 10,
		IgnoreGuiInset = true,
	}
	
	-- Create the leaderboard using the component
	local leaderboardFrame = self.scope:LeaderboardComponent({
		started = self.isVisible,
		Parent = self.leaderboardGui,
	})
	
	-- Find the player list container (ScrollingFrame)
	task.wait(0.1) -- Wait for UI to be created
	self.playerListContainer = self.leaderboardGui:WaitForChild("ScrollingFrame", 5).Folder
	if self.playerListContainer then
		---- print("[Leaderboard] Found player list container")
		-- Remove the placeholder IGN frame
		local placeholder = self.playerListContainer:FindFirstChild("IGN")
		if placeholder then
			placeholder:Destroy()
		end
	else
		warn("[Leaderboard] Could not find ScrollingFrame container")
	end
end

function LeaderboardManager:SetupPlayerTracking()
	-- Track all current players (with delay to wait for DisplayName)
	for _, player in ipairs(Players:GetPlayers()) do
		self:AddPlayer(player)
	end

	-- Listen for new players
	Players.PlayerAdded:Connect(function(player)
		self:AddPlayer(player)
	end)

	-- Listen for players leaving
	Players.PlayerRemoving:Connect(function(player)
		self:RemovePlayer(player)
	end)

	-- Update player data periodically (to catch DisplayName updates and prevent bugs)
	task.spawn(function()
		while true do
			task.wait(1) -- Update every 1 second to prevent leaderboard bugs
			self:UpdateAllPlayers()
		end
	end)
end

function LeaderboardManager:AddPlayer(player)
	---- print("[Leaderboard] Adding player:", player.Name)

	-- Wait for character to load and DisplayName to be set
	task.delay(5, function()
		-- Check if player is still in the game
		if not player:IsDescendantOf(Players) then
			---- print("[Leaderboard] Player left before being added:", player.Name)
			return
		end

		-- Get player data after delay
		local playerData = self:GetPlayerData(player)

		-- Add to player data array
		local currentData = peek(self.playerData)
		table.insert(currentData, playerData)
		self.playerData:set(currentData)

		-- Create player UI component
		self:CreatePlayerComponent(playerData)

		---- print("[Leaderboard] Added player after delay:", playerData.IGN)
	end)
end

function LeaderboardManager:RemovePlayer(player)
	---- print("[Leaderboard] Removing player:", player.Name)

	-- Remove from player data array
	local currentData = peek(self.playerData)
	for i, data in ipairs(currentData) do
		if data.Player == player then
			table.remove(currentData, i)
			break
		end
	end
	self.playerData:set(currentData)

	-- Remove player UI component
	local component = self.playerComponents[player.UserId]
	if component then
		-- Destroy the Frame
		if component.Frame and component.Frame:IsA("Instance") then
			component.Frame:Destroy()
		end

		-- Clean up Fusion values
		if component.IGN and component.IGN.set then
			component.IGN = nil
		end
		if component.Title and component.Title.set then
			component.Title = nil
		end
		if component.Faction and component.Faction.set then
			component.Faction = nil
		end

		self.playerComponents[player.UserId] = nil
		---- print("[Leaderboard] Removed UI for player:", player.Name)
	end
end

function LeaderboardManager:GetPlayerData(player)
	-- Get player's character and humanoid
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")

	-- Extract first and last name from Humanoid.DisplayName
	-- Format: "- Title -\nFirst Last"
	local ign = player.Name -- Fallback to username

	if humanoid and humanoid.DisplayName then
		local displayName = humanoid.DisplayName
		-- Split by newline to get the name part (second line)
		local lines = string.split(displayName, "\n")
		if #lines >= 2 then
			ign = lines[2] -- Second line contains "First Last"
		elseif #lines == 1 then
			-- If no newline, just use the whole display name
			ign = displayName
		end
	end

	-- For local player, we can get data from Global module
	local data = nil
	if player == Players.LocalPlayer then
		data = Global.GetData(player)
	end

	-- Extract title and faction from DisplayName or data
	local title = "Civilian"
	local faction = "None"

	if humanoid and humanoid.DisplayName then
		local displayName = humanoid.DisplayName
		-- Extract title from first line: "- Title -"
		local titleMatch = string.match(displayName, "^%- (.+) %-")
		if titleMatch then
			title = titleMatch
		end
	end

	-- If we have data (local player), use it for faction
	if data then
		faction = data.Clan or "None"
	end

	local level = (data and data.Level) or 1

	return {
		Player = player,
		IGN = ign,
		Title = title,
		Faction = faction,
		Level = level,
	}
end

function LeaderboardManager:CreatePlayerComponent(playerData)
	if not self.playerListContainer then
		warn("[Leaderboard] Player list container not found")
		return
	end
	
	-- Create Fusion Values for reactive data
	local ignValue = self.scope:Value(playerData.IGN)
	local titleValue = self.scope:Value(playerData.Title)
	local factionValue = self.scope:Value(playerData.Faction)
	
	-- Create the player component
	local playerFrame = self.scope:PlayerComponent({
		IGN = ignValue,
		Title = titleValue,
		Faction = factionValue,
	})
	
	-- Parent to container
	playerFrame.Parent = self.playerListContainer
	
	-- Store reference with reactive values
	self.playerComponents[playerData.Player.UserId] = {
		Frame = playerFrame,
		IGN = ignValue,
		Title = titleValue,
		Faction = factionValue,
	}
	
	---- print("[Leaderboard] Created UI for player:", playerData.IGN)
end

function LeaderboardManager:UpdateAllPlayers()
	-- Update data for all players
	for _, player in ipairs(Players:GetPlayers()) do
		self:UpdatePlayer(player)
	end
end

function LeaderboardManager:UpdatePlayer(player)
	local component = self.playerComponents[player.UserId]
	if not component then
		return
	end
	
	-- Get fresh player data
	local playerData = self:GetPlayerData(player)
	
	-- Update reactive values
	component.IGN:set(playerData.IGN)
	component.Title:set(playerData.Title)
	component.Faction:set(playerData.Faction)
end

function LeaderboardManager:SetupKeybind()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		
		if input.KeyCode == Enum.KeyCode.Period then
			self:Toggle()
		end
	end)
end

function LeaderboardManager:Toggle()
	local newState = not peek(self.isVisible)
	self.isVisible:set(newState)
	---- print("[Leaderboard] Toggled:", newState and "Visible" or "Hidden")
end

function LeaderboardManager:Show()
	self.isVisible:set(true)
end

function LeaderboardManager:Hide()
	self.isVisible:set(false)
end

function LeaderboardManager:Destroy()
	if self.scope then
		self.scope:doCleanup()
	end
	if self.leaderboardGui then
		self.leaderboardGui:Destroy()
	end
	instance = nil
end

return LeaderboardManager

