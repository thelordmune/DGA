local Players = game:GetService("Players")
local Replicated = game:GetService("ReplicatedStorage")
local ContentProvider = game:GetService("ContentProvider")

local StarterPlayer = game:GetService("StarterPlayer")
local world = require(game:GetService("ReplicatedStorage").Modules.ECS.jecs_world)
local comps = require(game:GetService("ReplicatedStorage").Modules.ECS.jecs_components)
local ref = require(game:GetService("ReplicatedStorage").Modules.ECS.jecs_ref)
local jecs = require(Replicated.Modules.Imports.jecs)
local Bridges = require(Replicated.Modules.Bridges)
local Visuals = require(Replicated.Modules.Visuals)
local start = require(Replicated.Modules.ECS.jecs_start)

if not game.Loaded then
	game.Loaded:Wait()
end

local ClientThread = require(script.PActor.Thread)

local Success, Client = xpcall(require, function(Error)
	-- print("Client Runtime Error | Client Initialization Failed \nError: " .. Error)
end, Replicated:WaitForChild("Client"))
if not Success then
	return
end

-- CRITICAL: Start ECS systems FIRST before loading any client modules
-- This ensures the client entity exists before InventoryHandler tries to use it
-- print("🔧 Starting client ECS systems before loading modules...")
-- print("🔍 Checking for Systems folder...")

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
	-- print("📁 Created Systems folder in ReplicatedStorage.Modules")
else
	-- print("📁 Systems folder found:", systemsFolder:GetFullName())
	-- print("📊 Systems in folder:", #systemsFolder:GetChildren())
	for _, system in systemsFolder:GetChildren() do
		if system:IsA("ModuleScript") then
			-- print("  - " .. system.Name)
		end
	end
end

-- Start ECS with a single attempt (no retries to avoid duplicate loading)
-- print("🚀 Starting ECS systems...")
local success, err = pcall(start, nil)
if success then
	-- print("✅ Client ECS systems started successfully")
	active = true
else
	error("❌ CRITICAL: Failed to start client ECS systems: " .. tostring(err))
end

-- CRITICAL: Load Events module FIRST to set up packet listeners before anything else
local EventsModule = Replicated:WaitForChild("Client"):WaitForChild("Events")
local Success, EventsReq = xpcall(function()
	return require(EventsModule)
end, function(Error)
	-- print("Client - Failed Require: Events\n" .. Error)
end)

if Success and EventsReq then
	Client.Modules["Events"] = EventsReq
	-- print("✅ Events module loaded - Bvel and other packet listeners are now active")
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
			-- print("Client - Failed Require: " .. Module.Name .. "\n" .. Error)
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
			-- print("Client - Failed Require: " .. Module.Name .. "\n" .. Error)
		end)

		if Success and Req then
			Client.Environment[Module.Name] = Req
		end
	end
end

Client.Packets.Visuals.listen(function(Packet)
    -- Process all VFX packets - no duplicate prevention needed with reliable networking
    -- -- print("Visual packet received:", Packet.Module, Packet.Function)
    if Client.Environment[Packet.Module] and Client.Environment[Packet.Module][Packet.Function] then
        Client.Environment[Packet.Module][Packet.Function](unpack(Packet.Arguments))
    else
        -- warn(`Index: {Packet.Function} Does Not Exist`)
    end
end)

-- Signal that the visuals listener is ready
_G.VisualsListenerReady = true
-- print("✅ Visuals listener is ready - dialogue check system can now start")

function ConvertToNumber(String)
	local Number = string.match(String, "%d+$")
	local IsNegative = string.match(String, "[-]%d+$") ~= nil

	if IsNegative and Number then
		Number = "-" .. Number
	end

	return Number and tonumber(Number) or 0
end

local function Remove()
	print("[PlayerHandler] 🧹 Starting cleanup on death...")

	-- Clean up UI components first (Fusion scopes)
	if Client.Stats and Client.Stats.CleanupUI then
		Client.Stats.CleanupUI()
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

	print("[PlayerHandler] ✅ Cleanup complete")
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

