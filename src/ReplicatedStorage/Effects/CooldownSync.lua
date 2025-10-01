--!strict
-- Client-side cooldown sync receiver

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Library = require(ReplicatedStorage.Modules.Library)

local player = Players.LocalPlayer

local CooldownSync = {}

-- Update cooldowns from server
function CooldownSync.Update(cooldownData)
	local character = player.Character
	if not character then return end
	
	-- Apply each cooldown to the client-side Library
	for skillName, data in pairs(cooldownData) do
		-- Set the cooldown on the client side so the UI can see it
		-- We use the endTime from the server to stay in sync
		local cooldowns = Library.GetCooldowns(character)
		cooldowns[skillName] = data.endTime
	end
end

return CooldownSync

