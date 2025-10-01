local NPC_CONTENTS, NPC_SHARED = script.Parent.Parent.NpcContents, script.Parent.Parent.NpcShared

-- Safe spawn location retrieval for RightGuard
local function getRightGuardSpawn()
	local world = workspace:FindFirstChild("World")
	if world then
		local spawns = world:FindFirstChild("Spawns")
		if spawns then
			local rightGuard = spawns:FindFirstChild("RightGuard")
			if rightGuard then
				print("RightGuard: Found spawn at", rightGuard.Position)
				return rightGuard.Position
			end
		end
	end

	-- Fallback position
	warn("RightGuard: Spawn not found, using default position")
	return Vector3.new(20, 5, 0)
end

local Settings = require(NPC_SHARED.BanditSettings)
local RightGuardData = {
	Name = "RightGuard",
	Quantity = 1,

	SpawnCooldown = 1,

	Type = "Active",

	AlwaysSpawn = true,

	DataToSendOverAndUdpate = {
		States = {
			IsPassive = true,
			AggressiveMode = false,
		},

		Spawning = {
			Locations = { getRightGuardSpawn() },
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

print("RightGuard configuration loaded successfully")
return RightGuardData
