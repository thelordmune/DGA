-- jecs_start.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local jabby = require(ReplicatedStorage.Modules.Imports.jabby)
local jecs = require(ReplicatedStorage.Modules.Imports.jecs)
local scheduler = require(script.Parent.jecs_scheduler)
local HotReloader = require(ReplicatedStorage.Modules.Imports.rewire).HotReloader
local world = require(script.Parent.jecs_world)
local pair = jecs.pair
local comps = require(script.Parent.jecs_components)

local hotReloader = HotReloader.new()
local initializedSystems = {}
local systemConnections = {}


do
    local callingScript = debug.traceback("jecs_start.lua was called from:")
    print("JECS Startup Trace:")
    print(callingScript)
    warn("JECS initialization called from:", callingScript)
end


local function cleanupSystem(name)
    for systemEntity, data in world:query(comps.System) do
        if data.name == name then
            
            if data.id then
                if scheduler.schedulers and #scheduler.schedulers > 0 then
                    pcall(function()
                        scheduler.schedulers[1]:remove_system(data.id)
                    end)
                else
                    warn("Scheduler not initialized during cleanup of", name)
                end
            end

            world:remove(systemEntity)
            
            if systemConnections[name] then
                systemConnections[name]:Disconnect()
                systemConnections[name] = nil
            end
            
            print("Cleaned up system:", name)
        end
    end
end

local function start(systemsFolder)
    if not world then
        error("World not initialized")
    end

    if not scheduler then
        error("Scheduler not initialized")
    end

    print("starting ecs initialization")
    print("Systems folder:", systemsFolder and systemsFolder:GetFullName() or "Using default detection")

    local phases = scheduler.SetupPhases()
    if not phases or not next(phases) then
        error("failed to setup phases")
    end

    local RunService = game:GetService("RunService")
    local Players = game:GetService("Players")

    local validPhases = {}
    for phaseEntity in world:query(comps.Phase):with(comps.Event) do
        table.insert(validPhases, phaseEntity)
        local phaseName = world:get(phaseEntity, comps.Name)
        local event = world:get(phaseEntity, comps.Event)
        print("Valid phase found:", phaseName, event)
    end

    if #validPhases == 0 then
        error("no valid phases found ecs will not be able to start")
    end

    local success, jabbyScheduler = pcall(scheduler.CreatingScheduler)
    if not success or not jabbyScheduler then
        error("failed to create scheduler")
    end

    -- Pass the systems folder to the scheduler
    local systemsSuccess, systemsError = pcall(scheduler.FillingSchedulerWithSystems, jabbyScheduler, systemsFolder)
    if not systemsSuccess then
        error("failed to fill scheduler with systems: " .. tostring(systemsError))
    end
      
    pcall(scheduler.RegisteringWorldToJabby)
    pcall(scheduler.RegisterSchedulerToJabby, jabbyScheduler)
    
    local events = scheduler.COLLECT()
    local connections = scheduler.BEGIN(events)

    print("✅ ECS system connections established")
    print("📊 Active phases:")
    for phaseEntity in world:query(comps.Phase):with(comps.Event) do
        local phaseName = world:get(phaseEntity, comps.Name) or "UnknownPhase"
        local systemCount = 0
        for _ in world:query(comps.System):with(pair(comps.DependsOn, phaseEntity)) do
            systemCount = systemCount + 1
        end
        print(`  - {phaseName}: {systemCount} systems`)
    end

    -- Note: System loading is now handled by scheduler.FillingSchedulerWithSystems
    -- The old hotReloader:scan approach has been replaced
    
    if RunService:IsClient() then
        local player = game:GetService("Players").LocalPlayer
        local client = jabby.obtain_client()
        UserInputService.InputBegan:Connect(function(input)
            if input.KeyCode == Enum.KeyCode.F4 then
                local playergui = player:WaitForChild("PlayerGui")
                local home = playergui:FindFirstChild("Home")
                if home then home:Destroy() end
                client.spawn_app(client.apps.home)
            end
        end)
    end
    
    jabby.set_check_function(function(_player) return true end)
end

return start