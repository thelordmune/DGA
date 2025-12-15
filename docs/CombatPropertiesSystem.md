# Combat Properties System

## Overview

The Combat Properties System is an intelligent NPC combat decision-making framework that allows NPCs to make smart tactical choices based on:
- Distance to target
- Available skills and cooldowns
- Combat context (aggressive mode, health, etc.)
- Skill properties (range, type, priority)
- Combo opportunities

**IMPORTANT:** NPCs use the **exact same systems as players**:
- Basic combat: `Combat.Light()`, `Combat.Heavy()`, `Combat.Critical()`, `Combat.HandleBlockInput()`
- Weapon skills: Same modules from `ServerScriptService/ServerConfig/Server/WeaponSkills/`
- Alchemy skills: Same modules from `ServerScriptService/ServerConfig/Server/Network/`

The CombatProperties module is **ONLY** for AI decision-making, not skill execution.

## Architecture

### 1. Combat Properties Module
**Location:** `src/ReplicatedStorage/Modules/CombatProperties.lua`

Defines tactical properties for every skill in the game (for AI decision-making only):

```lua
CombatProperties["SkillName"] = {
    SkillType = "Offensive", -- "Offensive" | "Defensive" | "Movement" | "Retreating"
    RangeType = "Close", -- "Close" | "Medium" | "Long"
    TargetingProperties = {
        MinRange = 0,  
        MaxRange = 10, 
        OptimalRange = 5, 
    },
    ComboProperties = {
        IsComboStarter = false,
        IsComboEnder = false,
        FollowupWindow = 0.5,
    },
    DashProperty = nil, -- nil | "Forward" | "Back" | "Side"
    SkillPriority = 0, -- Higher = more likely to use
}
```

### 2. Intelligent Attack System
**Location:** `src/ReplicatedStorage/NpcHelper/Conditions/DefaultActions/Combat/intelligent_attack.lua`

Core decision-making system that:
1. Gets available skills for the NPC (based on weapon, alchemy type)
2. Scores each skill based on:
   - Distance to target vs skill's optimal range
   - Skill priority
   - Aggressive mode bonuses
   - Health-based preferences (defensive when low HP)
   - Combo context (prefer enders after starters)
   - Range type matching
3. **Executes the highest-scoring skill using the same systems players use:**
   - `Combat.Light(npc)` for M1
   - `Combat.Heavy(npc)` for M2
   - `Combat.Critical(npc)` for Critical
   - `Combat.HandleBlockInput(npc, true)` for Block
   - `mainConfig.performAction(skill)` for weapon skills and alchemy skills
     - Weapon skills: Loads from `ServerScriptService/ServerConfig/Server/WeaponSkills/`
     - Alchemy skills: Loads from `ServerScriptService/ServerConfig/Server/Network/` and calls `.EndPoint()`

**Usage in Behavior Trees:**
```lua
Condition("intelligent_attack")
```

### 3. Guard Attack Pattern System
**Location:** `src/ReplicatedStorage/NpcHelper/Conditions/DefaultActions/Combat/guard_attack_pattern.lua`

Specialized pattern-based combat for guards with state machine:

**States:**
- **DEFENSIVE**: Block and wait for player to attack
- **COUNTER**: Quick M1 counter-attack (uses `Combat.Light()`)
- **PRESSURE**: Aggressive follow-up with M2/Critical (uses `Combat.Heavy()` or `Combat.Critical()`)
- **SPECIAL**: Use weapon-specific special skill (uses `mainConfig.performAction()`)
- **RESET**: Return to defensive stance

**Pattern Flow:**
```
DEFENSIVE → (player attacks) → COUNTER → PRESSURE → SPECIAL → RESET → DEFENSIVE
```

**All attacks use the same Combat system as players**, ensuring consistent behavior and damage.

**Usage in Behavior Trees:**
```lua
Condition("guard_attack_pattern")
```

## Skill Categories

### Basic Combat
- **M1**: Close-range combo starter (Priority: 10)
- **M2**: Close-range combo ender (Priority: 7)
- **Critical**: Close-range special with forward dash (Priority: 12)
- **Block**: Defensive skill (Priority: 15)

### Weapon Skills

#### Spear
- **Needle Thrust**: Medium-range gap closer with forward dash (Priority: 11)
- **Grand Cleave**: Close-range powerful combo (Priority: 13)

#### Guns
- **Shell Piercer**: Long-range attack (Priority: 14)
- **Strategist Combination**: Medium-range complex combo (Priority: 15)

#### Fist
- **Downslam Kick**: Close-range combo starter (Priority: 12)
- **Axe Kick**: Close-range guard break combo ender (Priority: 11)

