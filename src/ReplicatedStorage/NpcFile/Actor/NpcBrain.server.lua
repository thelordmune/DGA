local NpcBrain = {}

-- Services
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Types
type TaskConfig = {
	Min: number,
	Max: number?,
	Value: number
}

export type BehaviorNode<T...> = (T...) -> boolean | typeof(RUNNING)
export type NodeArray<T...> = {BehaviorNode<T...>}

-- Constants
local SUCCESS: boolean = true;
local FAILURE: boolean = false;

local RUNNING = newproxy() :: any

local Behaviors = require(ReplicatedStorage.NpcHelper.Behaviors)
local MainConfig = require(script.Parent.MainConfig)

-- local bridges = require(ReplicatedStorage.Bridges)
-- local bridgeNet2 = require(ReplicatedStorage.BridgeNet2)

local BT = {
	running = RUNNING,

	invert = function<T...>(children: NodeArray<T...>): BehaviorNode<T...>
		return function(...: T...)
			for _, node in children do
				local result = node(...)
				return if result == RUNNING then RUNNING
					else not result
			end
		end
	end,

	fallback = function<T...>(children: NodeArray<T...>): BehaviorNode<T...>
		return function(...: T...)
			for _, node in children do
				local status = node(...)
				if status == RUNNING or status == SUCCESS then
					return status
				end
			end
			return FAILURE
		end
	end,

	sequence = function<T...>(children: NodeArray<T...>): BehaviorNode<T...>
		return function(...: T...)
			for _, node in children do
				local status = node(...)
				if status == RUNNING or status == FAILURE then
					return status
				end
			end
			return SUCCESS
		end
	end
}

-- Configuration
local WaitRanges: {TaskConfig} = {
	{ Min = 100, Max = 200, Value = 0.5 },
	{ Min = 200, Max = 300, Value = 1.0 },
	{ Min = 300, Max = 500, Value = 2.0 },
	{ Min = 900, Value = 3.0 }
}

type UpdateParams = {
	npc: Model?,
	npcName: string,
	deltaTime: number
}

local DEFAULT_NUMBER: number = 0.2
local function calculateWaitTime(character: Model?): number
	if not character or not character:FindFirstChild("HumanoidRootPart") then
		return DEFAULT_NUMBER
	end

	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart
	local closestDistance: number? = nil

	for _, player: Player in game.Players:GetPlayers() do
		local playerCharacter = player.Character
		if not playerCharacter then 
			continue 
		end

		local root = playerCharacter:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then 
			continue
		end

		local distance = (root.Position - humanoidRootPart.Position).Magnitude
		closestDistance = if not closestDistance then distance
			else math.min(closestDistance, distance)

		if distance <= 500 then
			break
		end
	end

	if not closestDistance then
		return DEFAULT_NUMBER
	end

	local waitTime: number = DEFAULT_NUMBER
	for _, range in WaitRanges do
		if closestDistance >= range.Min and (not range.Max or closestDistance < range.Max) then
			waitTime = math.max(waitTime, range.Value)
		end
	end

	return waitTime
end

local cachedBehaviorTree = nil
local cachedBehaviorName = nil

function NpcBrain._update(params: UpdateParams)
	local behaviorName = `{params.npcName}_BehaviorTree`
	local behavior: any = Behaviors[behaviorName]


	if not behavior then
		return
	end

	if cachedBehaviorName ~= behaviorName then
		cachedBehaviorTree = behavior(BT)
		cachedBehaviorName = behaviorName
	end

	cachedBehaviorTree(script.Parent, MainConfig)
end

function NpcBrain.init()

	local lastUpdateTime = 0
	local npcName = script.Parent.Parent.Name

	-- Check if this NPC is controlled by ECS (combat NPCs)
	-- Use MainConfig.getNpc() which caches the reference (persists after Chrono moves the model)
	local ECSBridge = require(ReplicatedStorage.NpcHelper.ECSBridge)
	local npcModel = MainConfig.getNpc()
	local isECSControlled = ECSBridge.isCombatNPC(npcModel)

	if isECSControlled then
		print(`[NpcBrain] {npcName} is a combat NPC - ECS systems handle AI, skipping behavior tree`)
		-- Combat NPCs are fully controlled by ECS systems
		-- No need to run behavior tree at all
		return
	end

	script.Parent.Parent.Destroying:Connect(function()
		cachedBehaviorTree = nil
		cachedBehaviorName = nil
	end)

	RunService.Heartbeat:Connect(function(deltaTime: number)
		-- Use MainConfig.getNpc() which caches the reference (persists after Chrono moves the model)
		local npc = MainConfig.getNpc()

		local currentTime = os.clock()
		local waitTime = calculateWaitTime(npc)

		if currentTime - lastUpdateTime < waitTime then
			return
		end

		lastUpdateTime = currentTime

		local params: UpdateParams = {
			npc = npc,
			npcName = npcName,
			deltaTime = deltaTime
		}

		NpcBrain._update(params)
	end)
end

NpcBrain.init()
return NpcBrain