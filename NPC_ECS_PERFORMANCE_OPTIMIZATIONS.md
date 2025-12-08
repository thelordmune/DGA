# NPC ECS Performance Optimizations

## Overview
This document details the performance optimizations applied to the NPC ECS systems based on the query patterns from `refs/queries`. These optimizations significantly improve performance when dealing with multiple NPCs.

---

## Key Optimization Techniques Applied

### 1. **Spatial Grid (Voxel-Based Partitioning)**
**Pattern:** `refs/queries/spatial_grids.luau`

**Implementation:** [npc_targeting_ecs.luau](src/ServerScriptService/Systems/npc_targeting_ecs.luau)

**Changes:**
- Replaced O(n) linear player search with O(1) spatial grid lookup
- Grid size: 50 studs (configurable)
- Only checks players in nearby voxels (3x3 grid = 9 voxels max)

**Performance Impact:**
- **Before:** Every NPC checked ALL players (N NPCs × M players = O(N×M))
- **After:** Each NPC checks only nearby players (N NPCs × ~3 players average = O(N))
- **Estimated Improvement:** ~10-30x faster target finding with 10+ players

**Code:**
```lua
-- Get only nearby players using spatial grid
local nearbyPlayers = getNearbyPlayers(npcPos, captureDistance)

-- Only check nearby players instead of ALL players
for _, player in nearbyPlayers do
    -- distance check
end
```

---

### 2. **Change Tracking**
**Pattern:** `refs/queries/changetracking.luau`

**Implementation:** [npc_skill_scoring_ecs.luau](src/ServerScriptService/Systems/npc_skill_scoring_ecs.luau)

**Changes:**
- Cache player state checks (blocking, ragdolled, hyper armor)
- Cache duration: 33ms (2 frames at 60fps)
- Avoids redundant `PlayerStateDetector` calls

**Performance Impact:**
- **Before:** Every NPC calls `IsBlocking()`, `IsRagdolled()`, `HasHyperArmor()` separately
- **After:** Results cached and reused across multiple NPCs targeting same player
- **Estimated Improvement:** ~3-5x reduction in player state checks

**Code:**
```lua
-- Cache for player states (avoid redundant PlayerStateDetector calls)
local playerStateCache = {} -- [Model] = {blocking, ragdolled, hyperArmor, timestamp}

local function getPlayerState(target: Model, now: number)
    local cached = playerStateCache[target]
    if cached and (now - cached.timestamp) < PLAYER_STATE_CACHE_TIME then
        return cached.blocking, cached.ragdolled, cached.hyperArmor
    end
    -- Calculate and cache...
end
```

---

### 3. **Query Caching**
**Pattern:** `refs/queries/basics.luau`

**Implementation:** All NPC systems

**Changes:**
- Added `:cached()` to ALL queries
- Prevents query recreation every frame
- Maintains query state between iterations

**Performance Impact:**
- **Before:** Queries recreated every frame, re-evaluating archetypes
- **After:** Queries cached, only check dirty archetypes
- **Estimated Improvement:** ~2-3x faster query iteration

**Systems Updated:**
- ✅ [npc_targeting_ecs.luau](src/ServerScriptService/Systems/npc_targeting_ecs.luau:37)
- ✅ [npc_skill_scoring_ecs.luau](src/ServerScriptService/Systems/npc_skill_scoring_ecs.luau:29)
- ✅ [npc_combat_execution_ecs.luau](src/ServerScriptService/Systems/npc_combat_execution_ecs.luau:16)
- ✅ [npc_defense_ecs.luau](src/ServerScriptService/Systems/npc_defense_ecs.luau:25)
- ✅ [npc_guard_pattern_ecs.luau](src/ServerScriptService/Systems/npc_guard_pattern_ecs.luau:29)
- ✅ [npc_pathfinding_ecs.luau](src/ServerScriptService/Systems/npc_pathfinding_ecs.luau:24)
- ✅ [npc_wander_ecs.luau](src/ServerScriptService/Systems/npc_wander_ecs.luau:24)

**Code:**
```lua
-- Before
local query = world:query(comps.A, comps.B, comps.C)

-- After (OPTIMIZED)
local query = world:query(comps.A, comps.B, comps.C):cached()
```

---

### 4. **Raycast/Obstacle Check Caching**
**Pattern:** Change tracking + caching

**Implementation:** [npc_pathfinding_ecs.luau](src/ServerScriptService/Systems/npc_pathfinding_ecs.luau)

**Changes:**
- Cache obstacle check results per entity
- Cache duration: 100ms
- Reuse result if distance hasn't changed significantly (±5 studs)

**Performance Impact:**
- **Before:** Raycasts every frame for every pathfinding NPC
- **After:** Raycasts only when needed (position changed or cache expired)
- **Estimated Improvement:** ~5-10x fewer raycasts

