# Inventory Notification System

A beautiful notification system using Fusion and TextPlus that displays inventory updates at the bottom right of the screen.

## Features

✨ **Fade Diverge Animation** - SwagText-style text animation where characters converge from center
🎨 **Type-Based Styling**:
- **Skills**: Blue text (`Color3.fromRGB(100, 150, 255)`)
- **Items**: Rainbow animated text (cycles through HSV colors)

🌑 **Drop Shadow** - Subtle shadow for depth
📦 **Queue System** - Multiple notifications are queued and shown one at a time
🎯 **Bottom-Right Positioning** - Non-intrusive placement
⚡ **Smooth Animations** - Slide in from right, fade diverge text, slide out
🔄 **Automatic Integration** - Works automatically with your ECS inventory system!

---

## File Structure

```
src/
├── ReplicatedStorage/
│   └── Client/
│       ├── Components/
│       │   └── NotificationComp.lua          # Notification UI component
│       ├── NotificationManager.lua            # Notification queue manager
│       └── InventoryHandler.luau              # Modified to show notifications
```

---

## ✅ Already Integrated!

The notification system is **already integrated** with your ECS inventory system in `InventoryHandler.luau`.

Whenever items or skills are added to your inventory (via `InventoryManager.addItem()`), notifications will automatically appear!

---

## Usage

### Basic Usage

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local NotificationManager = require(ReplicatedStorage.Client.NotificationManager)

-- Show a skill notification
NotificationManager.ShowSkill("Fireball")

-- Show an item notification
NotificationManager.ShowItem("Health Potion")
```

---

## How It Works (Automatic Integration)

The notification system is integrated into `InventoryHandler.luau` and works automatically:

1. **Server adds item** via `InventoryManager.addItem(entity, itemName, itemType, ...)`
2. **Server syncs inventory** to client via `Bridges.Inventory:Fire(player, syncData)`
3. **Client receives update** in `InventoryHandler.luau`
4. **Client compares** new inventory with previous state
5. **Detects new items** or increased quantities
6. **Shows notification** automatically based on item type:
   - `typ == "skill"` → Blue skill notification
   - `typ != "skill"` → Rainbow item notification

### Code Integration (Already Done!)

<augment_code_snippet path="src/ReplicatedStorage/Client/InventoryHandler.luau" mode="EXCERPT">
```lua
-- Detect new items by comparing with previous inventory
local newItems = {}
for slot, item in pairs(syncData.inventory.items) do
    local previousItem = previousInventory[slot]

    if not previousItem then
        -- Brand new item
        table.insert(newItems, {
            name = item.name,
            typ = item.typ,
            quantity = item.quantity
        })
    end
end

-- Show notifications for new items
for _, item in ipairs(newItems) do
    if item.typ == "skill" then
        NotificationManager.ShowSkill(item.name)
    else
        NotificationManager.ShowItem(item.name)
    end
end
```
</augment_code_snippet>

### Manual Usage (If Needed)

You can also manually trigger notifications:

```lua
local NotificationManager = require(ReplicatedStorage.Client.NotificationManager)

-- Show a skill notification
NotificationManager.ShowSkill("Fireball")

-- Show an item notification
NotificationManager.ShowItem("Health Potion")
```

---

## Testing

### Automatic Testing

Just use your existing inventory system! The notifications will appear automatically when:

1. **Player receives starter items** (via `InventorySetup.giveStarterItems()`)
2. **Player learns weapon skills** (via `InventorySetup.giveWeaponSkills()`)
3. **Player picks up items** (via `InventoryManager.addItem()`)
4. **Any server-side inventory addition** that syncs to the client

### Example Test

```lua
-- On the server
local InventoryManager = require(ReplicatedStorage.Modules.Utils.InventoryManager)

-- Add a skill (will show blue notification)
InventoryManager.addItem(playerEntity, "Fireball", "skill", 1, false, "A powerful fire spell")

