# NPC Targeting Debug - Comprehensive Logging

**Date:** 2025-12-02
**Issue:** Guards attack in place but don't chase players - NPCTarget component missing

---

## 🔍 Debug Changes Added to npc_targeting_ecs.luau

### System Startup Logging
```
[npc_targeting_ecs] System active - found X guards total, Y in query
[npc_targeting_ecs] Query requires: Character, CombatNPC, NPCCombatState, NPCConfig, Hitbox
```

This will immediately show if guards are being excluded from the query due to missing components.

### Per-Frame Guard Processing
```
[npc_targeting_ecs] Frame N: Processing GuardName
[npc_targeting_ecs]   isPassive=true/false, isAggressive=true/false, hasBeenAttacked=true/false
[npc_targeting_ecs]   Damage_Log exists: true/false
[npc_targeting_ecs]   Damage_Log children: N
[npc_targeting_ecs]   hasBeenAttacked() returned: attacked=true/false, attacker=PlayerName/nil
```

This shows exactly what the targeting system sees when checking each guard.

### Attack Detection and Target Setting
```
[npc_targeting_ecs] GuardName was attacked! Attacker: PlayerName
[npc_targeting_ecs]   Setting GuardName to AGGRESSIVE mode
[npc_targeting_ecs]   GuardName is now AGGRESSIVE
[npc_targeting_ecs]   Setting NPCTarget for GuardName to PlayerName
[npc_targeting_ecs]   ✅ NPCTarget component SET: PlayerName
```

OR if there's an error:
```
[npc_targeting_ecs]   ❌ ERROR: NPCTarget component NOT set!
[npc_targeting_ecs]   ❌ Cannot set target: attacker=Model, isModel=true, hasHumanoid=true/false
```

---

## 📊 Expected Output When Working

### On Server Start:
```
[npc_targeting_ecs] System active - found 2 guards total, 2 in query
[npc_targeting_ecs] Query requires: Character, CombatNPC, NPCCombatState, NPCConfig, Hitbox
[npc_targeting_ecs] Frame 1: Processing LeftGuard272
[npc_targeting_ecs]   isPassive=true, isAggressive=false, hasBeenAttacked=false
[npc_targeting_ecs]   Damage_Log exists: false
[npc_targeting_ecs]   Damage_Log children: 0
[npc_targeting_ecs]   hasBeenAttacked() returned: attacked=false, attacker=nil
```

### When Player Attacks Guard:
```
[npc_targeting_ecs] Frame 45: Processing LeftGuard272
[npc_targeting_ecs]   isPassive=true, isAggressive=false, hasBeenAttacked=false
[npc_targeting_ecs]   Damage_Log exists: true
[npc_targeting_ecs]   Damage_Log children: 1
[npc_targeting_ecs]   hasBeenAttacked() returned: attacked=true, attacker=PlayerName
[npc_targeting_ecs] LeftGuard272 was attacked! Attacker: PlayerName
[npc_targeting_ecs]   Setting LeftGuard272 to AGGRESSIVE mode
[npc_targeting_ecs]   LeftGuard272 is now AGGRESSIVE
[npc_targeting_ecs]   Setting NPCTarget for LeftGuard272 to PlayerName
[npc_targeting_ecs]   ✅ NPCTarget component SET: PlayerName
```

Then immediately after (within ~0.125s):
```
[npc_movement_pattern_ecs] Found 1 guards with targets
[npc_movement_pattern_ecs] GUARD FOUND IN QUERY: LeftGuard272 targeting PlayerName
[npc_movement_pattern_ecs] LeftGuard272 chasing PlayerName - distance: 25 studs, pattern: Direct
[mob_movement_ecs] LeftGuard272 - Locomotion: dir={0.5, 0, 0.866}, speed=24
```

---

## 🐛 Possible Issues This Will Reveal

### Issue 1: Guards Not In Query
```
[npc_targeting_ecs] System active - found 2 guards total, 0 in query
```
**Cause:** Guards missing one of: Character, CombatNPC, NPCCombatState, NPCConfig, Hitbox
**Fix:** Check [mobs.luau](src/ServerScriptService/Systems/mobs.luau) initialization

### Issue 2: Damage_Log Not Detected
```
[npc_targeting_ecs]   Damage_Log exists: false
```
**Cause:** Damage.lua not creating Damage_Log OR being cleared before targeting system runs
**Fix:** Check [Damage.lua](src/ServerScriptService/ServerConfig/Server/Damage.lua)

### Issue 3: hasBeenAttacked() Returns False Despite Damage_Log
```
[npc_targeting_ecs]   Damage_Log exists: true
[npc_targeting_ecs]   Damage_Log children: 1
[npc_targeting_ecs]   hasBeenAttacked() returned: attacked=false, attacker=nil
```
**Cause:** Bug in hasBeenAttacked() function logic
**Fix:** Check [npc_targeting_ecs.luau:45-63](src/ServerScriptService/Systems/npc_targeting_ecs.luau#L45-L63)

### Issue 4: Attacker Not Valid
```
[npc_targeting_ecs]   ❌ Cannot set target: attacker=Model, isModel=false, hasHumanoid=false
```
**Cause:** Damage_Log.Value not pointing to player's Character model
**Fix:** Check Damage.lua - ensure ObjectValue.Value = Invoker (Character model)

### Issue 5: NPCTarget Component Not Setting
```
[npc_targeting_ecs]   Setting NPCTarget for GuardName to PlayerName
[npc_targeting_ecs]   ❌ ERROR: NPCTarget component NOT set!
```
**Cause:** ECS world:set() failing OR NPCTarget component not registered
**Fix:** Check [jecs_components.luau](src/ReplicatedStorage/Modules/ECS/jecs_components.luau)

---

## 🧪 Testing Steps

1. **Restart server** to reload npc_targeting_ecs with new logging
2. **Check console** - should see:
   ```
   [npc_targeting_ecs] System active - found X guards total, Y in query
   ```
3. **Attack a guard** with M1
4. **Watch console** for full trace of:
   - Damage_Log detection
   - hasBeenAttacked() result
   - Aggressive mode setting
   - NPCTarget component setting
   - Verification checkmark

5. **If NPCTarget is set correctly**, you should then see:
   ```
   [npc_movement_pattern_ecs] GUARD FOUND IN QUERY: GuardName targeting PlayerName
   [mob_movement_ecs] GuardName - Locomotion: dir={X, Y, Z}, speed=24
   ```

---

## 📁 Files Modified

| File | Changes |
|------|---------|
| [npc_targeting_ecs.luau](src/ServerScriptService/Systems/npc_targeting_ecs.luau) | Added extensive debug logging (lines 97-174) |

---

**Next Steps:** Run the game and paste the console output after attacking a guard. The logs will pinpoint exactly where the targeting system is failing.
