--[[
	Cooldown Cleanup System (Server)
	
	Automatically removes expired cooldowns from the Cooldowns component to prevent memory leaks.
	Runs every 5 seconds to garbage collect old cooldowns.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)
local world = require(ReplicatedStorage.Modules.ECS.jecs_world)

local CLEANUP_INTERVAL = 5 -- Clean up every 5 seconds
local lastCleanupTime = 0

local function cooldown_cleanup()
	local currentTime = os.clock()
	
	-- Only run cleanup every CLEANUP_INTERVAL seconds
	if currentTime - lastCleanupTime < CLEANUP_INTERVAL then
		return
	end
	
	lastCleanupTime = currentTime
	
	local cleanedCount = 0
	local totalCooldowns = 0
	
	-- Iterate through all entities with Cooldowns component
	for entity, cooldowns in world:query(comps.Cooldowns) do
		local expiredCooldowns = {}
		
		-- Find expired cooldowns
		for identifier, expiryTime in pairs(cooldowns) do
			totalCooldowns = totalCooldowns + 1
			
			if expiryTime <= currentTime then
				table.insert(expiredCooldowns, identifier)
			end
		end
		
		-- Remove expired cooldowns
		if #expiredCooldowns > 0 then
			for _, identifier in ipairs(expiredCooldowns) do
				cooldowns[identifier] = nil
				cleanedCount = cleanedCount + 1
			end
			
			-- Update component (create new table to ensure jecs detects change)
			local newCooldowns = {}
			for k, v in pairs(cooldowns) do
				newCooldowns[k] = v
			end
			world:set(entity, comps.Cooldowns, newCooldowns)
		end
	end
	
	if cleanedCount > 0 then
		print(`[Cooldown Cleanup] Removed {cleanedCount} expired cooldowns (Total: {totalCooldowns})`)
	end
end

return {
	run = function()
		cooldown_cleanup()
	end,
	settings = {
		phase = "Heartbeat",
		depends_on = {},
		server_only = true
	}
}

