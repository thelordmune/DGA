

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)
local world = require(ReplicatedStorage.Modules.ECS.jecs_world)

local lastTime = os.clock()
local UPDATE_HZ = 20
local UPDATE_TICK = 1 / UPDATE_HZ
local updateAcc = 0


local DURATION_COMPONENTS = {
	"Attacking", "Stun", "NoRotate", "Blocking", "Knocked", "IFrame",
	"Ragdoll", "CantMove", "NoJump", "Light", "NoDash", "CritCD",
	"Heavy", "IgnoreParry", "NoHurt", "ParryTick", "ParryStun",
	"Utility", "Action", "BBRegen", "Armor", "QDC", "Locked",
	"InCombat"
}

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


	for _, componentName in ipairs(DURATION_COMPONENTS) do
		local query = durationQueries[componentName]
		local component = comps[componentName]

		if query and component then
			for entity, componentInstance in query do
				if type(componentInstance) == "table"
					and componentInstance.duration ~= nil
					and componentInstance.value ~= nil then

					local newDuration = componentInstance.duration - deltaTime

					if newDuration <= 0 then
						world:remove(entity, component)
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
						-- CRITICAL FIX: Mutate the table in-place instead of calling world:set
						-- This prevents archetype fragmentation from constant component updates
						componentInstance.duration = newDuration
						-- DO NOT call world:set here - the table is already in the component
					end
				end
			end
		end
	end
end

return {
	run = function(_world, dt)
		updateAcc += dt
		if updateAcc >= UPDATE_TICK then
			local deltaTime = updateAcc
			updateAcc = 0

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