# Shell Piercer Voxel Destruction Setup Guide

## Overview

Shell Piercer is fully programmed to blast holes through walls and launch debris. The voxel destruction system is already implemented and working in the code. You just need to set up your walls properly in the workspace.

## How It Works

The Shell Piercer skill:
1. Creates a hitbox in front of the player (8x12x20 studs)
2. Detects all parts in `workspace.Transmutables` folder that have `Destroyable=true` attribute
3. Uses the VoxBreaker module to divide walls into small voxel pieces (minimum 3 studs)
4. Launches the debris forward with trails and physics
5. Debris can damage enemies it hits (5 damage, 8 posture damage)
6. Walls regenerate after 15 seconds

## Setting Up Destructible Walls

### Step 1: Create the Transmutables Folder

1. In Roblox Studio, open the Workspace
2. Create a new Folder named exactly `Transmutables`
3. This folder will hold all destructible walls

### Step 2: Add Your Walls

1. Place your wall parts/models inside the `Transmutables` folder
2. Walls can be Parts or MeshParts
3. For best results, use rectangular parts (not spheres or wedges)

### Step 3: Set the Destroyable Attribute

For each wall part that should be destructible:

1. Select the part in Explorer
2. In the Properties panel, find the Attributes section
3. Click the + button to add a new attribute
4. Name it: `Destroyable`
5. Type: `Boolean`
6. Value: `true` (checked)

### Step 4: Configure Part Properties

Make sure your wall parts have these properties:

```
- Anchored: true (walls should be anchored)
- CanCollide: true (important for detection)
- CanQuery: true (required for hitbox detection)
```

## Example Workspace Structure

```
Workspace
├── Transmutables (Folder)
│   ├── Wall1 (Part)
│   │   └── Attribute: Destroyable = true
│   ├── Wall2 (Part)
│   │   └── Attribute: Destroyable = true
│   ├── Castle (Model)
│   │   ├── WallSection1 (Part)
│   │   │   └── Attribute: Destroyable = true
│   │   ├── WallSection2 (Part)
│   │   │   └── Attribute: Destroyable = true
│   │   └── Door (Part)
│   │       └── Attribute: Destroyable = true
```

## Automatic Setup Script (Optional)

If you have many walls to set up, you can use this script in the Command Bar:

```lua
-- Run this in Roblox Studio Command Bar to automatically set up all walls in Transmutables
local transmutables = workspace:FindFirstChild("Transmutables")
if transmutables then
    for _, descendant in pairs(transmutables:GetDescendants()) do
        if descendant:IsA("Part") or descendant:IsA("MeshPart") then
            descendant:SetAttribute("Destroyable", true)
            descendant.CanCollide = true
            descendant.CanQuery = true
            print("✓ Set up:", descendant.Name)
        end
    end
    print("All walls in Transmutables are now destructible!")
else
    warn("Transmutables folder not found in Workspace!")
end
```

## Voxel Destruction Settings

The Shell Piercer is configured with these destruction parameters:

- **Minimum Voxel Size**: 3 studs (walls break into small chunks)
- **Reset Time**: 15 seconds (walls regenerate after this time)
- **Hitbox Size**: 4x5x14 studs (wide and deep for piercing effect)
- **Debris Speed**: 50-80 studs/second
- **Debris Trails**: White glowing trails with physics

## Testing

1. Equip Guns weapon
2. Use Shell Piercer skill (should be in your hotbar)
3. Aim at a wall in the Transmutables folder
4. The skill should:
   - Blast a hole through the wall
   - Launch debris forward with white trails
   - Debris can hit and damage enemies
   - Wall regenerates after 15 seconds

## Troubleshooting

### Walls not breaking?

**Check:**
- Is the wall inside `workspace.Transmutables`? (exact spelling, case-sensitive)
- Does the wall part have `Destroyable=true` attribute?
- Is the part's `CanQuery` property set to `true`?
- Is the part actually being hit by the skill hitbox? (Try larger walls for testing)

### Debris not launching?

**Check:**
- The debris physics system is fully implemented
- Make sure your walls are big enough (minimum 3 studs to subdivide)
- Try using rectangular walls first (easier to voxelize than irregular shapes)

### Walls not regenerating?

**Check:**
- The VoxBreaker module handles regeneration automatically
- Default reset time is 15 seconds
- Original wall transparency/collision properties are restored

## Advanced: Customizing Voxel Behavior

If you want to customize the destruction behavior, edit these values in Shell Piercer.lua (lines 102-129):

```lua
-- Hitbox size for wall detection (line 103)
local hitboxSize = Vector3.new(4, 5, 14) -- Width, Height, Depth

-- Minimum voxel size (line 126)
3, -- Smaller = more pieces, bigger hole

-- Time to reset walls (line 127)
15, -- Seconds until wall regenerates
```

## Notes

- The voxel destruction system uses PartCache for performance
- Destroyed parts are pooled and reused to prevent lag
- Debris automatically damages enemies it hits during flight
- The system works with both regular Parts and MeshParts
- You can add SurfaceAppearances and textures to walls - they'll copy to debris

---

## Already Implemented Features ✓

The Shell Piercer skill already has all these features working in the code:

- ✓ Voxel wall destruction with VoxBreaker module
- ✓ Debris physics with BodyVelocity and rotation
- ✓ White glowing trails on debris particles
- ✓ Debris collision damage to enemies (5 damage, 8 posture)
- ✓ Wall regeneration after 15 seconds
- ✓ Smart hitbox filtering (only hits Transmutables, never characters)
- ✓ PartCache optimization for performance
- ✓ Random debris trajectories with spread
- ✓ Trail visual effects with fade and transparency

**You just need to set up the walls in workspace as described above!**
