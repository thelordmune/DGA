--!strict
-- Main Menu Teleport Service (Server)
-- Handles server-side teleportation from main menu to main game

local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MAIN_GAME_PLACE_ID = 138824307106116

print("[MenuTeleportService] Initializing...")

-- Create remote event for teleport requests
local teleportRemote = Instance.new("RemoteEvent")
teleportRemote.Name = "RequestTeleport"
teleportRemote.Parent = ReplicatedStorage

-- Track players currently being teleported to prevent spam
local teleportingPlayers = {}
local TELEPORT_COOLDOWN = 2 -- seconds

-- Function to teleport player to main game
local function teleportToMainGame(player: Player)
	-- Check if player is already being teleported
	if teleportingPlayers[player.UserId] then
		warn(`[MenuTeleportService] {player.Name} is already being teleported`)
		return false
	end
	
	-- Check if player still exists
	if not player:IsDescendantOf(Players) then
		warn(`[MenuTeleportService] {player.Name} is no longer in the game`)
		return false
	end
	
	print(`[MenuTeleportService] Teleporting {player.Name} to main game...`)
	
	-- Mark player as teleporting
	teleportingPlayers[player.UserId] = true
	
	-- Create teleport options
	local teleportOptions = Instance.new("TeleportOptions")
	teleportOptions.ShouldReserveServer = false
	
	-- Set teleport data (optional - can include custom data)
	-- This data will be available in the main game via player:GetJoinData().TeleportData
	local teleportData = {
		FromMenu = true,
		Timestamp = os.time(),
	}
	
	-- Attempt teleport
	local success, result = pcall(function()
		return TeleportService:TeleportAsync(MAIN_GAME_PLACE_ID, {player}, teleportOptions)
	end)
	
	if success then
		print(`[MenuTeleportService] Successfully initiated teleport for {player.Name}`)
		
		-- Keep the teleporting flag for a bit to prevent spam
		task.delay(TELEPORT_COOLDOWN, function()
			teleportingPlayers[player.UserId] = nil
		end)
		
		return true
	else
		warn(`[MenuTeleportService] Teleport failed for {player.Name}:`, result)
		teleportingPlayers[player.UserId] = nil
		
		-- Send error back to client
		local errorRemote = ReplicatedStorage:FindFirstChild("TeleportError")
		if not errorRemote then
			errorRemote = Instance.new("RemoteEvent")
			errorRemote.Name = "TeleportError"
			errorRemote.Parent = ReplicatedStorage
		end
		errorRemote:FireClient(player, tostring(result))
		
		return false
	end
end

-- Handle teleport requests from clients
teleportRemote.OnServerEvent:Connect(function(player)
	print(`[MenuTeleportService] Teleport request from {player.Name}`)
	teleportToMainGame(player)
end)

-- Handle teleport failures
TeleportService.TeleportInitFailed:Connect(function(player, teleportResult, errorMessage, placeId, teleportOptions)
	if placeId == MAIN_GAME_PLACE_ID then
		warn(`[MenuTeleportService] Teleport init failed for {player.Name}:`, errorMessage)
		teleportingPlayers[player.UserId] = nil
		
		-- Notify client of failure
		local errorRemote = ReplicatedStorage:FindFirstChild("TeleportError")
		if errorRemote then
			errorRemote:FireClient(player, errorMessage)
		end
	end
end)

-- Clean up teleporting flags when players leave
Players.PlayerRemoving:Connect(function(player)
	teleportingPlayers[player.UserId] = nil
end)

print("[MenuTeleportService] Ready")
print("[MenuTeleportService] Target Place ID:", MAIN_GAME_PLACE_ID)

