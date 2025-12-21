# Game Development Portfolio
**Roblox Developer | Lua Engineer | Systems Architect**

---

## Professional Experience

### Ironveil (2024-2025)
**Role:** Lead Developer
**Technologies:** Lua, JECS (ECS), Fusion, BridgeNet2, ProfileService

#### Project Overview
Full-stack development of an action RPG featuring complex combat systems, quest mechanics, and optimized performance architecture.

#### Key Contributions
- **ECS Architecture:** Implemented complete entity-component system using JECS for scalable game state management
- **Combat System:** Multi-frame hit detection, combo tracking, ragdoll physics, and weapon-specific animations (800+ lines)
- **Physics Systems:** Advanced ragdoll impact detection with crater generation, velocity-based damage calculation, and throttled updates (15Hz impacts, 5Hz detection)
- **Quest Framework:** Client-server quest system with stage management, waypoint markers, and progress tracking
- **UI Systems:** Reactive UI components using Fusion with slot-based notification queues, cooldown visualizers, and spring animations
- **Network Optimization:** BridgeNet2 integration for efficient client-server communication
- **Data Persistence:** ProfileService implementation with session locking and global updates
- **Performance Optimization:** Cached ECS queries, throttled system updates, and optimized raycast patterns

#### Technical Highlights
```lua
// Ragdoll Impact System - Optimized ECS architecture
- Throttled detection: 5 Hz ragdoll detection, 15 Hz impact checking (92% CPU reduction)
- Dynamic crater generation based on velocity
- Velocity-based damage: 5-25 HP calculated from fall speed
- Dash effect system for high-velocity ragdolls

// Notification Queue Manager
- Slot-based system supporting 5 concurrent notifications
- Fusion reactive components with proper scope cleanup
- Queue throttling with spawn delays

// Alchemy Combination System
- Data-driven input sequence matching (Z, X, C combos)
- Designer-friendly: add abilities without code changes
- 34 lines, 12+ unique abilities
```

---

### Goalbound (2025)
**Role:** Backend Developer
**Technologies:** Lua, Core Systems Architecture

#### Key Contributions
- **Core Systems Development:** Built and maintained fundamental game systems and infrastructure
- **Bug Fixes & Optimization:** Identified and resolved critical backend issues
- **System Architecture:** Contributed to backend system design and implementation
- **Code Maintenance:** Regular codebase improvements and technical debt reduction

---

### Pantera (2024-2025)
**Role:** Gameplay & UI Developer
**Technologies:** Lua, UI Frameworks

#### Key Contributions
- **Skill Moves:** Designed and implemented combat abilities and character skills
- **User Interface:** Created responsive and polished UI systems for player interaction
- **Gameplay Mechanics:** Developed ability systems and player-facing features

---

### Grand Piece Online (2022-2024)
**Role:** Gameplay Developer
**Technologies:** Lua, Combat Systems

#### Key Contributions
- **Skill Moves:** Implemented character abilities and special attacks
- **Combat Mechanics:** Developed skill-based combat interactions
- **Ability Systems:** Created diverse movesets for player characters

---

## Technical Skills

### Languages & Frameworks
- **Lua/Luau** - Advanced proficiency with modern Roblox APIs
- **ECS Architecture** - JECS implementation and optimization
- **Reactive Programming** - Fusion framework expertise
- **Networking** - BridgeNet2 optimization and packet design

### Specializations
- **Combat Systems** - Multi-frame hit detection, state machines, combo tracking
- **Physics Programming** - Ragdoll systems, velocity-based mechanics, force calculations
- **Performance Optimization** - Query caching, throttling, spatial partitioning
- **UI/UX Development** - Reactive components, animations, state management
- **Data Persistence** - ProfileService, session management, DataStore optimization
- **Mathematics** - Vector math, spherical coordinates, cross products, linear interpolation

### Architecture & Design Patterns
- Entity Component System (ECS)
- State Machines
- Singleton Patterns
- Observer Pattern
- Object Pooling
- Data-Driven Design

---

## My Coding Exmaples

### 1. Alchemy Combination System
*34 lines of elegant input sequence matching*

**Why I think this is impressive:**
- Elegant input sequence matching for fighting game-style combos
- Data-driven: designers add abilities without touching code
- Self-documenting structure demonstrates design thinking

```lua
return {
    ["Z"] = "Construct",
    ["ZX"] = "Stone Lance",
    ["ZZZ"] = "Stone Lance Path",
    ["ZXC"] = "Cascade",
    ["XZXZ"] = "Rock Skewer",
    ["CCXZ"] = "Motor",
}
```

---

### 2. Ragdoll Impact System
*213 lines of optimized ECS physics*

**Why I think this is impressive:**
- ECS integration with JECS framework
- Heavily optimized: 15Hz impact checking, 5Hz ragdoll detection (92% CPU reduction)
- Dynamic crater generation with velocity-based damage
- Network replication to all clients
- State management with multiple ragdoll detection methods

**Core Logic:**
```lua
local IMPACT_CHECK_HZ = 15
local RAGDOLL_DETECT_HZ = 5
local MIN_IMPACT_VELOCITY = 30

local ragdollQuery = world:query(comps.Character, comps.RagdollImpact):cached()

local function createImpact(character, impactPosition, impactVelocity)
    local velocityMagnitude = math.abs(impactVelocity.Y)
    if velocityMagnitude < MIN_IMPACT_VELOCITY then return end

    local baseDamage = math.floor(velocityMagnitude / 10) * 5
    local damage = math.clamp(baseDamage, 5, 25)
    humanoid:TakeDamage(damage)
end
```

