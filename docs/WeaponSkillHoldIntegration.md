# Weapon Skill Hold System - Integration Guide

## ✅ Integration Complete!

The hold system has been integrated into your existing `Server.WeaponSkills` architecture.

---

## 🔄 How It Works Now

### **Flow:**

1. **Player presses hotbar key (1-7)**
   - Client sends `UseItem` packet with `inputType = "began"`
   
2. **Server receives "began" packet**
   - Checks if skill is a WeaponSkillHold instance
   - If yes: Calls `skill:OnInputBegan(player, character)`
   - If no: Calls old function-based skill

3. **Player releases hotbar key**
   - Client sends `UseItem` packet with `inputType = "ended"`
   
4. **Server receives "ended" packet**
   - Calls `skill:OnInputEnded(player)`
   - Skill executes with hold duration

---

## 📦 Files Modified

### **Client-Side (Input Handlers):**
- ✅ `src/ReplicatedStorage/Client/Inputs/Hotbar1.lua`
- ✅ `src/ReplicatedStorage/Client/Inputs/Hotbar2.lua`
- ✅ `src/ReplicatedStorage/Client/Inputs/Hotbar3.lua`

**Changes:**
- Track held skills per hotbar slot
- Send `inputType = "began"` on press
- Send `inputType = "ended"` on release

### **Server-Side (Skill Execution):**
- ✅ `src/ServerScriptService/ServerConfig/Server/Network/UseItem.lua`

**Changes:**
- Detect if skill is WeaponSkillHold instance
- Call `OnInputBegan` / `OnInputEnded` for hold skills
- Fall back to old function-based skills for compatibility

---

## 🎯 Converting Weapon Skills

### **Option 1: Keep Old System (No Changes Needed)**

Your existing weapon skills will continue to work as-is:

```lua
-- src/ServerScriptService/ServerConfig/Server/WeaponSkills/Spear/Needle Thrust.lua
return function(Player, Data, Server)
    -- Your existing code
    -- Executes immediately when hotbar key is pressed
end
```

### **Option 2: Convert to Hold System**

To enable hold mechanics for a skill:

```lua
-- src/ServerScriptService/ServerConfig/Server/WeaponSkills/Spear/Needle Thrust.lua
local ServerStorage = game:GetService("ServerStorage")
local Replicated = game:GetService("ReplicatedStorage")
local Library = require(Replicated.Modules.Library)
local Skills = require(ServerStorage.Stats._Skills)
local Global = require(Replicated.Modules.Shared.Global)

-- Import the hold system
local SkillFactory = require(Replicated.Modules.Utils.SkillFactory)

-- Create the skill with hold system
local NeedleThrust = SkillFactory.CreateWeaponSkill({
    name = "Needle Thrust",
    animation = Replicated.Assets.Animations.Skills.Weapons.Spear["Needle Thrust"],
    hasBodyMovers = true, -- Has LinearVelocity, so executes immediately
    damage = 3.5,
    cooldown = 6,
    
    execute = function(self, player, character, holdDuration)
        -- Your existing skill code here
        -- holdDuration will be 0 because hasBodyMovers = true
        
        local Server = require(script.Parent.Parent.Parent)
        
        -- Check if this is an NPC
        local isNPC = typeof(player) ~= "Instance" or not player:IsA("Player")
        
        if not isNPC and not character:GetAttribute("Equipped") then
            return
        end
        
        -- Get weapon
        local Weapon
        if isNPC then
            Weapon = character:GetAttribute("Weapon") or "Spear"
        else
            Weapon = Global.GetData(player).Weapon
        end
        
        if Weapon ~= "Spear" then
            return
        end
        
        -- ... rest of your existing code
    end
})

return NeedleThrust
```

---

## 🔧 Skill Configuration

### **hasBodyMovers Flag:**

This determines if a skill can be held:

| hasBodyMovers | Behavior | Use For |
|---------------|----------|---------|
| `false` | **Can be held** | Slashes, projectiles, stationary attacks |
| `true` | **Executes immediately** | Dashes, lunges, teleports (anything with BodyVelocity/LinearVelocity) |

### **Examples:**

```lua
-- CAN BE HELD (no body movers)
local StoneLance = SkillFactory.CreateWeaponSkill({
    name = "Stone Lance",
    hasBodyMovers = false, -- Stationary attack
    -- ...
})

-- EXECUTES IMMEDIATELY (has body movers)
local NeedleThrust = SkillFactory.CreateWeaponSkill({
    name = "Needle Thrust",
    hasBodyMovers = true, -- Uses LinearVelocity to dash
    -- ...
})
```

---

## 📋 Step-by-Step Conversion

### **1. Choose a Skill to Convert**

Start with a simple skill that doesn't use body movers (e.g., "Grand Cleave").

### **2. Add Imports**

