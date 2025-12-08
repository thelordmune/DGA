# NPC ECS System Flow - Complete Execution Order

**Date:** 2025-12-02

---

## 🔄 System Execution Order & Data Flow

### Phase 1: NPC Spawning (mobs.luau - one time)
```
Player joins / NPC spawns
    ↓
mobs.luau detects new NPC
    ↓
Adds ALL components:
  - Character (NPC model reference)
  - Transform (position/rotation)
  - Hitbox (combat hitbox reference)
  - Health (HP tracking)
  - Locomotion (movement intent: dir + speed)
  - CombatNPC (marker component)
  - NPCCombatState (passive/aggressive, attack timers)
  - NPCConfig (capture distance, speeds, etc.)
  - NPCMovementPattern (Direct/Strafe/CircleStrafe)
  - NPCSkillScoring (tracks best skill to use)
  - NPCGuardPattern (for guards only)
  - NPCPathfinding (obstacle avoidance state)
  - AIState (wander state - legacy, not used for guards)
  - Traits (AI personality weights)
  - Wander (old wander component - legacy)
  - NPCWander (new wander component - ONLY if canWander=true)
  - NPCSpawnData (spawn position tracking)
    ↓
NPC is ready for ECS systems to control
```

---

## 🎯 Phase 2: Idle State (Guards - No Target)

### When Guard is Standing Still:

**Every Frame (60 Hz):**
```
mob_brain_ecs.luau (8 Hz)
    ↓
  Check: Does NPC have NPCTarget component?
    YES → Skip (npc_movement_pattern_ecs handles it)
    NO  → Continue
    ↓
  Check: Is NPC passive and not attacked?
    YES → Set Locomotion = {dir: 0, speed: 0}
          Skip rest of logic
    NO  → Run wander AI
    ↓
  Result: Guard stands still with Locomotion = {0, 0, 0}
```

**Every Frame (60 Hz):**
```
mob_movement_ecs.luau (20 Hz)
    ↓
  For each NPC with Locomotion component:
    ↓
  Check: Does NPC have knockback states?
    YES → Skip (respect knockback physics)
    NO  → Continue
    ↓
  Read Locomotion component: {dir, speed}
    ↓
  Apply to Humanoid:
    - Humanoid:Move(dir)
    - Humanoid.WalkSpeed = speed
    ↓
  Result: Guard's Humanoid.WalkSpeed = 0, stands still
```

---

## ⚔️ Phase 3: Player Attacks Guard

### Step 1: Damage Detection (happens instantly)

```
Player presses M1
    ↓
Combat system executes
    ↓
DamageService.Tag() called
    ↓
Target is NPC? (IsNPC attribute = true)
    YES ↓
    Creates Damage_Log folder in NPC
    Adds ObjectValue with attacker reference
    ↓
Damage_Log created (SERVER SIDE ONLY)
```

### Step 2: Target Acquisition (15 Hz - runs every 0.067s)

```
npc_targeting_ecs.luau (15 Hz)
    ↓
  For each CombatNPC:
    ↓
  hasBeenAttacked() checks:
    - Does Damage_Log exist?
    - Are there attack records?
    - Is NPC in "RecentlyAttacked" state?
    ↓
  Attack detected!
    ↓
  Update NPCCombatState:
    - isAggressive = true
    - isPassive = false
    - hasBeenAttacked = true
    ↓
  Increase detection ranges:
    - captureDistance = 120
    - letGoDistance = 150
    ↓
  Add NPCTarget component = attacker's Character model
    ↓
  Console: "[npc_targeting_ecs] Guard was attacked!"
  Console: "[npc_targeting_ecs] Guard now targeting PlayerName"
```

---

## 🏃 Phase 4: Guard Chases Player (Active State)

### Brain System (mob_brain_ecs)

```
mob_brain_ecs.luau (8 Hz)
    ↓
  Check: Does NPC have NPCTarget component?
    YES → Skip this NPC (movement pattern handles it)
    ↓
  Result: Guard is SKIPPED by mob_brain_ecs
          (no longer controlled by wander AI)
```

### Movement Pattern System (CRITICAL - Makes Guard Chase)

```
npc_movement_pattern_ecs.luau (8 Hz - every 0.125s)
    ↓
  Query: NPCs with ALL of these:
    - Character ✅
    - Transform ✅
    - NPCTarget ✅ (just added by npc_targeting_ecs)
    - NPCMovementPattern ✅
    - NPCConfig ✅
    - Locomotion ✅
    - CombatNPC ✅
    ↓
  For each NPC with target:
    ↓
  Calculate distance to target
    ↓
  Too close (< 3 studs)?
    YES → Set Locomotion = {dir: 0, speed: 0}
          Skip (stop moving)
    NO  → Continue
    ↓
  Should sprint? (distance > 15 studs)
    YES → speed = runSpeed (24)
    NO  → speed = walkSpeed (16)
    ↓
  Pick movement pattern (every 2-3s):
    - Direct (straight line)
    - Strafe (side-to-side while advancing)
    - SideApproach (approach from side)
    - CircleStrafe (circle around target)
    - ZigZag (zig-zag approach)
    ↓
  Calculate direction vector based on pattern
    ↓
  Apply smooth interpolation (smoothingAlpha = 0.5)
    ↓
  Update Locomotion component:
    Locomotion = {
      dir = smoothedDirection (unit vector),
      speed = 16 or 24
    }
    ↓
  Console: "[npc_movement_pattern_ecs] Guard chasing Player - distance: 25, pattern: Direct"
```

