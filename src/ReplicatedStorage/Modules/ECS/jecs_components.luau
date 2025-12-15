local ReplicatedStorage = game:GetService("ReplicatedStorage")
local jecs = require(ReplicatedStorage.Modules.Imports.jecs)
local world = require(script.Parent.jecs_world)

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
    WallRunning: Entity<boolean>,
    Dashing: Entity<boolean>,
    Combat: Entity<{ equipped: boolean, animation: string, weapon: string }>,
    Blocking: Entity<{value: boolean, duration: number}>,
    Carrying: Entity<{target: Model, value: boolean}>,
    BeingGripped: Entity<boolean>,
    BeingCarried: Entity<boolean>,
    DeathLocation: Entity<CFrame>,
    Knocked: Entity<{duration: number, value: boolean}>,
    IFrame: Entity<{duration: number, value: boolean}>,
    Sprinting: Entity<{value: boolean}>,
    Ragdoll: Entity<{duration: number, value: boolean}>,
    CantMove: Entity<{value: boolean, duration: number}>,
    Dead: Entity<boolean>,
    Weapon: Entity<{name: string, type: string}>,
    Swing: Entity<any>,
    KeysLogged: Entity<number>,
    Light: Entity<{value: boolean, duration: number}>,
    NoDash: Entity<{value: boolean, duration: number}>,
    LastHit: Entity<number>,
    AttackInfo: Entity<{name: string, type: string, damage: number, damagetype: number, scales: boolean}>,
    CritCD: Entity<{value: boolean, duration: number}>,
    Heavy: Entity<{value: boolean, duration: number}>,
    IgnoreParry: Entity<{value: boolean, duration: number}>,
    Phase: Entity<RBXScriptSignal>,
    System: Entity<{callback: (any) -> (), name: string}>,
    Damage: Entity<{amount: number, victim: Model, type: string}>,
    NoHurt: Entity<{value: boolean, duration: number}>,
    ParryTick: Entity<{value: boolean, duration: number}>,
    QDC: Entity<{value: boolean, duration: number}>,
    BBRegen: Entity<{value: boolean, duration: number}>,
    LastMove: Entity<{move: string, tim: number}>,
    LastAction: Entity<{action: string, tim: number}>,
    ParryStun: Entity<{value: boolean, duration: number}>,
    InAir: Entity<boolean>,
    Utility: Entity<{value: boolean, duration: number}>,
    Transmutable: Entity<boolean>,
    Victim: Entity<Model>,
    Action: Entity<{value: boolean, duration: number}>,
    BlockBar: Entity<{Value: number, MaxValue: number}>,
    BlockBroken: Entity<boolean>,
    NoRagdoll: Entity<boolean>,
    InCombat: Entity<{duration: number, value: boolean}>,
    CustomOst: Entity<boolean>,
    Locked: Entity<{value: boolean, duration: number}>,
    TWall: Entity<boolean>,
    DependsOn: Entity<any>,
    Event: Entity<RBXScriptSignal>,
    Name: Entity<string>,
    After: Entity<any>,
    Special: Entity<boolean>,
    Attack: Entity<{type: string, name: string}>,
    Dialogue: Entity<{npc: Model, name: string, inrange: boolean, state: string}>,
    ActiveQuest: Entity<{npcName: string, questName: string, startTime: number, progress: {stage: string | number?, completed: boolean?, description: string? }}>,
    CompletedQuest: Entity<{npcName: string, questName: string, completedTime: number}>,
    QuestAccepted: Entity<{npcName: string, questName: string, acceptedAt: number, stage: string | number? }>,
    QuestData: Entity<{Description: string, Rewards: {}}>,
    QuestHolder: Entity<boolean>,
    Passive: Entity<{name: string, description: string?,cooldown : boolean}>,
    PassiveHolder: Entity<table>,
    Inventory: Entity<{items: {[number]: {name: string, typ: string, quantity: number, singleuse: boolean, slot: number?}}, maxSlots: number}>,
    Item: Entity<{name: string, typ: string, quantity: number, singleuse: boolean, description: string?, icon: string?, stackable: boolean?}>,
    Requirement: Entity<{type: string, value: any, description: string?}>,
    Hotbar: Entity<{slots: {[number]: number?}, activeSlot: number?}>,
    InventoryChanged: Entity<number>,
    ClockTime: Entity<{timeOfDay: number, dayLength: number, startTime: number}>,
    RagdollImpact: Entity<{lastImpactTime: number, wasInAir: boolean, lastVelocity: Vector3}>,
    Level: Entity<{current: number, max: number}>,
    Experience: Entity<{current: number, required: number, total: number}>,
    Alignment: Entity<{value: number, min: number, max: number}>,
    QuestItemCollected: Entity<{npcName: string, questName: string, itemName: string, collectedTime: number}>,
    QuestMarker: Entity<{markerType: string, npcName: string, questName: string?}>,
    Grab: Entity<{target: Model, value: boolean, duration: number, startTime: number?, distance: number?}>,

    StateActions: Entity<{string}>,
    StateStuns: Entity<{string}>,
    StateIFrames: Entity<{string}>,
    StateSpeeds: Entity<{string}>,
    StateFrames: Entity<{string}>,
    StateStatus: Entity<{string}>,

    -- Combat Systems
    Adrenaline: Entity<{value: number, comboHits: number}>, -- value: 0-100, comboHits: consecutive hits landed

    -- Initialization Tags
    ComponentsReady: Entity<boolean>, -- Tag to indicate all player components are initialized

    -- ECS Cooldown Management (replaces table-based cooldowns)
    Cooldowns: Entity<{[string]: number}>,

    -- AI/Movement Components (for performant ECS-based AI)
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
    CombatNPC: Entity<boolean>, -- Marks NPCs that should use ECS AI for combat
    BehaviorTreeOverride: Entity<boolean>, -- Allows behavior tree to override ECS AI
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
        WallRunning = world:component(),
        Dashing = world:component(),
        Combat = world:component(),
        Blocking = world:component(),
        Carrying = world:component(),
        BeingGripped = world:component(),
        BeingCarried = world:component(),
        DeathLocation = world:component(),
        Knocked = world:component(),
        IFrame = world:component(),
        Sprinting = world:component(),
        Ragdoll = world:component(),
        CantMove = world:component(),
        Dead = world:component(),
        Weapon = world:component(),
        Swing = world:component(),
        NoJump = world:component(),
        ToSpeed = world:component(),
        KeysLogged = world:component(),
        Light = world:component(),
        NoDash = world:component(),
        LastHit = world:component(),
        AttackInfo = world:component(),
        CritCD = world:component(),
        Heavy = world:component(),
        IgnoreParry = world:component(),
        System = world:component(),
        Damage = world:component(),
        NoHurt = world:component(),
        ParryTick = world:component(),
        ParryStun = world:component(),
        InAir = world:component(),
        Utility = world:component(),
        Victim = world:component(),
        Action = world:component(),
        BlockBar = world:component(),
        BBRegen = world:component(),
        BlockBroken = world:component(),
        Armor = world:component(),
        QDC = world:component(),
        NoRagdoll = world:component(),
        InCombat = world:component(),
        CustomOst = world:component(),
        Locked = world:component(),
        TWall = world:component(),
        Phase = world:component(),
        DependsOn = world:component(),
        Event = world:component(),
        Name = world:component(),
        After = world:component(),
        Special = world:component(),
        Attack = world:component(),
        Dialogue = world:component(),
        ActiveQuest = world:component(),
        CompletedQuest = world:component(),
        QuestAccepted = world:component(),
        QuestData = world:component(),
        QuestHolder = world:component(),
        Passive = world:component(),
        PassiveHolder = world:component(),
        Inventory = world:component(),
        Item = world:component(),
        Requirement = world:component(),
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
        Adrenaline = world:component(),

        -- Initialization Tags
        ComponentsReady = world:component(),

        -- ECS Cooldown Management
        Cooldowns = world:component(),

        -- AI/Movement Components
        Locomotion = world:component(),
        AIState = world:component(),
        Traits = world:component(),
        Wander = world:component(),
        Size = world:component(),
        Hitbox = world:component(),
        CombatNPC = world:component(),
        BehaviorTreeOverride = world:component(),

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
	}

    for name, component in components :: {[string]: jecs.Entity} do 
        -- ---- print("Setting component:", name, component)
        if component == nil then
            -- error("Component is nil: " .. name)
        end
        world:set(component, jecs.Name, name)
        -- ---- print("Component set successfully:", name)
    end

return table.freeze(components)