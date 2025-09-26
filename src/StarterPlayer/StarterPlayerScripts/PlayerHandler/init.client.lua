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
	print("Client Runtime Error | Client Initialization Failed \nError: " .. Error)
end, Replicated:WaitForChild("Client"))
if not Success then
	return
end

local Modules = Replicated:WaitForChild("Client"):GetChildren()
for __ = 1, #Modules do
	local Module = Modules[__]
	if Module:IsA("ModuleScript") then
		local Req
		local Success, Error = xpcall(function()
			Req = require(Module)
		end, function(Error)
			print("Client - Failed Require: " .. Module.Name .. "\n" .. Error)
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
			print("Client - Failed Require: " .. Module.Name .. "\n" .. Error)
		end)

		if Success and Req then
			Client.Environment[Module.Name] = Req
		end
	end
end

Client.Packets.Visuals.listen(function(Packet)
    -- Add a check to prevent duplicate processing
    if Client._processingVisual then return end
    Client._processingVisual = true
    
    -- print("Visual packet received:", Packet.Module, Packet.Function)
    if Client.Environment[Packet.Module] and Client.Environment[Packet.Module][Packet.Function] then
        Client.Environment[Packet.Module][Packet.Function](unpack(Packet.Arguments))
    else
        warn(`Index: {Packet.Function} Does Not Exist`)
    end
    
    -- Reset flag after a brief delay
    task.wait()
    Client._processingVisual = false
end)

function ConvertToNumber(String)
	local Number = string.match(String, "%d+$")
	local IsNegative = string.match(String, "[-]%d+$") ~= nil

	if IsNegative and Number then
		Number = "-" .. Number
	end

	return Number and tonumber(Number) or 0
end

local function Remove()
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

local pent = ref.get("local_player", Players.LocalPlayer)

function Initialize(Character: Model)
	Client.Service["RunService"].RenderStepped:Wait()
	Client.Character = Character

	-- COMPREHENSIVE CHARACTER REINITIALIZATION
	print("=== REINITIALIZING CHARACTER ===")
	print("Character:", Character.Name)

	-- Reset all client states
	Client.Dodging = false
	Client.Running = false
	Client.DodgeCharges = 2
	print("Reset client movement states")

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
			Client.Library.ResetCooldown(Character, "Feint")
			print("Reset all cooldowns for new character")
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
	print("Waiting for loading screen to finish...")
	while _G.LoadingScreenActive do
		task.wait(0.1)
	end
	print("Loading screen finished, loading HUD...")

	Client.Modules["Interface"].Check()

	safeConnect(Humanoid, "HealthChanged", function(Health)
		Client.Modules["Interface"].UpdateStats("Health", Health, Humanoid.MaxHealth)
	end)

	safeConnect(Posture, "Changed", function(Value)
		Client.Modules["Interface"].UpdateStats("Posture", Value, Posture.MaxValue)
	end)
	safeConnect(Energy, "Changed", function(Value)
		Client.Modules["Interface"].UpdateStats("Posture", Value, Posture.MaxValue)
	end)

	-- Energy.Changed:Connect(function(Value)
	-- 	Client.Modules["Interface"].UpdateStats("Energy", Value, Energy.MaxValue)
	-- end)

	--Posture.Changed:Connect(function(Value)
	--	Client.Modules["Interface"].UpdateStats("Posture", Value, Posture.MaxValue)
	--end)

	Client.Modules["Interface"].UpdateStats("Health", Humanoid.Health, Humanoid.MaxHealth)
	Client.Modules["Interface"].UpdateStats("Energy", Energy.Value, Energy.MaxValue)
	Client.Modules["Interface"].UpdateStats("Posture", Posture.Value, Posture.MaxValue)
	Client.Modules["Interface"].LoadHotbar()
	task.delay(3, function()
		Client.Modules["Interface"].Hotbar("Update")
	end)
	-- Client.Modules["Interface"].Hotbar("Update")
	Client.Modules["Interface"].Party()

	safeConnect(Actions, "Changed", function()
		if Client.Library.StateCheck(Speeds, "FlashSpeedSet50") then
			Client.Packets.Flash.send({ Remove = true })
		end
	end)

	safeConnect(Stuns, "Changed", function()
		if Client.Library.StateCheck(Speeds, "FlashSpeedSet50") then
			Client.Packets.Flash.send({ Remove = true })
		end
		if Client.Library.StateCheck(Stuns, "NoRotate") then
			Humanoid.AutoRotate = false
		else
			Humanoid.AutoRotate = true
		end
	end)

	safeConnect(Speeds, "Changed", function(Value)
		if not Humanoid then
			return
		end
		local FramesTable = Client.Service["HttpService"]:JSONDecode(Value)
		local DeltaSpeed = 16 -- Default speed
		local DeltaJump = 50 -- Default jump

		-- First find all speed modifications
		local speedModifiers = {}
		for _, Frame in FramesTable do
			if string.match(Frame, "Jump") then
				local Number = ConvertToNumber(Frame)
				DeltaJump += Number
			elseif string.match(Frame, "Speed") then
				local Number = ConvertToNumber(Frame)
				table.insert(speedModifiers, Number)
			end
		end

		-- Apply speed modifications with priority to lowest values
		for _, modifier in pairs(speedModifiers) do
			-- For negative modifiers (like -0), use them directly
			if modifier <= 0 then
				DeltaSpeed = modifier
				break -- Negative/zero speeds take priority
			else
				DeltaSpeed = math.min(DeltaSpeed + modifier, modifier) -- Cap at modifier if it's a "Set"
			end
		end

		-- Final speed assignment
		Humanoid.WalkSpeed = math.max(0, DeltaSpeed) -- Ensure never negative
		Humanoid.JumpPower = math.max(0, DeltaJump) -- Ensure never negative
	end)

	-- local pent = ref.get("player", Players.LocalPlayer)

	-- REINITIALIZE ALL SYSTEMS
	print("=== REINITIALIZING ALL SYSTEMS ===")

	-- Reinitialize animation system
	Client.Modules["Animate"].Init()
	print("Reinitialized animation system")

	-- Reinitialize zone controller
	Client.Modules["ZoneController"]()
	print("Reinitialized zone controller")

	-- Clear any stuck states in character frames
	task.wait(0.1) -- Wait for frames to be ready
	if Character:FindFirstChild("Actions") then
		Character.Actions.Value = "[]"
		print("Cleared Actions states")
	end
	if Character:FindFirstChild("Stuns") then
		Character.Stuns.Value = "[]"
		print("Cleared Stuns states")
	end
	if Character:FindFirstChild("Speeds") then
		Character.Speeds.Value = "[]"
		print("Cleared Speeds states")
	end
	if Character:FindFirstChild("Status") then
		Character.Status.Value = "[]"
		print("Cleared Status states")
	end

	-- Reset character attributes
	Character:SetAttribute("Equipped", false)
	Character:SetAttribute("DodgeCharges", 2)
	print("Reset character attributes")

	-- CLEAR HOTBAR AND INVENTORY (Fix item mismatch)
	local InventoryManager = require(Replicated.Modules.Utils.InventoryManager)
	if pent then
		InventoryManager.resetPlayerInventory(pent)
		print("Cleared hotbar and inventory to prevent item mismatch")
	end

	-- Clear hotbar UI display
	task.wait(0.2) -- Wait for UI to be ready
	if Client.Interface and Client.Interface.Stats then
		-- Clear all hotbar slot displays
		for i = 1, 10 do
			if Client.Interface.Stats.UpdateHotbarSlot then
				Client.Interface.Stats.UpdateHotbarSlot(i, "")
			end
		end
		print("Cleared hotbar UI display")
	end

	-- Client.Modules["InventoryHandler"]()

	local DialogueTracker = require(Replicated.Client.Misc.DialogueTracker)
	DialogueTracker.Start()

	local QuestEvents = require(Replicated.Modules.Utils.QuestEvents)
	QuestEvents.Connect()

	--// Clean Up
	Humanoid.Died:Once(Remove)
	Character:GetPropertyChangedSignal("PrimaryPart"):Once(function()
		if not Character.PrimaryPart then
			Remove()
		end
	end)

	ClientThread.Spawn()
