

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local jecs = require(ReplicatedStorage.Modules.Imports.jecs)

local tags = {
	-- Movement State Tags (mutually exclusive states)
	WallRunning = jecs.tag(),
	Dashing = jecs.tag(),
	InAir = jecs.tag(),
	Running = jecs.tag(),
	Sprinting = jecs.tag(),
	Sliding = jecs.tag(),
	Climbing = jecs.tag(),
	Grounded = jecs.tag(),

	-- Grip/Carry States
	BeingGripped = jecs.tag(),
	BeingCarried = jecs.tag(),

	-- Death/Combat States
	Dead = jecs.tag(),
	BlockBroken = jecs.tag(),
	PostureBroken = jecs.tag(), -- Posture was broken (triggers long stun)
	Stunned = jecs.tag(),       -- Entity is stunned (can't act)
	Attacking = jecs.tag(),     -- Entity is in attack animation  


	NoRagdoll = jecs.tag(),     
	CustomOst = jecs.tag(),     
	Special = jecs.tag(),       

	
	TWall = jecs.tag(),         


	QuestHolder = jecs.tag(),       -- NPC holds quests
	CombatNPC = jecs.tag(),         -- NPC uses ECS combat AI
	BehaviorTreeOverride = jecs.tag(), -- Allow behavior tree to override ECS
	WandererNPC = jecs.tag(),       -- NPC is a wandering citizen

	-- Guard System Tags
	Guard = jecs.tag(),         -- Entity is a guard NPC
	SpawnedGuard = jecs.tag(),  -- Guard was spawned by system (vs static)
	Hostile = jecs.tag(),       -- Entity is hostile

	-- Initialization Tags
	ComponentsReady = jecs.tag(), -- Entity fully initialized
}

return table.freeze(tags)
