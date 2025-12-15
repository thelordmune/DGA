local function getSystemsFolders() : table
 	local folders = {}
	local addedFolders = {} -- Track which folders we've already added to prevent duplicates

	if game:GetService("RunService"):IsServer() then
		-- Server loads from ServerScriptService
		local ServerScriptService = game:GetService("ServerScriptService")
		local serverSystems = ServerScriptService:WaitForChild("Systems", 10)
		if serverSystems then
			table.insert(folders, { folder = serverSystems, context = "server" })
			addedFolders[serverSystems] = true
			---- print("Server systems folder found:", serverSystems:GetFullName())
		end
	end

	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local modules = ReplicatedStorage:WaitForChild("Modules", 10)
	if modules then
		local sharedSystems = modules:FindFirstChild("Systems")
		if not sharedSystems then
			-- Create the folder if it doesn't exist
			sharedSystems = Instance.new("Folder")
			sharedSystems.Name = "Systems"
			sharedSystems.Parent = modules
			---- print("Created Systems folder in ReplicatedStorage.Modules")
		end

		-- Only add if we haven't already added this folder
		if sharedSystems and not addedFolders[sharedSystems] then
			local context = game:GetService("RunService"):IsClient() and "client" or "shared"
			table.insert(folders, { folder = sharedSystems, context = context })
			addedFolders[sharedSystems] = true
			---- print(`{context == "client" and "Client" or "Shared"} systems folder found:`, sharedSystems:GetFullName())
		end
	end

	return folders
end

local jabby = require(game:GetService("ReplicatedStorage").Modules.Imports.jabby)
local jecs = require(game:GetService("ReplicatedStorage").Modules.Imports.jecs)
local comps = require(script.Parent.jecs_components)
local world = require(script.Parent.jecs_world)
local pair = jecs.pair
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

-- Store active scheduler for system time tracking
local activeScheduler = nil

-- Add components from example
local System = comps.System :: jecs.Id<{ callback: (any) -> (), name: string }>
local DependsOn = comps.DependsOn
local Phase = comps.Phase :: jecs.Id<RBXScriptSignal>
local Event = comps.Event

-- Phase entities (kept from your code)
local PreRender = world:entity()
local Heartbeat = world:entity()
local PreSimulation = world:entity()
local PreAnimation = world:entity()

local function CreatingScheduler()
	activeScheduler = jabby.scheduler.create("MainScheduler")
	return activeScheduler
end

