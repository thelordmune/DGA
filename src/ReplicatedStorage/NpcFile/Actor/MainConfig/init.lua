local ReplicatedStorage = game:GetService("ReplicatedStorage")

local getRunPath = require(script.GetRunPath)
local getBlockPath = require(script.GetBlockPath)

local Signal = require(ReplicatedStorage.Signal)
local Serializer = require(ReplicatedStorage.Seralizer)

local Server = require(game:GetService("ServerScriptService").ServerConfig.Server)
local Library = Server.Library
-- local AnimationManager = require(ReplicatedStorage.AnimationHandler)

-- local bridges = require(ReplicatedStorage.Bridges)
-- local bridgeNet2 = require(ReplicatedStorage.BridgeNet2)

-- local Skill_Setup = require(ReplicatedStorage.Skill_Setup)

local Library = Server.Library

local Skill_Data = {}

for i_branch: string, v: { [string]: { [string]: any } } in require(ReplicatedStorage.Skill_Data) do
	for i, v in v do
		v.Branch = i_branch
		Skill_Data[i] = v
	end
end

type SpawningConfig = {
	Enabled: boolean,
	Cooldown: number,
	LastSpawned: number,
	Locations: { Vector3 },
	Despawning: {
		Enabled: boolean,
		DespawnDistance: number,
	},
}

type EnemyDetectionConfig = {
	Current: Player?,
	RaycastForCapture: boolean,
	CaptureDistance: number,
	LetGoDistance: number,
	MaxPerPlayer: number,
	CaptureOnStun: number,
	Lost: {
		MaxPathsRetry: number,
		Current: number,
	},
}

type IdleConfig = {
	WaitBeforeChangingDirection: {
		Min: number,
		Max: number,
	},
	WalkEnded: typeof(Signal.new()),
	GoAtSpawnFirstIfFar: boolean,
	Positions: { Vector3 },
	GoalPoint: Vector3?,
	ReachedGoal: boolean,
	LastArrived: number,
	Move_Places: boolean,
}

type MovementConfig = {
	Strafe: {
		Enabled: boolean,
		MinRange: number,
		MaxRange: number,
		Duration: {
			Min: number,
			Max: number,
		},
		Chance: {
			Min: Number,
			Max: Number,
		},
		BackawaySpeed: Number,
		StrafeSpeed: Number,
		ForwardMixRatio: Number, -- how much forward movement to mix in with strafe
	},
}

