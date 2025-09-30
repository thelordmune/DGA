# Alchemy System Rework - Directional Casting

## Overview
The alchemy system has been completely reworked to use a directional casting system instead of fixed Z/X/C key bindings. Players now cast alchemy moves by drawing directional sequences with their mouse.

## Key Changes

### 1. New Directional Casting System
- **File**: `src/ReplicatedStorage/Modules/Utils/DirectionalCasting.lua`
- **Purpose**: Modular casting system with mouse-based directional input
- **Features**:
  - Mouse tracking with shift-lock compatibility
  - **Reduced camera sensitivity during casting (20% of normal)**
  - Visual triangle indicators (Up, Down, Left, Right)
  - Base casting and modifier modes
  - Integration with Library StateManager
  - Fade animations and visual feedback

### 2. Updated Input Scripts

#### Z Key (ZMove.lua)
- **Old**: Fired specific alchemy move based on alchemy type
- **New**: Starts/stops directional casting
- **Behavior**: Press Z to start casting, press Z again to complete and process sequence

#### X Key (XMove.lua) 
- **Old**: Fired specific alchemy move based on alchemy type
- **New**: Controls modifier mode during casting
- **Behavior**: 
  - If not casting: Does nothing
  - If casting: Enters modifier mode (triangles turn red)
  - If in modifier mode: Stops casting and processes both sequences

#### C Key (CMove.lua)
- **Status**: REMOVED - No longer needed with new system

### 3. Comprehensive Combinations System
- **File**: `src/ReplicatedStorage/Modules/Shared/Combinations.luau`
- **Content**: All alchemy moves mapped to directional sequences
- **Format**: D=Down, U=Up, L=Left, R=Right

#### Basic Combinations
```lua
["Construct"] = "DU"              -- Down -> Up
["Cascade"] = "DLR"               -- Down -> Left -> Right  
["Cinder"] = "LRU"                -- Left -> Right -> Up
["AlchemicAssault"] = "DULR"      -- Down -> Up -> Left -> Right
```

#### Advanced Combinations (Base + Modifier)
```lua
["Greater Construct"] = {
    base = "DU",                  -- Base construct
    modifier = "RL"               -- Right -> Left modifier
}
```

### 4. Updated Skills Configuration
- **File**: `src/ReplicatedStorage/Modules/Shared/Skills.luau`
- **Change**: Removed fixed ZMove/XMove/CMove mappings
- **New**: Alchemy types with descriptions for compatibility

### 5. State Management Integration
- Uses Library StateManager for tracking casting states
- States: "IsCasting", "IsModifying"
- Automatic state cleanup on casting end

### 6. Updated UI System
- **File**: `src/ReplicatedStorage/Client/Interface/Stats.lua`
- **Change**: Hotbar now shows casting controls instead of specific moves
- **Display**: "Cast (Z)", "Modifier (X)", "[Type] Alchemy"

## How It Works

### Basic Casting Flow
1. Press **Z** to start casting
2. Move mouse to select directions (triangles light up)
3. Build sequence by moving through directions
4. Press **Z** again to complete cast
5. System matches sequence to alchemy move

### Modifier Casting Flow
1. Start casting with **Z**
2. Build base sequence with mouse movements
3. Press **X** to enter modifier mode (triangles turn red)
4. Build modifier sequence with mouse movements  
5. Press **X** again to complete advanced cast
6. System matches base + modifier to advanced move

### Visual Feedback
- **Gray triangles**: Inactive state
- **Yellow triangles**: Hover state (normal mode)
- **Green triangles**: Active state
- **Red triangles**: Modifier mode
- **Pink triangles**: Modifier hover state
- **White center dot**: Neutral zone indicator

## Alchemy Move Categories

### Stone Alchemy
- Construct, Cascade, Rock Skewer, Stone Wall
- Boulder Throw, Earth Spike, Stone Prison
- Advanced: Earthquake, Meteor

### Flame Alchemy  
- Construct, Cinder, Firestorm, Flame Wall
- Fireball, Flame Burst, Ignite, Inferno
- Advanced: Phoenix Flame

### Basic Alchemy
- Construct, Deconstruct, AlchemicAssault
- Transmute, Purify, Barrier
- Advanced: Greater Construct

## Technical Implementation

### State Tracking
```lua
-- Character states managed by Library StateManager
Actions.IsCasting = true/false
Actions.IsModifying = true/false
```

### Event System
```lua
-- Casting completion event
OnSequenceComplete:Connect(function(baseSequence, modifierSequence, isModifier)
    -- Process alchemy move
end)

-- State change event  
OnCastingStateChanged:Connect(function(isCasting, isModifying)
    -- Update UI/effects
end)
```

### Sequence Format
- Compact string format: "DULR" instead of "DOWN -> UP -> LEFT -> RIGHT"
- Easy to match against combination database
- Efficient for network transmission

### Camera Sensitivity Control
```lua
-- Reduce camera sensitivity during casting
self.originalMouseSensitivity = UserInputService.MouseDeltaSensitivity
UserInputService.MouseDeltaSensitivity = self.originalMouseSensitivity * 0.2

-- Restore after casting
UserInputService.MouseDeltaSensitivity = self.originalMouseSensitivity
```

**How it works:**
- Stores original `MouseDeltaSensitivity` when casting starts
- Reduces sensitivity to 20% of normal (configurable via `CONFIG.CAMERA.CASTING_SENSITIVITY`)
- Camera still moves but much slower and more controllable
- Restores original sensitivity when casting ends
- Works in all camera modes (normal, shift lock, etc.)
- Automatic cleanup on casting system destruction

## Benefits

1. **Unlimited Combinations**: No longer limited to 3 moves per alchemy type
2. **Skill Expression**: Players can learn complex sequences for powerful moves
3. **Intuitive Controls**: Mouse-based directional input feels natural
4. **Expandable**: Easy to add new combinations without UI changes
5. **Immersive**: Casting feels more like drawing magical symbols
6. **Modifier System**: Advanced moves through base + modifier combinations
7. **Camera Control**: Automatic sensitivity reduction during casting for precise directional input

## Demo Script
- **File**: `src/StarterPlayer/StarterPlayerScripts/AlchemyCastingDemo.client.lua`
- **Purpose**: Demonstrates the new casting system
- **Features**: Instructions, example combinations, event logging

## Migration Notes
- Old Z/X/C input scripts updated to use new system
- Skills.luau restructured but maintains alchemy type compatibility
- Hotbar UI updated to show casting controls
- All existing alchemy moves preserved in new combination format
- Library StateManager integration for proper state tracking
- **Character respawn handling**: Casting system automatically recreates when player respawns

## Respawn Handling
The system now properly handles character death and respawning:

```lua
-- Detects character changes and recreates casting instance
if currentCharacter ~= Client.Character then
    if castingInstance then
        castingInstance:Destroy() -- Clean up old instance
    end
    castingInstance = DirectionalCasting.new(Client.Character) -- Create new one
end
```

**Features:**
- Automatic detection of character respawn
- Proper cleanup of old casting instances
- Seamless recreation with new character
- No memory leaks or orphaned UI elements
- Works with all respawn methods (death, teleporting, etc.)

The new system provides a much more engaging and expandable alchemy experience while maintaining all existing functionality.
