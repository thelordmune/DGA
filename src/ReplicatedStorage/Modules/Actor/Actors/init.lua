local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")
local Replicated = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local Actors = {}
Actors.__index = Actors
local self = setmetatable({}, Actors)

self["ActorStorage"] = {}


local TempCallbacks = {};
local CoreGameCallbacks = {};

-- Connect any parallel code lalwalwlalwa
-- Create actors

RunService.Heartbeat:ConnectParallel(function(Delta)
	local CallbackValue
	for _, CallbackData in pairs(TempCallbacks) do
		CallbackValue = CallbackData.Callback(Delta)

		if CallbackValue then
			table.remove(TempCallbacks, table.find(TempCallbacks, CallbackData))
		end
	end
end);

(if RunService:IsServer() then RunService.Heartbeat else RunService.RenderStepped):ConnectParallel(function(Delta)
	for _, Callback in pairs(CoreGameCallbacks) do
		Callback(Delta)
	end

	local CallbackValue
	for _, CallbackData in pairs(TempCallbacks) do
		CallbackValue = CallbackData.Callback(Delta)

		if CallbackData.Warning ~= nil then
			if not CallbackData.Warning and os.clock() - CallbackData.Init > 60 then
				CallbackData.Warning = true
				warn("Temp Callback Not Disconnected", CallbackData.Trace)
			end
		end

		if CallbackValue then
			table.remove(TempCallbacks, table.find(TempCallbacks, CallbackData))
		end
	end
end);

function Actors.AddToTempLoop(callback)
	local Info = {Callback = callback}
	table.insert(TempCallbacks, Info)
end

Actors.CreateActor = function(Type: string, ActorParent, Information: {})
	if script.Templates:FindFirstChild(Type) then
		local Actor = script.Templates[Type]:Clone()
		Actor.Parent = ActorParent
		local ActorFunctions = require(Actor.ActorFunctions)
		--ActorFunctions.Information = Information
		return Actor
	end
end

--Actors.

Actors.Message = function(ActorName: string,...)
	local Arguments = {...}
	if self["ActorStorage"][ActorName]  and Actors[self["ActorStorage"][ActorName].Message] then
		Actors[self["ActorStorage"][ActorName].Message](table.unpack(Arguments))
	end
end

return Actors
