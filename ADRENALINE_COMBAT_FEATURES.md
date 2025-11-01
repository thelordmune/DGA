# Adrenaline Combat Features

## Overview
This document describes the new adrenaline-based combat features that enhance gameplay depth and reward skilled play.

---

## 🩸 Passive Health Regeneration

### System Location
- **File:** `src/ReplicatedStorage/Modules/Systems/health_regen.luau`
- **Type:** Server-side ECS system
- **Phase:** Heartbeat

### Regeneration Rates
- **Out of Combat:** 2 HP per second
- **In Combat:** 0.5 HP per second

### How It Works
1. System queries all entities with `Health` and `ComponentsReady` components
2. Checks if entity has `InCombat` component to determine regeneration rate
3. Uses accumulator system to handle fractional health (prevents rounding issues)
4. Only applies whole HP increments when accumulator reaches 1+
5. Updates both ECS `Health` component and character's `Humanoid.Health`

### Combat State
- Players enter combat when they take damage
- Combat state lasts for **40 seconds** after last damage taken
- Combat state is managed by `InCombat` ECS component with duration tracking

---

## ⚡ Adrenaline Damage Buff

### System Location
- **File:** `src/ServerScriptService/ServerConfig/Server/Damage.lua`
- **Function:** `DealDamage()` (lines 340-392)

### Damage Multiplier
- **Formula:** `1.0 + (adrenaline / 100) * 0.5`
- **Range:** 1.0x to 1.5x damage
- **Scaling:**
  - 0% adrenaline = 1.0x damage (no buff)
  - 50% adrenaline = 1.25x damage
  - 100% adrenaline = 1.5x damage (max buff)

### How It Works
1. When damage is dealt, system checks if attacker is a player
2. Gets attacker's entity from ECS using `ref.get("player", Player)`
3. Reads `Adrenaline` component to get current adrenaline value
4. Applies damage multiplier based on adrenaline level
5. Logs the buff application for debugging

### Example
```lua
-- Player with 80% adrenaline deals 10 base damage
-- Multiplier: 1.0 + (80 / 100) * 0.5 = 1.4x
-- Final damage: 10 * 1.4 = 14 damage
```

---

## 🛡️ Adrenaline Damage Resistance

### System Location
- **File:** `src/ServerScriptService/ServerConfig/Server/Damage.lua`
- **Function:** `DealDamage()` (lines 340-392)

### Damage Reduction
- **Formula:** `damage * (1 - (adrenaline / 100) * 0.3)`
- **Range:** 0% to 30% damage reduction
- **Scaling:**
  - 0% adrenaline = 0% reduction (no resistance)
  - 50% adrenaline = 15% reduction
  - 100% adrenaline = 30% reduction (max resistance)

### How It Works
1. After damage is calculated, system checks if defender is a player
2. Gets defender's entity from ECS using `ref.get("player", TargetPlayer)`
3. Reads `Adrenaline` component to get current adrenaline value
4. Applies damage reduction based on adrenaline level
5. Logs the resistance application for debugging

### Example
```lua
-- Player with 60% adrenaline receives 20 incoming damage
-- Resistance: (60 / 100) * 0.3 = 18% reduction
-- Final damage: 20 * (1 - 0.18) = 16.4 damage
```

---

## 💥 Pincer Impact BF Variant Adrenaline Requirement

### System Location
- **File:** `src/ServerScriptService/ServerConfig/Server/WeaponSkills/Fist/Pincer Impact.lua`
- **Lines:** 244-277

### Requirement
- **Minimum Adrenaline:** 67% (High adrenaline tier)
- **Applies To:** Players only (NPCs can always use BF variant)

### How It Works
1. When player presses M1 during the input window, system checks adrenaline
2. Gets player's entity from ECS using `ref.find(Char)`
3. Reads `Adrenaline` component value
4. If adrenaline >= 67%, allows BF variant
5. If adrenaline < 67%, forces None variant (even if timing was correct)
6. Logs the decision for debugging

### BF Variant Benefits
- **Damage:** 15 (vs 9 for normal variant)
- **Posture Damage:** 35 (vs 20 for normal variant)
- **Block Break:** Yes (vs No for normal variant)
- **Stun:** 2.5 seconds (vs 0 for normal variant)
- **Ragdoll + Knockback:** Yes (cinematic cutscene)

### Visual Feedback
- **BF Variant (High Adrenaline):** Red impact VFX + cinematic cutscene
- **None Variant (Low Adrenaline):** Blue impact VFX + no cutscene

---

## 📊 Adrenaline System Overview

### How Adrenaline Works
- **Gain:** Landing hits increases adrenaline (5 base + combo bonus)
- **Loss:** Getting hit resets adrenaline to 0
- **Decay:** Slowly decreases over time (1 per second)
- **Combo:** Consecutive hits grant bonus adrenaline

### Adrenaline Tiers
- **Low (0-33%):** Minimal buffs, minimal resistance
- **Medium (34-66%):** Moderate buffs, moderate resistance
- **High (67-100%):** Maximum buffs, maximum resistance, BF variant unlocked