local MainConfig = {
	States = {},
	Storage = {},

	SpawnConnections = {},

	Appearance = {},

	Movement = {
		MaxStrafeRadius = 25, -- maximum distance for strafing (increased from 15 - strafe at longer ranges)
		MaxAlignmentDot = 0.5, -- Minimum dot product to allow strafing (increased from 0.3 - strafe more often)
		BackupSpeed = 5, -- when being pressed by a player and the npc backs up

		-- Smooth movement interpolation
		CurrentDirection = Vector3.zero,
		SmoothingAlpha = 0.5, -- Higher = faster response, lower = smoother (0-1) - increased for very responsive movement

		Patterns = {
			Current = nil, -- Current pattern type
			LastChanged = 0,

			Duration = {
				Min = 0.8, -- Reduced from 1.5 - change patterns very frequently
				Max = 1.5, -- Reduced from 2.5 - change patterns very frequently
			},
			Types = {
				Strafe = {
					Speed = 2.0, -- Increased from 1.5 - strafe faster
					ForwardMix = 1.2, -- Increased from 1 - more aggressive forward movement while strafing
				},
				SideApproach = {
					ForwardSpeed = 1.3, -- Increased from 1
					SideSpeed = 2.5, -- Increased from 2
					Direction = nil, -- "Left" or "Right"
				},
				Direct = {
					Speed = 1,
				},
				CircleStrafe = {
					Speed = 1.0, -- Increased from 0.7 - circle strafe faster and more aggressively
					Radius = 10, -- Increased from 8 - wider circles for better positioning
				},
				ZigZag = {
					ForwardSpeed = 1.0, -- Increased from 0.7
					SideSpeed = 0.5, -- Increased from 0.3
				},
			},
		},
	} :: MovementConfig,

	EnemyDetection = {
		Current = nil,
		RaycastForCapture = false,
		CaptureDistance = 0,
		LetGoDistance = 100,
		MaxPerPlayer = 1,
		MaxCastDistance = 10,
		CaptureOnStun = true,
		Lost = {
			MaxPathsRetry = 2,
			Current = 2,
		},
		RunAway = {
			RunHp = 0,
			Ranges = {
				SafeRange = 37,
			},
		},
	} :: EnemyDetectionConfig,

	Setting = {
		CanWander = true,
		CanStrafe = true,
		LastStunned = 0,
		LastPunched = 0,
		Heal = {
			HealEvery = 300,
			CooldownFromStun = 30,
			LastHealed = 0,
			AddAmount = 1 / 100,
		},
	},

	Pathfinding = {
		IsRunning = false,
		PathState = "Direct",
	},

	Run = {
		IsRunning = false,
		RunAnimation = "",
		--Run = Signal.new(),
		RunOnFollowing = { Distance = 5, AwayOrNear = "Away", Enabled = true },
	},

	Idle = {
		Idling = false,
		SwayX = nil,
		SwayY = nil,
		NoiseOffset = math.random() * 100,
		MaxDistance = 22,
		NextPause = {
			Current = nil,
			Min = 5,
			Max = 7,
		},
		PauseDuration = {
			Current = nil,
			Min = 3,
			Max = 5,
		},
	},
	Idle2 = {
		WaitBeforeChangingDirection = {
			Min = 1,
			Max = 3,
		},
		WalkEnded = Signal.new(),
		GoAtSpawnFirstIfFar = true,
		Positions = {},
		-- Add these new fields
		-- OLD
		GoalPoint = nil, -- Current goal point
		ReachedGoal = false, -- Track if goal is reached
		LastArrived = 0, -- Time of last arrival at goal
		Move_Places = true, -- Enable/disable movement
	} :: IdleConfig,

	Spawning = {
		SpawnedAt = Vector3.zero,
		Enabled = true,
		Cooldown = 2,
		LastSpawned = 0,
		Locations = {},
		ChosenSpawnLocation = nil,
		Tags = { "Humanoids" },
		DespawnTime = 3,
		Despawning = {
			Enabled = true,
			DespawnDistance = 150,
		},
	} :: SpawningConfig,

	HumanoidDefaults = {
		WalkSpeed = 16,
		RunSpeed = 35,
		JumpPower = 50,
	},

	Weapons = {
		Enabled = false,
		WeaponList = {},
	},
}

-- Initialize with NPC data
local NpcData = script.Parent.Parent:WaitForChild(`Data`)
do
	local DataFetched = {}
	Serializer.ToTable(NpcData, DataFetched)

	---- print(DataFetched)

	local Spawning = DataFetched.Spawning
	if Spawning then
		for key, value in Spawning do
			MainConfig.Spawning[key] = value
		end
	end

	local Idling = DataFetched.Idling
	if Idling then
		for key, value in Idling do
			if key ~= "WalkEnded" then -- Skip signal
				MainConfig.Idle[key] = value
			end
		end
	end

	local EnemyDetection = DataFetched.EnemyDetection
	if EnemyDetection then
		for key, value in EnemyDetection do
			if key == "RunAway" then
				MainConfig.EnemyDetection.RunAway = value
			else
				MainConfig.EnemyDetection[key] = value
			end
		end
	end

	local HumanoidDefaults = DataFetched.HumanoidDefaults
	if HumanoidDefaults then
		for key, value in HumanoidDefaults do
			MainConfig.HumanoidDefaults[key] = value
		end
	end

	local Run = DataFetched.Run
	if Run then
		for key, value in Run do
			MainConfig.Run[key] = value
		end
	end

	local Setting = DataFetched.Setting
	if Setting then
		for key, value in Setting do
			MainConfig.Setting[key] = value
		end
	end

	if DataFetched.Appearance then
		MainConfig.Appearance = DataFetched.Appearance
	end

	-- Load States configuration
	if DataFetched.States then
		for key, value in DataFetched.States do
			MainConfig.States[key] = value
		end
		-- print("Loaded States config for NPC - IsPassive:", MainConfig.States.IsPassive, "AggressiveMode:", MainConfig.States.AggressiveMode)
	end

	-- Load weapon configuration
	if DataFetched.Weapons then
		-- Convert Weapon1, Weapon2, etc. back to WeaponList array
		local weaponList = {}
		if DataFetched.Weapons.WeaponCount then
			for i = 1, DataFetched.Weapons.WeaponCount do
				local weaponKey = "Weapon" .. i
				if DataFetched.Weapons[weaponKey] then
					table.insert(weaponList, DataFetched.Weapons[weaponKey])
				end
			end
		end

		MainConfig.Weapons = {
			Enabled = DataFetched.Weapons.Enabled,
			WeaponList = weaponList,
		}
		-- print("Loaded weapons config for NPC:", MainConfig.Weapons.Enabled, "Weapons:", table.concat(weaponList, ", "))
	end
