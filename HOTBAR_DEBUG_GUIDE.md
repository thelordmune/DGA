# Hotbar Debugging Guide

## Overview
Comprehensive debugging has been added to track the hotbar initialization and rendering process. Check the output console for these debug messages.

## Debug Output Locations

### 1. PlayerHandler Initialization
**File:** `src/StarterPlayer/StarterPlayerScripts/PlayerHandler/init.client.lua`

**Output:**
```
[PlayerHandler] ===== HOTBAR INITIALIZATION STARTING =====
[PlayerHandler] Interface module: <module>
[PlayerHandler] InitializeHotbar function: <function>
[PlayerHandler] Getting player entity...
[PlayerHandler] Player entity: <entity_id>
[PlayerHandler] Character: <character_model>
[PlayerHandler] Calling InitializeHotbar...
✅ Initialized Fusion Hotbar
[PlayerHandler] ===== HOTBAR INITIALIZATION COMPLETE =====
```

**What to check:**
- Is the Interface module loaded?
- Is InitializeHotbar function found?
- Is the player entity valid?
- Is the character valid?

---

### 2. Stats Interface Initialization
**File:** `src/ReplicatedStorage/Client/Interface/Stats.lua`

**Output:**
```
[Stats] ===== INITIALIZING HOTBAR =====
[Stats] Character: <character>
[Stats] Entity: <entity_id>
[Stats] UI: <screengui>
[Stats] UI type: ScreenGui
[Stats] UI name: ScreenGui
[Stats] UI children: <count>
[Stats] Hotbar frame not found, creating new one...
[Stats] ✅ Created Hotbar frame: <frame>
[Stats] Loading Hotbar component...
[Stats] Hotbar component loaded, creating scope...
[Stats] Scope created: <scope>
[Stats] Calling Hotbar function...
[Stats] ✅ Hotbar initialized with Fusion component
[Stats] ===== HOTBAR INITIALIZATION COMPLETE =====
```

**What to check:**
- Is UI found?
- Is Hotbar frame created successfully?
- Is Fusion scope created?
- Does the Hotbar component load?

---

### 3. Hotbar Component
**File:** `src/ReplicatedStorage/Client/Components/Hotbar.lua`

**Output:**
```
[Hotbar] ===== HOTBAR COMPONENT STARTING =====
[Hotbar] Character: <character>
[Hotbar] Parent: <frame>
[Hotbar] Parent type: Frame
[Hotbar] Entity: <entity_id>
[Hotbar] updateHotbarDisplay called
[Hotbar] Slot 1: <item_data>
[Hotbar] Slot 2: <item_data>
...
[Hotbar] Hotbar items updated
[Hotbar] Creating hotbar frame...
[Hotbar] Hotbar frame created: <frame>
[Hotbar] Creating 7 hotbar buttons...
[Hotbar] Creating button for slot 1
[Hotbar] Button created for slot 1: <button>
[Hotbar] Animating button 1
...
[Hotbar] ===== HOTBAR COMPONENT COMPLETE =====
```

**What to check:**
- Is the parent frame valid?
- Is the entity valid?
- Are inventory items being retrieved?
- Are buttons being created?
- Are animations being triggered?

---

### 4. HotbarButton Component
**File:** `src/ReplicatedStorage/Client/Components/HotbarButton.lua`

**Output:**
```
[HotbarButton] Creating button for slot 1
[HotbarButton] Parent: <frame>
[HotbarButton] Character: <character>
[HotbarButton] ItemName type: Computed
[HotbarButton] Creating ImageButton for slot 1 with key label: 1
[HotbarButton] ✅ Button created for slot 1: <button>
```

**What to check:**
- Is the parent frame valid?
- Is the character valid?
- Is the item name a Computed value?
- Is the button created successfully?

---

## Troubleshooting Checklist

### Hotbar Not Showing
1. **Check PlayerHandler logs** - Is InitializeHotbar being called?
2. **Check Stats logs** - Is the UI found? Is the Hotbar frame created?
3. **Check Hotbar logs** - Is the component starting?
4. **Check HotbarButton logs** - Are buttons being created?

### Buttons Not Appearing
1. **Check if buttons are created** - Look for "Button created for slot X" messages
2. **Check if parent is valid** - Parent should be a Frame
3. **Check if animations are running** - Look for "Animating button X" messages
4. **Check UI hierarchy** - Open DevTools and inspect the ScreenGui structure

### Cooldowns Not Working
1. **Check if character is valid** - Character should be passed to HotbarButton
2. **Check Library.GetCooldownTime** - Verify the old cooldown system is working
3. **Check RenderStepped connection** - Cooldown updates every frame

### Entity/Inventory Issues
1. **Check if entity is valid** - Entity should be a number (ECS entity ID)
2. **Check InventoryManager** - Verify getHotbarItem returns valid data
3. **Check inventory slots** - Slots 1-7 should have items

---

## Console Output Example

When everything is working correctly, you should see:

```
[PlayerHandler] ===== HOTBAR INITIALIZATION STARTING =====
[PlayerHandler] Interface module: <module>
[PlayerHandler] InitializeHotbar function: <function>
[PlayerHandler] Getting player entity...
[PlayerHandler] Player entity: 12345
[PlayerHandler] Character: Classified
[PlayerHandler] Calling InitializeHotbar...
[Stats] ===== INITIALIZING HOTBAR =====
[Stats] Character: Classified
[Stats] Entity: 12345
[Stats] UI: ScreenGui
[Stats] UI type: ScreenGui
[Stats] UI name: ScreenGui
[Stats] UI children: 5
[Stats] Hotbar frame already exists: Hotbar
[Stats] Loading Hotbar component...
[Stats] Hotbar component loaded, creating scope...
[Stats] Scope created: <scope>
[Stats] Calling Hotbar function...
[Hotbar] ===== HOTBAR COMPONENT STARTING =====
[Hotbar] Character: Classified
[Hotbar] Parent: Hotbar
[Hotbar] Parent type: Frame
[Hotbar] Entity: 12345
[Hotbar] updateHotbarDisplay called
[Hotbar] Slot 1: {name = "Fireball", icon = "..."}
[Hotbar] Slot 2: {name = "Dash", icon = "..."}
...
[Hotbar] Creating 7 hotbar buttons...
[HotbarButton] Creating button for slot 1
[HotbarButton] ✅ Button created for slot 1: <button>
[Hotbar] Animating button 1
...
✅ Initialized Fusion Hotbar
[PlayerHandler] ===== HOTBAR INITIALIZATION COMPLETE =====
```

---

## How to Read the Logs

1. **Open the Output window** in Roblox Studio (View > Output)
2. **Filter by "[Hotbar]"** to see only hotbar-related messages
3. **Look for error messages** - They will start with "❌"
4. **Check the order** - Messages should follow the sequence above
5. **Look for missing steps** - If a step is missing, that's where the issue is

---

## Common Issues

### Issue: "UI not found"
- **Cause:** Client.UI is not initialized
- **Solution:** Check that Interface.Check() is called before InitializeHotbar()

### Issue: "InitializeHotbar function not found"
- **Cause:** Stats module not loaded
- **Solution:** Check that Interface module is loaded correctly

### Issue: "No entity"
- **Cause:** Player entity not synced from server
- **Solution:** Check ECS entity sync in PlayerHandler

### Issue: "Buttons created but not visible"
- **Cause:** Parent frame not visible or positioned off-screen
- **Solution:** Check Hotbar frame position and size in DevTools