-- Listen for entity sync from server
Bridges.ECSClient:Connect(function(data)
	if data.Module == "EntitySync" and data.Action == "SetPlayerEntity" then
		local entityId = data.EntityId
		-- print(`[ECS] 🔗 Received synced entity ID from server: {entityId}`)

		-- Store the synced entity using network_id
		-- This ensures client uses the same entity ID as the server
		ref.define("network_id", Players.LocalPlayer.UserId, entityId)

		-- Also set it as the local player entity for convenience
		local player = Players.LocalPlayer
		ref.define("player", player, entityId)

		-- print(`[ECS] ✅ Entity {entityId} synced for local player`)

		-- Ensure Dialogue component exists on player entity
		if not world:get(entityId, comps.Dialogue) then
			-- print("🔧 Initializing Dialogue component for player entity")
			world:set(entityId, comps.Dialogue, { npc = nil, name = "none", inrange = false, state = "interact" })
		end

		-- Initialize leveling components on client
		local LevelingManager = require(Replicated.Modules.Utils.LevelingManager)
		if not world:has(entityId, comps.Level) then
			-- print("🔧 Initializing leveling components on client for player entity")
			LevelingManager.initialize(entityId)
		end
	elseif data.Module == "EntitySync" and data.Action == "EntityReady" then
		local entityId = data.EntityId
		-- print(`[ECS] ✅ Entity {entityId} is fully initialized, loading weapon skills`)

		-- Try to load weapon skills now that all components are ready
		if Client.Modules and Client.Modules.Interface and Client.Modules.Interface.Stats then
			local success, err = pcall(function()
				Client.Modules.Interface.Stats.LoadWeaponSkills()
			end)

			if not success then
				-- warn("[ECS] Failed to load weapon skills:", err)
			end
		end
	end
end)

local pent = ref.get("local_player")  -- This will now use the synced entity from server

