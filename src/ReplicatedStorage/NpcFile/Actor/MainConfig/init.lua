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


for i_branch: string, v: {[string]: {[string]: any}} in  require(ReplicatedStorage.Skill_Data) do 
	for i, v in v do 
		v.Branch = i_branch
		Skill_Data[i] = v 
	end
end

type SpawningConfig = {
	Enabled: boolean,
	Cooldown: number,
	LastSpawned: number,
	Locations: {Vector3},
	Despawning: {
		Enabled: boolean,
		DespawnDistance: number
	}
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
		Current: number
	}
}

type IdleConfig = {
	WaitBeforeChangingDirection: {
		Min: number,
		Max: number
	},
	WalkEnded: typeof(Signal.new()),
	GoAtSpawnFirstIfFar: boolean,
	Positions: {Vector3},
	GoalPoint: Vector3?,
	ReachedGoal: boolean,
	LastArrived: number,
	Move_Places: boolean
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
			Max: Number
		},
		BackawaySpeed: Number,
		StrafeSpeed: Number,
		ForwardMixRatio: Number -- how much forward movement to mix in with strafe
	}
}

local MainConfig = {
	States = {},
	Storage = {},

	SpawnConnections = {},

	Appearance = {},

	Movement = {
		MaxStrafeRadius = 15, -- maximum distance for strafing
		MaxAlignmentDot = 0.3, -- Minimum dot product to allow strafing
		BackupSpeed = 5, -- when being pressed by a player and the npc backs up


		Patterns = {
			Current = nil, -- Current pattern type
			LastChanged = 0,

			Duration = {
				Min = 2,
				Max = 3
			},
			Types = {
				Strafe = {
					Speed = 1.5,
					ForwardMix = 1,
				},
				SideApproach = {
					ForwardSpeed = 1,
					SideSpeed = 2,
					Direction = nil -- "Left" or "Right"
				},
				Direct = {
					Speed = 1
				},
				CircleStrafe = {
					Speed = 0.7,
					Radius = 8
				},
				ZigZag = {
					ForwardSpeed = 0.7,
					SideSpeed = 0.3,
				}
			}
		}
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
			Current = 2
		},
		RunAway = {
			RunHp = 0,
			Ranges = {
				SafeRange = 37
			},
		}
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
			AddAmount = 1/100,
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
		RunOnFollowing = {Distance = 5,AwayOrNear = "Away",Enabled = true},
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
			Max = 7
		},
		PauseDuration = {
			Current = nil,
			Min = 3,
			Max = 5
		},
	},
	Idle2 = {
		WaitBeforeChangingDirection = {
			Min = 1,
			Max = 3
		},
		WalkEnded = Signal.new(),
		GoAtSpawnFirstIfFar = true,
		Positions = {},
		-- Add these new fields
		-- OLD
		GoalPoint = nil,          -- Current goal point
		ReachedGoal = false,      -- Track if goal is reached
		LastArrived = 0,          -- Time of last arrival at goal
		Move_Places = true,       -- Enable/disable movement
	} :: IdleConfig,

	Spawning = {
		SpawnedAt = Vector3.zero,
		Enabled = true,
		Cooldown = 2,
		LastSpawned = 0,
		Locations = {},
		ChosenSpawnLocation = nil,
		Tags = {"Humanoids"},
		DespawnTime = 3,
		Despawning = {
			Enabled = true,
			DespawnDistance = 150
		}
	} :: SpawningConfig,

	HumanoidDefaults = {
		WalkSpeed = 16,
		RunSpeed =35,
		JumpPower = 50,
	}
}

-- Initialize with NPC data
local NpcData = script.Parent.Parent:WaitForChild(`Data`) do
	local DataFetched = {}
	Serializer.ToTable(NpcData, DataFetched)

	--print(DataFetched)

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
end

function MainConfig.onCooldown(actionData)
	-- simulate npc actions here
	--print(action)
	--return os.clock() -   -- Skill_Setup:checkCooldown(MainConfig.getNpc(), Skill_Data[action].Branch, action)
	return os.clock() - actionData.Last_Used < actionData.Cooldown
end

local skillHandlers: { [string]: SkillHandler } = {}
for i, v: ModuleScript in ReplicatedStorage.Actions:GetDescendants() do if v:IsA("ModuleScript") then 
		skillHandlers[v.Name] = require(v) :: any
	end
end

function MainConfig.performAction(action, ...)
	-- simulate npc actions here
	local character = MainConfig.getNpc()
	local skillExecution = skillHandlers[action]

	--print(skillHandlers, MainConfig.onCooldown(action))
	--print(Skill_Data[action])

	if not MainConfig.onCooldown(Skill_Data[action]) then
		--task.synchronize()
		skillExecution(character, {skill = action}, Skill_Data[action])
		--task.desynchronize()
	else
		print("on cooldown")
	end
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
	local statesFolder = game.ReplicatedStorage:FindFirstChild("PlayerStates")
	if not statesFolder then
		statesFolder = Instance.new("Folder")
		statesFolder.Name = "PlayerStates"
		statesFolder.Parent = ReplicatedStorage
	end

	-- Ensure we're using a StringValue, not a Folder
	local stateValue = statesFolder:FindFirstChild(player.Name)
	if not stateValue then
		stateValue = Instance.new("StringValue")
		stateValue.Name = player.Name
		stateValue.Value = "[]" -- Empty JSON array
		stateValue.Parent = statesFolder
	elseif stateValue:IsA("Folder") then
		-- Convert existing Folder to StringValue if needed
		local newValue = Instance.new("StringValue")
		newValue.Name = player.Name
		newValue.Value = "[]"
		newValue.Parent = statesFolder
		stateValue:Destroy()
		stateValue = newValue
	end

	return stateValue
