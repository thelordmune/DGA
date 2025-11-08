# Viewport Notification System (VPNoti)

A viewport-based notification system that displays NPC models with text instructions, perfect for tutorials and quest guidance.

## Overview

The VPNoti system consists of two main components:
1. **VPNoti Component** (`src/ReplicatedStorage/Client/Components/VPNoti.lua`) - The Fusion-based UI component
2. **VPNotiManager** (`src/ReplicatedStorage/Client/VPNotiManager.lua`) - Manager for showing/hiding notifications

## Features

✨ **Viewport NPC Display** - Shows 3D NPC models in a viewport frame
📝 **TextPlus Integration** - Uses TextPlus for high-quality text rendering
🎨 **Smooth Animations** - Spring-based fade in/out animations
⏱️ **Auto-dismiss** - Configurable duration with auto-hide
🔄 **Queue Support** - Automatically hides previous notifications before showing new ones

---

## Usage

### Basic Example

```lua
local VPNotiManager = require(ReplicatedStorage.Client.VPNotiManager)

-- Show a notification with Sam NPC
VPNotiManager.Show({
	npc = "Sam", -- NPC name from ReplicatedStorage.Assets.Viewports
	text = "Welcome to the tutorial!",
	duration = 5, -- seconds (optional, defaults to 5)
	onComplete = function()
		print("Notification closed")
	end
})

-- Hide the current notification
VPNotiManager.Hide()

-- Check if a notification is showing
if VPNotiManager.IsShowing() then
	print("A notification is currently visible")
end
```

### Using with Model Instance

```lua
-- You can also pass a Model instance directly
local npcModel = ReplicatedStorage.Assets.Viewports.Sam

VPNotiManager.Show({
	npc = npcModel,
	text = "Press Q to dash!",
	duration = 4,
})
```

### Sequential Notifications

```lua
-- Chain notifications with callbacks
VPNotiManager.Show({
	npc = "Sam",
	text = "First, learn to dash.",
	duration = 3,
	onComplete = function()
		task.wait(1)
		
		VPNotiManager.Show({
			npc = "Sam",
			text = "Now try blocking!",
			duration = 3,
		})
	end
})
```

---

## Integration with Quest System

The VPNoti system is integrated with Sam's quest for the tutorial sequence. Here's how it works:

### Sam's Quest Tutorial

When the player reaches the quest marker, a sequence of viewport notifications guides them through:

1. **Introduction** - Welcome message
2. **Dash Tutorial** - "Press Q to dash forward!"
3. **Parry Tutorial** - "Press F to parry incoming attacks."
4. **Block Tutorial** - "Hold Right Mouse Button to block attacks."
5. **Attack Tutorial** - "Left click to perform basic attacks."
6. **Alchemy Tutorial** - "Press G then Z to spawn an alchemy wall!"
7. **Alchemy Explanation** - "Alchemy lets you manipulate elements..."

### Implementation in Quest Module

```lua
-- In src/ReplicatedStorage/Modules/QuestsFolder/Sam.lua (client-side)

OnStageStart = function(stage, questData)
	if stage == 1 then
		local VPNotiManager = require(Replicated.Client.VPNotiManager)
		local samModel = Replicated.Assets.Viewports:FindFirstChild("Sam")
		
		-- Show tutorial when player reaches marker
		VPNotiManager.Show({
			npc = samModel,
			text = "Welcome to the Military Exam!",
			duration = 4,
			onComplete = function()
				-- Next tutorial step...
			end
		})
	end
end
```

---

## Component API

### VPNoti Component

The Fusion component that renders the viewport notification.

**Props:**
- `npc` (Model?) - The NPC model to display in the viewport
- `text` (string?) - The text to display
- `visible` (Fusion.Value<boolean>?) - Controls visibility (optional)
- `onComplete` (function?) - Callback when notification completes
- `Parent` (Instance?) - Parent GUI element

**Example:**
```lua
local scope = Fusion.scoped(Fusion)

scope:VPNoti({
	npc = npcModel,
	text = "Hello, player!",
	visible = scope:Value(true),
	Parent = playerGui,
})
```

### VPNotiManager API

#### `VPNotiManager.Show(config)`

Shows a viewport notification.

**Parameters:**
- `config.npc` (Model | string) - NPC model or name from ReplicatedStorage.Assets.Viewports
- `config.text` (string) - Text to display
- `config.duration` (number?) - Duration in seconds (default: 5, set to 0 for manual dismiss)
- `config.onComplete` (function?) - Callback when notification completes

**Returns:** Nothing

#### `VPNotiManager.Hide()`

Hides the current notification immediately.

**Returns:** Nothing

#### `VPNotiManager.IsShowing()`

Checks if a notification is currently visible.

**Returns:** `boolean`

---

## NPC Model Setup

NPC models for viewports should be placed in:
```
ReplicatedStorage
└── Assets
    └── Viewports
        ├── Sam
        ├── Magnus
        └── [Other NPCs]
```

### Model Requirements

1. **Must have a PrimaryPart** or **HumanoidRootPart**
2. **Humanoid** (optional, for animations)
3. **Properly rigged** for viewport display

The viewport camera automatically positions to frame the upper body/head of the NPC.

---

## Styling

The VPNoti uses the same visual style as other UI components:

- **Background**: Semi-transparent with gradient
- **Border**: Decorative corners and circle pattern
- **Text**: White with shadow and stroke (via TextPlus)
- **Viewport**: 100x100 positioned to the left of the text
- **Animation**: Spring-based fade in/out (GroupTransparency)

---

## Technical Details

### Viewport Setup

```lua
-- Camera positioning
local camera = Instance.new("Camera")
camera.CameraType = Enum.CameraType.Scriptable
camera.FieldOfView = 70

-- Position camera to frame upper body
local headHeight = rootPart.Position.Y + 1.5
camera.CFrame = CFrame.new(0, headHeight, 3) * CFrame.Angles(0, math.rad(180), 0)
```

### Text Rendering

Uses TextPlus for high-quality text with:
- Custom font (rbxassetid://12187607287)
- Drop shadow
- Stroke outline
- Left-aligned, top-aligned

### Animation

- **Fade In**: Spring animation (30 speed, 1 damping)
- **Fade Out**: Automatic after duration
- **GroupTransparency**: 0 (visible) to 1 (hidden)

---

## Best Practices

1. **Keep text concise** - Viewport notifications are meant for quick instructions
2. **Use appropriate durations** - 3-6 seconds is usually ideal
3. **Chain notifications** - Use callbacks for sequential tutorials
4. **Clean up properly** - VPNotiManager handles cleanup automatically
5. **Test NPC models** - Ensure NPCs are properly positioned in viewport

---

## Troubleshooting

### NPC not showing in viewport
- Check that the NPC model exists in `ReplicatedStorage.Assets.Viewports`
- Ensure the model has a PrimaryPart or HumanoidRootPart
- Verify the model is not anchored incorrectly

### Text not rendering
- Check that TextPlus module is available
- Ensure the text string is not empty
- Verify the textFrame is properly parented

### Notification not hiding
- Call `VPNotiManager.Hide()` explicitly if needed
- Check that duration is set correctly
- Ensure no errors in onComplete callback

---

## Future Enhancements

Potential improvements:
- Support for multiple NPCs in one notification
- Custom camera angles per NPC
- Animation playback in viewport
- Interactive buttons/choices
- Sound effects integration