### Boxing Skills
- **Jab Rush**: Close-range combo starter (Priority: 10)
- **Gazelle Punch**: Close-range gap closer with forward dash (Priority: 11)
- **Dempsey Roll**: Close-range ultimate move (Priority: 14)

### Brawler Skills
- **Rising Wind**: Close-range combo (Priority: 12)

### Alchemy Skills

#### Basic (All Types)
- **Construct**: Defensive wall (Priority: 9)
- **Deconstruct**: Medium-range offensive (Priority: 10)
- **AlchemicAssault**: Medium-range complex attack (Priority: 13)

#### Stone Alchemy
- **Cascade**: Medium-range area attack (Priority: 12)
- **Rock Skewer**: Medium-range ground attack (Priority: 11)

#### Flame Alchemy
- **Cinder**: Long-range spreading attack (Priority: 13)
- **Firestorm**: Medium-range powerful AOE (Priority: 14)

## Behavior Trees

### Guard Behavior Tree
**Location:** `src/ReplicatedStorage/NpcHelper/Behaviors/Forest/Guard_BehaviorTree.lua`

Guards use a specialized behavior tree that:
1. Remains passive until attacked
2. Enters aggressive mode when hit
3. Uses guard attack patterns for structured combat
4. Falls back to intelligent attack if pattern fails
5. Returns to defensive stance after combat

**NPCs Using This:**
- LeftGuard
- RightGuard

### Bandit Behavior Tree (Updated)
**Location:** `src/ReplicatedStorage/NpcHelper/Behaviors/Forest/Bandit_BehaviorTree.lua`

Bandits now use intelligent attack system:
1. Aggressive attack loop when in aggressive mode
2. Intelligent attack selection at all ranges
3. Fallback to basic attacks if intelligent system fails

## How It Works

### Example: Guard Combat Flow

1. **Player attacks guard**
   - `enter_aggressive_mode` triggers
   - Guard enters DEFENSIVE state

2. **Guard detects player attacking**
   - Transitions to COUNTER state
   - Uses M1 for quick counter

3. **Guard applies pressure**
   - Transitions to PRESSURE state
   - Uses M2 or Critical based on distance

4. **Guard uses special**
   - Transitions to SPECIAL state
   - Uses weapon skill (e.g., Grand Cleave for Spear)

5. **Guard resets**
   - Transitions to RESET state
   - Clears combo count
   - Returns to DEFENSIVE state

### Example: Bandit Intelligent Attack

1. **Bandit detects player at 12 studs**
   - Gets available skills: M1, M2, Critical, Fist skills
   - Scores each skill:
     - M1: 10 * 1.2 (good range) = 12
     - Critical: 12 * 1.5 (optimal range) = 18 ✓ **BEST**
     - Downslam Kick: 12 * 1.2 = 14.4

2. **Bandit executes Critical**
   - Dashes forward
   - Attacks player
   - Updates last skill used for combo tracking

3. **Next attack at 5 studs**
   - Scores skills again
   - M2 gets combo ender bonus (last skill was starter)
   - M2: 7 * 1.5 (optimal range) * 1.4 (combo ender) = 14.7 ✓ **BEST**

## Adding New Skills

To add a new skill to the system:

1. **Add to CombatProperties.lua:**
```lua
CombatProperties["NewSkill"] = {
    SkillType = "Offensive",
    RangeType = "Medium",
    TargetingProperties = {
        MinRange = 5,
        MaxRange = 20,
        OptimalRange = 12,
    },
    ComboProperties = {
        IsComboStarter = true,
        IsComboEnder = false,
        FollowupWindow = 0.6,
    },
    DashProperty = "Forward",
    SkillPriority = 11,
}
```

2. **Add to intelligent_attack.lua's getAvailableSkills:**
```lua
-- In appropriate weapon/alchemy section
table.insert(availableSkills, "NewSkill")
```

3. **NPCs will automatically use the skill** based on its properties!

## Debugging

The system includes debug print statements:

```lua
-- Intelligent attack
---- print("NPC", npc.Name, "using intelligent attack:", bestSkill, "with score:", bestScore, "at distance:", math.floor(distance))

-- Guard pattern
---- print("Guard", npc.Name, "using pattern:", currentState, "skill:", skillToUse)
---- print("Guard", npc.Name, "transitioning from", oldState, "to", newState)
```

## Performance Considerations

- Skills are scored every attack decision (not every frame)
- Cooldown checks prevent spam
- Pattern state machine is lightweight
- No unnecessary table allocations

## Future Enhancements

Potential improvements:
1. Team coordination (multiple NPCs working together)
2. Learning system (adapt to player patterns)
3. Difficulty scaling (adjust priorities based on difficulty)
4. Special boss patterns
5. Environmental awareness (use terrain, obstacles)

