-- local ReplicatedStorage = game:GetService("ReplicatedStorage")
-- local jecs = require(ReplicatedStorage.Modules.Imports.jecs)
-- local Bridges = require(ReplicatedStorage.Modules.Bridges)

-- return {
--     run = function()
--         local replicatedComponents = {
--             NoDash = true,
--             Dashing = true,
--             Attacking = true,
--             Armor = true,
--             InCombat = true
--         }

--         local world = require(ReplicatedStorage.Modules.ECS.jecs_world)
--         local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)
--         local ref = require(ReplicatedStorage.Modules.ECS.jecs_ref)

--         for compName in (replicatedComponents) do
--             world:set(comps[compName], jecs.OnChange, function(entity, id, value)
--                 local playerComp = world:get(entity, comps.Player)
--                 if not playerComp then return end
                
--                 local player = playerComp
--                 if not player or not player:IsA("Player") then return end

--                 Bridges.ECSClient:Fire(player, {
--                     Module = "ECS_Replication",
--                     Action = "ComponentUpdate",
--                     Component = compName,
--                     Data = value,
--                     EntityId = entity
--                 })
--             end)
--         end

--         game:GetService("Players").PlayerAdded:Connect(function(player)
--             player.CharacterAdded:Connect(function(character)
--                 local entity = ref.get("player", player)

--                 if not world:get(entity, comps.Player) then
--                     world:set(entity, comps.Player, player)
--                 end

--                 local state = {}
--                 for compName in (replicatedComponents) do
--                     local compData = world:get(entity, comps[compName])
--                     if compData then
--                         state[compName] = compData
--                     end
--                 end

--                 Bridges.ECSClient:Fire(player, {
--                     Module = "ECS_Replication",
--                     Action = "FullState",
--                     Data = state,
--                     EntityId = entity
--                 })
--             end)
--         end)
--     end,
--     settings = {
--         phase = "Heartbeat",
--         depends_on = {"PlayerAdded"},
--         server_only = true
--     }
-- }