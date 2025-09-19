local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local phase_util = require(ReplicatedStorage.Modules.ECS.jecs_phases_util)
local bridges = require(ReplicatedStorage.Modules.Bridges)
local RunService = game:GetService("RunService")
local scheduler = require(ReplicatedStorage.Modules.ECS.jecs_scheduler)

return {
    PlayerAdded = scheduler.PHASE({
        event = Players.PlayerAdded,
        name = "PlayerAdded",
        after = scheduler.PhaseEntities.Heartbeat
    }),
    PlayerRemoved = scheduler.PHASE({
        event = Players.PlayerRemoving,
        name = "PlayerRemoved",
        after = scheduler.PhaseEntities.Heartbeat
    }),
    ECSServer = scheduler.PHASE({
        event = bridges.ECSServer,
        name = "ECSServer",
        after = scheduler.PhaseEntities.Heartbeat
    }),
    Heartbeat = scheduler.PHASE({
        event = RunService.Heartbeat,
        name = "Heartbeat",
        after = scheduler.PhaseEntities.PreSimulation
    })
}