# Dialogue Animation Styles Guide

## Overview

Your dialogue system now has **3 different animation styles** you can easily switch between! All use TextPlus for smooth, professional-looking text animations.

## ✨ New Features

### **1. Disperse Animation**
When dialogue text changes to the next line, the old text disperses (spreads out and fades away) before the new text converges in. This creates a smooth transition between dialogue lines.

### **2. Horizontal Response Buttons**
Response buttons now appear side by side (horizontal layout) and automatically adjust their size to fit all responses, aligned to the bottom-right.

### **3. Auto-Hide Dialogue**
When the dialogue reaches the end (no more nodes), it waits 5 seconds total (2s for animation + 3s for reading) before automatically closing, giving the player plenty of time to read the final message.

---

## 🎬 Animation Flow

### **Complete Dialogue Cycle:**

1. **Dialogue Opens** → Frame fades in
2. **Text Converges** → Characters spread from center to final positions (fade diverge)
3. **Player Reads** → Text is fully visible
4. **Next Dialogue** → Old text disperses (spreads out and fades away)
5. **New Text Converges** → New characters spread from center
6. **Dialogue Ends** → Auto-closes after 5 seconds (2s animation + 3s reading time)

---

## 🎨 Animation Styles

### **Style 1: Fade Diverge (SwagText Style)** ⭐ DEFAULT

Characters fade in while spreading out from the center, creating a smooth "converge to position" effect.

**Effect:**
- Characters start converged toward the center
- Each character spreads to its final position
- Smooth fade-in during the spread
- Very professional, modern look

**Speed:** 0.015s delay per character (fast and smooth)

**Best for:** 
- Normal dialogue
- Professional/polished feel
- Modern UI aesthetic

---

### **Style 2: Slide Up Fade (Original)**

Characters slide up from below while fading in.

**Effect:**
- Characters start 8 pixels below final position
- Slide up to final position
- Fade in during the slide
- Classic typewriter feel

**Speed:** 0.02s delay per character

**Best for:**
- Traditional dialogue boxes
- Retro/classic feel
- Simple, clean animations

---

### **Style 3: Pop In (Bouncy)**

Characters pop in with a bouncy spring effect.

**Effect:**
- Characters start at size 0
- Spring/bounce to full size
- Fade in during the bounce
- Playful, energetic feel

**Speed:** 0.02s delay per character

**Best for:**
- Happy/excited dialogue
- Comedic moments
- Playful NPCs

---

## 🔧 How to Switch Styles

Open `src/ReplicatedStorage/Client/Components/DialogueComp.lua` and find the `animateTextIn` function (around line 145):

```lua
-- Main animation function (choose your style here!)
local function animateTextIn(textFrame, delayPerChar)
    task.wait(0.05) -- Wait for TextPlus to render
    
    -- Choose animation style:
    fadeDivergeAnimation(textFrame, delayPerChar)  -- SwagText style (DEFAULT)
    -- slideUpAnimation(textFrame, delayPerChar)   -- Original slide up
    -- popInAnimation(textFrame, delayPerChar)     -- Bouncy pop in
end
```

**To change the style:**
1. Comment out the current style (add `--` at the start)
2. Uncomment your desired style (remove `--`)

**Example - Switch to Slide Up:**
```lua
local function animateTextIn(textFrame, delayPerChar)
    task.wait(0.05)
    
    -- fadeDivergeAnimation(textFrame, delayPerChar)  -- Commented out
    slideUpAnimation(textFrame, delayPerChar)          -- Now active!
    -- popInAnimation(textFrame, delayPerChar)
end
```

---

## ⚡ Customization

### **Change Animation Speed**

Modify the delay in the animation call (line ~212):

```lua
-- In the scope:Computed function
animateTextIn(textFrame, 0.015)  -- Change this number
--                      ^^^^
--                      Delay between characters (seconds)
```

**Speed Guide:**
- `0.01` = Very fast (instant feel)
- `0.015` = Fast and smooth (DEFAULT)
- `0.02` = Medium speed
- `0.03` = Slower, more deliberate
- `0.05` = Very slow (dramatic)

