local NPC_CONTENTS,NPC_SHARED = script.Parent.Parent.NpcContents,script.Parent.Parent.NpcShared

-- Safe spawn location retrieval with error handling
local function getSpawnLocations()
    local locations = {}

    -- Try to get LeftGuard spawn
    local world = workspace:FindFirstChild("World")
    if world then
        local spawns = world:FindFirstChild("Spawns")
        if spawns then
            local leftGuard = spawns:FindFirstChild("LeftGuard")
            local rightGuard = spawns:FindFirstChild("RightGuard")

            if leftGuard then
                table.insert(locations, leftGuard.Position)
                -- print("Found LeftGuard spawn at:", leftGuard.Position)
            else
                warn("LeftGuard spawn not found - using default position")
                table.insert(locations, Vector3.new(-20, 5, 0))
            end

            if rightGuard then
                table.insert(locations, rightGuard.Position)
                -- print("Found RightGuard spawn at:", rightGuard.Position)
            else
                warn("RightGuard spawn not found - using default position")
                table.insert(locations, Vector3.new(20, 5, 0))
            end
        else
            warn("Spawns folder not found - using default positions")
            table.insert(locations, Vector3.new(-20, 5, 0)) -- Default left
            table.insert(locations, Vector3.new(20, 5, 0))  -- Default right
        end
    else
        warn("World folder not found - using default positions")
        table.insert(locations, Vector3.new(-20, 5, 0)) -- Default left
        table.insert(locations, Vector3.new(20, 5, 0))  -- Default right
    end

    -- print("Bandit spawn locations:", #locations, "locations found")
    for i, pos in pairs(locations) do
        -- print("- Location", i .. ":", pos)
    end

    return locations
end

local spawnLocations = getSpawnLocations()

local Settings = require(NPC_SHARED.BanditSettings)
local BanditData = {
	Name = "Bandit",
	Quantity = 0, -- Disabled - using separate LeftGuard and RightGuard

	SpawnCooldown = 1,

	Type = "Active",-- ex: dialogue, active, passive (can potentially be attacked and the npc will attack back) (gon do nun for now until we add functionality for it later)

	AlwaysSpawn = false, -- Disabled
	--[[
	data to send over and update is basically the data that updates the mainconfig table thats unique to the npc's data and replaces it,
	this is so each data setting is different (bc why would a bandit npc have the same data as a boss npc) ]]

	DataToSendOverAndUdpate = {
		Spawning = {
			Locations = spawnLocations,
			Cooldown = Settings.SpawnTime,
			DespawnTime = 3,
			Tags = {"Humanoids"}, -- stuff like f you want to do some special stuff like adding it to bosses tag nd looping through that tag and create specific ui
			Despawning = {
				Enabled = true,
				DespawnDistance = Settings.DespawnDistance or 200,
			}
		},

		HumanoidDefaults = {
			RunSpeed = 22,
			WalkSpeed = 13,
			JumpPower = 50,
		},

		Run = {
			RunOnFollowing = {Distance = 5, Away_Or_Near = "Away",Enabled = true},
		},


		Setting = {
			CanWander = true,
			CanStrafe = true,
			Heal = {
				HealEvery = 300,
				CooldownFromStun = 30,
				LastHealed = 0,
				AddAmount = 1/100,
			}
		},

		Idling = {
			Enabled = false;
			--WalkToPositions will be generated through script based on its spawn poisiton
		},

		EnemyDetection = {
			CaptureDistance = 80,
			LetGoDistance = 100,
			AddIfAgroed = 50,
			TargetGroups = {"Players"},
			MaxTargetsPerGroup = {
				Players = 1,
			},
			RunAway = {
				RunHp = 0.15, -- accounted for in %
				Ranges = {SafeRange = 35},

			}
		},

		Appearance = {
			Enabled = true,
			Hair = NPC_CONTENTS.Hair.General.GenerateHair,
			Face = NPC_CONTENTS.Face.General.GenerateFace, 
			Shirt = NPC_CONTENTS.Shirt.General.GenerateShirt,
			Pants = NPC_CONTENTS.Pants.General.GeneratePants,
			SkinColor = NPC_CONTENTS.SkinColor.General.GenerateSkinColor,
			Acessories = {} -- will add functioanltiy to this later
		}:: AppearanceType	
	},


}

return BanditData