end

function MainConfig.onCooldown(actionData)
	-- simulate npc actions here
	---- print(action)
	--return os.clock() -   -- Skill_Setup:checkCooldown(MainConfig.getNpc(), Skill_Data[action].Branch, action)
	return os.clock() - actionData.Last_Used < actionData.Cooldown
end

-- Load weapon skill and alchemy handlers from the same location players use
local ServerScriptService = game:GetService("ServerScriptService")
local weaponSkillHandlers = {}
local alchemySkillHandlers = {}

-- Load all weapon skills from ServerScriptService (same as players)
local function loadWeaponSkills()
	local weaponSkillsPath = ServerScriptService:FindFirstChild("ServerConfig")
	if weaponSkillsPath then
		weaponSkillsPath = weaponSkillsPath:FindFirstChild("Server")
		if weaponSkillsPath then
			weaponSkillsPath = weaponSkillsPath:FindFirstChild("WeaponSkills")
			if weaponSkillsPath then
				for _, weaponFolder in weaponSkillsPath:GetChildren() do
					if weaponFolder:IsA("Folder") then
						for _, skillModule in weaponFolder:GetChildren() do
							if skillModule:IsA("ModuleScript") then
								weaponSkillHandlers[skillModule.Name] = require(skillModule)
								-- print("Loaded weapon skill for NPCs:", skillModule.Name)
							end
						end
					end
				end
			end
		end
	end
end

-- Load all alchemy skills from Server/Network (same as players)
local function loadAlchemySkills()
	local networkPath = ServerScriptService:FindFirstChild("ServerConfig")
	if networkPath then
		networkPath = networkPath:FindFirstChild("Server")
		if networkPath then
			networkPath = networkPath:FindFirstChild("Network")
			if networkPath then
				-- Alchemy skills: Cascade, Cinder, Firestorm, Rock Skewer, Construct, Deconstruct, AlchemicAssault, Stone Lance
				local alchemySkills = {
					"Cascade",
					"Cinder",
					"Firestorm",
					"Rock Skewer",
					"Construct",
					"Deconstruct",
					"AlchemicAssault",
					"Stone Lance",
				}

				for _, skillName in alchemySkills do
					local skillModule = networkPath:FindFirstChild(skillName)
					if skillModule and skillModule:IsA("ModuleScript") then
						alchemySkillHandlers[skillName] = require(skillModule)
						-- print("Loaded alchemy skill for NPCs:", skillName)
					end
				end
			end
		end
	end
end

loadWeaponSkills()
loadAlchemySkills()