local function FillingSchedulerWithSystems(scheduler, customSystemsFolder)
    local systemsFolders = {}
    
    -- If a custom folder is provided, use only that
    if customSystemsFolder then
        if customSystemsFolder:IsA("Folder") then
            table.insert(systemsFolders, {folder = customSystemsFolder, context = "custom"})
            ---- print("Using custom systems folder:", customSystemsFolder:GetFullName())
        else
            warn("Invalid systems folder provided, falling back to default detection")
            systemsFolders = getSystemsFolders()
        end
    else
        -- Use default folder detection
        systemsFolders = getSystemsFolders()
    end
    
    if #systemsFolders == 0 then
        warn("No systems folders found, skipping system loading")
        return {}
    end

    local schedulerSystems = {}
    local phases = require(game:GetService("ReplicatedStorage").Modules.ECS.jecs_phases)

    -- Wait for phases to be ready
    local maxWait = 5
    local waited = 0
    while (not phases.Heartbeat or not world:exists(phases.Heartbeat)) and waited < maxWait do
        task.wait(0.1)
        waited = waited + 0.1
    end

    if not phases.Heartbeat or not world:exists(phases.Heartbeat) then
        error("Heartbeat phase not ready after waiting")
    end

    -- Load systems from all folders
    for _, folderData in pairs(systemsFolders) do
        local currentSystemsFolder = folderData.folder
        local context = folderData.context

        ---- print(`Loading {context} systems from: {currentSystemsFolder:GetFullName()}`)

        for _, module in pairs(currentSystemsFolder:GetChildren()) do
            if not module:IsA("ModuleScript") then
                continue
            end

            local success, err = pcall(function()
               -- print(`[Scheduler] Loading {context} system: {module.Name}`)
                local systemModule = require(module)

                -- Validate system structure
                if not systemModule.run then
                    warn(`[Scheduler] System {module.Name} missing run function`)
                    return
                end

                -- Check if system should run on this context (skip for custom folders)
                local settings = systemModule.settings or {}
                if context ~= "custom" then
                    local isServer = game:GetService("RunService"):IsServer()

                    -- Skip if context doesn't match
                    if isServer and settings.client_only then
                       -- print(`[Scheduler] Skipping client-only system {module.Name} on server`)
                        return
                    end
                    if not isServer and settings.server_only then
                       -- print(`[Scheduler] Skipping server-only system {module.Name} on client`)
                        return
                    end
                end

                -- Phase resolution with validation
                local phaseName = settings.phase or "Heartbeat"
                local phaseEntity = phases[phaseName]
                if not phaseEntity then
                    warn(`Phase {phaseName} not found for system {module.Name}, using Heartbeat`)
                    phaseEntity = phases.Heartbeat
                end

                -- Verify phase entity validity
                if not world:exists(phaseEntity) then
                    warn(`Invalid phase entity for {phaseName} in system {module.Name}`)
                    return
                end

                -- System registration
                local systemId = scheduler:register_system({
                    name = module.Name,
                    phase = phaseName,
                    paused = settings.paused or false,
                })

                -- Entity creation with validation
                local systemEntity = world:entity()
                if not systemEntity then
                    warn(`Failed to create entity for system {module.Name}`)
                    return
                end

                -- Component setup
                world:set(systemEntity, comps.System, {
                    id = systemId,
                    callback = systemModule.run,
                    name = module.Name,
                    phase = phaseName,
                    context = context,
                })

                -- Pair relationship with error checking
                world:add(systemEntity, jecs.pair(comps.DependsOn, phaseEntity))

                table.insert(schedulerSystems, {
                    id = systemId,
                    callback = systemModule.run,
                    entity = systemEntity,
                    phase = phaseEntity,
                    name = module.Name,
                    context = context,
                })

               -- print(`[Scheduler] ✅ Successfully loaded {context} system: {module.Name}`)
            end)

            if not success then
                warn(`Failed to load {context} system {module.Name}: {err}`)
            end
        end
    end

   -- print(`[Scheduler] 📦 Loaded {#schedulerSystems} systems total`)
    return schedulerSystems
end

local function RegisteringWorldToJabby()
	local RefManager = require(game:GetService("ReplicatedStorage").Modules.ECS.jecs_ref_manager)

	jabby.register({
		applet = jabby.applets.world,
		name = "World",
		configuration = {
			world = world,
			entities = {}, -- Populated by ref system
			get_entity_from_part = function(part)
				-- Try to get entity from character
				local character = part:FindFirstAncestorOfClass("Model")
				if character and character:FindFirstChildOfClass("Humanoid") then
					-- Use RefManager to find entity from model
					local entity = RefManager.getEntityFromModel(character)
					if entity then
						return entity, part
					end
				end
				return nil, nil
			end
		},
	})
end

local function RegisterSchedulerToJabby(scheduler)
	jabby.register({
		applet = jabby.applets.scheduler,
		name = "Scheduler",
		configuration = {
			scheduler = scheduler,
		},
	})
end

