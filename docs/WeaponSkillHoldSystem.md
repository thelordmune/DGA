# Weapon Skill Hold System

## Overview

The Weapon Skill Hold System allows weapon skills (without body movers) to be held before execution, creating timing-based gameplay and feint opportunities.

### Behavior:

- **Weapon Skills (no body movers)**: Can be held
  - Press key → Animation plays 0.1s then freezes
  - Release key → Animation completes and skill executes
  - Visual feedback: Blue glow and particles while holding

- **Weapon Skills (with body movers)**: Execute immediately
  - No hold mechanic (would conflict with movement)

- **Alchemy Skills**: Always execute immediately
  - No hold mechanic

---

## Installation

The system consists of two modules:

1. `src/ReplicatedStorage/Modules/Utils/WeaponSkillHold.lua` - Core system
2. `src/ReplicatedStorage/Modules/Utils/SkillFactory.lua` - Helper factory

---

## Usage

### Method 1: Using SkillFactory (Recommended)

```lua
local SkillFactory = require(ReplicatedStorage.Modules.Utils.SkillFactory)

-- Create a weapon skill
local StoneLance = SkillFactory.CreateWeaponSkill({
    name = "Stone Lance",
    animation = animations.StoneLance,
    hasBodyMovers = false, -- Can be held
    damage = 50,
    cooldown = 8,
    execute = function(self, player, character, holdDuration)
        print(`Stone Lance held for {holdDuration}s`)
        
        -- Your skill logic here
        local damage = self.damage
        
        -- Optional: Bonus damage for holding longer
        if holdDuration > 0.5 then
            damage = damage * (1 + holdDuration * 0.2)
            print(`Charged damage: {damage}`)
        end
        
        -- Create hitbox, deal damage, etc.
    end
})

-- Create an alchemy skill
local FlameBurst = SkillFactory.CreateAlchemySkill({
    name = "Flame Burst",
    animation = animations.FlameBurst,
    damage = 40,
    cooldown = 5,
    execute = function(self, player, character, holdDuration)
        -- holdDuration will always be 0 for alchemy
        print("Flame Burst executed immediately")
        
        -- Your alchemy logic here
    end
})
```

### Method 2: Direct WeaponSkillHold Usage

```lua
local WeaponSkillHold = require(ReplicatedStorage.Modules.Utils.WeaponSkillHold)

local StoneLance = WeaponSkillHold.new({
    name = "Stone Lance",
    animation = animations.StoneLance,
    skillType = "weapon",
    hasBodyMovers = false,
    damage = 50,
    cooldown = 8
})

function StoneLance:Execute(player, character, holdDuration)
    -- Your skill logic here
end
```

---

## Input Handler Integration

### Weapon Skills (Z, X, C keys)

```lua
-- In ZMove.lua (or XMove.lua, CMove.lua)
local currentSkill = nil

InputModule.InputBegan = function(_, Client)
    local character = Client.Character
    local player = Client.Player
    
    -- Get the weapon skill assigned to this key
    currentSkill = getWeaponSkill(player, "Z") -- Returns skill instance
    
    if currentSkill and currentSkill.OnInputBegan then
        currentSkill:OnInputBegan(player, character)
    end
end

InputModule.InputEnded = function(_, Client)
    if currentSkill and currentSkill.OnInputEnded then
        currentSkill:OnInputEnded(Client.Player)
    end
end

return InputModule
```

### Alchemy Skills (G key or other)

```lua
-- In your alchemy input handler
local currentSkill = nil

InputModule.InputBegan = function(_, Client)
    local character = Client.Character
    local player = Client.Player
    
    -- Get the alchemy skill
    currentSkill = getAlchemySkill(player) -- Returns skill instance
    
    if currentSkill and currentSkill.OnInputBegan then
        -- Will execute immediately because skillType = "alchemy"
        currentSkill:OnInputBegan(player, character)
    end
end

InputModule.InputEnded = function(_, Client)
    -- Alchemy skills don't need InputEnded, but call for consistency
    if currentSkill and currentSkill.OnInputEnded then
        currentSkill:OnInputEnded(Client.Player)
    end
end

return InputModule
```

---

## Example: Converting Existing Stone Lance Skill

### Before (Old System):

```lua
-- src/ServerScriptService/ServerConfig/Server/Network/Stone Lance.lua
local module = {}

module.Execute = function(player, character)
    -- Play animation
    local anim = character.Humanoid:LoadAnimation(animations.StoneLance)
    anim:Play()
    
    -- Create hitbox
    -- Deal damage
    -- etc...
end

return module
```

### After (With Hold System):