```lua
local SkillFactory = require(Replicated.Modules.Utils.SkillFactory)
```

### **3. Wrap in SkillFactory**

```lua
local MySkill = SkillFactory.CreateWeaponSkill({
    name = "My Skill",
    animation = Replicated.Assets.Animations.Skills.Weapons.Spear["My Skill"],
    hasBodyMovers = false, -- or true
    damage = 50,
    cooldown = 8,
    execute = function(self, player, character, holdDuration)
        -- Move your existing code here
    end
})

return MySkill
```

### **4. Move Existing Code**

Copy your existing skill logic into the `execute` function.

### **5. Add Hold Bonuses (Optional)**

```lua
execute = function(self, player, character, holdDuration)
    local damage = self.damage
    
    -- Bonus for holding
    if holdDuration > 0.5 then
        damage = damage * (1 + holdDuration * 0.2) -- +20% per second
        ---- print(`⚡ Charged damage: {damage}`)
    end
    
    -- Your existing skill code with bonuses
end
```

---

## 🎮 Testing

### **Test Old Skills:**
1. Join game
2. Equip weapon
3. Press hotbar key (1-7)
4. Skill should execute immediately (old behavior)

### **Test New Hold Skills:**
1. Convert one skill to hold system
2. Join game
3. Press and **hold** hotbar key
4. Should see blue glow/particles
5. Release key
6. Skill should execute

---

## 🐛 Troubleshooting

### **Skill executes twice**
**Problem:** Both old and new system are running  
**Solution:** Make sure you `return` the SkillFactory instance, not a function

```lua
-- ❌ WRONG
return function(Player, Data, Server)
    -- ...
end

-- ✅ CORRECT
local MySkill = SkillFactory.CreateWeaponSkill({...})
return MySkill
```

### **Skill doesn't hold**
**Problem:** `hasBodyMovers = true` or skill is old function-based  
**Solution:** Set `hasBodyMovers = false` and use SkillFactory

### **Error: "attempt to call a table value"**
**Problem:** Old code trying to call skill as function  
**Solution:** UseItem.lua now handles both types automatically

---

## 📊 Compatibility Matrix

| Skill Type | Old System | New Hold System | Notes |
|------------|-----------|-----------------|-------|
| **Function-based** | ✅ Works | ❌ N/A | Executes immediately |
| **SkillFactory + hasBodyMovers=true** | ✅ Works | ⚠️ No hold | Executes immediately |
| **SkillFactory + hasBodyMovers=false** | ✅ Works | ✅ Can hold | Full hold mechanics |

---

## 🚀 Recommended Conversion Order

1. **Start with simple skills** (no body movers)
   - Grand Cleave
   - Shell Piercer
   - Axe Kick

2. **Then complex skills** (with body movers)
   - Needle Thrust
   - Strategist Combination

3. **Finally alchemy skills** (if desired)
   - Stone Lance
   - Rock Skewer
   - Sky Arc

---

## 💡 Example: Grand Cleave Conversion

### **Before:**

```lua
-- src/ServerScriptService/ServerConfig/Server/WeaponSkills/Spear/Grand Cleave.lua
return function(Player, Data, Server)
    local Character = Player.Character
    if not Character then return end
    
    -- ... existing code
end
```

### **After:**

```lua
-- src/ServerScriptService/ServerConfig/Server/WeaponSkills/Spear/Grand Cleave.lua
local Replicated = game:GetService("ReplicatedStorage")
local SkillFactory = require(Replicated.Modules.Utils.SkillFactory)

local GrandCleave = SkillFactory.CreateWeaponSkill({
    name = "Grand Cleave",
    animation = Replicated.Assets.Animations.Skills.Weapons.Spear["Grand Cleave"],
    hasBodyMovers = false, -- Can be held
    damage = 50,
    cooldown = 6,
    
    execute = function(self, player, character, holdDuration)
        local Server = require(script.Parent.Parent.Parent)
        
        if not character then return end
        
        -- Bonus damage for holding
        local damage = self.damage
        if holdDuration > 0.5 then
            damage = damage * (1 + holdDuration * 0.2)
        end
        
        -- ... rest of existing code
    end
})

return GrandCleave
```

---

## 📚 Additional Resources

- **Full Documentation:** `docs/WeaponSkillHoldSystem.md`
- **Quick Start:** `docs/WeaponSkillHoldQuickStart.md`
- **Example:** `docs/StoneLanceHoldExample.lua`

---

## ✅ Summary

- ✅ **Hotbar inputs** now send InputBegan/InputEnded
- ✅ **UseItem.lua** handles both old and new skills
- ✅ **Old skills** continue to work without changes
- ✅ **New skills** can use hold mechanics
- ✅ **Backward compatible** - convert skills gradually

**You can now convert weapon skills one at a time without breaking existing functionality!** 🎯

