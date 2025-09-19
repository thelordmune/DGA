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
    local systemsSuccess, systemsResult = pcall(scheduler.FillingSchedulerWithSystems, jabbyScheduler, systemsFolder)
    if not systemsSuccess then
        error("failed to fill scheduler with systems")
    end
      
    pcall(scheduler.RegisteringWorldToJabby)
    pcall(scheduler.RegisterSchedulerToJabby, jabbyScheduler)
    
    local events = scheduler.COLLECT()
    scheduler.BEGIN(events)
    
    local lastTime = os.clock()
    local function getDeltaTime()
        local currentTime = os.clock()
        local delta = currentTime - lastTime
        lastTime = currentTime
        return math.clamp(delta, 1/60, 1/30)
    end
    
    
   local function executeSystems(phaseEntity)
    if not world:has(phaseEntity, comps.Phase) then
        warn("Invalid phase entity (missing Phase component):", phaseEntity)
        return
    end
    local event = world:get(phaseEntity, comps.Event)
    if not event then
        warn("Phase missing event component:", world:get(phaseEntity, comps.Name) or phaseEntity)
        return
    end


    
   local phaseName = world:get(phaseEntity, comps.Name) or "UnknownPhase"
    print(`Initializing systems for phase: {phaseName}`)
    local isFrameEvent = (
        event == RunService.Heartbeat or
        event == RunService.Stepped or
        event == RunService.RenderStepped
    )

    systemConnections[phaseEntity] = event:Connect(function(...)
        local args = {...}
        local success, err = pcall(function()
            
            local delta = isFrameEvent and getDeltaTime() or nil
            
            
            for system in world:query(comps.System):with(pair(comps.DependsOn, phaseEntity)) do
                local sysData = world:get(system, comps.System)
                
                if not sysData then
                    warn("System entity missing data:", system)
                    continue
                end

                
                local systemName = sysData.name or "UnnamedSystem"
                local startTime = os.clock()

                
                local systemArgs
                if isFrameEvent then
                    systemArgs = {world, delta}
                else
                    systemArgs = {world, table.unpack(args)}
                end

                
                local execSuccess, execErr = pcall(function()
                    jabbyScheduler:run(sysData.id, function()
                        sysData.callback(table.unpack(systemArgs))
                    end)
                end)

                
                if not execSuccess then
                    warn(`System '{systemName}' in phase '{phaseName}' failed: {execErr}`)
                    warn("Arguments:", systemArgs)
                    warn("Stack trace:", debug.traceback())
                else
                    
                    local duration = os.clock() - startTime
                    if duration > 0.1 then
                        warn(`System '{systemName}' took {math.round(duration * 1000)}ms`)
                    end
                end
            end
        end)

        if not success then
            warn(`Phase '{phaseName}' execution failed: {err}`)
            warn("Event args:", args)
            warn("Stack trace:", debug.traceback())
        end
    end)


    print(`Connected phase '{phaseName}' to event {tostring(event)}`)
end

    for _, phaseEntity in pairs(validPhases) do
        executeSystems(phaseEntity)
    end
    
    local systemsFolder = RunService:IsServer() 
        and game:GetService("ServerScriptService").Systems
        or game:GetService("ReplicatedStorage"):FindFirstChild("Modules"):FindFirstChild("Systems")
    
    local function init(module)
        -- cleanupSystem(module.Name)
        local success, systemModule = pcall(require, module)
        if not success then return end
        
        local systemFunc = systemModule.run
        local settings = systemModule.settings or {}
        local phaseName = settings.phase or "Heartbeat"
        local phaseEntity = phases[phaseName] or phases.Heartbeat
        
        local systemId = jabbyScheduler:register_system({
            name = module.Name,
            phase = phaseName,
            paused = settings.paused or false
        })
        
        local systemEntity = world:entity()
        world:set(systemEntity, comps.System, {
            id = systemId,
            callback = systemFunc,
            name = module.Name,
            phase = phaseName
        })
        world:add(systemEntity, pair(comps.DependsOn, phaseEntity))
        
        initializedSystems[module.Name] = systemId
        print("Registered system:", module.Name)
    end
    
    -- hotReloader:scan(systemsFolder, init)
    
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
    
    jabby.set_check_function(function(player) return true end)
end

return start