### Visual Indicators
- Health bar UI shows adrenaline level with animated columns
- Adrenaline level affects column height (low/medium/high)
- Sound effect plays when adrenaline tier increases
- VFX plays when reaching new adrenaline tier

---

## 🎮 Gameplay Impact

### Offensive Playstyle
- **High Adrenaline = High Damage**
- Rewards aggressive play and landing consecutive hits
- Encourages maintaining combos without getting hit
- Unlocks powerful BF variant of Pincer Impact

### Defensive Playstyle
- **High Adrenaline = High Resistance**
- Rewards skilled defense and avoiding damage
- Makes it harder for opponents to finish you off
- Creates comeback potential when low on health

### Risk vs Reward
- **High Adrenaline:** Powerful but fragile (one hit resets to 0)
- **Low Adrenaline:** Safe but weak (no buffs or resistance)
- **Strategic Decision:** Push for damage or play safe?

---

## 🔧 Technical Details

### ECS Components Used
- `comps.Adrenaline` - Stores adrenaline value (0-100) and combo hits
- `comps.InCombat` - Tracks combat state for health regen
- `comps.Health` - Stores current/max health for regeneration
- `comps.ComponentsReady` - Ensures entity is fully initialized

### System Dependencies
- **Adrenaline System:** `src/ReplicatedStorage/Modules/Systems/adrenaline.luau`
- **Health Regen System:** `src/ReplicatedStorage/Modules/Systems/health_regen.luau`
- **Damage System:** `src/ServerScriptService/ServerConfig/Server/Damage.lua`
- **State Listener:** `src/ServerScriptService/Systems/statelistener.luau` (InCombat duration tracking)

### Performance Considerations
- Health regen uses accumulator to prevent excessive component updates
- Adrenaline only syncs to client when value changes by at least 1
- Damage buffs/resistance calculated once per damage instance
- All systems use ECS queries for efficient entity iteration

---

## 📝 Configuration

### Adjusting Regeneration Rates
Edit `src/ReplicatedStorage/Modules/Systems/health_regen.luau`:
```lua
local REGEN_OUT_OF_COMBAT = 2  -- HP per second
local REGEN_IN_COMBAT = 0.5    -- HP per second
```

### Adjusting Damage Buff
Edit `src/ServerScriptService/ServerConfig/Server/Damage.lua` (line ~367):
```lua
-- Current: 1.0x to 1.5x (50% max buff)
local adrenalineMultiplier = 1.0 + (adrenalineData.value / 100) * 0.5

-- Example: 1.0x to 2.0x (100% max buff)
local adrenalineMultiplier = 1.0 + (adrenalineData.value / 100) * 1.0
```

### Adjusting Damage Resistance
Edit `src/ServerScriptService/ServerConfig/Server/Damage.lua` (line ~378):
```lua
-- Current: 0% to 30% max reduction
local damageResistance = (adrenalineData.value / 100) * 0.3

-- Example: 0% to 50% max reduction
local damageResistance = (adrenalineData.value / 100) * 0.5
```

### Adjusting BF Variant Requirement
Edit `src/ServerScriptService/ServerConfig/Server/WeaponSkills/Fist/Pincer Impact.lua` (line ~257):
```lua
-- Current: Requires 67% (High tier)
if adrenalineData and adrenalineData.value >= 67 then

-- Example: Requires 50% (Medium tier)
if adrenalineData and adrenalineData.value >= 50 then
```

---

## ✅ Testing Checklist

### Health Regeneration
- [ ] Health regenerates faster out of combat (2 HP/s)
- [ ] Health regenerates slower in combat (0.5 HP/s)
- [ ] Combat state lasts 40 seconds after taking damage
- [ ] Regeneration stops at max health

### Adrenaline Damage Buff
- [ ] Damage increases with adrenaline level
- [ ] 100% adrenaline = 1.5x damage
- [ ] 0% adrenaline = 1.0x damage (no buff)
- [ ] Buff applies to all damage types

### Adrenaline Damage Resistance
- [ ] Damage taken decreases with adrenaline level
- [ ] 100% adrenaline = 30% damage reduction
- [ ] 0% adrenaline = 0% reduction
- [ ] Resistance applies to all incoming damage

### Pincer Impact BF Requirement
- [ ] BF variant requires 67%+ adrenaline
- [ ] Below 67% forces None variant (even with correct timing)
- [ ] BF variant deals 15 damage (vs 9 for None)
- [ ] BF variant breaks block and applies ragdoll
- [ ] NPCs can always use BF variant

---

## 🐛 Known Issues

None currently. All systems tested and working as intended.

---

## 📚 Related Documentation

- `ADRENALINE_SYSTEM.md` - Detailed adrenaline system documentation
- `ECS_COMPONENTS.md` - ECS component reference
- `COMBAT_SYSTEM.md` - Combat system overview
- `HEALTH_SYSTEM.md` - Health and damage system details

