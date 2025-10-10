# Grand Cleave - Hold System Conversion

## ✅ Conversion Complete!

Grand Cleave has been converted to use the Weapon Skill Hold System.

---

## 🎯 What Changed

### **Before (Old System):**
```lua
return function(Player, Data, Server)
    -- Skill executed immediately when hotbar key pressed
end
```

### **After (New Hold System):**
```lua
local SkillFactory = require(Replicated.Modules.Utils.SkillFactory)

local GrandCleave = SkillFactory.CreateWeaponSkill({
    name = "Grand Cleave",
    animation = Replicated.Assets.Animations.Skills.Weapons.Spear["Grand Cleave"],
    hasBodyMovers = false, -- Can be held
    damage = 50,
    cooldown = 6,
    
    execute = function(self, Player, Character, holdDuration)
        -- Skill executes when key is released
        -- holdDuration = how long the key was held
    end
})

return GrandCleave
```

---

## ⚡ New Features

### **1. Hold Mechanic**
- Press hotbar key → Animation plays 0.1s then freezes
- Hold key → Blue glow and particles appear
- Release key → Animation completes and skill executes

### **2. Hold Bonuses**

#### **Damage Multiplier:**
- Base: 1.0x damage
- +20% per second held
- Example: Hold for 2 seconds = 1.4x damage

#### **Range Multiplier:**
- Base: 1.0x range (10x10x12 hitbox)
- +10% per second held
- Example: Hold for 2 seconds = 1.2x range (12x12x14.4 hitbox)

### **3. Visual Feedback**

While holding:
- Blue PointLight (Brightness: 2, Range: 10)
- Blue particle emitter (20 particles/sec)
- Animation frozen at 10% completion

---

## 🎮 How to Use

### **In-Game:**

1. **Equip Spear weapon**
2. **Add Grand Cleave to hotbar** (should already be there)
3. **Press and HOLD hotbar key** (e.g., key 1)
   - You'll see blue glow/particles
   - Animation freezes
4. **Release key**
   - Animation completes
   - Skill executes with bonuses

### **Testing Hold Bonuses:**

```
No hold (instant release):
- Damage: 1.0x
- Range: 1.0x

Hold for 1 second:
- Damage: 1.2x (+20%)
- Range: 1.1x (+10%)

Hold for 2 seconds:
- Damage: 1.4x (+40%)
- Range: 1.2x (+20%)

Hold for 3 seconds:
- Damage: 1.6x (+60%)
- Range: 1.3x (+30%)
```

---

## 🔧 Technical Details

### **Changes Made:**

1. **Imported SkillFactory**
   ```lua
   local SkillFactory = require(Replicated.Modules.Utils.SkillFactory)
   ```

2. **Wrapped skill in CreateWeaponSkill**
   ```lua
   local GrandCleave = SkillFactory.CreateWeaponSkill({...})
   ```

3. **Added hold duration tracking**
   ```lua
   execute = function(self, Player, Character, holdDuration)
   ```

4. **Calculated hold bonuses**
   ```lua
   local damageMultiplier = 1 + (holdDuration * 0.2)
   local rangeMultiplier = 1 + (holdDuration * 0.1)
   ```

5. **Applied bonuses to all 3 slashes**
   - Slash1: Damage and range multiplied
   - Slash2: Damage and range multiplied
   - Slash3: Damage and range multiplied

6. **Removed manual cooldown**
   ```lua
   -- Cooldown is handled by WeaponSkillHold system
   -- Server.Library.SetCooldown(Character, script.Name, 6)
   ```

---

## 📊 Damage Comparison

### **Slash1 (Base: 5 damage)**

| Hold Time | Damage | Range |
|-----------|--------|-------|
| 0s | 5.0 | 10x10x12 |
| 1s | 6.0 | 11x11x13.2 |
| 2s | 7.0 | 12x12x14.4 |
| 3s | 8.0 | 13x13x15.6 |

### **Slash2 (Base: 7 damage)**

| Hold Time | Damage | Range |
|-----------|--------|-------|
| 0s | 7.0 | 10x10x12 |
| 1s | 8.4 | 11x11x13.2 |
| 2s | 9.8 | 12x12x14.4 |
| 3s | 11.2 | 13x13x15.6 |

### **Slash3 (Base: 10 damage, Block Break)**

| Hold Time | Damage | Range |
|-----------|--------|-------|
| 0s | 10.0 | 10x10x12 |
| 1s | 12.0 | 11x11x13.2 |
| 2s | 14.0 | 12x12x14.4 |
| 3s | 16.0 | 13x13x15.6 |

---

## 🐛 Troubleshooting

### **Skill executes immediately (no hold)**
**Problem:** Old cached version  
**Solution:** Restart server, rejoin game

### **No blue glow/particles**
**Problem:** Character not fully loaded  
**Solution:** Wait a moment after spawning, then try again

### **Damage not increasing**
**Problem:** Not holding long enough  
**Solution:** Hold for at least 0.5 seconds to see bonuses

### **Error in console**
**Problem:** Missing SkillFactory module  
**Solution:** Ensure `src/ReplicatedStorage/Modules/Utils/SkillFactory.lua` exists

---

## 🎯 Next Steps

### **Other Skills to Convert:**

**Easy (No Body Movers):**
- ✅ Grand Cleave (DONE)
- ⬜ Shell Piercer (Guns)
- ⬜ Axe Kick (Fist)
- ⬜ Pincer Impact (Fist)

**Medium (Has Body Movers):**
- ⬜ Needle Thrust (Spear) - Will execute immediately
- ⬜ Strategist Combination (Guns) - Will execute immediately

**Alchemy (Always Immediate):**
- ⬜ Stone Lance
- ⬜ Rock Skewer
- ⬜ Sky Arc

---

## 💡 Tips

1. **Hold for 1-2 seconds** for optimal damage boost
2. **Use against groups** - Increased range hits more enemies
3. **Charge before engaging** - Hold before entering combat
4. **Visual cue** - Blue glow indicates charging

---

**Grand Cleave is now a charged skill! Hold to power up your attacks!** ⚔️

