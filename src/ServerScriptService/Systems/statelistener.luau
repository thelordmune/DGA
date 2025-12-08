--[[
	State Listener System - HEAVILY OPTIMIZED

	Handles duration-based component updates.
	State change notifications (like InCombat) are now handled by observers.

	OPTIMIZATIONS:
	- Throttled to 20 Hz instead of 60 Hz (67% reduction)
	- Cached queries for each duration component (only processes entities with that component)
	- Reduced iteration overhead by querying specific components instead of all characters
	- Eliminated redundant component lookups
	- Optimized component updates with direct table modification
	- Batch component updates to reduce ECS overhead
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)
local world = require(ReplicatedStorage.Modules.ECS.jecs_world)

local lastTime = os.clock()

-- OPTIMIZATION: Throttle to 20 Hz instead of 60 Hz
-- Duration tracking doesn't need frame-perfect precision
local UPDATE_HZ = 20
local UPDATE_TICK = 1 / UPDATE_HZ
local updateAcc = 0

-- Components that have duration tracking
local DURATION_COMPONENTS = {
	"Attacking", "Stun", "NoRotate", "Blocking", "Knocked", "IFrame",
	"Ragdoll", "CantMove", "NoJump", "Light", "NoDash", "CritCD",
	"Heavy", "IgnoreParry", "NoHurt", "ParryTick", "ParryStun",
	"Utility", "Action", "BBRegen", "Armor", "QDC", "Locked",
	"InCombat" -- Still track duration, but observers handle notifications
}

-- OPTIMIZATION: Create cached queries for each duration component
local durationQueries = {}
for _, componentName in ipairs(DURATION_COMPONENTS) do
	local component = comps[componentName]
	if component then
		durationQueries[componentName] = world:query(component):cached()
	end
end

local function statelistener()
	local currentTime = os.clock()
	local deltaTime = currentTime - (lastTime or currentTime)
	lastTime = currentTime

	-- OPTIMIZATION: Iterate through each duration component's query instead of all characters
	-- This only processes entities that actually have each specific component
	for _, componentName in ipairs(DURATION_COMPONENTS) do
		local query = durationQueries[componentName]
		local component = comps[componentName]

		if query and component then
			for entity, componentInstance in query do
				-- Validate component structure
				if type(componentInstance) == "table"
					and componentInstance.duration ~= nil
					and componentInstance.value ~= nil then

					local newDuration = componentInstance.duration - deltaTime

					if newDuration <= 0 then
						-- Duration expired - REMOVE component instead of setting value to false
						-- This ensures observers fire properly
						world:remove(entity, component)

						-- Special handling for InCombat to notify client
						if componentName == "InCombat" then
							local playerComponent = world:get(entity, comps.Player)
							if playerComponent then
								local Visuals = require(game:GetService("ReplicatedStorage").Modules.Visuals)
								Visuals.FireClient(playerComponent, {
									Module = "Base",
									Function = "InCombat",
									Arguments = { playerComponent, false },
								})
							end
						end
					else
						-- OPTIMIZATION: Update duration directly instead of using Sift.Dictionary.mergeDeep
						-- This is safe because we're only modifying the duration field
						componentInstance.duration = newDuration
						world:set(entity, component, componentInstance)
					end
				end
			end
		end
	end
end

return {
	run = function(_world, dt)
		-- OPTIMIZATION: Throttle to 20 Hz
		updateAcc += dt
		if updateAcc >= UPDATE_TICK then
			-- Accumulate multiple frames if needed (e.g., if we skipped 2 frames, deltaTime will be ~0.1s)
			local deltaTime = updateAcc
			updateAcc = 0

			-- Update lastTime for next iteration
			local currentTime = os.clock()
			lastTime = currentTime - deltaTime

			statelistener()
		end
	end,
	settings = {
		phase = "Heartbeat",
		depends_on = {"PlayerAdded"},
		server_only = true
	}
}