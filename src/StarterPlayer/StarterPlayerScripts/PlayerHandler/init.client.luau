local Players = game:GetService("Players")
local Replicated = game:GetService("ReplicatedStorage")
local ContentProvider = game:GetService("ContentProvider")
local StarterGui = game:GetService("StarterGui")

local StarterPlayer = game:GetService("StarterPlayer")

-- Disable default Roblox CoreGui elements (backpack and playerlist/leaderboard)
local function disableCoreGui()
	local success, err = pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
	end)
	if not success then
		-- Retry after a short delay if it fails (CoreGui may not be ready yet)
		task.delay(1, function()
			pcall(function()
				StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
				StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
			end)
		end)
	end
end
disableCoreGui()
local world = require(game:GetService("ReplicatedStorage").Modules.ECS.jecs_world)
local comps = require(game:GetService("ReplicatedStorage").Modules.ECS.jecs_components)
local ref = require(game:GetService("ReplicatedStorage").Modules.ECS.jecs_ref)
local jecs = require(Replicated.Modules.Imports.jecs)
local Bridges = require(Replicated.Modules.Bridges)
local Visuals = require(Replicated.Modules.Visuals)
local start = require(Replicated.Modules.ECS.jecs_start)
local AB = require(Replicated.Modules.Utils.AymanBolt)
local JecsBatch = require(Replicated.Modules.ECS.jecs_batch)

-- CRITICAL: Set up entity sync listener IMMEDIATELY after Bridges loads
-- This must happen BEFORE any other initialization to catch SetPlayerEntity from server
-- The server sends this very early, so we need to be listening right away
local entitySyncReceived = false
local lastSyncedEntityId = nil -- Track which entity we've already synced
Bridges.ECSClient:Connect(function(data)
	if data.Module == "EntitySync" and data.Action == "SetPlayerEntity" then
		local entityId = data.EntityId
		print(`[ECS] 🔗 EARLY: Received synced entity ID from server: {entityId}`)

		-- Skip if we've already synced this same entity (prevents duplicate initialization)
		if entitySyncReceived and lastSyncedEntityId == entityId then
			print(`[ECS] ⏭️ Entity {entityId} already synced, skipping duplicate`)
			return
		end

		-- CRITICAL: Ensure the entity exists in the client's JECS world
		-- Entity IDs from server don't automatically exist in client world
		-- We must explicitly create/claim the entity ID
		world:entity(entityId)
		print(`[ECS] ✅ Created/claimed entity {entityId} in client world`)

		-- Store the synced entity using network_id
		-- This ensures client uses the same entity ID as the server
		ref.define("network_id", Players.LocalPlayer.UserId, entityId)

		-- Also set it as the local player entity for convenience
		local player = Players.LocalPlayer
		ref.define("player", player, entityId)

		-- CRITICAL: Initialize state components on the CLIENT entity
		-- This is needed for client-side state_sync to work properly
		-- The server initializes these in playerloader, but client needs them too
		-- Use batch operation to prevent archetype fragmentation
		-- Include Inventory/Hotbar with defaults - InventoryHandler will update them later
		JecsBatch.setMany(entityId, {
			{comps.StateActions, {}},
			{comps.StateStuns, {}},
			{comps.StateIFrames, {}},
			{comps.StateSpeeds, {}},
			{comps.StateFrames, {}},
			{comps.StateStatus, {}},
			{comps.Dialogue, { npc = nil, name = "none", inrange = false, state = "interact" }},
			{comps.Inventory, {items = {}, maxSlots = 50}},
			{comps.Hotbar, {slots = {}, activeSlot = 1}},
		})
		print(`[ECS] ✅ Initialized state components on client entity {entityId} (batched)`)

		lastSyncedEntityId = entityId
		entitySyncReceived = true
		print(`[ECS] ✅ EARLY: Entity {entityId} synced for local player`)
		-- Note: Dialogue component is now initialized in the batch above
	elseif data.Module == "EntitySync" and data.Action == "EntityReady" then
		local entityId = data.EntityId
		print(`[ECS] ✅ Entity {entityId} is fully initialized`)

		-- Initialize leveling components on client (only after entity is fully ready)
		local LevelingManager = require(Replicated.Modules.Utils.LevelingManager)
		if not world:has(entityId, comps.Level) then
			LevelingManager.initialize(entityId)
		end

		-- Try to load weapon skills now that all components are ready
		-- Use task.defer to ensure Client.Modules is loaded
		-- Also wait for Hotbar component to be set by InventoryHandler
		task.defer(function()
			-- Wait for Hotbar component to exist (set by InventoryHandler when inventory syncs)
			local hotbarAttempts = 0
			while hotbarAttempts < 100 do -- Wait up to 10 seconds
				if world:has(entityId, comps.Hotbar) and world:has(entityId, comps.Inventory) then
					print(`[ECS] ✅ Hotbar and Inventory components found on entity {entityId}`)
					break
				end
				hotbarAttempts = hotbarAttempts + 1
				if hotbarAttempts % 20 == 0 then
					print(`[ECS] Waiting for Hotbar/Inventory components... (attempt {hotbarAttempts})`)
				end
				task.wait(0.1)
			end

			if not world:has(entityId, comps.Hotbar) then
				warn("[ECS] ⚠️ Hotbar component never arrived, skipping LoadWeaponSkills")
				return
			end

			-- Wait for Client module to be ready
			local attempts = 0
			while attempts < 50 do
				local Client = _G.ClientModule
				if Client and Client.Modules and Client.Modules.Interface and Client.Modules.Interface.Stats then
					local success, err = pcall(function()
						Client.Modules.Interface.Stats.LoadWeaponSkills()
					end)
					if success then
						print("[ECS] ✅ Weapon skills loaded successfully")
					else
						warn("[ECS] LoadWeaponSkills error:", err)
					end
					break
				end
				attempts = attempts + 1
				task.wait(0.1)
			end
		end)
	end
end)
print("[ECS] 🎯 Entity sync listener registered EARLY (before game.Loaded)")

