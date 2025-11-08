# Running Speed Debug Guide

## Problem
When joining the server, the running speed doesn't apply the first time you start running.

## Systems Involved

### 1. Input Handler (`src/ReplicatedStorage/Client/Inputs/Run.lua`)
- Detects Shift key press
- Calls `Movement.Run(true)`

### 2. Movement System (`src/ReplicatedStorage/Client/Movement.lua`)
- Line 225: Adds `"RunSpeedSet30"` to Speeds via `Library.AddState(Client.Speeds, "RunSpeedSet30")`
- This updates the **ECS component** (StateSpeeds)

### 3. State Sync System (`src/ReplicatedStorage/Modules/Systems/state_sync.luau`)
- Runs on **Heartbeat** (client-side)
- Syncs ECS components → StringValues
- Line 103: `syncStateToStringValue(character, "StateSpeeds", "Speeds", states)`
- Updates `character.Speeds.Value` to `["RunSpeedSet30"]`

### 4. Walkspeed Controller (`src/ReplicatedStorage/Modules/Systems/walkspeed_controller.luau`)
- Runs on **Heartbeat** with priority 200 (after state_sync)
- Reads from **StringValue** (not ECS)
- Line 83: Parses JSON from `speedsStringValue.Value`
- Line 130: Sets `humanoid.WalkSpeed = modifier` (should be 30)

## Expected Flow

```
1. Player presses Shift
   ↓
2. Movement.Run(true) called
   ↓
3. Library.AddState(Client.Speeds, "RunSpeedSet30")
   ↓
4. StateManager.AddState(character, "Speeds", "RunSpeedSet30")
   ↓
5. ECS component StateSpeeds updated: ["RunSpeedSet30"]
   ↓
6. state_sync runs (Heartbeat)
   ↓
7. Speeds StringValue updated: ["RunSpeedSet30"]
   ↓
8. walkspeed_controller runs (Heartbeat, priority 200)
   ↓
9. Reads Speeds.Value: ["RunSpeedSet30"]
   ↓
10. Extracts number: 30
   ↓
11. Sets Humanoid.WalkSpeed = 30
```

## Potential Issues

### Issue 1: Timing/Race Condition
- `state_sync` and `walkspeed_controller` both run on Heartbeat
- If they run in wrong order, walkspeed_controller reads old value
- **Fix**: walkspeed_controller has `depends_on = {"state_sync"}` and `priority = 200`

### Issue 2: First Frame Delay
- On first join, character might not be fully initialized
- StringValues might not exist yet
- **Check**: Line 76 in walkspeed_controller checks if StringValues exist

### Issue 3: ECS Entity Not Ready
- StateManager.AddState needs entity to exist
- If entity not found, state won't be added
- **Check**: Line 88 in StateManager warns if no entity found

## Debug Steps

### Step 1: Enable Debug Logging
Already enabled in:
- `walkspeed_controller.luau` (line 19): `DEBUG = true`
- `state_sync.luau` (line 31): `DEBUG = true`
- `Movement.lua` (line 224): Added print statements

### Step 2: Join Game and Press Shift
Watch console for these messages:

**Expected Output:**
```
[Movement.Run] ✅ Starting running - adding RunSpeedSet30 to Speeds
[Movement.Run] Speeds.Value after AddState: ["RunSpeedSet30"]
[StateSync/Client] ✅ Updated [Character].Speeds: ["RunSpeedSet30"]
[WalkspeedController] Applied speed modifier: 30, DeltaSpeed set to 30
```

**If you see:**
```
[Movement.Run] ✅ Starting running - adding RunSpeedSet30 to Speeds
[Movement.Run] Speeds.Value after AddState: []
```
→ StateManager.AddState failed (entity not found)

**If you see:**
```
[Movement.Run] Speeds.Value after AddState: ["RunSpeedSet30"]
(no StateSync message)
```
→ state_sync not running or not finding character

**If you see:**
```
[StateSync/Client] ✅ Updated [Character].Speeds: ["RunSpeedSet30"]
(no WalkspeedController message)
```
→ walkspeed_controller not reading the value

### Step 3: Check Walkspeed Value
After pressing Shift, check:
```lua
print(player.Character.Humanoid.WalkSpeed)
```

Should be **30**, not **16**.

## Possible Fixes

### Fix 1: Ensure Entity Exists Before Running
In `Movement.lua`, add entity check:
```lua
local ref = require(ReplicatedStorage.Modules.ECS.jecs_ref)
local playerEntity = ref.get("local_player")
if not playerEntity then
    warn("[Movement.Run] No player entity found!")
    return
end
```

### Fix 2: Force Immediate StringValue Update
Instead of relying on state_sync, update StringValue directly:
```lua
-- In Movement.lua after AddState
local HttpService = game:GetService("HttpService")
local StateManager = require(ReplicatedStorage.Modules.ECS.StateManager)
local states = StateManager.GetAllStates(Client.Character, "Speeds")
Client.Speeds.Value = HttpService:JSONEncode(states)
```

### Fix 3: Change walkspeed_controller Phase
Run on RenderStepped instead of Heartbeat for more immediate response:
```lua
settings = {
    phase = "RenderStepped", -- Changed from Heartbeat
    client_only = true,
}
```

## Testing Checklist

- [ ] Join game fresh
- [ ] Wait 2 seconds for initialization
- [ ] Press Shift to run
- [ ] Check console for debug messages
- [ ] Check Humanoid.WalkSpeed value
- [ ] Try running again (does it work the second time?)
- [ ] Try after respawning (does it work after death?)

## Current Status

**Debug logging enabled in:**
- ✅ walkspeed_controller.luau
- ✅ state_sync.luau  
- ✅ Movement.lua

**Next step:** Test in-game and check console output.

