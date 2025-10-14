# LinearVelocity Anti-Flinging Fix

## Problem
Players were being flung by:
1. **LinearVelocity on moves** - Using `MaxForce = math.huge` causing physics instability
2. **Crater and debris parts** - Set to `CanCollide = true` with physics enabled

## Solution Applied

### 1. Reduced MaxForce from math.huge to 200000

The key fix was changing from unlimited force to a reasonable force limit:

**BEFORE (Caused Flinging):**
```lua
lv.MaxForce = math.huge  -- Unlimited force = physics instability
```

**AFTER (Stable):**
```lua
lv.MaxForce = 200000  -- Sufficient force for movement, prevents excessive flinging
```

### 2. Direction Flattening

All horizontal movement functions now flatten the direction vector to prevent slope issues:

```lua
-- Get current forward direction and flatten to horizontal
local forwardVector = rootPart.CFrame.LookVector
forwardVector = Vector3.new(forwardVector.X, 0, forwardVector.Z).Unit
```

This prevents:
- Going into the ground when looking down
- Flying upward when looking up
- Inconsistent movement speeds on slopes

### 3. Updated Functions in Bvel.lua

All the following functions were updated to use `MaxForce = 200000` and flatten directions:

- ✅ `FistRunningBvel`
- ✅ `PIBvel`
- ✅ `PIBvel2`
- ✅ `AABvel`
- ✅ `NTBvel`
- ✅ `FlameRunningBvel`
- ✅ `GunsRunningBvel`
- ✅ `StoneLaunchVelocity`
- ✅ `PincerForwardVelocity`

### 4. Crater & Debris Fix

**File:** `src/ReplicatedStorage/Modules/Utils/RockMod/init.lua`

Changed `CreatePart` function:
```lua
Part.CanCollide = false  -- Changed from true to prevent flinging players
```

**Impact:**
- Crater parts (anchored) won't collide with players
- Debris parts (unanchored with physics) won't fling players on contact
- Visual effects remain intact
- No gameplay impact - purely visual elements

## Testing Checklist

- [ ] Test all weapon running attacks (Fist, Flame, Guns, Bone Gauntlets)
- [ ] Test Pincer Impact forward velocity
- [ ] Test Needle Thrust (PIBvel, PIBvel2)
- [ ] Test Stone Lance launch
- [ ] Test moves with arc motion (NTBvel, AABvel)
- [ ] Verify crater effects don't fling players
- [ ] Verify debris particles don't fling players
- [ ] Test on slopes and uneven terrain
- [ ] Test with multiple players in combat

## Technical Notes

### Why 200000?
- **200000** is sufficient force to move a player character reliably
- It's high enough to overcome gravity and friction
- It's low enough to prevent physics engine instability
- Roblox's physics engine handles this value well without causing flinging

### Why Not `math.huge`?
Using `MaxForce = math.huge` causes:
- Physics engine instability (the engine can't handle infinite force)
- Unpredictable interactions with other forces (gravity, friction, collisions)
- Excessive velocity buildup that bypasses normal physics constraints
- Flinging when combined with any velocity vector

### The Real Issue
The problem wasn't about constraining force per-axis (like M1Bvel does with `MaxAxesForce`). The issue was using **unlimited force** (`math.huge`), which causes the physics engine to apply excessive force trying to reach the target velocity, resulting in flinging.

### M1Bvel's Approach
M1Bvel uses a different approach with `ForceLimitsEnabled` and `MaxAxesForce`:
- This is for **fine-tuned control** over directional forces
- Useful when you want different force limits on different axes
- More complex but allows for precise movement control
- **Not required** to prevent flinging - just using a reasonable `MaxForce` value works

### Collision Groups
All debris/crater parts use:
```lua
Part.CollisionGroup = "CharactersOff"
```
This should already prevent player collision, but setting `CanCollide = false` adds an extra layer of safety.

## Files Modified

1. `src/ReplicatedStorage/Client/Events/Bvel.lua` - Updated 9 velocity functions
2. `src/ReplicatedStorage/Modules/Utils/RockMod/init.lua` - Disabled debris collision

## Related Systems

- Anti-Fling system (`src/StarterPlayer/StarterPlayerScripts/AntiFling.client.lua`) - Clamps excessive velocities
- Server Anti-Fling (`src/ServerScriptService/AntiFling.server.lua`) - Server-side velocity clamping
- These systems work as a safety net but shouldn't be relied upon as the primary solution