-- Modified from example's phasescheduler
local function SetupPhases()
	local phases = {}

	-- Core phases with explicit component setup
	phases.Heartbeat = world:entity()
	world:add(phases.Heartbeat, comps.Phase)
	world:set(phases.Heartbeat, comps.Event, RunService.Heartbeat)
	world:set(phases.Heartbeat, comps.Name, "Heartbeat")

	phases.PreSimulation = world:entity()
	world:add(phases.PreSimulation, comps.Phase)
	world:set(phases.PreSimulation, comps.Event, RunService.PreSimulation)
	world:set(phases.PreSimulation, comps.Name, "PreSimulation")

	if RunService:IsServer() then
		-- Server-specific phases
		phases.PlayerAdded = world:entity()
		world:add(phases.PlayerAdded, comps.Phase)
		world:set(phases.PlayerAdded, comps.Event, Players.PlayerAdded)
		world:set(phases.PlayerAdded, comps.Name, "PlayerAdded")
	else
		-- Client-specific phases
		phases.PreRender = world:entity()
		world:add(phases.PreRender, comps.Phase)
		world:set(phases.PreRender, comps.Event, RunService.PreRender)
		world:set(phases.PreRender, comps.Name, "PreRender")
	end

	-- Debug print all created phases
	for name, entity in pairs(phases) do
		---- print(`Created phase {name}:`)
		---- print("- Entity ID:", entity)
		---- print("- Event:", world:get(entity, comps.Event))
		---- print("- Name:", world:get(entity, comps.Name))
	end

	return phases
end
local function phasescheduler(d)
	local phase = world:entity()
	world:add(phase, comps.Phase)

	if d.event then
		world:set(phase, comps.Event, d.event)
		world:set(phase, comps.Name, d.name or tostring(d.event))
	end

	if d.after then
		world:add(phase, jecs.pair(comps.DependsOn, d.after))
	end

	return phase
end

local function collecteventsystems(event)
	local systems = {}

	local function systemrecursive(systems, phase)
		local phase_name = world:get(phase, comps.Name)
		for _, s in world:query(comps.System):with(jecs.pair(comps.DependsOn, phase)) do
			table.insert(systems, {
				id = s.id,
				callback = s.callback,
				name = s.name,
			})
		end
		for after in world:query(comps.Phase):with(jecs.pair(comps.DependsOn, phase)):iter() do
			systemrecursive(systems, after)
		end
	end

	systemrecursive(systems, event)
	return systems
end

local function collectallsystems()
	local events = {}
	for phase in world:query(comps.Phase) do
		local event = world:get(phase, comps.Event)
		if event then
			events[event] = collecteventsystems(phase)
		end
	end
	return events
end

local function begin()
	local connections = {}

	-- Iterate through all phase entities with Event component
	for phaseEntity in world:query(comps.Phase):with(comps.Event) do
		local event = world:get(phaseEntity, comps.Event)
		local phaseName = world:get(phaseEntity, comps.Name) or "UnknownPhase"

		if not event then
			warn("Phase missing event:", phaseName)
			continue
		end

		-- Get systems associated with this phase
		local systems = {}
		for systemEntity in world:query(comps.System):with(jecs.pair(comps.DependsOn, phaseEntity)) do
			local sysData = world:get(systemEntity, comps.System)
			if sysData then
				table.insert(systems, sysData)
			end
		end

		-- Create connection
		connections[phaseEntity] = event:Connect(function(...)
			local args = {...}
			for _, sysData in pairs(systems) do
				if sysData.callback and sysData.id then
					-- Wrap the callback in pcall, not the scheduler:run call
					-- This ensures scheduler frame tracking completes even if system errors
					local wrappedCallback = function(...)
						local success, err = pcall(sysData.callback, ...)
						if not success then
							warn(`System {sysData.name} error: {err}`)
						end
					end

					-- Use scheduler:run() to automatically track execution time for Jabby
					activeScheduler:run(sysData.id, wrappedCallback, world, table.unpack(args))
				end
			end
		end)
	end

	return connections
end

return {
	CreatingScheduler = CreatingScheduler,
	FillingSchedulerWithSystems = FillingSchedulerWithSystems,
	RegisteringWorldToJabby = RegisteringWorldToJabby,
	RegisterSchedulerToJabby = RegisterSchedulerToJabby,
	SetupPhases = SetupPhases,
	PHASE = phasescheduler,
	COLLECT = collectallsystems,
	BEGIN = begin,
	PhaseEntities = {
		PreRender = PreRender,
		Heartbeat = Heartbeat,
		PreSimulation = PreSimulation,
		PreAnimation = PreAnimation,
	},
}
