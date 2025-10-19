-- Debug script to check player entity references
-- Run this in the command bar: require(game.ServerScriptService.DebugPlayerEntity)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local RefManager = require(ReplicatedStorage.Modules.ECS.jecs_ref_manager)
local ref = RefManager.player -- Use player-specific ref system
local world = require(ReplicatedStorage.Modules.ECS.jecs_world)
local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)

-- print("=== PLAYER ENTITY DEBUG ===")

for _, player in ipairs(Players:GetPlayers()) do
    -- print("\n🔍 Checking player:", player.Name, "UserId:", player.UserId)
    
    -- Try to get entity via ref.get
    local entity = ref.get("player", player)
    -- print("  ref.get('player', player):", entity)
    
    -- Check if entity exists in world
    if entity then
        local exists = world:contains(entity)
        -- print("  Entity exists in world:", exists)
        
        if exists then
            -- Check what components it has
            -- print("  Components:")
            if world:has(entity, comps.Player) then
                local playerComp = world:get(entity, comps.Player)
                -- print("    - Player:", playerComp and playerComp.Name or "nil")
            end
            if world:has(entity, comps.Character) then
                local charComp = world:get(entity, comps.Character)
                -- print("    - Character:", charComp and charComp.Name or "nil")
            end
            if world:has(entity, comps.Level) then
                local levelComp = world:get(entity, comps.Level)
                -- print("    - Level:", levelComp and levelComp.current or "nil")
            end
            if world:has(entity, comps.Experience) then
                local expComp = world:get(entity, comps.Experience)
                -- print("    - Experience:", expComp and expComp.current or "nil")
            end
            if world:has(entity, comps.Alignment) then
                local alignComp = world:get(entity, comps.Alignment)
                -- print("    - Alignment:", alignComp and alignComp.value or "nil")
            end
        end
    else
        -- print("  ❌ No entity found via ref.get!")
        
        -- Try to find entity by searching world
        -- print("  🔍 Searching world for Player component...")
        for e in world:query(comps.Player):iter() do
            local playerComp = world:get(e, comps.Player)
            if playerComp == player then
                -- print("  ✅ Found entity in world:", e)
                -- print("    But ref.get returned nil - ref system is broken!")
                break
            end
        end
    end
end

-- print("\n=== END DEBUG ===")

