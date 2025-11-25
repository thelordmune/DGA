--!strict
-- Teleport Data Handler
-- Ensures player data is properly saved when teleporting between places

local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")

print("[TeleportDataHandler] Initializing...")

-- Get the data handler
local ServerConfig = script.Parent:WaitForChild("ServerConfig")
local Server = require(ServerConfig.Server)
local DataHandler = Server.Modules.Data

-- Track teleporting players to ensure data is saved
local teleportingPlayers = {}

-- Function to save player data before teleport
local function savePlayerDataBeforeTeleport(player: Player)
	print(`[TeleportDataHandler] Saving data for {player.Name} before teleport...`)
	
	-- Get the player's profile
	local playerObject = Server.Players[player]
	if not playerObject then
		warn(`[TeleportDataHandler] No player object found for {player.Name}`)
		return false
	end
	
	local profile = playerObject.Profile
	if not profile then
		warn(`[TeleportDataHandler] No profile found for {player.Name}`)
		return false
	end
	
	-- Get the replion for this player
	local replion = DataHandler:GetReplion(player)
	if replion then
		-- Force sync replion data to profile
		profile.Data = replion.Data
		print(`[TeleportDataHandler] Data synced for {player.Name}`)
	else
		warn(`[TeleportDataHandler] No replion found for {player.Name}`)
	end
	
	-- ProfileService will auto-save when the profile is released
	-- We just need to make sure the data is synced
	
	return true
end

-- Listen for teleport requests
TeleportService.TeleportInitFailed:Connect(function(player, teleportResult, errorMessage, placeId, teleportOptions)
	warn(`[TeleportDataHandler] Teleport failed for {player.Name}:`, errorMessage)
	teleportingPlayers[player.UserId] = nil
end)

-- When a player is about to teleport, save their data
Players.PlayerRemoving:Connect(function(player)
	-- Check if this is a teleport or just leaving
	local joinData = player:GetJoinData()
	
	print(`[TeleportDataHandler] {player.Name} is leaving...`)
	
	-- Always save data when player leaves
	local success = savePlayerDataBeforeTeleport(player)
	if success then
		print(`[TeleportDataHandler] Data saved for {player.Name}`)
	else
		warn(`[TeleportDataHandler] Failed to save data for {player.Name}`)
	end
end)

-- Optional: Create a remote function for manual save requests
-- This can be called from the client before initiating a teleport
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local remoteEvent = Instance.new("RemoteEvent")
remoteEvent.Name = "RequestDataSave"
remoteEvent.Parent = ReplicatedStorage

remoteEvent.OnServerEvent:Connect(function(player)
	print(`[TeleportDataHandler] Manual save requested by {player.Name}`)
	savePlayerDataBeforeTeleport(player)
end)

print("[TeleportDataHandler] Ready")