### Movement Application System

```
mob_movement_ecs.luau (20 Hz - every 0.05s)
    ↓
  For each NPC with Locomotion:
    ↓
  Check knockback states:
    - KnockbackStun?
    - ParryKnockback?
    - NoRotate?
    - BlockBreak?
    YES → Skip (don't override knockback)
    NO  → Continue
    ↓
  Read Locomotion component:
    dir = {X, Y, Z}
    speed = 16 or 24
    ↓
  Apply to Humanoid:
    Humanoid:Move(dir)
    Humanoid.WalkSpeed = speed
    ↓
  Update Transform component with new position
    ↓
  Result: Guard actually MOVES toward player!
```

### Pathfinding System (if blocked)

```
npc_pathfinding_ecs.luau (20 Hz)
    ↓
  For each NPC with NPCTarget:
    ↓
  Raycast to target - is path blocked?
    NO  → Set pathfinding.isActive = false
          Skip (use direct movement)
    YES → Continue
    ↓
  Compute pathfinding waypoints (every 0.5s)
    ↓
  Follow waypoints:
    - Calculate direction to next waypoint
    - Update Locomotion component
    - Jump if needed
    ↓
  Result: Guard navigates around obstacles
```

---

## 💥 Phase 5: Guard Attacks Player

### Skill Scoring System

```
npc_skill_scoring_ecs.luau (15 Hz)
    ↓
  For each NPC with NPCTarget:
    ↓
  Get distance to target
    ↓
  Score all available skills:
    - M1 (basic attack)
    - M2 (critical attack)
    - Block
    - Special skills (if equipped)
    ↓
  Scoring factors:
    - Distance to target
    - Target's current action
    - Cooldowns
    - NPC's health
    ↓
  Pick best skill (highest score)
    ↓
  Update NPCSkillScoring:
    bestSkill = "M1"
    bestScore = 85
```

### Combat Execution System

```
npc_combat_execution_ecs.luau (60 Hz)
    ↓
  For each NPC with NPCTarget:
    ↓
  Check global action cooldown (0.5s)
    On cooldown? → Skip
    ↓
  Get best skill from NPCSkillScoring
    ↓
  Execute skill:
    - M1 → MainConfig.performAction("M1")
    - M2 → MainConfig.performAction("Critical")
    - Block → MainConfig.performAction("Block")
    - Skill → MainConfig.performAction(skillName)
    ↓
  Update combat state:
    lastActionTime = now
    lastAttackTime = now
    lastSkillUsed = skillName
    ↓
  Result: Guard punches/attacks player
```

### Defense System

```
npc_defense_ecs.luau (60 Hz)
    ↓
  For each NPC with NPCTarget:
    ↓
  Check defense cooldown (1s)
    On cooldown? → Skip
    ↓
  Detect player's action:
    - Is player attacking?
    - Is player using skill?
    ↓
  Should defend?
    ↓
  Execute defense:
    - Block (30% chance)
    - Parry (15% chance if skilled)
    - Dodge (10% chance)
    ↓
  Result: Guard blocks/parries player attacks
```

### Guard Pattern System (Guards Only)

```
npc_guard_pattern_ecs.luau (60 Hz)
    ↓
  For each guard with NPCTarget:
    ↓
  Is guard aggressive? (has been attacked)
    NO → Skip
    YES → Continue
    ↓
  Check distance to target
    Too far (> 25 studs)? → Skip
    ↓
  Determine pattern state:
    - Defensive (> 15 studs)
    - Aggressive (< 15 studs)
    - Counter (after parry)
    ↓
  Execute pattern-specific behavior:
    Defensive: Block more, retreat if low HP
    Aggressive: M1 combos, skills
    Counter: Immediate attack after parry
    ↓
  Result: Guard uses advanced combat tactics
```

---

## 🎯 Complete Flow Diagram

