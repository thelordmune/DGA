local NPC_CONTENTS, NPC_SHARED = script.Parent.Parent.NpcContents, script.Parent.Parent.NpcShared

-- Safe spawn location retrieval for LeftGuard
local function getLeftGuardSpawn()
	local world = workspace:FindFirstChild("World")
	if world then
		local spawns = world:FindFirstChild("Spawns")
		if spawns then
			local leftGuard = spawns:FindFirstChild("LeftGuard")
			if leftGuard then
				print("LeftGuard: Found spawn at", leftGuard.Position)
				return leftGuard.Position
			end
		end
	end

	-- Fallback position
	warn("LeftGuard: Spawn not found, using default position")
	return Vector3.new(-20, 5, 0)
end

local Settings = require(NPC_SHARED.BanditSettings)
local LeftGuardData = {
	Name = "LeftGuard",
	Quantity = 1,

	SpawnCooldown = 1,

	Type = "Active",

	AlwaysSpawn = true,

	DataToSendOverAndUdpate = {
		Spawning = {
			Locations = { getLeftGuardSpawn() },
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
			WeaponList = { "Fist", "Guns" },
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

	BehaviorTree = require(game.ReplicatedStorage.NpcHelper.Behaviors.Forest.Bandit_BehaviorTree),
}

print("LeftGuard configuration loaded successfully")
return LeftGuardData