-- Ensure Dialogue component exists on player entity (fallback if sync hasn't happened yet)
if pent and not world:get(pent, comps.Dialogue) then
	-- print("🔧 Initializing Dialogue component for player entity")
	world:set(pent, comps.Dialogue, { npc = nil, name = "none", inrange = false, state = "interact" })
end

function Initialize(Character: Model)
	-- Set Character component on client for local player entity
	-- This is needed for client-side ECS systems like ragdoll_impact
	if pent then
		world:set(pent, comps.Character, Character)
		-- print("🔧 Set Character component on client player entity")
	end
	Client.Service["RunService"].RenderStepped:Wait()
	Client.Character = Character

	-- COMPREHENSIVE CHARACTER REINITIALIZATION
	-- print("=== REINITIALIZING CHARACTER ===")
	-- print("Character:", Character.Name)

	-- Reset all client states
	Client.Dodging = false
	Client.Running = false
	Client.DodgeCharges = 2
	-- print("Reset client movement states")

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
			-- print("Reset all cooldowns for new character")
		end
	end

	local Humanoid = Character:WaitForChild("Humanoid") :: Humanoid
	local Speeds = Character:WaitForChild("Speeds", 60) :: StringValue
	local Statuses = Character:WaitForChild("Status", 60) :: StringValue
	local Stuns = Character:WaitForChild("Stuns", 60) :: StringValue
	local Actions = Character:WaitForChild("Actions", 60) :: StringValue
	local Frames = Character:WaitForChild("Frames", 60) :: StringValue

	local Energy = Character:WaitForChild("Energy", 60) :: IntConstrainedValue
	local Posture = Character:WaitForChild("Posture", 60) :: IntConstrainedValue

	if not Speeds or not Statuses or not Stuns or not Actions or not Frames or not Energy or not Posture then
		return
	end

	Client.Animator = Humanoid:WaitForChild("Animator") :: Animator
	Client.Humanoid = Humanoid
	Client.Root = Character.PrimaryPart or Character:WaitForChild("HumanoidRootPart") :: BasePart

	Client.Speeds = Speeds
	Client.Statuses = Statuses
	Client.Stuns = Stuns
	Client.Actions = Actions
	Client.Frames = Frames

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
	-- print("Waiting for loading screen to finish...")
	while _G.LoadingScreenActive do
		task.wait(0.1)
	end
	-- print("Loading screen finished, loading HUD...")

	Client.Modules["Interface"].Check()

	-- Initialize leaderboard
	if Client.Modules["Interface"].InitLeaderboard then
		Client.Modules["Interface"].InitLeaderboard()
		-- print("Initialized leaderboard")
	end

	-- Initialize Quest Tracker
	if Client.Modules["Interface"].InitQuestTracker then
		Client.Modules["Interface"].InitQuestTracker()
		-- print("✅ Initialized Quest Tracker")
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
	-- print("[PlayerHandler] ===== HOTBAR INITIALIZATION STARTING =====")
	-- print(`[PlayerHandler] Interface module: {Client.Modules["Interface"]}`)
	-- print(`[PlayerHandler] InitializeHotbar function: {Client.Modules["Interface"].InitializeHotbar}`)

	if Client.Modules["Interface"].InitializeHotbar then
		-- print("[PlayerHandler] Getting player entity...")
		local playerEntity = ref.get("player", Players.LocalPlayer)
		-- print(`[PlayerHandler] Player entity: {playerEntity}`)
		-- print(`[PlayerHandler] Character: {Character}`)
		-- print("[PlayerHandler] Calling InitializeHotbar...")
		Client.Modules["Interface"].InitializeHotbar(Character, pent)
		-- print("✅ Initialized Fusion Hotbar")
	else
		-- print("❌ InitializeHotbar function not found!")
	end
	-- print("[PlayerHandler] ===== HOTBAR INITIALIZATION COMPLETE =====")

	safeConnect(Actions, "Changed", function()
		if Client.Library.StateCheck(Speeds, "FlashSpeedSet50") then
			Client.Packets.Flash.send({ Remove = true })
		end
	end)

	safeConnect(Stuns, "Changed", function()
		if Client.Library.StateCheck(Speeds, "FlashSpeedSet50") then
			Client.Packets.Flash.send({ Remove = true })
		end
		-- Check if ANY stun state is active (not just NoRotate)
		if Client.Library.StateCount(Stuns) then
			Humanoid.AutoRotate = false
		else
			Humanoid.AutoRotate = true
		end
	end)
	
	local maxWait = 2
	local waited = 0
	while waited < maxWait do
		if Character:FindFirstChild("Actions") and
		   Character:FindFirstChild("Stuns") and
		   Character:FindFirstChild("Speeds") then
			break
		end
		task.wait(0.1)
		waited = waited + 0.1
	end

	if not Character:FindFirstChild("Actions") or
	   not Character:FindFirstChild("Stuns") or
	   not Character:FindFirstChild("Speeds") then
		-- warn("[PlayerHandler] StringValues not created after waiting - inputs may not work correctly")
	else
		print("[PlayerHandler] StringValues verified - ready to bind inputs")
	end

	-- Rebind all input actions (fixes running not working after respawn)
	if Client.Modules["Inputs"] and Client.Modules["Inputs"].BindAllActions then
		Client.Modules["Inputs"].BindAllActions()
		print("[PlayerHandler] Rebound all input actions")
	end

	-- Reinitialize animation system
	Client.Modules["Animate"].Init()
	-- print("Reinitialized animation system")

	-- Reinitialize zone controller
	Client.Modules["ZoneController"]()
	-- print("Reinitialized zone controller")

	-- Clear any stuck states in character frames
	task.wait(0.1) -- Wait for frames to be ready
	if Character:FindFirstChild("Actions") then
		Character.Actions.Value = "[]"
		-- print("Cleared Actions states")
	end
	if Character:FindFirstChild("Stuns") then
		Character.Stuns.Value = "[]"
		-- print("Cleared Stuns states")
	end
	if Character:FindFirstChild("Speeds") then
		Character.Speeds.Value = "[]"
		-- print("Cleared Speeds states")
	end
	if Character:FindFirstChild("Status") then
		Character.Status.Value = "[]"
		-- print("Cleared Status states")
	end

	-- Reset character attributes
	Character:SetAttribute("Equipped", false)
	Character:SetAttribute("DodgeCharges", 2)
	-- print("Reset character attributes")

	-- DON'T clear inventory on client - server will sync it
	-- The server clears and repopulates the inventory, then syncs to client via Bridges.Inventory

	-- Clear hotbar UI display (will be repopulated when server syncs inventory)
	task.wait(0.2) -- Wait for UI to be ready
	if Client.Interface and Client.Interface.Stats then
		-- Clear all hotbar slot displays
		for i = 1, 10 do
			if Client.Interface.Stats.UpdateHotbarSlot then
				Client.Interface.Stats.UpdateHotbarSlot(i, "")
			end
		end
		-- print("Cleared hotbar UI display - waiting for server inventory sync")
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

	--// Clean Up
	Humanoid.Died:Once(function()
		-- Clear combat state on death
		_G.PlayerInCombat = false
		-- print("[Death] Cleared combat state")
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

		-- print("🎯 Loading weapon skills (final initialization step)...")
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
						-- print("✅ Weapon skills loaded successfully on attempt", attempt)
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
	world:set(pent, comps.Dialogue, { npc = nil, name = "none", inrange = false, state = "interact" })

	ID = true
	Initialize(Character)
end)

Players.LocalPlayer:GetAttributeChangedSignal("Weapon"):Connect(function()
	Client.Weapon = Players.LocalPlayer:GetAttribute("Weapon")
end)

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
				-- print("full state", compName, compData)
			end
		elseif data.Action == "ComponentUpdate" then
			world:set(myEntityId, comps[data.Component], data.Data)
			-- print("component update", data.Component, data.Data)
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
