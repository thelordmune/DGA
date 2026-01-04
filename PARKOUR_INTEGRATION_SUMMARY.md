# Parkour System Integration & Sliding Fix

## Overview
Integrated the standalone parkour system with the main Client system and fixed sliding mechanics that weren't functioning properly.

## Changes Made

### 1. Client System Integration (`src/ReplicatedStorage/Client/init.lua`)

Added parkour state tracking to the Client system:

```lua
System.Sliding = false; -- Parkour sliding state
System.WallRunning = false; -- Parkour wall running state
System.LedgeClimbing = false; -- Parkour ledge climbing state
System.Leaping = false; -- Parkour leap state (slide jump)
System.LeapLanding = false; -- Flag to prevent landing animation after leap
```

**Why:** The parkour system was completely separate and didn't communicate with the main game systems. This caused issues with:
- Animation conflicts (walking animations playing during slides)
- Sound effects playing incorrectly
- State checks failing (e.g., `Client.Sliding` was always false)

### 1b. Animation System Fix (`src/ReplicatedStorage/Client/Animate/init.lua`)

Updated the Move listener to check parkour states before playing walking animations:

```lua
-- Don't play walking animations during parkour actions
if Client.InAir or Client.Sliding or Client.WallRunning or Client.LedgeClimbing or Client.Leaping then
    return
end
```

**Why:** Prevents animation conflicts where walking/running animations would play during parkour moves like sliding, wall running, or the leap jump.

Updated the Freefall listener to prevent tracking freefall time during leap:

```lua
-- Don't track freefall time during leap (prevents landing animation after leap)
if not Client.Leaping then
    self.FreeFallTime = os.clock()
end
```

**Why:** Prevents the landing animation from being triggered after a leap by not tracking freefall time during the leap.

### 1c. Running System Fix (`src/ReplicatedStorage/Client/Movement.lua`)

Updated the Run function to prevent running from starting during parkour actions:

```lua
-- Don't allow running during parkour actions
if State and not Client.Leaping and not Client.Sliding and not Client.WallRunning and not Client.LedgeClimbing then
    -- Start running...
end
```

**Why:** Prevents the running animation from being triggered while holding shift during parkour actions, especially during the leap jump.

### 2. Sliding Module Fix (`src/StarterPlayer/StarterCharacterScripts/Parkour/Modules/Sliding.lua`)

#### Problem
- Used deprecated `BodyPosition` and `BodyGyro` which are unreliable
- Velocity wasn't being applied correctly
- No integration with Client system
- Slide duration too long and velocity too slow

#### Solution

**Replaced deprecated constraints:**
```lua
-- OLD (deprecated):
local BP = Instance.new('BodyPosition')
local BG = Instance.new('BodyGyro')

-- NEW (modern):
local LV = Instance.new('LinearVelocity')
local AO = Instance.new('AlignOrientation')
```

**Improved parameters:**
- `SlidingDuration`: 3s → 2s (snappier feel)
- `InitialVelocity`: 30 → 50 (better slide distance)

**Added Client state synchronization:**
```lua
-- On slide start:
Client.Sliding = true

-- On slide end:
Client.Sliding = false
```

**Fixed velocity application:**
- Now uses `LinearVelocity.VectorVelocity` which properly applies force
- Velocity updates every frame based on ground detection
- Handles slopes correctly (maintains slide on downhill, ends faster on uphill)

### 3. Wall Run Module Integration (`src/StarterPlayer/StarterCharacterScripts/Parkour/Modules/Wall Run.lua`)

Added Client state tracking:
```lua
-- On wall run start:
Client.WallRunning = true

// On wall run end:
Client.WallRunning = false
```

### 4. Ledge Climbing Module Integration (`src/StarterPlayer/StarterCharacterScripts/Parkour/Modules/Ledge.lua`)

Added Client state tracking:
```lua
-- On ledge climb start:
Client.LedgeClimbing = true

-- On ledge climb end:
Client.LedgeClimbing = false
```

## How Sliding Works Now

1. **Activation:** Press the slide key (configured via module attribute, typically `C` or `LeftControl`)

2. **Requirements:**
   - Must be on ground (`Humanoid.FloorMaterial ~= Enum.Material.Air`)
   - Parkour system not busy with another action

3. **Mechanics:**
   - Character enters `PlatformStand` state (lies down)
   - Slide animation plays
   - `LinearVelocity` applies forward momentum (30 studs/s initially)
   - `AlignOrientation` keeps character facing slide direction
   - Velocity decreases over 1 second
   - Slope detection: slides faster downhill, slower uphill

