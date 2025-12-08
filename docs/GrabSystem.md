# Grab ECS System

The grab system allows characters (players and NPCs) to grab and hold other characters at a fixed distance using the ECS architecture.

## Overview

There are two grab systems:
- **Client System** (`grab_client.luau`): Handles players grabbing other players
- **Server System** (`grab_server.luau`): Handles NPCs grabbing players/other NPCs

Both systems work by:
1. Monitoring entities with the `Grab` component
2. Positioning the grabbed target at a fixed distance (3 studs) in front of the grabber
3. Using the `Transform` component to update positions smoothly
4. Maintaining the grab for the specified duration

## Component Structure

The `Grab` component has the following structure:

```lua
Grab: Entity<{
    target: Model,        -- The character being grabbed
    value: boolean,       -- Whether the grab is active
    duration: number,     -- How long to hold (0 = infinite)
    startTime: number?,   -- When the grab started (tick())
    distance: number?     -- Distance in studs to hold target (defaults to 3)
}>
```

## Usage Examples

### Making a Player Grab Another Player (Client)

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local world = require(ReplicatedStorage.Modules.ECS.jecs_world)
local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)
local RefManager = require(ReplicatedStorage.Modules.ECS.jecs_ref_manager)

-- Get the grabber's entity
local grabberEntity = RefManager.entity.find(grabberCharacter)

-- Apply the Grab component
world:set(grabberEntity, comps.Grab, {
    target = targetCharacter,
    value = true,
    duration = 5, -- Hold for 5 seconds (0 = infinite)
    startTime = tick(),
    distance = 3 -- Optional: Distance in studs (defaults to 3)
})
```

### Making an NPC Grab a Player (Server)

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local world = require(ReplicatedStorage.Modules.ECS.jecs_world)
local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)
local RefManager = require(ReplicatedStorage.Modules.ECS.jecs_ref_manager)

-- Get the NPC's entity
local npcEntity = RefManager.entity.find(npcCharacter)

-- Apply the Grab component
world:set(npcEntity, comps.Grab, {
    target = playerCharacter,
    value = true,
    duration = 10, -- Hold for 10 seconds
    startTime = tick(),
    distance = 5 -- Optional: Distance in studs (defaults to 3)
})
```

### Releasing a Grab Early

```lua
-- Simply remove the Grab component
world:remove(grabberEntity, comps.Grab)
```

### Infinite Duration Grab

```lua
-- Set duration to 0 for infinite hold
world:set(grabberEntity, comps.Grab, {
    target = targetCharacter,
    value = true,
    duration = 0, -- Infinite
    startTime = tick(),
    distance = 3 -- Optional: Distance in studs (defaults to 3)
})
```

## System Behavior

### Client System (`grab_client.luau`)
- Runs on `RenderStepped` at 60 Hz for smooth positioning
- Only affects player-to-player grabs
- Updates the target's `Transform` component
- Directly sets CFrame for immediate visual feedback
- Cancels target's velocity to prevent movement

### Server System (`grab_server.luau`)
- Runs on `Heartbeat` at 20 Hz (throttled for performance)
- Handles NPC-to-player and NPC-to-NPC grabs
- Checks if grabber can still act (not stunned/ragdolled)
- Applies "Grabbed" stun state to target
- Sets target's `PlatformStand` to true
- Replicates via Transform component updates

## Automatic Grab Release

Grabs are automatically released when:
1. **Duration expires**: The grab duration reaches 0
2. **Target removed**: The target character is destroyed or removed from workspace
3. **Grabber stunned**: (Server only) The grabber becomes stunned or ragdolled
4. **Grab component removed**: The component is manually removed

## Integration with Skills

You can integrate grabs into weapon skills or NPC abilities:

```lua
-- Example: NPC grab skill
local function executeGrabSkill(npcCharacter, targetCharacter)
    local npcEntity = RefManager.entity.find(npcCharacter)

    if npcEntity then
        world:set(npcEntity, comps.Grab, {
            target = targetCharacter,
            value = true,
            duration = 3, -- 3 second grab
            startTime = tick(),
            distance = 4 -- Hold at 4 studs distance
        })
    end
end
```

## Performance Notes

- **Client system**: Updates at 60 Hz for smooth visuals
- **Server system**: Throttled to 20 Hz to reduce server load
- Both systems use cached queries for optimal performance
- Transform component updates are automatically replicated to clients

## Customization

### Distance

You can customize the grab distance per-grab by setting the `distance` field:

```lua
world:set(grabberEntity, comps.Grab, {
    target = targetCharacter,
    value = true,
    duration = 5,
    startTime = tick(),
    distance = 10 -- Hold at 10 studs distance
})
```

If `distance` is not specified, it defaults to 3 studs (defined by `GRAB_DISTANCE` constant in the system files).

### Constants

You can modify these constants in the system files:

- `GRAB_DISTANCE`: Default distance to hold target (default: 3 studs)
- `UPDATE_HZ`: Update frequency (client: 60 Hz, server: 20 Hz)

