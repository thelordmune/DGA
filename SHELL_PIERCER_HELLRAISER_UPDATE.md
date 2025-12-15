# Shell Piercer & Hellraiser Update Summary

## Changes Made

### 1. Music System ✓
**File:** [sounds.luau:14](src/ReplicatedStorage/Modules/Systems/sounds.luau#L14)

Added easy toggle to disable all in-game music:
```lua
-- ============================================
-- MUSIC CONTROL TOGGLE
-- Set this to true to disable all music in the game
-- ============================================
local MUSIC_DISABLED = false
-- ============================================
```

**To disable music:** Change `false` to `true`
**To enable music:** Change `true` to `false`

This controls:
- Day ambient music
- Night ambient music
- Combat music

---

### 2. Shell Piercer - Wall Destruction ✓
**File:** [Shell Piercer.lua](src/ServerScriptService/ServerConfig/Server/WeaponSkills/Guns/Shell Piercer.lua)

**What Changed:**
- Now works like Deconstruct - destroys Construct walls on hit
- Detects walls by checking for `Id` attribute (same as Deconstruct)
- Voxelizes walls into debris pieces permanently
- Debris launches forward with physics and trails
- Debris can damage enemies (5 damage, 8 posture)

**How It Works:**
1. Shell Piercer fires and creates hitbox
2. Hits both enemies AND Construct walls in the same hitbox
3. If wall has `Id` attribute (created by Construct), it voxelizes
4. Wall breaks into ~20 pieces
5. Debris launches forward at 120 studs/second with random spread
6. Debris has white trails and can hit enemies
7. **Walls are permanently destroyed** (no regeneration)

**Trail Settings (Shrunk):**
- Lifetime: 0.8 seconds
- Width: 0.2 → 0.1 → 0.05 (much smaller than before)

---

### 3. Hellraiser - Wall Destruction on Final Hit ✓
**File:** [Hellraiser.lua:174-343](src/ServerScriptService/ServerConfig/Server/WeaponSkills/Guns/Hellraiser.lua#L174-L343)

**What Changed:**
- Final hit (3rd hit) now destroys Construct walls
- Uses exact same system as Shell Piercer and Deconstruct
- Walls voxelize and debris launches forward
- Debris can damage enemies during flight

**How It Works:**
1. Hellraiser's rapid fire does first 10 hits (normal damage)
2. Second hit does normal damage
3. **Final hit** destroys walls and launches debris
4. Same voxel system, same debris physics, same trails
5. **Walls are permanently destroyed** (no regeneration)

---

## Technical Details

### Wall Detection System
Both skills now use the same detection as Deconstruct:
```lua
if Target:GetAttribute("Id") then
    -- This is a Construct wall, destroy it
end
```

### Permanent Destruction
Walls are voxelized with `-1` time parameter:
```lua
local parts = VoxBreaker:VoxelizePart(Target, 20, -1)
```
- `20` = number of voxel pieces to create
- `-1` = negative time means **no regeneration** (permanent)

### Debris Trail Sizes (Shrunk)
Old values (Deconstruct):
```lua
trail.WidthScale = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 0.6),
    NumberSequenceKeypoint.new(0.5, 0.4),
    NumberSequenceKeypoint.new(1, 0.1)
})
trail.Lifetime = 1.5
```

New values (Shell Piercer & Hellraiser):
```lua
trail.WidthScale = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 0.2),   -- 67% smaller
    NumberSequenceKeypoint.new(0.5, 0.1), -- 75% smaller
    NumberSequenceKeypoint.new(1, 0.05)   -- 50% smaller
})
trail.Lifetime = 0.8  -- 47% shorter duration
```

### Debris Physics
- **Velocity:** 120 studs/second forward
- **Random spread:** ±0.5 on X/Z, +0.5 on Y (slight upward bias)
- **Collision group:** "Rock"
- **Damage:** 5 HP, 8 posture damage
- **Lifetime:** 8-12 seconds before despawn

---

## What Works Now

### Shell Piercer
✅ Destroys Construct walls
✅ Launches debris with trails
✅ Debris damages enemies
✅ Permanent wall destruction
✅ Smaller trail effects

### Hellraiser
✅ Final hit destroys Construct walls
✅ Launches debris with trails
✅ Debris damages enemies
✅ Permanent wall destruction
✅ Smaller trail effects

### Music System
✅ Easy toggle to disable all music
✅ Stops day/night ambient tracks
✅ Stops combat music

---

## Testing

1. **Create a Construct wall** using the Construct alchemy skill
2. **Use Shell Piercer** - wall should explode into debris
3. **Use Hellraiser** - final hit should explode wall into debris
4. **Check debris** - should have small white trails and damage enemies
5. **Check regeneration** - walls should NOT come back

**Music Test:**
1. Set `MUSIC_DISABLED = true` in sounds.luau
2. Join game - no music should play
3. Set back to `false` - music should resume

---

## Files Modified

1. [sounds.luau](src/ReplicatedStorage/Modules/Systems/sounds.luau) - Music toggle
2. [Shell Piercer.lua](src/ServerScriptService/ServerConfig/Server/WeaponSkills/Guns/Shell Piercer.lua) - Complete rewrite
3. [Hellraiser.lua](src/ServerScriptService/ServerConfig/Server/WeaponSkills/Guns/Hellraiser.lua) - Added voxel destruction to final hit

---

## Notes

- Both skills work identically to Deconstruct for wall destruction
- Walls created by Construct have `Id` attribute - this is how they're detected
- Debris uses PartCache system for performance optimization
- Trail sizes are significantly smaller than Deconstruct's debris
- Negative voxel time (-1) = permanent destruction
- Debris automatically cleans up after 8-12 seconds