function MainConfig.performAction(action, ...)
	-- Use the same weapon skill and alchemy system that players use
	local character = MainConfig.getNpc()
	if not character then
		warn("No NPC character found for performAction")
		return false
	end

	-- Get Server module (same way skills do)
	local Server = require(ServerScriptService.ServerConfig.Server)

	-- Create a fake player object for the NPC (skills expect a Player parameter)
	local fakePlayer = {
		Character = character,
		Name = character.Name,
	}

	-- DEBUG: Log NPC weapon and action
	local npcWeapon = character:GetAttribute("Weapon")
	-- print(string.format("[NPC %s] Attempting action: %s (Weapon: %s)", character.Name, action, npcWeapon or "NONE"))

	-- Check if it's a weapon skill first
	local weaponSkillHandler = weaponSkillHandlers[action]
	if weaponSkillHandler then
		-- Execute the weapon skill using the same function players use
		-- Weapon skills signature: function(Player, Data, Server)
		-- print(string.format("[NPC %s] Executing weapon skill: %s", character.Name, action))
		weaponSkillHandler(fakePlayer, {}, Server)
		return true
	end

	-- Check if it's an alchemy skill
	local alchemySkillHandler = alchemySkillHandlers[action]
	if alchemySkillHandler then
		-- Execute the alchemy skill using the same function players use
		-- Alchemy skills signature: NetworkModule.EndPoint(Player, Data)
		if alchemySkillHandler.EndPoint then
			alchemySkillHandler.EndPoint(fakePlayer, {})
		else
			warn("Alchemy skill", action, "does not have EndPoint function")
			return false
		end
		return true
	end

	warn("No skill handler found for:", action)
	return false
end

function MainConfig.getNpc()
	return script.Parent:FindFirstChildOfClass("Model")
end
function MainConfig.hasState(player: Model | Player, state: string, value: any)
	local stateValue = MainConfig.getState(player)
	if value then
		-- For specific value checks with the Library system
		-- You'll need to implement custom logic based on your needs
		warn("Value-based state checking requires custom implementation")
		return false
	end
	return Library.StateCheck(stateValue, state)
end

function MainConfig.getState(player: Model | Player)
	player = player or MainConfig.getNpc()

	-- Get the character model
	local character = player
	if player:IsA("Player") then
		character = player.Character
	end

	if not character then
		warn("MainConfig.getState: No character found for", player.Name)
		return nil
	end

	-- For both NPCs and players, use the standard Stuns state object from the character
	-- This is created by the entity system (Entities.Initialize)
	local stunState = character:FindFirstChild("Stuns")
	if stunState then
		return stunState
	else
		-- If no Stuns state exists, the character hasn't been properly initialized
		warn("Character", character.Name, "missing Stuns state - may need entity initialization")
		-- Create a temporary state to prevent errors
		local tempState = Instance.new("StringValue")
		tempState.Name = "TempStuns"
		tempState.Value = "[]"
		tempState.Parent = character
		return tempState
	end
end

function MainConfig.getSkillData(skill: string)
	return Skill_Data[skill]
end

function MainConfig.setTarget(player: Player?)
	MainConfig.EnemyDetection.Current = player
end

function MainConfig.getTarget(): Player?
	return MainConfig.EnemyDetection.Current
end

function MainConfig.getRunAnimation()
	return getRunPath(MainConfig.getNpc(), MainConfig)
end
function MainConfig.getBlockAnimation()
	return getBlockPath(MainConfig.getNpc(), MainConfig)
end
function MainConfig.getTargetCFrame(): CFrame
	return MainConfig.getTarget():GetPivot()
end

function MainConfig.getNpcCFrame(): CFrame
	return MainConfig.getNpc():GetPivot()
end

function MainConfig.StopWalking()
	MainConfig.Idle.WalkEnded:Fire()
end

function MainConfig.Alert(npc: Model)
	---- print(";hyw")

	if not npc or not npc:FindFirstChild("Head") then
		return
	end
	---- print("hyw1")
	--	bridges.Client:Fire(bridgeNet2.AllPlayers(),{
	--		Module = "AlertEffect",
	--Head = npc.Head,
	--	})
end

function MainConfig.TeleportSpawn()
	--TODO: Effect
end

function MainConfig.SpawnEffect(position): Vector3
	--TODO: Effect
	Server.Visuals.Ranged(position, 300, { Module = "Base", Function = "Spawn", Arguments = { Position = position } })
	print("doing spawn effect for npcs")
	print("position:", position)
end

function MainConfig.DespawnEffect(position): Vector3
	--TODO: Effect
	local specificDespawnEffectForNpc = `{MainConfig.getNpc().Name}DespawnEffect`
	-- print(specificDespawnEffectForNpc,position)
end

