local NpcBrain = {}

-- Services
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Types
export type BehaviorNode<T...> = (T...) -> boolean | typeof(RUNNING)
export type NodeArray<T...> = {BehaviorNode<T...>}

-- Constants
local SUCCESS = true
local FAILURE = false
local RUNNING = newproxy()

local Behaviors = require(ReplicatedStorage.NpcHelper.Behaviors)
local MainConfig = require(script.Parent.MainConfig)

local bridges = require(ReplicatedStorage.Bridges)
local bridgeNet2 = require(ReplicatedStorage.BridgeNet2)

local BT = {
	running = RUNNING,

	invert =function<T...>(children: NodeArray<T...>): BehaviorNode<T...>
		return function(...: T...)
			for _, node in children do
				local result = node(...)
				return if result == RUNNING then RUNNING 
					else not result
			end
		end
	end ,
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

function NpcBrain._update(deltaTime: number, npcName: string)
	local behavior = Behaviors[`{npcName}_BehaviorTree`](BT)
	behavior(script.Parent, MainConfig) -- Pass Actor and MainConfig
end

function NpcBrain.init()
	local actor = script:FindFirstAncestorWhichIsA("Actor")
	if not actor then
		warn(`{script.Name} must be parented to an Actor`)
		return
	end

	RunService.Heartbeat:ConnectParallel(function(deltaTime: number)
		local npcName = script.Parent.Parent.Name -- npc name
		local npc = script.Parent:FindFirstChildOfClass("Model") 

		--local _ = npc and -- print(`{npc.Name} <- NpcName`)
		--local _ = not npc and MainConfig.cleanup()
		NpcBrain._update(deltaTime,npcName)	

	end)
end

NpcBrain.init()
return NpcBrain