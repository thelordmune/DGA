--!strict
-- Cooldown Sync System - Sends server cooldowns to client for UI display

local ServerStorage = game:GetService("ServerStorage")
local Replicated = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NetworkModule = {}
local Server = require(script.Parent.Parent)
NetworkModule.__index = NetworkModule
local self = setmetatable({}, NetworkModule)

-- Track last sync time for each player
local lastSyncTime = {}
local SYNC_INTERVAL = 0.1 -- Sync every 100ms (10 times per second)

-- Start syncing cooldowns for all players
local function startCooldownSync()
	RunService.Heartbeat:Connect(function()
		local currentTime = os.clock()
		
		for _, player in pairs(game.Players:GetPlayers()) do
			local character = player.Character
			if not character then continue end
			
			-- Throttle syncs per player
			local lastSync = lastSyncTime[player] or 0
			if currentTime - lastSync < SYNC_INTERVAL then
				continue
			end
			lastSyncTime[player] = currentTime
			
			-- Get all cooldowns for this character
			local cooldowns = Server.Library.GetCooldowns(character)
			if not cooldowns then continue end
			
			-- Build cooldown data to send
			local cooldownData = {}
			for skillName, endTime in pairs(cooldowns) do
				local remaining = endTime - currentTime
				if remaining > 0 then
					cooldownData[skillName] = {
						endTime = endTime,
						remaining = remaining
					}
				end
			end
			
			-- Only send if there are active cooldowns
			if next(cooldownData) then
				Server.Visuals.FireClient(player, {
					Module = "CooldownSync",
					Function = "Update",
					Arguments = {cooldownData}
				})
			end
		end
	end)
end

-- Start the sync system
startCooldownSync()

-- Cleanup when player leaves
game.Players.PlayerRemoving:Connect(function(player)
	lastSyncTime[player] = nil
end)

return NetworkModule

