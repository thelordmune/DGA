# ✅ NPC MainConfig Fix - PlayerStates Error

## 🎯 **The Error**

When you hit an NPC, you got this error:
```
[Library] StringValue "LordMune" parent is not a Model: Folder named "PlayerStates"
```

---

## 🔍 **The Problem**

The `MainConfig.getState()` function had **legacy code** that created StringValues inside a **PlayerStates folder** for players:

### **Old Code (BROKEN):**
```lua
-- For players, use the original PlayerStates system
local statesFolder = game.ReplicatedStorage:FindFirstChild("PlayerStates")
if not statesFolder then
    statesFolder = Instance.new("Folder")
    statesFolder.Name = "PlayerStates"
    statesFolder.Parent = ReplicatedStorage
end

-- Create StringValue inside the folder
local stateValue = statesFolder:FindFirstChild(player.Name)
if not stateValue then
    stateValue = Instance.new("StringValue")
    stateValue.Name = player.Name
    stateValue.Value = "[]"
    stateValue.Parent = statesFolder  -- ❌ Parent is a Folder, not the character!
end

return stateValue
```

### **The Issue:**

When `Library.AddState()` or `Library.StateCheck()` is called with this StringValue, it tries to get the character from `stringValue.Parent`, but the parent is a **Folder**, not a **Model**!

```lua
-- Library.lua line 321-324
if not parent:IsA("Model") then
    warn(`[Library] StringValue "{stringValue.Name}" parent is not a Model: {parent.ClassName} named "{parent.Name}"`)
    return nil
end
```

---

## ✅ **The Fix**

Changed `MainConfig.getState()` to return the Stuns StringValue **directly from the character Model**, just like NPCs do:

### **New Code (FIXED):**
```lua
function MainConfig.getState(player: Model | Player)
    player = player or MainConfig.getNpc()

    -- Get the character model
    local character = player
    if player:IsA("Player") then
        character = player.Character
    end

    if not character then
        warn("MainConfig.getState: No character found for", player.Name)
        return nil
    end

    -- For both NPCs and players, use the standard Stuns state object from the character
    -- This is created by the entity system (Entities.Initialize)
    local stunState = character:FindFirstChild("Stuns")
    if stunState then
        return stunState  -- ✅ Parent is the character Model!
    else
        -- If no Stuns state exists, the character hasn't been properly initialized
        warn("Character", character.Name, "missing Stuns state - may need entity initialization")
        -- Create a temporary state to prevent errors
        local tempState = Instance.new("StringValue")
        tempState.Name = "TempStuns"
        tempState.Value = "[]"
        tempState.Parent = character  -- ✅ Parent is the character Model!
        return tempState
    end
end
```

---

## 🎉 **Why This Works**

### **Before:**
```
ReplicatedStorage
└── PlayerStates (Folder)
    └── LordMune (StringValue)  ← Parent is a Folder! ❌
```

When `Library.AddState()` is called:
1. Gets `stringValue.Parent` → Returns **Folder**
2. Checks `if not parent:IsA("Model")` → **TRUE** (it's a Folder!)
3. **Warns and returns nil** ❌

### **After:**
```
Workspace
└── LordMune (Model)
    └── Stuns (StringValue)  ← Parent is the character Model! ✅
```

When `Library.AddState()` is called:
1. Gets `stringValue.Parent` → Returns **Model** (the character)
2. Checks `if not parent:IsA("Model")` → **FALSE** (it's a Model!)
3. **Works correctly** ✅

---

## 📁 **File Changed**

**`src/ReplicatedStorage/NpcFile/Actor/MainConfig/init.lua`** (lines 458-487)

**Changes:**
- ❌ Removed legacy PlayerStates folder system
- ✅ Now returns Stuns StringValue directly from character Model
- ✅ Works the same for both NPCs and players
- ✅ Compatible with ECS entity system

---

## 🧪 **Test Now:**

1. **Run the game**
2. **Hit an NPC**
3. **Check console** - Should NOT see the error anymore:
   - ❌ OLD: `[Library] StringValue "LordMune" parent is not a Model: Folder named "PlayerStates"`
   - ✅ NEW: No error!
4. **Verify walkspeed still works:**
   - Sprint → Walkspeed = 24 ✅
   - M1 → Walkspeed = 12 ✅
   - Hit NPC → No errors ✅

---

## 🔑 **Key Insight**

The **PlayerStates folder** was a legacy system from before the ECS migration. Now that all characters (both players and NPCs) have StringValues created directly in the character Model by the entity system, we don't need the PlayerStates folder anymore!

**All state StringValues should be children of the character Model, not in a separate folder!**

---

**Test it and let me know if the error is gone!** 🚀