if not game.Loaded then
	game.Loaded:Wait()
end

local ClientThread = require(script.PActor.Thread)

local Success, Client = xpcall(require, function(Error)
	---- --print("Client Runtime Error | Client Initialization Failed \nError: " .. Error)
end, Replicated:WaitForChild("Client"))
if not Success then
	return
end

-- Store Client in _G so the early entity sync listener can access it later
_G.ClientModule = Client

-- CRITICAL: Start ECS systems FIRST before loading any client modules
-- This ensures the client entity exists before InventoryHandler tries to use it
---- --print("🔧 Starting client ECS systems before loading modules...")
---- --print("🔍 Checking for Systems folder...")

-- Ensure the Systems folder exists before starting
local modules = Replicated:WaitForChild("Modules", 10)
if not modules then
	error("❌ CRITICAL: ReplicatedStorage.Modules not found!")
end

local systemsFolder = modules:FindFirstChild("Systems")
if not systemsFolder then
	systemsFolder = Instance.new("Folder")
	systemsFolder.Name = "Systems"
	systemsFolder.Parent = modules
	---- --print("📁 Created Systems folder in ReplicatedStorage.Modules")
else
	---- --print("📁 Systems folder found:", systemsFolder:GetFullName())
	---- --print("📊 Systems in folder:", #systemsFolder:GetChildren())
	for _, system in systemsFolder:GetChildren() do
		if system:IsA("ModuleScript") then
			---- --print("  - " .. system.Name)
		end
	end
end

-- Start ECS with a single attempt (no retries to avoid duplicate loading)
---- --print("🚀 Starting ECS systems...")
local success, err = pcall(start, nil)
if success then
	---- --print("✅ Client ECS systems started successfully")
	active = true
else
	error("❌ CRITICAL: Failed to start client ECS systems: " .. tostring(err))
end

-- CRITICAL: Load Events module FIRST to set up packet listeners before anything else
local EventsModule = Replicated:WaitForChild("Client"):WaitForChild("Events")
local Success, EventsReq = xpcall(function()
	return require(EventsModule)
end, function(Error)
	---- --print("Client - Failed Require: Events\n" .. Error)
end)

if Success and EventsReq then
	Client.Modules["Events"] = EventsReq
	---- --print("✅ Events module loaded - Bvel and other packet listeners are now active")
end

-- Now load all other modules (ECS is already running, so InventoryHandler will work)
local Modules = Replicated:WaitForChild("Client"):GetChildren()
for __ = 1, #Modules do
	local Module = Modules[__]
	if Module:IsA("ModuleScript") and Module ~= EventsModule then -- Skip Events since we already loaded it
		local Req
		local Success, Error = xpcall(function()
			Req = require(Module)
		end, function(Error)
			---- --print("Client - Failed Require: " .. Module.Name .. "\n" .. Error)
		end)

		if Success and Req then
			Client.Modules[Module.Name] = Req
		end
	end
end

local EffectModules = Replicated:WaitForChild("Effects"):GetChildren()
for __ = 1, #EffectModules do
	local Module = EffectModules[__]
	if Module:IsA("ModuleScript") then
		local Req
		local Success, Error = xpcall(function()
			Req = require(Module)
		end, function(Error)
			--print("Client - Failed Require: " .. Module.Name .. "\n" .. Error)
			return Error
		end)

		if Success and Req then
			Client.Environment[Module.Name] = Req
			----print("✅ Loaded effect module:", Module.Name)
		else
			--warn("❌ Failed to load effect module:", Module.Name, "Error:", Error)
		end
	end
end

-- Get the client's own NpcRegistryCamera (tagged with ClientOwned attribute)
local cachedClientCamera = nil
local function getClientNpcCamera()
    if cachedClientCamera and cachedClientCamera.Parent then
        return cachedClientCamera
    end
    for _, child in workspace:GetChildren() do
        if child.Name == "NpcRegistryCamera" and child:IsA("Camera") and child:GetAttribute("ClientOwned") then
            cachedClientCamera = child
            return child
        end
    end
    return nil
end

-- Resolve Chrono marker tables (sent by server Visuals.lua) to client clone models
-- Markers are tables with {_chronoMarker = true, _chronoId = number, _name = string}
local function resolveChronoMarker(arg)
    if type(arg) == "table" and arg._chronoMarker then
        local clientCamera = getClientNpcCamera()
        if not clientCamera then return nil end

        -- Client clones are named tostring(id) inside the client camera
        local clone = clientCamera:FindFirstChild(tostring(arg._chronoId))
        if clone and clone:IsA("Model") then
            return clone
        end

        -- Recursive search as fallback
        clone = clientCamera:FindFirstChild(tostring(arg._chronoId), true)
        if clone and clone:IsA("Model") then
            return clone
        end

        -- Fallback: try by original model name
        if arg._name then
            local byName = clientCamera:FindFirstChild(arg._name, true)
            if byName and byName:IsA("Model") then
                return byName
            end
        end

        return nil
    end

    -- Also handle Instance refs that ended up in server's NpcRegistryCamera
    if typeof(arg) == "Instance" and arg:IsA("Model") and not Players:GetPlayerFromCharacter(arg) then
        local parent = arg.Parent
        while parent do
            if parent.Name == "NpcRegistryCamera" then
                local clientCamera = getClientNpcCamera()
                if not clientCamera then return arg end

                local chronoId = arg:GetAttribute("ChronoId") or arg:GetAttribute("NPC_ID")
                if chronoId then
                    local clone = clientCamera:FindFirstChild(tostring(chronoId), true)
                    if clone and clone:IsA("Model") then
                        return clone
                    end
                end

                if arg.Name then
                    local byName = clientCamera:FindFirstChild(arg.Name, true)
                    if byName and byName:IsA("Model") then
                        return byName
                    end
                end
                return arg
            end
            parent = parent.Parent
        end
    end

    return arg
end

Client.Packets.Visuals.listen(function(Packet)
    if Client.Environment[Packet.Module] and Client.Environment[Packet.Module][Packet.Function] then
        -- Resolve any Chrono NPC markers/references in arguments to client clones
        local resolvedArgs = Packet.Arguments
        if resolvedArgs then
            for i, arg in resolvedArgs do
                resolvedArgs[i] = resolveChronoMarker(arg)
            end
        end
        Client.Environment[Packet.Module][Packet.Function](unpack(resolvedArgs))
    else
       warn(`[Visuals] Module: {Packet.Module}, Function: {Packet.Function} Does Not Exist`)
    end
end)

-- Signal that the visuals listener is ready
_G.VisualsListenerReady = true
---- --print("✅ Visuals listener is ready - dialogue check system can now start")

function ConvertToNumber(String)
	local Number = string.match(String, "%d+$")
	local IsNegative = string.match(String, "[-]%d+$") ~= nil

	if IsNegative and Number then
		Number = "-" .. Number
	end

	return Number and tonumber(Number) or 0
end

local function Remove()
	--print("[PlayerHandler] 🧹 Starting cleanup on death...")

	-- Clean up VFX first
	local VFXCleanup = require(Replicated.Modules.Utils.VFXCleanup)
	if Client.Character then
		VFXCleanup.CleanupCharacter(Client.Character)
		VFXCleanup.DisableCharacterParticles(Client.Character)
		--print("[PlayerHandler] Cleaned up VFX on death")
	end

	-- Stop all animations to prevent memory leaks
	if Client.Animator then
		local animTracks = Client.Animator:GetPlayingAnimationTracks()
		for _, track in ipairs(animTracks) do
			track:Stop(0)
			track:Destroy()
		end
	end

	-- Clean up Text+ instance pools to prevent userdata memory growth
	local TextPlus = require(Replicated.Modules.Utils.Text)
	if TextPlus and TextPlus.CleanupPools then
		TextPlus.CleanupPools(20) -- Keep 20 instances max per pool
	end

	-- Clean up UI components first (Fusion scopes)
	-- CRITICAL FIX: Client.Stats doesn't exist - Stats is in Client.Modules["Interface"].Modules["Stats"]
	local Stats = Client.Modules and Client.Modules["Interface"] and Client.Modules["Interface"].Modules and Client.Modules["Interface"].Modules["Stats"]
	if Stats and Stats.CleanupUI then
		Stats.CleanupUI()
	end

	-- Clean up Quest Tracker
	local QuestTracker = require(Replicated.Client.Interface.QuestTracker)
	if QuestTracker and QuestTracker.new then
		local tracker = QuestTracker.new() -- Gets singleton instance
		if tracker and tracker.Destroy then
			tracker:Destroy()
		end
	end

	-- Clean up Quest Markers
	local QuestMarkers = require(Replicated.Client.QuestMarkers)
	if QuestMarkers and QuestMarkers.Cleanup then
		QuestMarkers.Cleanup()
	end

	-- Clean up Quest Handler
	local QuestHandler = require(Replicated.Client.QuestHandler)
	if QuestHandler and QuestHandler.Cleanup then
		QuestHandler.Cleanup()
	end

	-- Clean up Leaderboard
	local Leaderboard = require(Replicated.Client.Interface.Leaderboard)
	if Leaderboard and Leaderboard.new then
		local leaderboard = Leaderboard.new() -- Gets singleton instance
		if leaderboard and leaderboard.Destroy then
			leaderboard:Destroy()
		end
	end

	-- Clean up Notification Manager
	local NotificationManager = require(Replicated.Client.NotificationManager)
	if NotificationManager and NotificationManager.ClearAll then
		NotificationManager.ClearAll()
	end

	-- Clean up Dialogue Proximity (call global cleanup function)
	if _G.DialogueProximity_Cleanup then
		_G.DialogueProximity_Cleanup()
	end

	-- Clean up NPCBodyTracking (stop RenderStepped connection)
	local NPCBodyTracking = require(Replicated.Client.Misc.NPCBodyTracking)
	if NPCBodyTracking and NPCBodyTracking.Stop then
		NPCBodyTracking.Stop()
	end

	-- Clean up InventoryState (reset selection on death)
	local InventoryState = require(Replicated.Client.InventoryState)
	if InventoryState and InventoryState.reset then
		InventoryState.reset()
	end

	-- Clean up InventoryHandler (reset inventory tracking state on death)
	local InventoryHandler = require(Replicated.Client.InventoryHandler)
	if InventoryHandler and InventoryHandler.resetInventoryState then
		InventoryHandler.resetInventoryState()
	end

	if Client.Connections then
		for _, conn in ipairs(Client.Connections) do
			conn:Disconnect()
		end
		Client.Connections = {}
	end

	Client.Character = nil
	Client.Humanoid = nil
	Client.Animator = nil
	Client.Root = nil
	Client.Speeds = nil
	Client.Statuses = nil
	Client.Stuns = nil
	Client.Actions = nil
	Client.Posture = nil
	Client.Energy = nil

	--print("[PlayerHandler] ✅ Cleanup complete")
end

local DisabledStateTypes = {
	"FallingDown",
	"StrafingNoPhysics",
	"Ragdoll",
	"GettingUp",
	"Flying",
	"Seated",
	"Swimming",
	"Climbing",
}

-- Entity sync listener is now registered EARLY at the top of the file (after Bridges loads)
-- This ensures we don't miss SetPlayerEntity messages from the server

-- IMPORTANT: Don't access entity here at module load time!
-- The entity sync from server may not have arrived yet.
-- Wait until entity sync is received, or get it fresh in Initialize.
local pent = nil -- Will be set in Initialize after entity sync

-- NOTE: Dialogue component is now initialized in the entity sync handler (line 72-74)
-- This ensures it's set on the correct synced entity from server

function Initialize(Character: Model)
	-- Wait for entity sync if it hasn't happened yet
	if not entitySyncReceived then
		print("[PlayerHandler] Waiting for entity sync before Initialize...")
		local attempts = 0
		while not entitySyncReceived and attempts < 50 do
			task.wait(0.1)
			attempts = attempts + 1
		end
		if not entitySyncReceived then
			warn("[PlayerHandler] Entity sync not received after 5 seconds!")
		end
	end

	-- Refresh pent to get the latest synced entity
	-- Use ref.get("player", player) to match what entity sync defines
	pent = ref.get("player", Players.LocalPlayer)
	if not pent then
		pent = ref.get("local_player")
	end
	print(`[PlayerHandler] Initialize called - pent: {pent}, entitySyncReceived: {entitySyncReceived}`)

	-- Set Character component on client for local player entity
	-- This is needed for client-side ECS systems like ragdoll_impact
	if pent then
		world:set(pent, comps.Character, Character)
		print(`[PlayerHandler] 🔧 Set Character component on entity {pent}`)
	else
		warn("[PlayerHandler] No entity found for local player!")
	end
	Client.Service["RunService"].RenderStepped:Wait()
	Client.Character = Character

	-- COMPREHENSIVE CHARACTER REINITIALIZATION
	---- --print("=== REINITIALIZING CHARACTER ===")
	---- --print("Character:", Character.Name)

	-- Reset all client states
	Client.Dodging = false
	Client.Running = false
	Client.DodgeCharges = 2
	---- --print("Reset client movement states")

	-- Comprehensive cleanup of previous character data
	if Client.Library and Client.Library.CleanupCharacter then
		-- This will clear animations, cooldowns, and stop all tracks
		Client.Library.CleanupCharacter(Character)
	end

	-- Additional manual cleanup for any stuck states
	if Client.Library then
		if Client.Library.ResetCooldown then
			Client.Library.ResetCooldown(Character, "Dodge")
			Client.Library.ResetCooldown(Character, "DodgeCancel")
			---- --print("Reset all cooldowns for new character")
		end
	end

	local Humanoid = Character:WaitForChild("Humanoid") :: Humanoid

	-- Energy and Posture are still IntConstrainedValue instances (not StringValue)
	local Energy = Character:WaitForChild("Energy", 60) :: IntConstrainedValue
	local Posture = Character:WaitForChild("Posture", 60) :: IntConstrainedValue

	if not Energy or not Posture then
		return
	end

	Client.Animator = Humanoid:WaitForChild("Animator") :: Animator
	Client.Humanoid = Humanoid
	Client.Root = Character.PrimaryPart or Character:WaitForChild("HumanoidRootPart") :: BasePart

	-- State is now managed via ECS StateManager - no StringValue children needed
	-- Client.Library.StateCount(Client.Character, "Stuns") etc. work directly with ECS

	Client.Energy = Energy
	Client.Posture = Posture

	Client.Weapon = Players.LocalPlayer:GetAttribute("Weapon")
	Client.Connections = Client.Connections or {}

	local function safeConnect(obj, event, callback)
		if obj then
			local conn = obj[event]:Connect(callback)
			table.insert(Client.Connections, conn)
			return conn
		end
		return nil
	end

	--// Setup
	for _, StateType in DisabledStateTypes do
		Humanoid:SetStateEnabled(Enum.HumanoidStateType[StateType], false)
	end

	-- Wait for loading screen to finish before loading HUD/Interface
	---- --print("Waiting for loading screen to finish...")
	while _G.LoadingScreenActive do
		task.wait(0.1)
	end
	---- --print("Loading screen finished, loading HUD...")

	Client.Modules["Interface"].Check()

	-- Initialize leaderboard
	if Client.Modules["Interface"].InitLeaderboard then
		Client.Modules["Interface"].InitLeaderboard()
		---- --print("Initialized leaderboard")
	end

	-- Initialize Quest Tracker
	if Client.Modules["Interface"].InitQuestTracker then
		Client.Modules["Interface"].InitQuestTracker()
		---- --print("✅ Initialized Quest Tracker")
	end

	-- Initialize Inventory
	if Client.Modules["Interface"].InitInventory then
		Client.Modules["Interface"].InitInventory()
		---- --print("✅ Initialized Inventory")
	end

	safeConnect(Humanoid, "HealthChanged", function(Health)
		Client.Modules["Interface"].UpdateStats("Health", Health, Humanoid.MaxHealth)
	end)

	safeConnect(Posture, "Changed", function(Value)
		Client.Modules["Interface"].UpdateStats("Posture", Value, Posture.MaxValue)
	end)
	safeConnect(Energy, "Changed", function(Value)
		Client.Modules["Interface"].UpdateStats("Posture", Value, Posture.MaxValue)
	end)

	Client.Modules["Interface"].UpdateStats("Health", Humanoid.Health, Humanoid.MaxHealth)
	Client.Modules["Interface"].UpdateStats("Energy", Energy.Value, Energy.MaxValue)
	Client.Modules["Interface"].UpdateStats("Posture", Posture.Value, Posture.MaxValue)
	Client.Modules["Interface"].Party()

	-- Initialize Fusion-based Hotbar
	-- IMPORTANT: Wait for server entity sync before initializing hotbar
	-- The server sends SetPlayerEntity after playerloader processes the player
	-- We need to wait for that to ensure we use the correct entity ID
	task.spawn(function()
		print("[PlayerHandler] Waiting for server entity sync before initializing hotbar...")

		-- Wait for server-synced entity
		-- The early ECSClient listener (at top of file) receives SetPlayerEntity
		-- and stores it via ref.define("player", player, entityId)
		-- We need to wait until that entity ID is > 300 (server entities are higher)
		-- Client fallback entities start at lower numbers
		local maxWait = 50 -- 5 seconds max
		local attempts = 0
		local serverEntity = nil

		while attempts < maxWait do
			serverEntity = ref.get("player", Players.LocalPlayer)

			-- Server entities are typically > 400, client fallbacks are < 300
			-- A simpler check: wait until entitySyncReceived flag is true
			if serverEntity and entitySyncReceived then
				print(`[PlayerHandler] Server entity {serverEntity} confirmed (sync received)`)
				break
			end

			attempts = attempts + 1
			if attempts % 10 == 0 then
				print(`[PlayerHandler] Still waiting for server entity... (attempt {attempts}/{maxWait}, current: {serverEntity or "nil"})`)
			end
			task.wait(0.1)
		end

		if not serverEntity then
			warn("[PlayerHandler] ⚠️ Server entity sync timeout - using fallback entity")
			serverEntity = ref.get("local_player")
		end

		if Client.Modules["Interface"].InitializeHotbar then
			print(`[PlayerHandler] Initializing hotbar with server entity: {serverEntity}`)
			Client.Modules["Interface"].InitializeHotbar(Character, serverEntity)
			print("✅ Initialized Fusion Hotbar")
		else
			warn("❌ InitializeHotbar function not found!")
		end
	end)

	-- Use ECS StateManager observers instead of StringValue.Changed events
	local StateManager = require(Replicated.Modules.ECS.StateManager)

	-- When actions change, check for flash speed state
	local actionsDisconnect = StateManager.OnStateAdded(Character, "Actions", function(_stateName)
		if StateManager.StateCheck(Character, "Speeds", "FlashSpeedSet50") then
			Client.Packets.Flash.send({ Remove = true })
		end
	end)
	table.insert(Client.Connections, { Disconnect = actionsDisconnect })

	-- When stuns are added/removed, handle auto-rotate and flash speed
	local stunsAddedDisconnect = StateManager.OnStateAdded(Character, "Stuns", function(_stateName)
		if StateManager.StateCheck(Character, "Speeds", "FlashSpeedSet50") then
			Client.Packets.Flash.send({ Remove = true })
		end
		-- Disable auto-rotate when stunned
		Humanoid.AutoRotate = false
	end)
	table.insert(Client.Connections, { Disconnect = stunsAddedDisconnect })

	local stunsRemovedDisconnect = StateManager.OnStateRemoved(Character, "Stuns", function(_stateName)
		-- Re-enable auto-rotate when no longer stunned
		if not StateManager.StateCount(Character, "Stuns") then
			Humanoid.AutoRotate = true
		end
	end)
	table.insert(Client.Connections, { Disconnect = stunsRemovedDisconnect })

	-- ECS state is managed by StateManager - no need to wait for StringValues
	--print("[PlayerHandler] ECS state management initialized")

	-- Rebind all input actions (fixes running not working after respawn)
	if Client.Modules["Inputs"] and Client.Modules["Inputs"].BindAllActions then
		Client.Modules["Inputs"].BindAllActions()
		--print("[PlayerHandler] Rebound all input actions")
	end

	-- Reinitialize animation system
	Client.Modules["Animate"].Init()
	---- --print("Reinitialized animation system")

	-- Reinitialize zone controller
	Client.Modules["ZoneController"]()
	---- --print("Reinitialized zone controller")

	-- Clear any stuck states via StateManager (ECS)
	task.wait(0.1) -- Wait for ECS to be ready
	StateManager.ClearCategory(Character, "Actions")
	StateManager.ClearCategory(Character, "Stuns")
	StateManager.ClearCategory(Character, "Speeds")
	StateManager.ClearCategory(Character, "Status")
	---- --print("Cleared all state categories via StateManager")

	-- Reset character attributes
	Client.Character:SetAttribute("Equipped", false)
	Client.Character:SetAttribute("DodgeCharges", 2)
	---- --print("Reset character attributes")

	-- DON'T clear inventory on client - server will sync it
	-- The server clears and repopulates the inventory, then syncs to client via Bridges.Inventory

	-- Clear hotbar UI display (will be repopulated when server syncs inventory)
	task.wait(0.2) -- Wait for UI to be ready
	local InterfaceStats = Client.Modules and Client.Modules["Interface"] and Client.Modules["Interface"].Modules and Client.Modules["Interface"].Modules["Stats"]
	if InterfaceStats then
		-- Clear all hotbar slot displays
		for i = 1, 10 do
			if InterfaceStats.UpdateHotbarSlot then
				InterfaceStats.UpdateHotbarSlot(i, "")
			end
		end
		---- --print("Cleared hotbar UI display - waiting for server inventory sync")
	end

	-- Client.Modules["InventoryHandler"]()

	local DialogueTracker = require(Replicated.Client.Misc.DialogueTracker)
	DialogueTracker.Start()

	local NPCBodyTracking = require(Replicated.Client.Misc.NPCBodyTracking)
	NPCBodyTracking.Start()

	local QuestEvents = require(Replicated.Modules.Utils.QuestEvents)
	QuestEvents.Connect()

	local QuestCompletionController = require(Replicated.Client.QuestCompletionController)
	QuestCompletionController.Initialize()

	local QuestMarkers = require(Replicated.Client.QuestMarkers)
	QuestMarkers.Init()

	local QuestHandler = require(Replicated.Client.QuestHandler)
	QuestHandler.Init()

	AB.Init()

	--// Clean Up
	Humanoid.Died:Once(function()
		-- Clear combat state on death
		_G.PlayerInCombat = false
		---- --print("[Death] Cleared combat state")
		Remove()
	end)
	Character:GetPropertyChangedSignal("PrimaryPart"):Once(function()
		if not Character.PrimaryPart then
			Remove()
		end
	end)

	ClientThread.Spawn()

	-- Load weapon skills LAST after everything else is initialized
	-- This ensures all dependencies (ECS, inventory, UI) are ready
	task.spawn(function()
		task.wait(1) -- Wait for all other systems to initialize

		---- --print("🎯 Loading weapon skills (final initialization step)...")
		local weaponSkillsLoaded = false
		local maxAttempts = 5
		local attempt = 0

		while not weaponSkillsLoaded and attempt < maxAttempts do
			attempt = attempt + 1

			-- Check if all dependencies are ready
			if Client.Modules and Client.Modules["Interface"] and Client.Modules["Interface"].Modules and Client.Modules["Interface"].Modules["Stats"] then
				local Stats = Client.Modules["Interface"].Modules["Stats"]

				if Stats.LoadWeaponSkills and typeof(Stats.LoadWeaponSkills) == "function" then
					local success, err = pcall(function()
						Stats.LoadWeaponSkills()
					end)

					if success then
						weaponSkillsLoaded = true
						---- --print("✅ Weapon skills loaded successfully on attempt", attempt)
					else
						-- warn("⚠️ Failed to load weapon skills (attempt " .. attempt .. "/" .. maxAttempts .. "):", err)
						if attempt < maxAttempts then
							task.wait(0.5) -- Wait before retry
						end
					end
				else
					-- warn("⚠️ LoadWeaponSkills function not found (attempt " .. attempt .. "/" .. maxAttempts .. ")")
					if attempt < maxAttempts then
						task.wait(0.5)
					end
				end
			else
				-- warn("⚠️ Interface/Stats modules not ready (attempt " .. attempt .. "/" .. maxAttempts .. ")")
				if attempt < maxAttempts then
					task.wait(0.5)
				end
			end
		end

		if not weaponSkillsLoaded then
			-- warn("❌ Failed to load weapon skills after", maxAttempts, "attempts")
		end
	end)
end

-- Initialize ragdoll handling system (only once)
local RagdollHandling = require(Replicated.Client.Events.RagdollHandling)
RagdollHandling.Init()

-- Initialize ragdoll impact system (crater effects when hitting ground)
-- local RagdollImpact = require(Replicated.Client.RagdollImpact)
-- RagdollImpact.Init()

local ID = false
-- Note: 'active' variable is now set at the top when ECS starts

Players.LocalPlayer.CharacterAdded:Connect(function(Character)
	-- Note: Dialogue component is already initialized in entity sync handler (batched)
	-- Only reset it if we have an existing entity and want to clear dialogue state
	if pent and world:has(pent, comps.Dialogue) then
		world:set(pent, comps.Dialogue, { npc = nil, name = "none", inrange = false, state = "interact" })
	end

	ID = true
	Initialize(Character)
end)

Players.LocalPlayer:GetAttributeChangedSignal("Weapon"):Connect(function()
	Client.Weapon = Players.LocalPlayer:GetAttribute("Weapon")
end)

local EmitModule = require(game.ReplicatedStorage.Modules.Utils.EmitModule)
EmitModule.init()

if Players.LocalPlayer.Character then
	if not ID then
		-- ECS already started at the top, no need to start again
		Initialize(Players.LocalPlayer.Character)
	end

	Bridges.ECSClient:Connect(function(data)
		if data.Module ~= "ECS_Replication" then
			return
		end

		local myEntityId = ref.get("local_player")  -- Use local_player on client

		if not myEntityId then
			return
		end

		if data.Action == "FullState" then
			for compName, compData in pairs(data.Data) do
				world:set(myEntityId, comps[compName], compData)
				---- --print("full state", compName, compData)
			end
		elseif data.Action == "ComponentUpdate" then
			world:set(myEntityId, comps[data.Component], data.Data)
			---- --print("component update", data.Component, data.Data)
		end
	end)
end

-- Client.Packets.Visuals.listen(function(Packet)
-- 	if Client.Environment[Packet.Module] and Client.Environment[Packet.Module][Packet.Function] then
-- 		Client.Environment[Packet.Module][Packet.Function](unpack(Packet.Arguments))
-- 	else
-- 		-- warn(`Index: {Packet.Function} Does Not Exist`)
-- 	end
-- end)

-- Store client's entity ID
