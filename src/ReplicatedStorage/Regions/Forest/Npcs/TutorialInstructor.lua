local NPC_CONTENTS, NPC_SHARED = script.Parent.Parent.NpcContents, script.Parent.Parent.NpcShared

-- Safe spawn location retrieval for TutorialInstructor
local function getTutorialInstructorSpawn()
	local world = workspace:FindFirstChild("World")
	if world then
		local quests = world:FindFirstChild("Quests")
		if quests then
			local sam = quests:FindFirstChild("Sam")
			if sam then
				local npcSpawn = sam:FindFirstChild("Npc_Spawn", true)
				if npcSpawn then
					print("[TutorialInstructor] Found spawn at", npcSpawn.Position)
					return npcSpawn.Position
				end
			end
		end
	end

	-- Fallback position
	--warn("[TutorialInstructor] Spawn not found, using default position")
	return Vector3.new(0, 5, 0)
end

local Settings = require(NPC_SHARED.BanditSettings)
local TutorialInstructorData = {
	Name = "TutorialInstructor",
	Quantity = 0, -- Will be spawned dynamically by quest

	SpawnCooldown = 1,

	Type = "Active",

	AlwaysSpawn = false, -- Don't spawn automatically

	DataToSendOverAndUdpate = {
		States = {
			IsPassive = true, -- Passive NPC
			AggressiveMode = false, -- Never aggressive
		},

		Spawning = {
			Locations = {}, -- Will be set dynamically by quest
			Cooldown = Settings.SpawnTime,
			DespawnTime = 3,
			Tags = { "Humanoids" },
		},

		Idle = {
			Enabled = true,
			Positions = {},
			WalkSpeed = 5,
			WaitTime = 3,
		},

		Attacking = {
			Enabled = false, -- Passive NPCs don't attack
			AttackDistance = 0,
			AttackCooldown = 0,
			AttackDamage = 0,
		},

		Chasing = {
			Enabled = false, -- Passive NPCs don't chase
			ChaseDistance = 0,
			ChaseSpeed = 0,
			GiveUpDistance = 0,
		},

		Health = {
			MaxHealth = 100,
			RunHp = 0.15,
		},

		EnemyDetection = {
			CaptureDistance = 0, -- Don't detect enemies
			LetGoDistance = 0,
			AddIfAgroed = 0,
			TargetGroups = {},
			MaxTargetsPerGroup = {},
			RunAway = {
				RunHp = 0.15,
				Ranges = { SafeRange = 35 },
			},
		},

		Combat = {
			Light = false, -- No combat
		},

		Weapons = {
			Enabled = false, -- No weapons
			Weapon1 = nil,
			Weapon2 = nil,
			WeaponCount = 0,
		},

		Appearance = {
			Enabled = true,
			Hair = NPC_CONTENTS.Hair.General.GenerateHair,
			Face = NPC_CONTENTS.Face.General.GenerateFace,
			Shirt = NPC_CONTENTS.Shirt.General.GenerateShirt,
			Pants = NPC_CONTENTS.Pants.General.GeneratePants,
			SkinColor = NPC_CONTENTS.SkinColor.General.GenerateSkinColor,
			Acessories = {},
		},
	},

	BehaviorTree = require(game.ReplicatedStorage.NpcHelper.Behaviors.Forest.Guard_BehaviorTree),
}

print("[TutorialInstructor] Configuration loaded successfully")
return TutorialInstructorData