---

### **Adjust Diverge Amount**

For the Fade Diverge style, change how far characters spread:

```lua
-- In fadeDivergeAnimation function (around line 45)
local divergeAmount = 8  -- Change this number
--                    ^
--                    Pixels to spread from center
--                    Higher = more spread
--                    Lower = less spread
```

**Diverge Guide:**
- `4` = Subtle spread
- `8` = Medium spread (DEFAULT)
- `12` = Wide spread
- `16` = Very wide spread

---

### **Adjust Slide Distance**

For the Slide Up style, change how far characters slide:

```lua
-- In slideUpAnimation function (around line 93)
character.Position = originalPos + UDim2.fromOffset(0, 8)
--                                                     ^
--                                                     Pixels to slide up from
```

---

### **Change Easing Style**

Modify the tween easing for different feels:

```lua
-- In any animation function
local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)
--                                   ^^^^^^^^^^^^^^^^^^^^
--                                   Change this

-- Options:
-- Enum.EasingStyle.Linear    -- No easing, constant speed
-- Enum.EasingStyle.Cubic     -- Smooth (DEFAULT)
-- Enum.EasingStyle.Quad      -- Gentle
-- Enum.EasingStyle.Quart     -- Strong
-- Enum.EasingStyle.Sine      -- Very smooth
-- Enum.EasingStyle.Back      -- Overshoot (bouncy)
-- Enum.EasingStyle.Elastic   -- Spring effect
-- Enum.EasingStyle.Bounce    -- Bouncing
```

---

## 🎭 Per-NPC Animation Styles

Want different NPCs to have different animation styles? You can pass a style parameter:

```lua
-- In Dialogue.lua, when creating the dialogue component:
scope:Dialogue({
    displayText = dpText,
    npcname = Params.name,
    animationStyle = "fadeDiverge",  -- Add this!
    start = begin,
    Parent = parent,
    fade = fadein,
    responses = resp,
    responseMode = respMode,
})
```

Then in DialogueComp.lua:

```lua
-- Add to props
local animationStyle = props.animationStyle or "fadeDiverge"

-- In animateTextIn function
local function animateTextIn(textFrame, delayPerChar)
    task.wait(0.05)
    
    if animationStyle == "fadeDiverge" then
        fadeDivergeAnimation(textFrame, delayPerChar)
    elseif animationStyle == "slideUp" then
        slideUpAnimation(textFrame, delayPerChar)
    elseif animationStyle == "popIn" then
        popInAnimation(textFrame, delayPerChar)
    else
        fadeDivergeAnimation(textFrame, delayPerChar) -- Default
    end
end
```

---

## 🌟 Advanced: Emotion-Based Animations

You could automatically choose animation based on dialogue emotion:

```lua
local function detectEmotion(text)
    if text:match("!") and text:upper() == text then
        return "angry"
    elseif text:match("%.%.%.") then
        return "sad"
    elseif text:match("😊") or text:match("haha") then
        return "happy"
    else
        return "normal"
    end
end

local function animateTextIn(textFrame, delayPerChar, text)
    task.wait(0.05)
    
    local emotion = detectEmotion(text)
    
    if emotion == "angry" then
        -- Fast, aggressive animation
        fadeDivergeAnimation(textFrame, 0.01)
    elseif emotion == "sad" then
        -- Slow, gentle animation
        slideUpAnimation(textFrame, 0.04)
    elseif emotion == "happy" then
        -- Bouncy, playful animation
        popInAnimation(textFrame, 0.015)
    else
        -- Normal animation
        fadeDivergeAnimation(textFrame, 0.015)
    end
end
```

---

## 📊 Comparison Table

| Style | Speed | Feel | Best For |
|-------|-------|------|----------|
| **Fade Diverge** | Fast (0.015s) | Modern, smooth | Normal dialogue, professional |
| **Slide Up** | Medium (0.02s) | Classic, clean | Traditional dialogue, simple |
| **Pop In** | Medium (0.02s) | Playful, bouncy | Happy NPCs, comedy |