end

function MainConfig.getSkillData(skill: string)
	return  Skill_Data[skill]
end

function MainConfig.setTarget(player: Player?)
	MainConfig.EnemyDetection.Current = player
end

function MainConfig.getTarget(): Player?
	return MainConfig.EnemyDetection.Current
end

function MainConfig.getRunAnimation()
	return getRunPath(MainConfig.getNpc(),MainConfig)
end
function MainConfig.getBlockAnimation()
	return getBlockPath(MainConfig.getNpc(),MainConfig)
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
	--print(";hyw")

	if not npc or not npc:FindFirstChild("Head") then
		return
	end
	--print("hyw1")
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
	local specificSpawnEffectForNpc = `{MainConfig.getNpc().Name}SpawnEffect`
	print(specificSpawnEffectForNpc,position)
end

function MainConfig.DespawnEffect(position): Vector3
	--TODO: Effect
	local specificDespawnEffectForNpc = `{MainConfig.getNpc().Name}DespawnEffect`
	print(specificDespawnEffectForNpc,position)
end


function MainConfig.LoadAppearance()
	local npc = MainConfig.getNpc()
	if not npc or not MainConfig.Appearance then 
		return
	end

	local actor = script.Parent :: Actor
	if not actor:IsA("Actor") then
		warn(`MainConfig isnnt parented under an Actor || Parent: {actor}`)
		return
	end


	if not MainConfig.Appearance.Enabled then
		return
	end

	local appearanceData  = {
		Hair = require(MainConfig.Appearance.Hair),
		Face = require(MainConfig.Appearance.Face), 
		Shirt = require(MainConfig.Appearance.Shirt),
		Pants = require(MainConfig.Appearance.Pants),
		SkinColor = require(MainConfig.Appearance.SkinColor),
	}
	for _,apperanceModule in appearanceData do
		apperanceModule(npc,MainConfig)
	end

	local accessories = MainConfig.Appearance.Accessories do
		if accessories and #accessories > 0 then
			for _, accessory in accessories do
				--todo
			end
		end
	end

end

function MainConfig.InitiateRun(ShouldRun: boolean)
	local npc = MainConfig.getNpc()
	if not npc then return end

	local npcStates = MainConfig.getState(npc)
	if not npcStates then return end

	-- Check states using Library system
	local canRun = not (Library.StateCheck(npcStates, "Stunned") or Library.StateCheck(npcStates, "ToSpeed"))
	ShouldRun = if canRun then ShouldRun else false

	-- Handle sprinting state
	if ShouldRun then
		if not Library.StateCheck(npcStates, "Sprinting") then
			Library.AddState(npcStates, "Sprinting")
		end
	else
		if Library.StateCheck(npcStates, "Sprinting") then
			Library.RemoveState(npcStates, "Sprinting")
		end
	end

	local runAnimation = MainConfig.getRunAnimation()
	if runAnimation then
		if ShouldRun then
			Library.PlayAnimation(npc, runAnimation)
		else
			Library.StopAnimation(npc, runAnimation, {FadeTime = 0.25})
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
	Folder.Name = Perequisite_Folder_Name;

	local pathfindingState: IntValue = Instance.new("IntValue")
	pathfindingState.Name = "PathState";
	pathfindingState.Parent = Folder;

	local pathfindingId: IntValue = Instance.new("IntValue")
	pathfindingId.Name = "StateId"
	pathfindingId.Parent = Folder;
	
	Folder.Parent = npc;
	return Folder
end

function MainConfig.InitiateBlock(ShouldBlock: boolean)
	local npc = MainConfig.getNpc()
	if not npc then return end

	local npcStates = MainConfig.getState()
	if not npcStates then return end

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
				Library.StopAnimation(npc, blockAnimation, {FadeTime = 0.25})
			end,
		}
		config[tostring(ShouldBlock)]()
	end
end


function MainConfig.cleanup(boolean: boolean)
	--print(debug.info(2, "sl"))
	if #MainConfig.Storage > 0 then
		--task.synchronize()
		for _,specificTag in MainConfig.Spawning.Tags do
			game.CollectionService:RemoveTag(MainConfig.getNpc(),specificTag)
		end

		for _,trash in MainConfig.Storage do
			if typeof(trash) == "RBXScriptConnection" then trash:Disconnect(); else trash:Destroy(); end
		end
		--task.desynchronize()
	end
	table.clear(MainConfig.Storage)
	table.clear(MainConfig.States)

	MainConfig.EnemyDetection.Current = nil


end

return MainConfig