**Code:**
```lua
-- Cache obstacle check results to reduce raycasts
local obstacleCheckCache = {} -- [entity] = {blocked, timestamp, distance}

local function isPathBlocked(entity: number, startPos: Vector3, endPos: Vector3, now: number): boolean
    local cached = obstacleCheckCache[entity]
    if cached and (now - cached.timestamp) < OBSTACLE_CHECK_CACHE_TIME then
        local currentDistance = (endPos - startPos).Magnitude
        if math.abs(currentDistance - cached.distance) < 5 then
            return cached.blocked  -- Reuse cached result
        end
    end
    -- Do raycast and cache result...
end
```

---

### 5. **Player List Caching**
**Pattern:** Reduce redundant lookups

**Implementation:** [npc_targeting_ecs.luau](src/ServerScriptService/Systems/npc_targeting_ecs.luau)

**Changes:**
- Cache `Players:GetPlayers()` result
- Update cache every 0.5s instead of every frame
- Update spatial grid when player cache updates

**Performance Impact:**
- **Before:** Rebuilds player list every frame (~15 Hz = 15x per second)
- **After:** Rebuilds player list every 0.5s (2x per second)
- **Estimated Improvement:** ~7-8x fewer player list rebuilds

---

## Advanced Patterns Available (Not Yet Implemented)

### 6. **Archetype-Level Optimization**
**Pattern:** `refs/queries/archetypes/visibility_cascades.luau`

**Potential Use:** Process similar NPCs in batches at archetype level

**Example Use Case:**
- Batch process all guards with same weapon type
- Find parent/voxel once per archetype instead of per entity

**Code Example:**
```lua
local archetypes = world:query(Position, pair(ChildOf, __)):archetypes()

for _, archetype in archetypes do
    local types = archetype.types
    local p = jecs.pair_second(world, types[parent_cr[archetype.id]])
    -- Process all entities in archetype with same parent
    for row, entity in archetype.entities do
        -- Optimized processing
    end
end
```

---

### 7. **Wildcard Query Optimization**
**Pattern:** `refs/queries/archetypes/targets.luau`, `refs/queries/wildcards.luau`

**Potential Use:** Optimize multi-target relationships

**Example Use Case:**
- NPCs with multiple targets (aggro list)
- NPCs with multiple buffs/debuffs

**Code Example:**
```lua
-- Access wildcard relationship columns directly
local likes_cr = likes.records
local likes_counts = likes.counts

for _, archetype in archetypes do
    local wc = likes_cr[archetype.id]
    local count = likes_counts[archetype.id]

    for entity in archetype.entities do
        for cr = wc, wc + count - 1 do
            -- Process each relationship efficiently
        end
    end
end
```

---

## Performance Metrics (Estimated)

### With 20 NPCs and 10 Players:

| System | Before | After | Improvement |
|--------|--------|-------|-------------|
| **Targeting (findClosestTarget)** | 200 checks/frame | ~60 checks/frame | **~3.3x faster** |
| **Skill Scoring (player state)** | 60 calls/frame | ~10 calls/frame | **~6x faster** |
| **Pathfinding (raycasts)** | 20 raycasts/frame | ~2-4 raycasts/frame | **~5-10x faster** |
| **Query Iteration** | Full scan | Cached scan | **~2-3x faster** |

### Overall System Performance:
- **CPU Time Reduction:** ~40-60% (estimated)
- **Scales Better:** Linear scaling instead of quadratic for targeting
- **Frame Budget:** More headroom for other systems

---

## Future Optimization Opportunities

1. **Implement Archetype-Level Processing** for hot paths (targeting, skill scoring)
2. **Add Spatial Grid for NPCs** (not just players) for NPC-vs-NPC interactions
3. **Component Pooling** to reduce garbage collection
4. **Batch Updates** for similar NPCs (e.g., all guards update together)
5. **LOD System** (reduce update frequency for distant NPCs)

---

## Testing Recommendations

1. **Spawn 50+ NPCs** and monitor performance
2. **Profile with Microprofiler** to verify improvements
3. **Compare before/after** with multiple players
4. **Test edge cases:** NPCs far apart, NPCs clustered, mixed scenarios

---

## References

- Spatial Grids: [refs/queries/spatial_grids.luau](refs/queries/spatial_grids.luau)
- Change Tracking: [refs/queries/changetracking.luau](refs/queries/changetracking.luau)
- Query Basics: [refs/queries/basics.luau](refs/queries/basics.luau)
- Archetype Optimization: [refs/queries/archetypes/visibility_cascades.luau](refs/queries/archetypes/visibility_cascades.luau)
- Wildcard Queries: [refs/queries/wildcards.luau](refs/queries/wildcards.luau)

---

## Summary

The optimizations applied transform the NPC systems from naive O(N×M) algorithms to efficient cached and spatially-aware systems. The biggest wins come from:

1. **Spatial Grid** - Eliminates most player checks
2. **Caching** - Reuses expensive calculations
3. **Query Caching** - Faster iteration over entities

These changes should provide **significant** performance improvements, especially with many NPCs and players active simultaneously.