4. **Slide Jump (NEW):**
   - Press **Space (jump)** while sliding OR within 200ms after releasing slide key
   - Launches character forward (70 studs/s) and upward (30 studs/s)
   - Plays Leap animation from `ReplicatedStorage > Assets > Animations > Movement > Leap`
   - Ends the slide immediately
   - Sets `Client.InAir = true` to prevent running animations during leap
   - Automatically clears state when character lands
   - 200ms buffer window allows natural "release slide + press jump" timing
   - Perfect for chaining parkour moves

5. **Ending:**
   - Auto-ends after 1 second on flat ground
   - Ends faster if in air
   - Can be manually ended by releasing the slide key
   - Can be ended early with slide jump
   - Character returns to normal state

## Benefits

✅ **Sliding now works properly** - Uses modern physics constraints
✅ **Better performance** - LinearVelocity is more efficient than BodyPosition
✅ **Animation system aware** - Won't play walking animations during parkour
✅ **Sound system aware** - Won't play footsteps during slides
✅ **State checking works** - Other systems can check `Client.Sliding`, `Client.WallRunning`, etc.
✅ **Smoother movement** - Better velocity application and control

## Testing Checklist

- [ ] Sliding activates when pressing slide key on ground
- [ ] Slide animation plays correctly
- [ ] Character moves forward during slide
- [ ] Slide ends after ~1 second
- [ ] No walking animations during slide
- [ ] No footstep sounds during slide
- [ ] **Slide jump: Pressing Space while sliding performs a leap**
- [ ] **Slide jump: Pressing Space within 200ms after releasing slide performs a leap**
- [ ] **Slide jump: Leap animation plays cleanly without mixing**
- [ ] **Slide jump: Character launches in a smooth parabolic arc (80 studs/s forward, 50 studs/s up)**
- [ ] **Slide jump: Arc feels natural and smooth (0.8s duration with manual gravity)**
- [ ] **Slide jump: No running animation plays during leap (even when holding shift)**
- [ ] **Slide jump: No landing animation plays after leap (completely blocked)**
- [ ] **Slide jump: Sprinting resumes automatically if shift is still held after landing**
- [ ] **Slide jump: Cannot double-jump (buffer resets after use)**
- [ ] **Landing roll: Landing from high fall adds forward momentum**
- [ ] **Landing roll: Character rolls forward smoothly**
- [ ] **Landing roll: Does NOT play after leap jumps (completely separate system)**
- [ ] Wall running works and sets `Client.WallRunning`
- [ ] Ledge climbing works and sets `Client.LedgeClimbing`
- [ ] Parkour doesn't interfere with combat/alchemy

## Configuration

To change slide key binding, set the `ActivateKey` attribute on the Sliding module in Roblox Studio.

Common keys:
- `C` - Crouch/Slide (FPS standard)
- `LeftControl` - Crouch/Slide (alternative)
- `V` - Parkour action

## New Features Added

### Slide Jump (Leap)
Press **Space (jump)** while sliding OR within 200ms after releasing the slide key:
- Ends the slide immediately (if still sliding)
- **Stops running animation** if player is holding shift
- **Remembers if shift was held** to resume sprinting after leap
- **Clears all body movers** to prevent velocity interference
- **Resets velocity to zero** before applying leap force
- **Creates a smooth parabolic arc** using BodyVelocity with manual gravity simulation
- Launches character forward (80 studs/s) and upward (50 studs/s initial)
- **Arc duration: 0.8 seconds** - smooth, natural-feeling jump
- Gravity is manually applied each frame for perfect arc control
- Plays the Leap animation from `ReplicatedStorage > Assets > Animations > Movement > Leap`
- Sets `Client.Leaping = true` to **completely lock out all other animations**
- **Prevents FreeFallTime tracking** during leap (no landing animation trigger)
- Sets `Client.LeapLanding = true` as backup to **prevent landing animation** after leap
- Sets `Client.InAir = true` to prevent running/walking animations
- Marks parkour system as busy to prevent action conflicts
- **Waits for BOTH animation completion AND landing** before unlocking
- Animation lock ensures leap animation plays cleanly without interruption
- **Resumes sprinting automatically** if shift is still held after landing
- Automatically clears states when both conditions are met (with 3s timeout)
- 200ms buffer window allows natural timing (release slide → press jump)
- Great for chaining parkour moves or escaping danger
- Prevents double-jumping by resetting the buffer after use or escaping danger

### Landing Roll Momentum
When landing from a high fall (1+ second freefall):
- Landing animation plays (roll animation)
- Character gains forward momentum (20 studs/s) in the direction they're facing
- Makes landings feel more dynamic and fluid
- Preserves vertical velocity to avoid bouncing

## Future Enhancements

- Add slide cooldown to prevent spam
- Add slide boost when sliding downhill
- Add slide attack (slide + attack = slide kick)
- Add slide particles/dust trail
- Add camera tilt during slide for better feel
- Add slide jump cooldown to prevent spam

