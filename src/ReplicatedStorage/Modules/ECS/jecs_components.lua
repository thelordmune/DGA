local ReplicatedStorage = game:GetService("ReplicatedStorage")
local jecs = require(ReplicatedStorage.Modules.Imports.jecs)
local world = require(script.Parent.jecs_world)
local tags = require(script.Parent.jecs_tags)

type Entity<T = nil> = jecs.Entity<T>

local components: {
	Character: Entity<Model>,
	Mob: Entity<Model>,
	Model: Entity<Model>,
	Player: Entity<Player>,
	Target: Entity<Model>,
	Transform: Entity<{ new: CFrame, old: CFrame }>,
	Velocity: Entity<Vector3>,
	Previous: Entity<any>,
    Health: Entity<{current: number, new: number, old: number, tick: number, tickspeed: number}>,
    Energy: Entity<{current: number, max: number, new: number, old: number, tick: number, tickspeed: number}>,
    Attacking: Entity<{value: boolean, duration: number}>,
    Stun: Entity<{value: boolean, duration: number}>,
    NoJump: Entity<{value: boolean, duration: number}>,
    ToSpeed: Entity<number>,
    NoRotate: Entity<{value: boolean, duration: number}>,
    Gripping: Entity<{target: Model, value: boolean}>,
    Sliding: Entity<{direction: CFrame, value: boolean}>,
    WallRunning: Entity<nil>, -- Tag from jecs_tags
    Dashing: Entity<nil>, -- Tag from jecs_tags
    Combat: Entity<{ equipped: boolean, animation: string, weapon: string }>,
    Blocking: Entity<{value: boolean, duration: number}>,
    Carrying: Entity<{target: Model, value: boolean}>,
    BeingGripped: Entity<nil>, -- Tag from jecs_tags
    BeingCarried: Entity<nil>, -- Tag from jecs_tags
    DeathLocation: Entity<CFrame>,
    Knocked: Entity<{duration: number, value: boolean}>,
    IFrame: Entity<{duration: number, value: boolean}>,
    Sprinting: Entity<{value: boolean}>,
    Ragdoll: Entity<{duration: number, value: boolean}>,
    CantMove: Entity<{value: boolean, duration: number}>,
    Dead: Entity<nil>, -- Tag from jecs_tags
    DeathInfo: Entity<{killer: Model?, damageType: string?, timestamp: number}>,
    Weapon: Entity<{name: string, type: string}>,
    Light: Entity<{value: boolean, duration: number}>,
    NoDash: Entity<{value: boolean, duration: number}>,
    Phase: Entity<RBXScriptSignal>,
    System: Entity<{callback: (any) -> (), name: string}>,
    Damage: Entity<{amount: number, victim: Model, type: string}>,
    NoHurt: Entity<{value: boolean, duration: number}>,
    ParryTick: Entity<{value: boolean, duration: number}>,
    BBRegen: Entity<{value: boolean, duration: number}>,
    InAir: Entity<nil>, -- Tag from jecs_tags
    Action: Entity<{value: boolean, duration: number}>,
    BlockBar: Entity<{Value: number, MaxValue: number}>,
    BlockBroken: Entity<nil>, -- Tag from jecs_tags

    -- Posture System (Deepwoken-style)
    PostureBar: Entity<{
        current: number,        -- Current posture damage (0 = fresh, 100 = broken)
        max: number,            -- Max posture before break (default 100)
        regenRate: number,      -- How fast posture recovers per second (default 10)
        regenDelay: number,     -- Seconds after last damage before regen starts (default 2)
        lastDamageTime: number, -- Timestamp of last posture damage taken
    }>,
    PostureBroken: Entity<nil>, -- Tag: posture was just broken (triggers stun)
    NoRagdoll: Entity<nil>, -- Tag from jecs_tags
    InCombat: Entity<{duration: number, value: boolean}>,
    CustomOst: Entity<nil>, -- Tag from jecs_tags
    Locked: Entity<{value: boolean, duration: number}>,
    TWall: Entity<nil>, -- Tag from jecs_tags
    DependsOn: Entity<any>,
    Event: Entity<RBXScriptSignal>,
    Name: Entity<string>,
    After: Entity<any>,
    Special: Entity<nil>, -- Tag from jecs_tags
    Attack: Entity<{type: string, name: string}>,
    Dialogue: Entity<{npc: Model, name: string, inrange: boolean, state: string}>,
    ActiveQuest: Entity<{npcName: string, questName: string, startTime: number, progress: {stage: string | number?, completed: boolean?, description: string? }}>,
    CompletedQuest: Entity<{npcName: string, questName: string, completedTime: number}>,
    QuestAccepted: Entity<{npcName: string, questName: string, acceptedAt: number, stage: string | number? }>,
    QuestData: Entity<{Description: string, Rewards: {}}>,
    QuestHolder: Entity<nil>, -- Tag from jecs_tags
    Passive: Entity<{name: string, description: string?,cooldown : boolean}>,
    PassiveHolder: Entity<table>,
    Inventory: Entity<{items: {[number]: {name: string, typ: string, quantity: number, singleuse: boolean, slot: number?}}, maxSlots: number}>,
    Item: Entity<{name: string, typ: string, quantity: number, singleuse: boolean, description: string?, icon: string?, stackable: boolean?}>,
    Hotbar: Entity<{slots: {[number]: number?}, activeSlot: number?}>,
    InventoryChanged: Entity<number>,
    ClockTime: Entity<{timeOfDay: number, dayLength: number, startTime: number}>,
    RagdollImpact: Entity<{lastImpactTime: number, wasInAir: boolean, lastVelocity: Vector3}>,
    Level: Entity<{current: number, max: number}>,
    Experience: Entity<{current: number, required: number, total: number}>,
    Alignment: Entity<{value: number, min: number, max: number}>,
    QuestItemCollected: Entity<{npcName: string, questName: string, itemName: string, collectedTime: number}>,
    Grab: Entity<{target: Model, value: boolean, duration: number, startTime: number?, distance: number?}>,

    StateActions: Entity<{string}>,
    StateStuns: Entity<{string}>,
    StateIFrames: Entity<{string}>,
    StateSpeeds: Entity<{string}>,
    StateFrames: Entity<{string}>,
    StateStatus: Entity<{string}>,

    -- Combat Systems
    Stamina: Entity<{current: number, max: number, regenRate: number, drainRate: number}>, -- Stamina system for Nen abilities

    -- Focus System
    Focus: Entity<{
        current: number,         -- Current focus (0-100)
        max: number,             -- Current max focus (starts 50, trainable to 100)
        decayRate: number,       -- Passive decay per second
        permanentFloor: number,  -- Trained minimum (0-40)
        tempFloor: number,       -- Temporary floor set when entering Absolute Focus
        trainingXP: number,      -- Accumulated training progress
        trainingLevel: number,   -- Current training level (determines max)
        inMiniMode: boolean,     -- Currently in mini mode (50%+)
        inAbsoluteMode: boolean, -- Currently in absolute focus (100%)
    }>,

    -- Status Effects (ECS-driven, replaces RunService loops)
    Burning: Entity<{
        damagePerTick: number,
        tickInterval: number,
        remainingTime: number,
        lastTick: number,
        source: Model?
    }>,
    Bleeding: Entity<{
        damagePerTick: number,
        tickInterval: number,
        remainingTime: number,
        lastTick: number,
        stacks: number
    }>,
    Poisoned: Entity<{
        damagePerTick: number,
        tickInterval: number,
        remainingTime: number,
        lastTick: number,
        source: Model?
    }>,

    -- Nen System
    NenAbility: Entity<{
        active: string?,           -- Currently active toggle ability (Ten, Ren, etc.)
        activeAbilities: {string}, -- List of all active abilities
        cooldowns: {[string]: number}, -- Cooldowns per ability
        level: number,             -- Nen mastery level
    }>,
    NenEffects: Entity<{
        damageBonus: number,       -- Multiplier for outgoing damage (1.0 = no change)
        damageReduction: number,   -- Reduction for incoming damage (0.2 = 20% reduction)
        speedModifier: number,     -- Speed multiplier (1.0 = no change)
        invisibility: number,      -- Transparency level (0 = visible, 1 = invisible)
        detectionRadius: number,   -- En detection radius
        focusedLimb: string?,      -- For Ryu - which limb is focused
    }>,

    -- Initialization Tags
    ComponentsReady: Entity<nil>, -- Tag from jecs_tags

    -- Action Priority System (ECS-driven action management)
    CurrentAction: Entity<{
        name: string,
        priority: number,
        startTime: number,
        duration: number?,
        interruptible: boolean
    }>,

    -- ECS Cooldown Management (replaces table-based cooldowns)
    Cooldowns: Entity<{[string]: number}>,

    Locomotion: Entity<{ dir: Vector3, speed: number }>,
    AIState: Entity<{
        state: string,   -- "wander" | "chase" | "flee" | "circle" | "idle"
        t: number,       -- time spent in state
        dur: number,     -- how long to stay in state (seconds)
        circleSign: number, -- +1 / -1 for circle direction
    }>,

    -- NPC Combat AI Components
    NPCTarget: Entity<Model>, -- Current enemy target
    NPCCombatState: Entity<{
        isPassive: boolean,
        isAggressive: boolean,
        hasBeenAttacked: boolean,
        lastAttackTime: number,
        lastDefenseTime: number,
        lastActionTime: number,
        justParried: boolean,
        parryTime: number,
        lastM1Time: number,
        lastSkillUsed: string?,
        hitsTaken: number,
    }>,
    NPCSkillScoring: Entity<{
        bestSkill: string?,
        bestScore: number,
        lastScoringTime: number,
    }>,
    NPCGuardPattern: Entity<{
        enabled: boolean,
        currentState: string, -- "DEFENSIVE" | "COUNTER" | "PRESSURE" | "SPECIAL" | "RESET"
        stateStartTime: number,
        comboCount: number,
    }>,
    NPCPathfinding: Entity<{
        isActive: boolean,
        pathState: string, -- "Direct" | "Pathfind"
        stateId: number,
        waypoints: {Vector3}?,
        currentWaypointIndex: number,
        lastRecomputeTime: number,
    }>,
    NPCMovementPattern: Entity<{
        current: string, -- "Direct" | "Strafe" | "SideApproach" | "CircleStrafe" | "ZigZag"
        lastChanged: number,
        duration: number,
        strafeDirection: Vector3?,
        sideDirection: string?, -- "Left" | "Right"
        circleDirection: number, -- 1 or -1
        zigzagDirection: number, -- 1 or -1
        zigzagTimer: number,
    }>,
    NPCWander: Entity<{
        center: Vector3,
        radius: number,
        nextMove: number,
        swayX: number,
        swayY: number,
        noiseOffset: number,
        currentDirection: Vector3,
    }>,
    NPCConfig: Entity<{
        captureDistance: number,
        letGoDistance: number,
        runAwayHP: number,
        safeRange: number,
        canStrafe: boolean,
        canWander: boolean,
        maxStrafeRadius: number,
        maxAlignmentDot: number,
        walkSpeed: number,
        runSpeed: number,
        jumpPower: number,
        smoothingAlpha: number,
    }>,
    NPCSpawnData: Entity<{
        spawnPosition: Vector3,
        maxWanderDistance: number,
    }>,
    Traits: Entity<{
        baseSpeedMul: number,
        chaseWeight: number,
        fleeWeight: number,
        circleWeight: number,
        jumpWeight: number,
        fleeDistance: number,
        preferDistance: number,
        detectRange: number,
        loseSightRange: number,
    }>,
    Wander: Entity<{ center: Vector3, radius: number, nextMove: number }>,
    Size: Entity<number>,
    Hitbox: Entity<Part>,
    CombatNPC: Entity<nil>, -- Tag from jecs_tags
    BehaviorTreeOverride: Entity<nil>, -- Tag from jecs_tags

    -- Guard System Tags
    Guard: Entity<nil>, -- Tag from jecs_tags
    SpawnedGuard: Entity<nil>, -- Tag from jecs_tags
    Hostile: Entity<nil>, -- Tag from jecs_tags

    -- Interaction System
    Interactable: Entity<{objectId: string, promptText: string, handlerName: string, model: Model}>,

    -- Wandering NPC System (Non-Combat Citizens)
    WandererNPC: Entity<nil>, -- Tag from jecs_tags
    NPCIdentity: Entity<{
        name: string,           -- "Heinrich", "Maria", etc.
        occupation: string,     -- "Automail Engineer", "Soldier", etc.
        occupationType: string, -- "Military" | "Civilian"
        personality: string,    -- "Friendly" | "Grumpy" | "Nervous" | "Professional" | "Curious"
    }>,
    NPCRelationship: Entity<{
        relationships: {[number]: number},    -- [userId] = 0-100 relationship value
        hitCounts: {[number]: number},        -- [userId] = hits taken for flee trigger
        dailyInteractions: {[number]: number}, -- [userId] = interaction count today
        lastDayReset: number,                 -- timestamp of last daily reset
    }>,
    NPCProximity: Entity<{
        nearbyPlayer: Model?,     -- Current nearby player model
        isWanderPaused: boolean,  -- Is wandering paused due to player proximity
        detectionRange: number,   -- Detection range in studs (default 8)
    }>,
    NPCFlee: Entity<{
        isFleeing: boolean,       -- Currently fleeing from player
        fleeTarget: Model?,       -- Player to flee from
        fleeEndTime: number,      -- When to stop fleeing (os.clock timestamp)
    }>,

    -- Limb Loss & Junction System
    LimbState: Entity<{
        leftArm: boolean,         -- true = attached, false = severed
        rightArm: boolean,
        leftLeg: boolean,
        rightLeg: boolean,
        bleedingStacks: number,   -- Each missing limb adds 1 stack of bleeding
    }>,

    -- Damage Tracking (replaces Damage_Log folder for ECS-native damage tracking)
    DamageHistory: Entity<{
        recent: {{attacker: Model, timestamp: number, amount: number}},
        lastDamageTime: number,
        lastAttacker: Model?,
    }>,

    -- Pre-cached parts list for grab/death operations (avoids GetDescendants())
    PartsList: Entity<{
        baseParts: {BasePart},
        scripts: {Instance},
    }>,

    -- Split from NPCMovementPattern - core movement data
    NPCMovement: Entity<{
        current: string,      -- "Direct" | "Strafe" | "SideApproach" | "CircleStrafe" | "ZigZag"
        lastChanged: number,
        duration: number,
    }>,

    -- Split from NPCMovementPattern - transient pattern state
    NPCMovementState: Entity<{
        strafeDirection: Vector3?,
        sideDirection: string?,   -- "Left" | "Right"
        circleDirection: number,  -- 1 or -1
        zigzagDirection: number,  -- 1 or -1
        zigzagTimer: number,
    }>,

    -- ============================================
    -- UNIFIED STATE CONSOLIDATION COMPONENTS
    -- (Replaces Entity.Combo, Entity.LastHit, module-local state, etc.)
    -- ============================================

    -- Combat State (replaces Entity.Combo, Entity.LastHit, Entity.SwingConnection)
    CombatState: Entity<{
        combo: number,                      -- Current combo count (0-5)
        lastHitTime: number,                -- os.clock() timestamp of last successful hit
        swingConnection: RBXScriptConnection?, -- Active swing animation connection
    }>,

    -- Animation State (replaces Animate/init.lua module locals)
    AnimationState: Entity<{
        current: string,                    -- Currently playing animation name
        pose: string,                       -- Current pose ("Standing", "Running", "FreeFall", etc.)
        freeFallTime: number,               -- Time spent in freefall (for animation timing)
        jumpAnimTime: number,               -- Time spent in jump animation
    }>,

    -- Input State (replaces PlayerObject.Keys on server)
    InputState: Entity<{
        attack: boolean,                    -- Attack key held
        dash: boolean,                      -- Dash key held
        block: boolean,                     -- Block key held
        critical: boolean,                  -- Critical key held
        construct: boolean,                 -- Construct key held
    }>,

    -- Client Movement State (replaces Client.InAir, Client.Dodging, etc. booleans)
    ClientMovementState: Entity<{
        inAir: boolean,
        dodging: boolean,
        running: boolean,
        runAtk: boolean,
        sliding: boolean,
        wallRunning: boolean,
        ledgeClimbing: boolean,
        leaping: boolean,
        leapLanding: boolean,
    }>,
} =
	{
		Character = world:component(),
		Mob = world:component(),
		Model = world:component(),
		Player = world:component(),
		Target = world:component(),
		Transform = world:component(),
		Velocity = world:component(),
		Previous = world:component(),
        Health = world:component(),
        Energy = world:component(),
        Attacking = world:component(),
        Stun = world:component(),
        NoRotate = world:component(),
        Gripping = world:component(),
        Sliding = world:component(),
        WallRunning = tags.WallRunning,
        Dashing = tags.Dashing,
        Combat = world:component(),
        Blocking = world:component(),
        Carrying = world:component(),
        BeingGripped = tags.BeingGripped,
        BeingCarried = tags.BeingCarried,
        DeathLocation = world:component(),
        Knocked = world:component(),
        IFrame = world:component(),
        Sprinting = world:component(),
        Ragdoll = world:component(),
        CantMove = world:component(),
        Dead = tags.Dead,
        DeathInfo = world:component(),
        Weapon = world:component(),
        NoJump = world:component(),
        ToSpeed = world:component(),
        Light = world:component(),
        NoDash = world:component(),
        System = world:component(),
        Damage = world:component(),
        NoHurt = world:component(),
        ParryTick = world:component(),
        InAir = tags.InAir,
        Action = world:component(),
        BlockBar = world:component(),
        BBRegen = world:component(),
        BlockBroken = tags.BlockBroken,

        -- Posture System (Deepwoken-style)
        PostureBar = world:component(),
        PostureBroken = tags.PostureBroken,
        Armor = world:component(),
        NoRagdoll = tags.NoRagdoll,
        InCombat = world:component(),
        CustomOst = tags.CustomOst,
        Locked = world:component(),
        TWall = tags.TWall,
        Phase = world:component(),
        DependsOn = world:component(),
        Event = world:component(),
        Name = world:component(),
        After = world:component(),
        Special = tags.Special,
        Attack = world:component(),
        Dialogue = world:component(),
        ActiveQuest = world:component(),
        CompletedQuest = world:component(),
        QuestAccepted = world:component(),
        QuestData = world:component(),
        QuestHolder = tags.QuestHolder,
        Passive = world:component(),
        PassiveHolder = world:component(),
        Inventory = world:component(),
        Item = world:component(),
        Hotbar = world:component(),
        InventoryChanged = world:component(),
        ClockTime = world:component(),
        RagdollImpact = world:component(),
        Level = world:component(),
        Experience = world:component(),
        Alignment = world:component(),
        QuestItemCollected = world:component(),
        Grab = world:component(),

        -- ECS State Management
        StateActions = world:component(),
        StateStuns = world:component(),
        StateIFrames = world:component(),
        StateSpeeds = world:component(),
        StateFrames = world:component(),
        StateStatus = world:component(),

        -- Combat Systems
        Stamina = world:component(),
        Focus = world:component(),

        -- Status Effects (ECS-driven)
        Burning = world:component(),
        Bleeding = world:component(),
        Poisoned = world:component(),

        -- Nen System
        NenAbility = world:component(),
        NenEffects = world:component(),

        -- Initialization Tags
        ComponentsReady = tags.ComponentsReady,

        -- Action Priority System
        CurrentAction = world:component(),

        -- ECS Cooldown Management
        Cooldowns = world:component(),

        -- AI/Movement Components
        Locomotion = world:component(),
        AIState = world:component(),
        Traits = world:component(),
        Wander = world:component(),
        Size = world:component(),
        Hitbox = world:component(),
        CombatNPC = tags.CombatNPC,
        BehaviorTreeOverride = tags.BehaviorTreeOverride,

        -- Guard System Tags
        Guard = tags.Guard,
        SpawnedGuard = tags.SpawnedGuard,
        Hostile = tags.Hostile,

        -- NPC Combat AI Components
        NPCTarget = world:component(),
        NPCCombatState = world:component(),
        NPCSkillScoring = world:component(),
        NPCGuardPattern = world:component(),
        NPCPathfinding = world:component(),
        NPCMovementPattern = world:component(),
        NPCWander = world:component(),
        NPCConfig = world:component(),
        NPCSpawnData = world:component(),

        -- Interaction System
        Interactable = world:component(),

        -- Wandering NPC System
        WandererNPC = tags.WandererNPC,
        NPCIdentity = world:component(),
        NPCRelationship = world:component(),
        NPCProximity = world:component(),
        NPCFlee = world:component(),

        -- Limb Loss & Junction System
        LimbState = world:component(),

        -- Damage Tracking (replaces Damage_Log folder)
        DamageHistory = world:component(),

        -- Pre-cached parts list for grab/death operations
        PartsList = world:component(),

        -- Split NPCMovementPattern components
        NPCMovement = world:component(),
        NPCMovementState = world:component(),

        -- Unified State Consolidation Components
        CombatState = world:component(),
        AnimationState = world:component(),
        InputState = world:component(),
        ClientMovementState = world:component(),
	}

    for name, component in components :: {[string]: jecs.Entity} do
        -- ---- print("Setting component:", name, component)
        if component == nil then
            -- error("Component is nil: " .. name)
        end
        world:set(component, jecs.Name, name)
        -- ---- print("Component set successfully:", name)
    end

-- NOTE: OnDeleteTarget traits are NOT used here because these components store
-- Roblox Model instances, NOT JECS entity IDs. OnDeleteTarget only works with
-- JECS entity relationships (pairs/relations).
--
-- For cleanup of dangling Model references, use EntityCleanup.register() in the
-- systems that manage these components (see grab_server.luau).

return table.freeze(components)