```lua
-- src/ServerScriptService/ServerConfig/Server/Network/Stone Lance.lua
local SkillFactory = require(ReplicatedStorage.Modules.Utils.SkillFactory)

local StoneLance = SkillFactory.CreateWeaponSkill({
    name = "Stone Lance",
    animation = ReplicatedStorage.Animations.StoneLance,
    hasBodyMovers = false, -- No body movers, can be held
    damage = 50,
    cooldown = 8,
    execute = function(self, player, character, holdDuration)
        print(`Stone Lance executed after {holdDuration}s hold`)
        
        -- Your existing skill code
        local damage = self.damage
        
        -- Optional: Charge mechanic
        if holdDuration > 0.5 then
            damage = damage * (1 + holdDuration * 0.2) -- +20% per second
            print(`⚡ Charged! Damage: {damage}`)
        end
        
        -- Create hitbox, deal damage, etc.
        -- ... your existing code
    end
})

return StoneLance
```

---

## Advanced Features

### Hold Duration Bonuses

```lua
execute = function(self, player, character, holdDuration)
    local damage = self.damage
    
    -- Damage scales with hold time
    local damageMultiplier = 1 + (holdDuration * 0.2) -- +20% per second
    damageMultiplier = math.min(damageMultiplier, 2.0) -- Cap at 2x
    
    damage = damage * damageMultiplier
    
    -- Range scales with hold time
    local range = 10 + (holdDuration * 2) -- +2 studs per second
    
    print(`Damage: {damage}, Range: {range}`)
end
```

### Perfect Release Timing

```lua
execute = function(self, player, character, holdDuration)
    -- Perfect release window (0.5-1.0 seconds)
    local isPerfectRelease = holdDuration >= 0.5 and holdDuration <= 1.0
    
    if isPerfectRelease then
        print("⭐ PERFECT RELEASE!")
        -- Bonus effects
        damage = damage * 1.5
        -- Play special effect
    end
end
```

### Checking Remaining Cooldown

```lua
local remainingCooldown = skill:GetRemainingCooldown(player)
if remainingCooldown > 0 then
    print(`Skill on cooldown for {remainingCooldown}s`)
end
```

---

## Visual Effects

### While Holding (Automatic):
- Blue PointLight (Brightness: 2, Range: 10)
- Blue particle emitter (20 particles/sec)
- Animation frozen at 10% completion

### Customizing Hold Effects:

Override the `ApplyHoldEffect` method:

```lua
function StoneLance:ApplyHoldEffect(character, isHolding)
    local primaryPart = character.PrimaryPart
    if not primaryPart then return end
    
    if isHolding then
        -- Custom hold effect
        local glow = Instance.new("PointLight")
        glow.Name = "CustomHoldGlow"
        glow.Brightness = 5
        glow.Range = 20
        glow.Color = Color3.fromRGB(255, 0, 0) -- Red for Stone Lance
        glow.Parent = primaryPart
    else
        -- Remove effect
        local glow = primaryPart:FindFirstChild("CustomHoldGlow")
        if glow then glow:Destroy() end
    end
end
```

---

## API Reference

### WeaponSkillHold.new(config)

Creates a new skill instance.

**Parameters:**
- `config.name` (string) - Skill name
- `config.animation` (Animation) - Animation instance
- `config.skillType` (string) - "weapon" or "alchemy"
- `config.hasBodyMovers` (boolean) - Whether skill uses body movers
- `config.damage` (number) - Base damage
- `config.cooldown` (number) - Cooldown in seconds

**Returns:** Skill instance

### skill:OnInputBegan(player, character)

Called when input begins (key pressed).

### skill:OnInputEnded(player)

Called when input ends (key released).

### skill:Execute(player, character, holdDuration)

Override this method with your skill logic.

**Parameters:**
- `player` (Player) - The player executing the skill
- `character` (Model) - The player's character
- `holdDuration` (number) - How long the skill was held (0 for immediate execution)

### skill:IsOnCooldown(player)

Returns whether the skill is on cooldown for the player.

### skill:GetRemainingCooldown(player)

Returns remaining cooldown time in seconds.

---

## Troubleshooting

### Skill executes immediately instead of holding

**Cause:** Either `skillType = "alchemy"` or `hasBodyMovers = true`

**Solution:** Set `skillType = "weapon"` and `hasBodyMovers = false`

### Animation doesn't freeze

**Cause:** Animation might not be loaded properly

**Solution:** Ensure animation is a valid Animation instance

### Hold effect doesn't appear

**Cause:** Character might not have a PrimaryPart or HumanoidRootPart

**Solution:** Ensure character is fully loaded before calling OnInputBegan

---

## Performance Notes

- Held skills are tracked per player (minimal memory overhead)
- Cooldowns are cleaned up when players leave
- Visual effects are destroyed when hold ends
- No performance impact on alchemy skills or body mover skills

---

## Future Enhancements

Potential additions:
- Charge meter UI
- Sound effects for charging
- Different charge levels (tier 1, 2, 3)
- Cancel mechanic (press another key to cancel)
- Overcharge penalty (holding too long reduces damage)

