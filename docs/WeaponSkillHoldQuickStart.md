# Weapon Skill Hold System - Quick Start

## 📦 What's Included

Three new files have been created:

1. **`src/ReplicatedStorage/Modules/Utils/WeaponSkillHold.lua`** - Core hold system
2. **`src/ReplicatedStorage/Modules/Utils/SkillFactory.lua`** - Helper factory for creating skills
3. **`docs/WeaponSkillHoldSystem.md`** - Full documentation
4. **`docs/StoneLanceHoldExample.lua`** - Example integration with Stone Lance

---

## 🎯 What It Does

### Weapon Skills (without body movers):
- **Press key** → Animation plays 0.1s then freezes
- **Hold key** → Blue glow and particles appear
- **Release key** → Animation completes and skill executes
- **Bonus**: Longer hold = more damage/range/power (optional)

### Weapon Skills (with body movers):
- Execute immediately (no hold)

### Alchemy Skills:
- Execute immediately (no hold)

---

## 🚀 Quick Integration

### Step 1: Create a Weapon Skill

```lua
local SkillFactory = require(ReplicatedStorage.Modules.Utils.SkillFactory)

local MyWeaponSkill = SkillFactory.CreateWeaponSkill({
    name = "My Skill",
    animation = animations.MySkill,
    hasBodyMovers = false, -- Set to true if skill uses BodyVelocity, LinearVelocity, etc.
    damage = 50,
    cooldown = 8,
    execute = function(self, player, character, holdDuration)
        ---- print(`Skill executed after {holdDuration}s hold`)
        
        -- Your skill logic here
        local damage = self.damage
        
        -- Optional: Bonus for holding
        if holdDuration > 0.5 then
            damage = damage * (1 + holdDuration * 0.2)
        end
        
        -- Create hitbox, deal damage, etc.
    end
})

return MyWeaponSkill
```

### Step 2: Hook Up Input Handler

```lua
-- In your input module (e.g., ZMove.lua)
local currentSkill = nil

InputModule.InputBegan = function(_, Client)
    -- Get the skill for this key
    currentSkill = getPlayerWeaponSkill(Client.Player, "Z")
    
    if currentSkill and currentSkill.OnInputBegan then
        currentSkill:OnInputBegan(Client.Player, Client.Character)
    end
end

InputModule.InputEnded = function(_, Client)
    if currentSkill and currentSkill.OnInputEnded then
        currentSkill:OnInputEnded(Client.Player)
    end
end
```

### Step 3: Create Alchemy Skills (No Hold)

```lua
local AlchemySkill = SkillFactory.CreateAlchemySkill({
    name = "Flame Burst",
    animation = animations.FlameBurst,
    damage = 40,
    cooldown = 5,
    execute = function(self, player, character, holdDuration)
        -- holdDuration will always be 0 for alchemy
        ---- print("Alchemy skill executed immediately")
        
        -- Your alchemy logic here
    end
})
```

---

## 💡 Key Differences

| Skill Type | Hold Mechanic | When to Use |
|------------|---------------|-------------|
| **Weapon (no body movers)** | ✅ Can be held | Attacks, slashes, projectiles |
| **Weapon (with body movers)** | ❌ Executes immediately | Dashes, lunges, teleports |
| **Alchemy** | ❌ Executes immediately | All alchemy skills |

---

## 🎨 Visual Feedback

While holding a weapon skill:
- **Blue PointLight** (Brightness: 2, Range: 10)
- **Blue particles** (20/sec)
- **Animation frozen** at 10% completion

---

## 🔧 Optional: Hold Duration Bonuses

Add these inside your `execute` function:

```lua
execute = function(self, player, character, holdDuration)
    local damage = self.damage
    local range = 30
    
    -- Damage bonus: +20% per second held
    if holdDuration > 0.5 then
        damage = damage * (1 + holdDuration * 0.2)
        ---- print(`⚡ Charged damage: {damage}`)
    end
    
    -- Range bonus: +5 studs per second held
    if holdDuration > 0.5 then
        range = range + (holdDuration * 5)
        ---- print(`⚡ Charged range: {range}`)
    end
    
    -- Your skill logic with bonuses
end
```

---

## 📋 Checklist for Converting Existing Skills

- [ ] Import `SkillFactory` module
- [ ] Wrap skill in `CreateWeaponSkill()` or `CreateAlchemySkill()`
- [ ] Set `hasBodyMovers = true/false` correctly
- [ ] Move skill logic into `execute` function
- [ ] Update input handler to call `OnInputBegan` and `OnInputEnded`
- [ ] Test holding and releasing
- [ ] (Optional) Add hold duration bonuses

---

## 🐛 Troubleshooting

### Skill executes immediately instead of holding
**Problem:** `skillType = "alchemy"` or `hasBodyMovers = true`  
**Solution:** Use `CreateWeaponSkill()` and set `hasBodyMovers = false`

### Animation doesn't freeze
**Problem:** Animation not loaded properly  
**Solution:** Ensure `animation` is a valid Animation instance

### No visual effects while holding
**Problem:** Character not fully loaded  
**Solution:** Ensure character exists before calling `OnInputBegan`

---

## 📚 Full Documentation

See `docs/WeaponSkillHoldSystem.md` for:
- Complete API reference
- Advanced features
- Custom visual effects
- Performance notes

---

## 🎮 Example: Stone Lance

See `docs/StoneLanceHoldExample.lua` for a full working example showing:
- How to convert your existing Stone Lance skill
- Hold duration bonuses (range, size, damage, launch power)
- Integration with your existing systems

---

## 🎯 Next Steps

1. **Test the system** with a simple weapon skill
2. **Convert one existing skill** (e.g., Stone Lance)
3. **Add hold bonuses** if desired
4. **Roll out to all weapon skills**

---

## ⚡ Quick Reference

```lua
-- Weapon skill (can hold)
local Skill = SkillFactory.CreateWeaponSkill({
    name = "Name",
    animation = anim,
    hasBodyMovers = false,
    damage = 50,
    cooldown = 8,
    execute = function(self, player, character, holdDuration)
        -- Your logic
    end
})

-- Alchemy skill (no hold)
local Skill = SkillFactory.CreateAlchemySkill({
    name = "Name",
    animation = anim,
    damage = 40,
    cooldown = 5,
    execute = function(self, player, character, holdDuration)
        -- Your logic (holdDuration always 0)
    end
})

-- Input handler
InputModule.InputBegan = function(_, Client)
    skill:OnInputBegan(Client.Player, Client.Character)
end

InputModule.InputEnded = function(_, Client)
    skill:OnInputEnded(Client.Player)
end
```

---

**Ready to use! Drop the modules into your game and start converting skills.** 🚀