end

local ID = false
local active = false
local maxRetries = 5
local retryCount = 0

local function startECSWithRetry()
	if active then
		return
	end

	print("Attempting to start client ECS systems... (Attempt", retryCount + 1, ")")
	local success, err = pcall(start)
	if success then
		print("Client ECS systems started successfully")
		active = true
		return true
	else
		warn("Failed to start client ECS systems:", err)
		retryCount = retryCount + 1
		if retryCount < maxRetries then
			print("Retrying in 2 seconds...")
			task.wait(2)
			return startECSWithRetry()
		else
			warn("Max retries reached, ECS systems failed to start")
			return false
		end
	end
end

Players.LocalPlayer.CharacterAdded:Connect(function(Character)
	world:set(pent, comps.Dialogue, { npc = nil, name = "none", inrange = false, state = "interact" })

	-- task.spawn(startECSWithRetry)

	ID = true
	Initialize(Character)
end)

Players.LocalPlayer:GetAttributeChangedSignal("Weapon"):Connect(function()
	Client.Weapon = Players.LocalPlayer:GetAttribute("Weapon")
end)

if Players.LocalPlayer.Character then
	if not ID then
		if not active then
			task.spawn(startECSWithRetry)
		end
		Initialize(Players.LocalPlayer.Character)
	end

	Bridges.ECSClient:Connect(function(data)
		if data.Module ~= "ECS_Replication" then
			return
		end

		local player = game.Players.LocalPlayer
		local myEntityId = ref.get("player", player)

		if not myEntityId then
			return
		end

		if data.Action == "FullState" then
			for compName, compData in pairs(data.Data) do
				world:set(myEntityId, comps[compName], compData)
				print("full state", compName, compData)
			end
		elseif data.Action == "ComponentUpdate" then
			world:set(myEntityId, comps[data.Component], data.Data)
			print("component update", data.Component, data.Data)
		end
	end)
end

-- Client.Packets.Visuals.listen(function(Packet)
-- 	if Client.Environment[Packet.Module] and Client.Environment[Packet.Module][Packet.Function] then
-- 		Client.Environment[Packet.Module][Packet.Function](unpack(Packet.Arguments))
-- 	else
-- 		warn(`Index: {Packet.Function} Does Not Exist`)
-- 	end
-- end)

-- Store client's entity ID