-- Add an item (will show rainbow notification)
InventoryManager.addItem(playerEntity, "Health Potion", "consumable", 5, true, "Restores 50 HP")
```

---

## Customization

### Change Notification Duration

In `NotificationComp.lua`, line ~200:
```lua
-- Wait before fading out
task.wait(3)  -- Change this number (seconds)
```

### Change Colors

**Skill Color** (line ~100):
```lua
local textColor = if notifType == "Skill" 
    then Color3.fromRGB(100, 150, 255)  -- Change this
    else Color3.fromRGB(255, 255, 255)
```

**Border Color** (line ~150):
```lua
scope:New("UIStroke")({
    Color = if notifType == "Skill" 
        then Color3.fromRGB(100, 150, 255)  -- Skill border
        else Color3.fromRGB(255, 200, 50),  -- Item border
    Thickness = 2,
    Transparency = 0.3,
}),
```

### Change Position

In `NotificationManager.lua`, line ~50:
```lua
holderFrame.Position = UDim2.fromScale(1, 0.95)  -- (X, Y)
-- X: 1 = right edge, 0 = left edge
-- Y: 0.95 = 95% down from top
```

### Change Animation Speed

In `NotificationComp.lua`, line ~190:
```lua
fadeDivergeAnimation(textFrame, 0.01)  -- Lower = faster, higher = slower
```

### Change Rainbow Speed (Items)

In `NotificationComp.lua`, line ~75:
```lua
hue = (hue + 0.01) % 1  -- Increase 0.01 for faster rainbow
task.wait(0.03)         -- Decrease for faster updates
```

---

## API Reference

### NotificationManager

#### `NotificationManager.ShowSkill(skillName: string)`
Shows a skill notification with blue text.

**Parameters:**
- `skillName` - Name of the skill to display

**Example:**
```lua
NotificationManager.ShowSkill("Fireball")
```

---

#### `NotificationManager.ShowItem(itemName: string)`
Shows an item notification with rainbow animated text.

**Parameters:**
- `itemName` - Name of the item to display

**Example:**
```lua
NotificationManager.ShowItem("Health Potion")
```

---

#### `NotificationManager.ClearAll()`
Clears all queued notifications and destroys the current notification.

**Example:**
```lua
NotificationManager.ClearAll()
```

---

## How It Works

### Animation Timeline

```
1. Notification queued
   ↓
2. Previous notification finishes (if any)
   ↓
3. Notification frame slides in from right (0.5s)
   ↓
4. Text animates with fade diverge effect (0.3s)
   - Characters start converged toward center
   - Spread to final positions while fading in
   ↓
5. If Item: Rainbow animation starts
   ↓
6. Wait 3 seconds for player to read
   ↓
7. Notification slides out to right (0.5s)
   ↓
8. Next notification in queue (if any)
```

### Queue System

- Notifications are added to a queue
- Only one notification shows at a time
- When a notification completes, the next one automatically shows
- 0.2s delay between notifications for smooth transitions

---

## Troubleshooting

### Notifications not showing

1. Check console for errors
2. Verify NotificationManager is required correctly
3. Make sure TextPlus module exists at `ReplicatedStorage.Modules.Utils.Text`

### Text not animating

1. Check if TextPlus is working (test with other TextPlus features)
2. Verify the frame is parented to DataModel before rendering
3. Check console for `[NotificationComp]` warnings

### Rainbow not working for items

1. Verify `notifType` is exactly `"Item"` (case-sensitive)
2. Check if the rainbow loop is running (add print statements)

---

## Summary

✅ **Created NotificationComp.lua** - Fusion component with TextPlus  
✅ **Created NotificationManager.lua** - Queue system  
✅ **Created TestNotifications.client.lua** - Test script  
✅ **Fade diverge animation** - SwagText-style text  
✅ **Type-based styling** - Blue for skills, rainbow for items  
✅ **Drop shadow** - Depth effect  
✅ **Queue system** - Smooth sequential notifications  
✅ **Bottom-right positioning** - Non-intrusive  

Ready to integrate with your inventory system! 🎉

