local NPC_CONTENTS, NPC_SHARED = script.Parent.Parent.NpcContents, script.Parent.Parent.NpcShared

local Settings = require(NPC_SHARED.BanditSettings)
local QuestGuardData = {
	Name = "QuestGuard",
	Quantity = 0, -- Will be spawned dynamically by quest

	SpawnCooldown = 1,

	Type = "Active",

	AlwaysSpawn = false, -- Don't spawn automatically

	DataToSendOverAndUdpate = {
		States = {
			IsPassive = false, -- Start aggressive
			AggressiveMode = true, -- Start in aggressive mode
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
			Enabled = true,
			AttackDistance = 15,
			AttackCooldown = 1,
			AttackDamage = 10,
		},

		Chasing = {
			Enabled = true,
			ChaseDistance = 25,
			ChaseSpeed = 16,
			GiveUpDistance = 50,
		},

		Health = {
			MaxHealth = 100,
			RunHp = 0.15,
		},

		EnemyDetection = {
			CaptureDistance = 80,
			LetGoDistance = 100,
			AddIfAgroed = 50,
			TargetGroups = { "Players" },
			MaxTargetsPerGroup = {
				Players = 1,
			},
			RunAway = {
				RunHp = 0.15,
				Ranges = { SafeRange = 35 },
			},
		},

		Combat = {
			Light = true,
		},

		Weapons = {
			Enabled = true,
			Weapon1 = "Fist",
			Weapon2 = "Guns",
			WeaponCount = 2,
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

-- print("QuestGuard configuration loaded successfully")
return QuestGuardData