---

### 3. Notification Queue Manager
*242 lines of reactive UI orchestration*

**Why I think this is impressive:**
- Slot-based system supporting 5 concurrent notifications
- Queue management with spawn throttling
- Fusion reactive components with proper cleanup
- Lifecycle management (scopes, callbacks, timers)

**Key Feature:**
```lua
local function findAvailableSlot()
    for slot = 0, MAX_NOTIFICATIONS - 1 do
        local slotTaken = false
        for _, notif in ipairs(activeNotifications) do
            if notif.slot == slot then
                slotTaken = true
                break
            end
        end
        if not slotTaken then return slot end
    end
    return nil
end
```

---

### 4. Anti-Fling System
*202 lines of exploit prevention*

**Why I think this is impressive:**
- Real-time physics safety system running every frame
- Per-frame velocity clamping (horizontal vs vertical limits)
- Orphaned body mover detection with lifetime tracking
- Handles character respawns gracefully
- Demonstrates exploit prevention awareness

**Core Algorithm:**
```lua
local function clampVelocity(velocity: Vector3): Vector3
    local horizontal = Vector3.new(velocity.X, 0, velocity.Z)
    local vertical = Vector3.new(0, velocity.Y, 0)

    if horizontal.Magnitude > MAX_HORIZONTAL_VELOCITY then
        horizontal = horizontal.Unit * MAX_HORIZONTAL_VELOCITY
    end

    if math.abs(vertical.Y) > MAX_VERTICAL_VELOCITY then
        vertical = Vector3.new(0, math.sign(velocity.Y) * MAX_VERTICAL_VELOCITY, 0)
    end

    return horizontal + vertical
end
```

---

### 5. Spherical Debris Spread
*Advanced mathematics for realistic particle effects*

**Why I think this is impressive:**
- Spherical coordinate mathematics for uniform debris distribution
- Physics-based spread using polar coordinates (theta, phi)
- Transforms local directions to world space

```lua
local function getSpreadDirection(anchorCF: CFrame, spreadAngle: number): Vector3
    local baseDir = anchorCF.UpVector
    local angle = math.rad(spreadAngle)

    local theta = math.random() * 2 * math.pi
    local u = math.random()
    local phi = math.acos(1 - u * (1 - math.cos(angle)))

    local x = math.sin(phi) * math.cos(theta)
    local y = math.cos(phi)
    local z = math.sin(phi) * math.sin(theta)

    local cf = CFrame.lookAt(Vector3.zero, baseDir.Unit)
    return (cf.RightVector * x + cf.LookVector * z + cf.UpVector * y).Unit
end
```

---

### 6. Quest Handler System
*214 lines of client-side orchestration*

**Why I think this is impressive:**
- Client-side quest orchestration with ECS integration
- Stage management with lifecycle callbacks (OnStageStart, OnStageUpdate, OnStageEnd)
- Automatic marker cleanup and module hot-reloading
- Handles quest transitions and completions smoothly

**State Management:**
```lua
local function updateQuestState()
    local playerEntity = ref.get("local_player")
    if world:has(playerEntity, comps.ActiveQuest) then
        local activeQuest = world:get(playerEntity, comps.ActiveQuest)
        local isNewQuest = currentQuest.npcName ~= activeQuest.npcName
        local isNewStage = currentQuest.stage ~= stage

        if isNewQuest then
            cleanupMarkers()
            local questModule = loadQuestModule(activeQuest.npcName)
            if questModule.OnStageStart then
                pcall(questModule.OnStageStart, stage, questData)
            end
        end
    end
end
```

---

## Project Statistics

### Ironveil Codebase Metrics
- **Total Lines:** ~15,000+ Lua/Luau
- **Architecture:** ECS-based with JECS
- **Systems Implemented:** 20+ (Combat, Physics, Quests, UI, Data, Network)
- **Custom Modules:** 50+ reusable components
- **Network Optimization:** BridgeNet2 integration with packet batching
- **Performance:** 60 FPS maintained with 100+ entities

---

## What I Bring to the Table

### Technical Excellence
- **Modern Architecture:** ECS patterns, reactive programming, state machines
- **Performance-First:** Cached queries, throttled updates, object pooling
- **Clean Code:** Self-documenting, minimal comments, designer-friendly APIs
- **Mathematics:** Vector operations, physics calculations, coordinate transformations

### Professional Skills
- **Full-Stack Game Development:** Client, server, UI, data, networking
- **System Design:** Scalable architectures that grow with game complexity
- **Optimization:** Identifying bottlenecks and implementing efficient solutions
- **Collaboration:** Designer-friendly systems, maintainable codebases

### Problem Solving
- **Multi-frame hit detection** for fast-moving combat
- **Throttled system updates** for 92% CPU reduction
- **Surface-aligned physics** for dynamic environmental effects
- **Exploit prevention** through velocity clamping and orphan cleanup

---

## Contact

**GitHub:** https://github.com/uuath
**Roblox:** https://www.roblox.com/users/1166419362/profile
**Discord:** lordmune.

---

*Portfolio showcasing production-ready code from real shipping games. All systems are battle-tested, optimized, and designed for scalability.*
