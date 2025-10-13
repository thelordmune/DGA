# TextPlus Dialogue System Guide

## Overview

The dialogue system now uses **TextPlus** for beautiful, animated text rendering! TextPlus provides:
- ✨ Smooth character-by-character animations
- 🎨 Custom fonts support
- 📝 Advanced text styling (stroke, shadow, rotation)
- ⚡ Better performance than default Roblox text
- 🎯 Precise character spacing control

## What Changed

### Before (Old System)
- Used `RichText.AnimateText()` for text animation
- Used a single TextLabel for dialogue text
- Limited styling options
- Basic fade/diverge effects

### After (New System with TextPlus)
- Uses `TextPlus.Create()` for text rendering
- Uses a Frame container with individual character instances
- Character-by-character slide-up + fade-in animation
- Full control over text appearance
- Support for custom fonts

## Files Modified

1. **`src/ReplicatedStorage/Client/Components/DialogueComp.lua`** (MODIFIED)
   - Replaced `RichText` with `TextPlus`
   - Changed from TextLabel to Frame container
   - Added `animateTextIn()` function for character animations
   - **UI layout remains exactly the same!**

## How It Works

### Text Rendering Flow

1. **Dialogue text changes** → Triggers `Computed` function
2. **Clear previous text** → Removes old characters
3. **Render with TextPlus** → `TextPlus.Create()` creates character instances
4. **Animate characters** → Each character slides up and fades in

### Animation Details

```lua
-- Each character starts:
- Invisible (Transparency = 1)
- Offset down by 8 pixels
- Position: originalPos + UDim2.fromOffset(0, 8)

-- Then tweens to:
- Visible (Transparency = 0)
- Original position
- Duration: 0.25 seconds
- Easing: Cubic Out
- Delay between characters: 0.02 seconds
```

## Customization Options

### Current Settings (in DialogueComp.lua)

```lua
-- Around line 85-92
TextPlus.Create(textFrame, currentText, {
    Font = Font.new("rbxasset://fonts/families/SourceSansPro.json"),
    Size = 18,
    Color = Color3.fromRGB(255, 255, 255),
    Transparency = 1, -- Start invisible for animation
    XAlignment = "Left",
    YAlignment = "Top",
})
```

### Available Options

You can customize the text appearance by modifying the options table:

```lua
{
    -- Font (Roblox font or custom font)
    Font = Font.new("rbxasset://fonts/families/SourceSansPro.json"),
    
    -- Size
    Size = 18,
    
    -- Color and transparency
    Color = Color3.fromRGB(255, 255, 255),
    Transparency = 0,
    
    -- Stroke (outline)
    StrokeSize = 2,
    StrokeColor = Color3.fromRGB(0, 0, 0),
    StrokeTransparency = 0.5,
    
    -- Shadow
    ShadowOffset = Vector2.new(2, 2),
    ShadowColor = Color3.fromRGB(0, 0, 0),
    ShadowTransparency = 0.5,
    
    -- Spacing
    CharacterSpacing = 1.0,  -- 1 = normal, <1 = tighter, >1 = wider
    LineHeight = 1.2,
    
    -- Alignment
    XAlignment = "Left",  -- "Left", "Center", "Right", "Justified"
    YAlignment = "Top",   -- "Top", "Center", "Bottom", "Justified"
    
    -- Sorting (for advanced animations)
    WordSorting = false,  -- Creates folders for each word
    LineSorting = false,  -- Creates folders for each line
}
```

## Animation Speed

To change how fast the text appears, modify the delay in the animation call:

```lua
-- In DialogueComp.lua, around line 95
task.spawn(function()
    animateTextIn(textFrame, 0.02)  -- Change this value
    --                      ^^^^
    --                      Delay between characters (seconds)
    --                      0.01 = faster, 0.05 = slower
end)
```

## Using Custom Fonts

TextPlus supports custom fonts! Here's how to add one:

### Step 1: Create a Font Module

Create a ModuleScript tagged with "Fonts" in CollectionService:

```lua
-- Example: ReplicatedStorage.Modules.CustomFonts
return {
    MyCustomFont = {
        Image = 123456789,  -- Asset ID of font spritesheet
        Size = 32,          -- Base size of font
        Characters = {
            ["A"] = {width, height, offset, xAdvance, ...},
            ["B"] = {width, height, offset, xAdvance, ...},
            -- ... more characters
        }
    }
}
```

### Step 2: Tag the Module

1. Select the ModuleScript in Studio
2. Open the Tags window (View → Tags)
3. Add the tag: `Fonts`

### Step 3: Use in Dialogue

```lua
local CustomFonts = require(ReplicatedStorage.Modules.CustomFonts)

TextPlus.Create(textFrame, currentText, {
    Font = CustomFonts.MyCustomFont,  -- Use custom font
    Size = 18,
    Color = Color3.fromRGB(255, 255, 255),
})
```

## Advanced: Per-Character Effects

Want to make certain words shine or bounce? Use `WordSorting`:

```lua
-- Enable word sorting
TextPlus.Create(textFrame, "Hello fantastic world!", {
    Font = Font.new("rbxasset://fonts/families/SourceSansPro.json"),
    Size = 18,
    Color = Color3.fromRGB(255, 255, 255),
    WordSorting = true,  -- Enable word sorting
})

-- Now you can animate specific words
task.spawn(function()
    -- Word 2 is "fantastic"
    local word2Folder = textFrame:FindFirstChild("2")
    if word2Folder then
        for _, character in word2Folder:GetChildren() do
            -- Make it shine!
            TweenService:Create(character, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
                ImageColor3 = Color3.fromRGB(255, 255, 0)
            }):Play()
        end
    end
end)
```

## Example: Adding Stroke to Dialogue

To add an outline to dialogue text for better readability:

```lua
-- In DialogueComp_TextPlus.lua, modify the TextPlus.Create call:
TextPlus.Create(textFrame, currentText, {
    Font = Font.new("rbxasset://fonts/families/SourceSansPro.json"),
    Size = 18,
    Color = Color3.fromRGB(255, 255, 255),
    Transparency = 1,
    
    -- Add stroke
    StrokeSize = 2,
    StrokeColor = Color3.fromRGB(0, 0, 0),
    StrokeTransparency = 0.3,
    
    WordSorting = false,
})
```

## Troubleshooting

### Text not appearing?
- Check that `displayText` is being set correctly
- Verify `start` and `framein` states are true
- Look for errors in the console

### Animation too fast/slow?
- Adjust the delay in `animateTextIn(textFrame, 0.02)`
- Modify the tween duration in the TweenInfo

### Characters overlapping?
- Adjust `CharacterSpacing` in the options
- Try values like 1.1 or 1.2 for more space

### Want instant text (no animation)?
- Set all characters to visible immediately:
```lua
TextPlus.Create(textFrame, currentText, {
    Font = Font.new("rbxasset://fonts/families/SourceSansPro.json"),
    Size = 18,
    Color = Color3.fromRGB(255, 255, 255),
    Transparency = 0,  -- Start visible (no animation)
})
```

## Resources

- **TextPlus Documentation**: https://alexxander.gitbook.io/textplus
- **TextPlus GitHub**: https://github.com/AlexanderLindholt/TextPlus
- **Example File**: `MenuButton_TextPlus.lua` (in workspace root)
- **Demo File**: `TextPlus_Demo.lua` (in workspace root)

## Summary

✅ **Dialogue now uses TextPlus** for beautiful animated text  
✅ **Character-by-character animations** with slide-up + fade-in  
✅ **Fully customizable** - fonts, colors, stroke, shadow, spacing  
✅ **Better performance** than old RichText system  
✅ **Custom fonts support** via CollectionService tags  

Enjoy your new dialogue system! 🎉

