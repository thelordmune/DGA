# 🐛 DEBUG: Walkspeed Not Updating

## 🔍 **The Issue**

You said: **"looking at jabby it says the state is being added but the walkspeed is still not being updated when i m1 or anything"**

This means:
1. ✅ States ARE being added to the Speeds StringValue (Jabby shows this)
2. ❌ Walkspeed is NOT being updated

---

## 🧪 **Debug Steps**

### **Step 1: Check if walkspeed_controller is loading**

Look in the console (F9) for these messages:

```
Loading client system: walkspeed_controller
Successfully loaded client system: walkspeed_controller
```

If you DON'T see these messages, the system is not loading!

---

### **Step 2: Check if walkspeed_controller is running**

Look in the console for:

```
[WalkspeedController] ✅ System started successfully!
```

If you DON'T see this message, the system is not running!

---

### **Step 3: Check for errors**

Look for any of these error messages:

```
[WalkspeedController] No LocalPlayer found!
[WalkspeedController] No character found!
[WalkspeedController] No humanoid found!
[WalkspeedController] No Speeds StringValue found!
[WalkspeedController] Failed to parse Speeds JSON: ...
```

---

### **Step 4: Check if states are being added**

Run this in console when you M1:

```lua
print("Speeds:", game.Players.LocalPlayer.Character.Speeds.Value)
```

Should show something like:
```
Speeds: ["M1Speed12"]
```

---

### **Step 5: Check if walkspeed is being set**

Run this in console:

```lua
print("WalkSpeed:", game.Players.LocalPlayer.Character.Humanoid.WalkSpeed)
```

Should show the current walkspeed.

---

## 🔧 **Possible Issues**

### **Issue #1: System Not Loading**

**Symptom:** No "Loading client system: walkspeed_controller" message

**Cause:** System file is not in the right folder or has syntax errors

**Fix:** Make sure `walkspeed_controller.luau` is in `src/ReplicatedStorage/Modules/Systems/`

---

### **Issue #2: System Not Running**

**Symptom:** System loads but no "✅ System started successfully!" message

**Cause:** System is loading but not executing (phase not running, or client_only check failing)

**Fix:** Check if PreRender phase is set up correctly

---

### **Issue #3: Character Not Found**

**Symptom:** "No character found!" error

**Cause:** System is running before character spawns

**Fix:** System should wait for character to exist (already handled in code)

---

### **Issue #4: Speeds StringValue Not Found**

**Symptom:** "No Speeds StringValue found!" error

**Cause:** Character doesn't have a Speeds StringValue

**Fix:** Check if character has Speeds StringValue:
```lua
print(game.Players.LocalPlayer.Character:FindFirstChild("Speeds"))
```

---

### **Issue #5: Old Listener Still Running**

**Symptom:** Walkspeed changes sometimes but not consistently

**Cause:** Old Speeds.Changed listener is still active (not properly commented out)

**Fix:** Make sure the old listener in PlayerHandler is fully commented out

---

### **Issue #6: PreRender Phase Not Running**

**Symptom:** System loads but never executes

**Cause:** PreRender phase is not set up or not running

**Fix:** Check console for phase setup messages:
```
📊 Active phases:
  - PreRender: X systems
```

---

## 🧪 **Manual Test**

Run this in console to manually test the walkspeed logic:

```lua
local HttpService = game:GetService("HttpService")
local character = game.Players.LocalPlayer.Character
local humanoid = character:FindFirstChildOfClass("Humanoid")
local speedsStringValue = character:FindFirstChild("Speeds")

print("Character:", character)
print("Humanoid:", humanoid)
print("Speeds StringValue:", speedsStringValue)
print("Speeds Value:", speedsStringValue.Value)

local speedStates = HttpService:JSONDecode(speedsStringValue.Value)
print("Parsed states:", speedStates)

-- Test ConvertToNumber function
local function ConvertToNumber(String)
    local Number = string.match(String, "%d+$")
    local IsNegative = string.match(String, "[-]%d+$") ~= nil
    if IsNegative and Number then
        Number = "-" .. Number
    end
    return Number and tonumber(Number) or 0
end

for _, state in ipairs(speedStates) do
    if string.match(state, "Speed") then
        local Number = ConvertToNumber(state)
        print(`State: {state}, Number: {Number}`)
    end
end
```

---

## 🔍 **What to Check in Jabby**

1. **Scheduler Tab:**
   - Find "walkspeed_controller" in the list
   - Check if it's paused (should NOT be paused)
   - Check execution time (should be > 0)

2. **World Tab:**
   - Find your player entity
   - Check if it has StateSpeeds component
   - Check the value of StateSpeeds

---

## 📝 **Expected Console Output**

When the system is working correctly, you should see:

```
Loading client system: walkspeed_controller
Successfully loaded client system: walkspeed_controller
📊 Active phases:
  - PreRender: X systems
[WalkspeedController] ✅ System started successfully!
[WalkspeedController] WalkSpeed set to 16 (states: )
[WalkspeedController] WalkSpeed set to 24 (states: RunSpeedSet24)
[WalkspeedController] WalkSpeed set to 16 (states: )
[WalkspeedController] WalkSpeed set to 12 (states: M1Speed12)
[WalkspeedController] WalkSpeed set to 16 (states: )
```

---

## 🚨 **If Nothing Works**

If the system is loading and running but walkspeed still doesn't change:

1. **Check if something else is overriding walkspeed:**
   - Look for other scripts that set `Humanoid.WalkSpeed`
   - Check if there's a Humanoid.Changed event that resets walkspeed

2. **Check if the old listener is still running:**
   - Search for "safeConnect(Speeds, "Changed"" in PlayerHandler
   - Make sure it's fully commented out

3. **Try disabling movement_lock system:**
   - It might be interfering with walkspeed changes
   - Comment out movement_lock.luau temporarily

---

## 🔧 **Quick Fix to Test**

Add this to the top of walkspeed_controller to force it to always print:

```lua
local frameCount = 0
local function walkspeed_controller()
    frameCount = frameCount + 1
    if frameCount % 60 == 0 then -- Print every 60 frames (1 second)
        print(`[WalkspeedController] Frame {frameCount} - System is running!`)
    end
    
    -- ... rest of code ...
end
```

This will confirm the system is actually running every frame.

---

**Run the game and check the console for these debug messages!**

