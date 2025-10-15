# 🐛 M1 WALKSPEED DEBUG

## 🎯 **The Issue**

You said: **"when i sprint it goes up but whenever i m1 or use a skill it doesnt fluxates as normal it doesnt goes up"**

This means:
- ✅ **Sprint works** - Walkspeed changes to 24
- ❌ **M1 doesn't work** - Walkspeed stays at 16
- ❌ **Skills don't work** - Walkspeed doesn't change

---

## 🔍 **Why Sprint Works But M1 Doesn't**

### **Sprint (CLIENT-SIDE):**
1. Client adds `"RunSpeedSet24"` to ECS component
2. Client `state_sync` syncs ECS → StringValue
3. Client `walkspeed_controller` reads StringValue
4. **Works immediately!** ✅

### **M1 (SERVER-SIDE):**
1. Server adds `"M1Speed12"` to ECS component
2. Server `state_sync` syncs ECS → StringValue
3. **StringValue replicates** from server to client
4. Client `walkspeed_controller` reads StringValue
5. **Should work...** but doesn't! ❌

---

## 🧪 **Debug Steps**

I've enabled DEBUG mode on both systems. Now run the game and check console:

### **Step 1: Check State Sync (Server)**

When you M1, look for:
```
[StateSync/Server] Updated YourCharacterName.Speeds: ["M1Speed12"]
```

**Do you see this message on the SERVER console?**

---

### **Step 2: Check State Sync (Client)**

When you M1, look for:
```
[StateSync/Client] Updated YourCharacterName.Speeds: ["M1Speed12"]
```

**Do you see this message on the CLIENT console (F9)?**

---

### **Step 3: Check Walkspeed Controller**

When you M1, look for:
```
[WalkspeedController] WalkSpeed set to 12 (states: M1Speed12)
```

**Do you see this message?**

---

### **Step 4: Manual Check**

Run this in console (F9) when you M1:

```lua
-- Check StringValue
print("Speeds StringValue:", game.Players.LocalPlayer.Character.Speeds.Value)

-- Check actual walkspeed
print("WalkSpeed:", game.Players.LocalPlayer.Character.Humanoid.WalkSpeed)

-- Check if state_sync is running
local world = require(game.ReplicatedStorage.Modules.ECS.jecs_world)
local comps = require(game.ReplicatedStorage.Modules.ECS.jecs_components)
local ref = require(game.ReplicatedStorage.Modules.ECS.jecs_ref)

local entity = ref.get("character", game.Players.LocalPlayer.Character)
if entity then
    local speedsComponent = world:get(entity, comps.StateSpeeds)
    print("ECS StateSpeeds component:", speedsComponent)
else
    print("No entity found for character!")
end
```

---

## 🔧 **Possible Issues**

### **Issue #1: State Sync Not Running on Server**

**Symptom:** No `[StateSync/Server]` message when M1

**Cause:** state_sync system not loaded on server

**Fix:** Check if state_sync.luau is in Systems folder and has `server_only = false`

---

### **Issue #2: State Sync Not Running on Client**

**Symptom:** No `[StateSync/Client]` message when M1

**Cause:** state_sync system not loaded on client

**Fix:** Check if state_sync.luau is in Systems folder and has `server_only = false`

---

### **Issue #3: StringValue Not Replicating**

**Symptom:** Server shows state added, but client doesn't see it

**Cause:** StringValue is not replicating from server to client

**Fix:** Check if Speeds StringValue is in the character (not in a LocalScript folder)

---

### **Issue #4: Walkspeed Controller Not Reading StringValue**

**Symptom:** StringValue updates but walkspeed doesn't change

**Cause:** walkspeed_controller not reading the StringValue correctly

**Fix:** Check console for `[WalkspeedController]` errors

---

### **Issue #5: Something Else Overriding Walkspeed**

**Symptom:** Walkspeed changes briefly then resets

**Cause:** Another script is setting walkspeed back to 16

**Fix:** Search for other scripts that modify `Humanoid.WalkSpeed`

