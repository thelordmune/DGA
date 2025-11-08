local NPC_CONTENTS, NPC_SHARED = script.Parent.Parent.NpcContents, script.Parent.Parent.NpcShared

-- Function to find wanderer spawn points in workspace
local function getWandererSpawns()
    local spawns = {}
    local wanderersFolder = workspace:FindFirstChild("Wanderers")

    if wanderersFolder then
        -- print("Found Wanderers folder with", #wanderersFolder:GetChildren(), "spawn points")
        for _, part in pairs(wanderersFolder:GetChildren()) do
            if part:IsA("BasePart") then
                table.insert(spawns, part.Position)
                -- -- print("Added wanderer spawn at:", part.Position)
            end
        end
    else
        warn("Wanderers folder not found in workspace")
        -- Fallback spawns for testing
        spawns = {
            Vector3.new(0, 5, 0),
            Vector3.new(10, 5, 10),
            Vector3.new(-10, 5, -10)
        }
        -- print("Using fallback spawns:", #spawns)
    end

    return spawns
end

-- Get spawns and ensure we have at least 1
local wandererSpawns = getWandererSpawns()
local wandererCount = math.max(1, #wandererSpawns) -- At least 1 wanderer

print("[Wanderer] 🚶 Loading Wanderer configuration")
print("[Wanderer] Spawn count:", wandererCount)
print("[Wanderer] Spawn locations:", #wandererSpawns)
for i, spawn in ipairs(wandererSpawns) do
	print("[Wanderer]   Spawn", i, ":", spawn)
end

local WandererData = {
	Name = "Wanderer",
	Quantity = wandererCount,

	SpawnCooldown = 1,

	Type = "Active",
	AlwaysSpawn = false, -- DISABLED - Wanderers are turned off
	LoadDistance = nil, -- DISABLED - Set to nil to prevent spawning

	DataToSendOverAndUdpate = {
		Spawning = {
			Enabled = true,
			Cooldown = 5,
			LastSpawned = 0,
			Locations = wandererSpawns, -- Use the spawns we already calculated
			Tags = {"Humanoids"},
			DespawnTime = 3,
		},

		Idling = {
			Enabled = true,
			Positions = {},
			WalkSpeed = 8, -- Slower wandering speed
			WaitTime = 5, -- Wait longer between movements
			MaxDistance = 15, -- Don't wander too far from spawn
		},

		Chasing = {
			Enabled = false, -- Wanderers don't chase
			ChaseDistance = 0,
			ChaseSpeed = 0,
			GiveUpDistance = 0,
		},

		Attacking = {
			Enabled = false, -- Wanderers don't attack
			AttackDistance = 0,
			AttackCooldown = 0,
			AttackDamage = 0,
		},

		Health = {
			MaxHealth = 50, -- Lower health for wanderers
			RunHp = 0.3, -- Run away when health is low
		},

		EnemyDetection = {
			CaptureDistance = 30, -- Detect players but don't chase
			LetGoDistance = 50,
			AddIfAgroed = 0,
			TargetGroups = {"Players"},
			MaxTargetsPerGroup = {
				Players = 0, -- Don't target players for combat
			},
			RunAway = {
				RunHp = 0.3,
				Ranges = {SafeRange = 25}, -- Run away from players
			}
		},

		Combat = {
			Light = false, -- No combat
		},

		Weapons = {
			Enabled = false, -- No weapons
			WeaponList = {},
		},

			 Appearance = {
				Enabled = true,
				Hair = NPC_CONTENTS.Hair.General.GenerateHair,
				Face = NPC_CONTENTS.Face.General.GenerateFace,
				Shirt = NPC_CONTENTS.Shirt.General.GenerateShirt,
				Pants = NPC_CONTENTS.Pants.General.GeneratePants,
				SkinColor = NPC_CONTENTS.SkinColor.General.GenerateSkinColor,
			 },

	
	},
	BehaviorTree = require(game.ReplicatedStorage.NpcHelper.Behaviors.Forest.Wanderer_BehaviorTree),
}

-- print("[Wanderer] ✅ Wanderer configuration loaded successfully")
-- print("[Wanderer] AlwaysSpawn:", WandererData.AlwaysSpawn)
-- print("[Wanderer] LoadDistance:", WandererData.LoadDistance)

return WandererData