function MainConfig.LoadAppearance()
	local npc = MainConfig.getNpc()
	if not npc or not MainConfig.Appearance then
		return
	end

	if not MainConfig.Appearance.Enabled then
		return
	end

	local appearanceData = {
		Hair = require(MainConfig.Appearance.Hair),
		Face = require(MainConfig.Appearance.Face),
		Shirt = require(MainConfig.Appearance.Shirt),
		Pants = require(MainConfig.Appearance.Pants),
		SkinColor = require(MainConfig.Appearance.SkinColor),
	}
	for _, apperanceModule in appearanceData do
		apperanceModule(npc, MainConfig)
	end

	local accessories = MainConfig.Appearance.Accessories
	do
		if accessories and #accessories > 0 then
			for _, accessory in accessories do
				--todo
			end
		end
	end
end

function MainConfig.InitiateRun(ShouldRun: boolean)
	local npc = MainConfig.getNpc()
	if not npc then
		return
	end

	local npcStates = MainConfig.getState(npc)
	if not npcStates then
		return
	end

	-- Check states using Library system
	local canRun = not (Library.StateCheck(npcStates, "Stunned") or Library.StateCheck(npcStates, "ToSpeed"))
	ShouldRun = if canRun then ShouldRun else false

	-- Handle s-- printing state
	if ShouldRun then
		if not Library.StateCheck(npcStates, "S-- printing") then
			Library.AddState(npcStates, "S-- printing")
		end
	else
		if Library.StateCheck(npcStates, "S-- printing") then
			Library.RemoveState(npcStates, "S-- printing")
		end
	end

	local runAnimation = MainConfig.getRunAnimation()
	if runAnimation then
		if ShouldRun then
			Library.PlayAnimation(npc, runAnimation)
		else
			Library.StopAnimation(npc, runAnimation, { FadeTime = 0.25 })
		end
	end
end

function MainConfig.getMimic(): Folder
	local Perequisite_Folder_Name: string = "AiPrerequistes"

	local npc: Model? = MainConfig.getNpc()
	if not npc then
		return
	end

	if npc:FindFirstChild(Perequisite_Folder_Name) then
		return npc[Perequisite_Folder_Name]
	end

	local Folder: Folder = Instance.new("Folder")
	Folder.Name = Perequisite_Folder_Name

	local pathfindingState: IntValue = Instance.new("IntValue")
	pathfindingState.Name = "PathState"
	pathfindingState.Parent = Folder

	local pathfindingId: IntValue = Instance.new("IntValue")
	pathfindingId.Name = "StateId"
	pathfindingId.Parent = Folder

	Folder.Parent = npc

	return Folder
end

function MainConfig.InitiateBlock(ShouldBlock: boolean)
	local npc = MainConfig.getNpc()
	if not npc then
		return
	end

	local npcStates = MainConfig.getState()
	if not npcStates then
		return
	end

	local canBlock = not Library.StateCheck(npcStates, "Stunned")
	ShouldBlock = if canBlock then ShouldBlock else false

	-- Update blocking state
	if ShouldBlock then
		Library.AddState(npcStates, "Blocking")
	else
		Library.RemoveState(npcStates, "Blocking")
	end

	local blockAnimation = MainConfig.getBlockAnimation()
	if blockAnimation then
		local config = {
			[`true`] = function()
				Library.PlayAnimation(npc, blockAnimation)
			end,
			[`false`] = function()
				Library.StopAnimation(npc, blockAnimation, 0.25) -- Pass fade time as number, not table
			end,
		}
		config[tostring(ShouldBlock)]()
	end
end

function MainConfig.cleanup(boolean: boolean)
	---- print(debug.info(2, "sl"))
	if #MainConfig.Storage > 0 then
		--task.synchronize()
		for _, specificTag in MainConfig.Spawning.Tags do
			game.CollectionService:RemoveTag(MainConfig.getNpc(), specificTag)
		end

		for _, trash in MainConfig.Storage do
			if typeof(trash) == "RBXScriptConnection" then
				trash:Disconnect()
			else
				trash:Destroy()
			end
		end
		--task.desynchronize()
	end
	table.clear(MainConfig.Storage)
	table.clear(MainConfig.States)

	MainConfig.EnemyDetection.Current = nil
end

return MainConfig