```
IDLE STATE (No Target):
┌─────────────────────────────────────┐
│  mob_brain_ecs (8 Hz)               │
│  - Guard is passive                 │
│  - Set Locomotion = {0, 0, 0}       │
└──────────────┬──────────────────────┘
               ↓
┌─────────────────────────────────────┐
│  mob_movement_ecs (20 Hz)           │
│  - Apply Locomotion to Humanoid     │
│  - Humanoid:Move(Vector3.zero)      │
│  - Guard stands still               │
└─────────────────────────────────────┘


PLAYER ATTACKS:
┌─────────────────────────────────────┐
│  DamageService.Tag()                │
│  - Create Damage_Log                │
│  - Add attack record                │
└──────────────┬──────────────────────┘
               ↓
┌─────────────────────────────────────┐
│  npc_targeting_ecs (15 Hz)          │
│  - Detect Damage_Log                │
│  - Set isAggressive = true          │
│  - Add NPCTarget component          │
└──────────────┬──────────────────────┘
               ↓
AGGRESSIVE STATE (Has Target):
┌─────────────────────────────────────┐
│  mob_brain_ecs (8 Hz)               │
│  - Has NPCTarget? → SKIP            │
└─────────────────────────────────────┘
               ↓
┌─────────────────────────────────────┐
│  npc_movement_pattern_ecs (8 Hz)    │
│  - Calculate direction to target    │
│  - Pick movement pattern            │
│  - Set Locomotion = {dir, speed}    │
└──────────────┬──────────────────────┘
               ↓
┌─────────────────────────────────────┐
│  npc_pathfinding_ecs (20 Hz)        │
│  - If blocked, use waypoints        │
│  - Update Locomotion with path      │
└──────────────┬──────────────────────┘
               ↓
┌─────────────────────────────────────┐
│  mob_movement_ecs (20 Hz)           │
│  - Read Locomotion component        │
│  - Humanoid:Move(dir)               │
│  - Guard chases player!             │
└──────────────┬──────────────────────┘
               ↓
┌─────────────────────────────────────┐
│  npc_skill_scoring_ecs (15 Hz)      │
│  - Score all available skills       │
│  - Pick best skill                  │
└──────────────┬──────────────────────┘
               ↓
┌─────────────────────────────────────┐
│  npc_combat_execution_ecs (60 Hz)   │
│  - Execute best skill (M1/M2/etc)   │
│  - Guard attacks!                   │
└─────────────────────────────────────┘
               │
               ├──→ npc_defense_ecs (60 Hz)
               │    - Guard blocks/parries
               │
               └──→ npc_guard_pattern_ecs (60 Hz)
                    - Guard uses advanced tactics
```

---

## 🐛 Why Guard Attacks But Doesn't Move

**Symptoms:**
- ✅ Guard detects hit (npc_targeting_ecs working)
- ✅ Guard gets NPCTarget (targeting working)
- ✅ Guard attacks in place (combat execution working)
- ❌ Guard doesn't chase (movement pattern NOT working)

**Root Cause:**

One of these is true:

### Option A: npc_movement_pattern_ecs Not Running
```
npc_movement_pattern_ecs query doesn't match guard
    ↓
Guard is missing required component:
  - Character ❓
  - Transform ❓
  - NPCTarget ✅ (we know this exists)
  - NPCMovementPattern ❓ ← MOST LIKELY MISSING
  - NPCConfig ❓
  - Locomotion ❓
  - CombatNPC ❓
```

### Option B: Locomotion Not Being Applied
```
npc_movement_pattern_ecs sets Locomotion
    ↓
BUT mob_movement_ecs doesn't apply it
    ↓
Reasons:
  - Guard has knockback state stuck
  - System not running for guards
  - Humanoid.WalkSpeed locked at 0
```

---

## 🔍 Debug Logging Added

I'm adding comprehensive debug logging to ALL NPC systems so we can trace exactly what's happening.

**Expected Console Output When Working:**
```
[Scheduler] Loading server system: npc_targeting_ecs
[Scheduler] ✅ Successfully loaded server system: npc_targeting_ecs
...
[Mobs] ⚔️ Initialized COMBAT NPC: RightGuard212 Entity: 314
[Mobs]    - isPassive: true, canWander: false
[Mobs]    - Components: NPCCombatState, NPCMovementPattern, ...
[npc_targeting_ecs] Processing RightGuard212

--- PLAYER ATTACKS ---

[npc_targeting_ecs] RightGuard212 was attacked! Attacker: PlayerName
[npc_targeting_ecs] RightGuard212 entered AGGRESSIVE mode
[npc_targeting_ecs] RightGuard212 now targeting PlayerName
[npc_movement_pattern_ecs] Found 1 guards with targets
[npc_movement_pattern_ecs] GUARD FOUND IN QUERY: RightGuard212 targeting PlayerName
[npc_movement_pattern_ecs] RightGuard212 chasing PlayerName - distance: 25, pattern: Direct
[mob_movement_ecs] RightGuard212 - Locomotion: dir={0.5, 0, 0.866}, speed=24
[npc_skill_scoring_ecs] RightGuard212 - Best skill: M1 (score: 85)
[npc_combat_execution_ecs] RightGuard212 executing M1
```

**If missing any of these messages, we know which system is broken!**