---

## 🎯 Quick Reference

**Current Default:** Fade Diverge (SwagText style)

**To change globally:** Edit line ~147 in `DialogueComp.lua`

**To change speed:** Edit line ~212 in `DialogueComp.lua`

**To customize effect:** Edit the individual animation functions (lines 33-140)

---

## 💡 Tips

1. **Keep it consistent** - Use the same style for all dialogue unless you have a specific reason
2. **Match the tone** - Serious games = subtle animations, playful games = bouncy animations
3. **Test with long text** - Make sure the animation doesn't take too long
4. **Consider readability** - Faster isn't always better if players can't read the text

---

## 🎯 New Features Details

### **Disperse Animation**

**What it does:**
- When dialogue text changes, the old text doesn't just disappear
- Characters spread outward from their positions (opposite of converge)
- Each character fades out while moving away
- Creates a smooth, professional transition

**Customization:**
```lua
-- In disperseAnimation function (around line 147)
local disperseAmount = 12  -- How far characters spread
--                     ^^
--                     Higher = more dramatic disperse
--                     Lower = subtle disperse

delayPerChar = 0.008  -- Speed of disperse
--             ^^^^
--             Lower = faster, Higher = slower
```

**Visual:**
```
Before:  Hello traveler!
         (all visible)

During:  H e l l o   t r a v e l e r !
         → → → → → | ← ← ← ← ← ← ←
         (spreading outward, fading)

After:   [empty]
         (ready for new text)
```

---

### **Horizontal Response Buttons**

**What changed:**
- Response buttons now appear **side by side** (horizontal)
- Frame automatically adjusts to fit all responses
- Buttons align to the bottom-right
- Each button auto-sizes to fit its text
- 10 pixels spacing between buttons

**Layout:**
```
                    [Response 1] [Response 2] [Response 3]
                    ← Horizontal, aligned right
```

**Customization:**
```lua
-- In ResponseFrame (around line 520)
FillDirection = Enum.FillDirection.Horizontal,  -- Side by side
Padding = UDim.new(0, 10),  -- Space between buttons (10 pixels)
--                    ^^
--                    Increase for more spacing
```

---

### **Auto-Hide Dialogue**

**What it does:**
- When dialogue reaches the end (no more nodes):
  1. Waits 2 seconds for animation to complete
  2. Then waits 3 more seconds for player to read
  3. Total: 5 seconds before auto-close
- Gives player plenty of time to read the final message
- No need to manually close or walk away

**Customization:**
```lua
-- In LoadNodes function (around line 658-662)
task.wait(2)  -- Wait for animation to finish
--        ^
--        Animation completion time

task.wait(3)  -- Wait for player to read
--        ^
--        Reading time - increase if players need more time
```

**Disable auto-close:**
```lua
-- In LoadNodes function, comment out the auto-close:
if #Nodes <= 0 then
    DebugPrint("No nodes to load")
    -- task.wait(2)  -- Disabled
    -- Close(Params)  -- Disabled
    -- Now dialogue stays open until player walks away
else
```

---

## 📊 Updated Comparison Table

| Feature | Before | After |
|---------|--------|-------|
| **Text Animation** | Simple fade | Fade diverge (SwagText style) |
| **Text Transition** | Instant clear | Disperse animation |
| **Response Layout** | Horizontal | Vertical stack |
| **Response Sizing** | Fixed width | Auto-size to fit |
| **Dialogue End** | Manual close | Auto-close after 2s |
| **Animation Speed** | 0.02s/char | 0.015s/char (faster) |

---

## 🎮 Testing Checklist

- [ ] Talk to an NPC
- [ ] Watch text converge from center
- [ ] Advance to next dialogue line
- [ ] Watch old text disperse before new text appears
- [ ] Check if response buttons stack vertically
- [ ] Verify multiple responses fit properly
- [ ] Let dialogue reach the end
- [ ] Confirm it auto-closes after 2 seconds

---

Enjoy your new dialogue animations! 🎉

