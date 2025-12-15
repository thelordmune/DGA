-- Diagnostic script to check guard components
-- Paste this in SERVER console (not client) after attacking guard

local comps = require(game.ReplicatedStorage.Modules.ECS.jecs_components)
local world = require(game.ReplicatedStorage.Modules.ECS.jecs_world)
local RefManager = require(game.ReplicatedStorage.Modules.ECS.jecs_ref_manager)

-- Find guard
local guard = nil
for _, desc in workspace:GetDescendants() do
    if desc:IsA("Model") and desc.Name:match("Guard") and desc:FindFirstChild("Humanoid") then
        guard = desc
        break
    end
end

if not guard then
   -- print("ERROR: No guard found")
    return
end

print("=== GUARD COMPONENT CHECK ===")
print("Guard:", guard.Name)

local entity = RefManager.entity.find(guard)
if not entity then
   -- print("ERROR: Guard has no ECS entity!")
    return
end

print("Entity ID:", entity)
print("\nRequired for npc_movement_pattern_ecs query:")
print("  ✓ Character:", world:has(entity, comps.Character))
print("  ✓ Transform:", world:has(entity, comps.Transform))
print("  ✓ NPCTarget:", world:has(entity, comps.NPCTarget))
print("  ✓ NPCMovementPattern:", world:has(entity, comps.NPCMovementPattern))
print("  ✓ NPCConfig:", world:has(entity, comps.NPCConfig))
print("  ✓ Locomotion:", world:has(entity, comps.Locomotion))
print("  ✓ CombatNPC:", world:has(entity, comps.CombatNPC))

if world:has(entity, comps.NPCTarget) then
    local target = world:get(entity, comps.NPCTarget)
   -- print("\nTarget:", target and target.Name or "nil")
end

if world:has(entity, comps.Locomotion) then
    local loco = world:get(entity, comps.Locomotion)
   -- print("\nLocomotion:")
   -- print("  dir:", loco.dir)
   -- print("  speed:", loco.speed)
end

if world:has(entity, comps.NPCMovementPattern) then
    local pattern = world:get(entity, comps.NPCMovementPattern)
   -- print("\nNPCMovementPattern:")
   -- print("  current:", pattern.current)
   -- print("  lastChanged:", pattern.lastChanged)
else
   -- print("\n❌ MISSING NPCMovementPattern component!")
   -- print("   This is why guard can't move!")
end

print("\n=== END CHECK ===")
