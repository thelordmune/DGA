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

function NpcBrain._update(params: UpdateParams)
	local behavior: any = Behaviors[`{params.npcName}_BehaviorTree`]
	if not behavior then 
		return 
	end

	--task.desynchronize()

	local btInstance = behavior(BT)
	task.spawn(btInstance,script.Parent,MainConfig)

	--task.synchronize()

	local waitTime: number = calculateWaitTime(params.npc)
	task.wait(waitTime)
end

function NpcBrain.init()
	local actor = script:FindFirstAncestorWhichIsA("Actor")
	assert(actor, `{script.Name} must be parented to an Actor`)
	
	
	task.spawn(function()
		while true do
			local npc = script.Parent:FindFirstChildOfClass("Model")

			--local _ = npc and print(`{npc.Name} <- NpcName`)
			--local _ = not npc and MainConfig.cleanup()

			local params: UpdateParams = {
				npc = npc,
				npcName = script.Parent.Parent.Name,
				deltaTime = RunService.Heartbeat:Wait()
			}

			NpcBrain._update(params)
		end
	end)
end

NpcBrain.init()
return NpcBrain