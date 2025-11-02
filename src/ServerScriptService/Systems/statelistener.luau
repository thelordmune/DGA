--[[
	State Listener System - Modernized

	Handles duration-based component updates.
	State change notifications (like InCombat) are now handled by observers.

	This system still runs every frame to update durations, but state transitions
	are detected and handled by the observer system in jecs_observers.luau
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)
local world = require(ReplicatedStorage.Modules.ECS.jecs_world)
local Sift = require(ReplicatedStorage.Modules.Imports.Sift)

local lastTime = os.clock()

-- Components that have duration tracking
local DURATION_COMPONENTS = {
	"Attacking", "Stun", "NoRotate", "Blocking", "Knocked", "IFrame",
	"Ragdoll", "CantMove", "NoJump", "Light", "NoDash", "CritCD",
	"Heavy", "IgnoreParry", "NoHurt", "ParryTick", "ParryStun",
	"Utility", "Action", "BBRegen", "Armor", "QDC", "Locked",
	"InCombat" -- Still track duration, but observers handle notifications
}

local function statelistener()
	local currentTime = os.clock()
	local deltaTime = currentTime - (lastTime or currentTime)
	lastTime = currentTime

	-- Only iterate through entities with Character component
	for entity in world:query(comps.Character):iter() do
		-- Only check duration-based components
		for _, componentName in ipairs(DURATION_COMPONENTS) do
			local component = comps[componentName]
			if component then
				local componentInstance = world:get(entity, component)

				if type(componentInstance) == "table"
					and componentInstance.duration ~= nil
					and componentInstance.value ~= nil then

					local newDuration = componentInstance.duration - deltaTime

					if newDuration <= 0 then
						-- Duration expired - set value to false
						world:set(entity, component, Sift.Dictionary.mergeDeep(
							componentInstance,
							{
								value = false,
								duration = 0
							}
						))

						-- Observers will handle any notifications needed
					else
						-- Update duration
						world:set(entity, component, Sift.Dictionary.mergeDeep(
							componentInstance,
							{
								duration = newDuration
							}
						))
					end
				end
			end
		end
	end
end

return {
	run = function()
		statelistener()
	end,
	settings = {
		phase = "Heartbeat",
		depends_on = {"PlayerAdded"},
		server_only = true
	}
}