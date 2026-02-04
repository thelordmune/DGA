local NPC_CONTENTS, NPC_SHARED = script.Parent.Parent.NpcContents, script.Parent.Parent.NpcShared

-- Function to find wanderer spawn points in workspace
-- NOTE: This is called at module load time - workspace.Wanderers might not exist yet!
-- The actual spawn locations are fetched dynamically in spawn_entity.lua
local function getWandererSpawns()
    local spawns = {}
    local wanderersFolder = workspace:FindFirstChild("Wanderers")

    if wanderersFolder then
        for _, part in pairs(wanderersFolder:GetChildren()) do
            if part:IsA("BasePart") then
                table.insert(spawns, part.Position)
            end
        end
    end

    -- If no spawns found at load time, that's OK - spawn_entity.lua will fetch them dynamically
    if #spawns == 0 then
        print("[Wanderer] No spawns found at module load time - spawn_entity will fetch dynamically from workspace.Wanderers")
    end

    return spawns
end

-- Get spawns - may be empty at load time, spawn_entity.lua handles dynamic fetching
local wandererSpawns = getWandererSpawns()
-- Default to 10 wanderers if no spawns found yet - spawn_entity will use workspace.Wanderers
local wandererCount = #wandererSpawns > 0 and math.clamp(#wandererSpawns, 1, 20) or 10

--print("[Wanderer] 🚶 Loading Wanderer configuration")
--print("[Wanderer] Spawn count:", wandererCount)
--print("[Wanderer] Spawn locations:", #wandererSpawns)
for i, spawn in ipairs(wandererSpawns) do
	--print("[Wanderer]   Spawn", i, ":", spawn)
end

local WandererData = {
	Name = "Wanderer",
	Quantity = wandererCount,

	SpawnCooldown = 1,

	Type = "Active",
	AlwaysSpawn = true, -- ENABLED - Wanderers spawn on game start
	LoadDistance = nil, -- No proximity spawning needed since AlwaysSpawn is true

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
			CaptureDistance = 0, -- No combat targeting - wanderers are peaceful
			LetGoDistance = 0,
			AddIfAgroed = 0,
			TargetGroups = {},
			MaxTargetsPerGroup = {
				Players = 0, -- Don't target players for combat
			},
			RunAway = {
				RunHp = 0.3,
				Ranges = {SafeRange = 25}, -- Run away from players when low health
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
				-- DISABLED: Wanderer appearance is handled by mobs.luau applyWandererAppearance()
				-- which uses CustomizationData and stores attributes for the relationship system
				Enabled = false,
			 },

	
	},
	BehaviorTree = require(game.ReplicatedStorage.NpcHelper.Behaviors.Forest.Wanderer_BehaviorTree),
}

---- --print("[Wanderer] ✅ Wanderer configuration loaded successfully")
---- --print("[Wanderer] AlwaysSpawn:", WandererData.AlwaysSpawn)
---- --print("[Wanderer] LoadDistance:", WandererData.LoadDistance)

return WandererData