---

## 📊 **Expected Console Output**

### **When you Sprint (Shift):**

**Client Console:**
```
[StateSync/Client] Updated YourName.Speeds: ["RunSpeedSet24"]
[WalkspeedController] WalkSpeed set to 24 (states: RunSpeedSet24)
```

---

### **When you M1:**

**Server Console:**
```
[StateSync/Server] Updated YourName.Speeds: ["M1Speed12"]
```

**Client Console:**
```
[StateSync/Client] Updated YourName.Speeds: ["M1Speed12"]
[WalkspeedController] WalkSpeed set to 12 (states: M1Speed12)
```

---

## 🚨 **If State Sync Shows But Walkspeed Doesn't Change**

If you see `[StateSync/Client]` messages but NO `[WalkspeedController]` messages, then:

1. **walkspeed_controller is not running**
   - Check if it's loaded: Look for "Loading client system: walkspeed_controller"
   - Check if it's in the right folder: `src/ReplicatedStorage/Modules/Systems/`

2. **walkspeed_controller is returning early**
   - Check for error messages like "No Speeds StringValue found!"
   - Check if character exists

3. **walkspeed_controller is running but not updating**
   - The "only update if changed" logic might be broken
   - I already removed this check, so it should always update

---

## 🔍 **Deep Dive: How It Should Work**

### **Server Side (M1 Attack):**
```lua
-- Combat.lua line 67
Server.Library.AddState(Character.Speeds, "M1Speed12")
```

This calls:
```lua
-- Library.lua line 341
StateManager.AddState(character, "Speeds", "M1Speed12")
```

Which updates the ECS component:
```lua
-- StateManager.luau line 97
table.insert(states, "M1Speed12")
world:set(entity, comps.StateSpeeds, states)
```

Then state_sync runs (Heartbeat):
```lua
-- state_sync.luau line 92
syncStateToStringValue(character, "StateSpeeds", "Speeds", states)
```

Which updates the StringValue:
```lua
-- state_sync.luau line 56
stringValue.Value = HttpService:JSONEncode(states) -- ["M1Speed12"]
```

---

### **Client Side (Replication):**

StringValue automatically replicates from server to client (Roblox handles this).

Then walkspeed_controller runs (PreRender):
```lua
-- walkspeed_controller.luau line 80
local speedStates = HttpService:JSONDecode(speedsStringValue.Value)
```

Which should give: `["M1Speed12"]`

Then it extracts the number:
```lua
-- walkspeed_controller.luau line 102
local Number = ConvertToNumber("M1Speed12") -- Returns 12
```

And sets walkspeed:
```lua
-- walkspeed_controller.luau line 119
humanoid.WalkSpeed = 12
```

---

## 🧪 **Test Each Step**

Run these in console to test each step:

### **1. Check if state is added to ECS (Server Console):**
```lua
local world = require(game.ReplicatedStorage.Modules.ECS.jecs_world)
local comps = require(game.ReplicatedStorage.Modules.ECS.jecs_components)
local ref = require(game.ReplicatedStorage.Modules.ECS.jecs_ref)

-- Replace "PlayerName" with your username
local character = workspace:FindFirstChild("PlayerName")
local entity = ref.get("character", character)
if entity then
    local speedsComponent = world:get(entity, comps.StateSpeeds)
    print("Server ECS StateSpeeds:", speedsComponent)
end
```

### **2. Check if StringValue is updated (Server Console):**
```lua
local character = workspace:FindFirstChild("PlayerName")
print("Server Speeds StringValue:", character.Speeds.Value)
```

### **3. Check if StringValue replicated (Client Console F9):**
```lua
print("Client Speeds StringValue:", game.Players.LocalPlayer.Character.Speeds.Value)
```

### **4. Check if walkspeed_controller is reading it (Client Console):**
```lua
-- This should be printed automatically by walkspeed_controller
-- Look for: [WalkspeedController] WalkSpeed set to X
```

---

**Run the game, M1 attack, and tell me what messages you see in console!**

