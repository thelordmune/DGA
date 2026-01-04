--[[
	Guard Spawner System

	Spawns guard NPCs on players who have committed crimes.
	- Monitors player reputation/wanted levels
	- Spawns 2 guards near criminal players
	- Guards pursue and attempt to arrest (kill) the player
	- On guard kill, player is sent to jail
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local Global = require(ReplicatedStorage.Modules.Shared.Global)
local InfluenceManager = require(ReplicatedStorage.Modules.Utils.InfluenceManager)
local Bridges = require(ReplicatedStorage.Modules.Bridges)
local Seralizer = require(ReplicatedStorage.Seralizer)

-- Use the existing QuestGuard data module (same as Magnus quest)
-- This includes BehaviorTree and Appearance which are required for NPC spawning
local QuestGuardData = require(ReplicatedStorage.Regions.Forest.Npcs.QuestGuard)

-- Tag for spawned guards to prevent them from attacking each other
local GUARD_TAG = "SpawnedGuard"

-- Track spawned guards per player
local playerGuards: {[number]: {Model}} = {}
local guardSpawnCooldowns: {[number]: number} = {}

-- Track players pending jail (killed by guards, waiting for respawn)
local pendingJail: {[number]: {duration: number, reason: string}} = {}

local GUARD_SPAWN_COOLDOWN = 60 -- Seconds between guard spawns
local GUARDS_PER_SPAWN = 2


-- Spawn guards near a player using proper NPC spawning pipeline
local function spawnGuardsOnPlayer(player: Player)
	local character = player.Character
	if not character then return end

	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	-- Check cooldown
	local now = os.clock()
	local lastSpawn = guardSpawnCooldowns[player.UserId] or 0
	if now - lastSpawn < GUARD_SPAWN_COOLDOWN then
		return
	end
	guardSpawnCooldowns[player.UserId] = now

	-- Clean up old guard NpcFiles
	if playerGuards[player.UserId] then
		for _, guard in playerGuards[player.UserId] do
			if guard and guard.Parent then
				guard:Destroy()
			end
		end
	end
	playerGuards[player.UserId] = {}

	-- Get NpcFile template (configuration container)
	local npcFileTemplate = ReplicatedStorage:FindFirstChild("NpcFile")
	if not npcFileTemplate then
		warn("[GuardSpawner] No NpcFile template found!")
		return
	end

	-- Set up region/NPCs container structure (same as Magnus quest)
	local regionName = "SpawnedGuards"
	local regionContainer = workspace.World.Live:FindFirstChild(regionName)
	if not regionContainer then
		regionContainer = Instance.new("Folder")
		regionContainer.Name = regionName
		regionContainer.Parent = workspace.World.Live
	end

	local npcsContainer = regionContainer:FindFirstChild("NPCs")
	if not npcsContainer then
		npcsContainer = Instance.new("Folder")
		npcsContainer.Name = "NPCs"
		npcsContainer.Parent = regionContainer
	end

	-- Spawn new guards
	local spawnPositions = {
		hrp.Position + Vector3.new(10, 0, 10),
		hrp.Position + Vector3.new(-10, 0, -10),
	}

	-- Available weapons for guards (randomly assigned)
	local GUARD_WEAPONS = {"Spear", "Guns"}

	for i = 1, GUARDS_PER_SPAWN do
		local spawnPos = spawnPositions[i] or (hrp.Position + Vector3.new(math.random(-15, 15), 0, math.random(-15, 15)))

		-- Update QuestGuardData spawn location (like Magnus quest does)
		QuestGuardData.DataToSendOverAndUdpate.Spawning.Locations = { spawnPos }
		QuestGuardData.Quantity = 1
		QuestGuardData.AlwaysSpawn = true

		-- Randomly assign weapon (Spear or Guns)
		local randomWeapon = GUARD_WEAPONS[math.random(1, #GUARD_WEAPONS)]
		QuestGuardData.DataToSendOverAndUdpate.Weapons.Weapon2 = randomWeapon

		-- Clone NpcFile (config container)
		-- IMPORTANT: Name must be "QuestGuard" to match QuestGuard_BehaviorTree
		-- The NpcBrain script looks for {npcName}_BehaviorTree in the Behaviors module
		local npcFile = npcFileTemplate:Clone()
		local guardId = "SystemGuard_" .. player.UserId .. "_" .. i
		npcFile.Name = "QuestGuard" -- Must match behavior tree name
		npcFile:SetAttribute("SetName", guardId) -- Custom ID for targeting
		npcFile:SetAttribute("DefaultName", "Military Police")
		npcFile:SetAttribute("IsGuard", true)
		npcFile:SetAttribute("IsSpawnedGuard", true) -- For spawn_entity to copy to model
		npcFile:SetAttribute("SpawnedBySystem", true)
		npcFile:SetAttribute("TargetPlayerId", player.UserId)
		npcFile:SetAttribute("IsHostile", true)
		npcFile:SetAttribute("GuardId", guardId) -- Store for lookup

		-- Create Data folder with QuestGuard configuration (includes BehaviorTree, Appearance, etc.)
		local dataFolder = Instance.new("Folder")
		dataFolder.Name = "Data"
		Seralizer.LoadTableThroughInstance(dataFolder, QuestGuardData.DataToSendOverAndUdpate)
		dataFolder.Parent = npcFile

		-- Parent to NPCs container - the NPC system will spawn the actual model
		npcFile.Parent = npcsContainer

		-- Track the NpcFile for cleanup
		table.insert(playerGuards[player.UserId], npcFile)

		print(string.format("[GuardSpawner] Created guard NpcFile %d for criminal %s at %s", i, player.Name, tostring(spawnPos)))
	end

	-- Wait for guards to spawn and set them to target the player
	task.spawn(function()
		local guardsFound = 0
		local maxWaitTime = 10
		local startTime = os.clock()
		local targetPattern = "SystemGuard_" .. player.UserId

		while guardsFound < GUARDS_PER_SPAWN and (os.clock() - startTime) < maxWaitTime do
			for _, model in workspace.World.Live:GetDescendants() do
				if model:IsA("Model") and model:FindFirstChild("Humanoid") then
					-- spawn_entity sets model.Name = SetName + random number
					-- So check the model's Name property for our pattern
					if model.Name:find(targetPattern) and not model:GetAttribute("GuardSetup") then
						-- Mark as setup to prevent duplicate processing
						model:SetAttribute("GuardSetup", true)

						-- Tag guard so they won't attack each other
						CollectionService:AddTag(model, GUARD_TAG)

						-- Set attributes to identify as spawned guard
						model:SetAttribute("IsSpawnedGuard", true)
						model:SetAttribute("TargetPlayerId", player.UserId)

						-- Add player to damage log so guard targets them immediately
						local damageLog = model:FindFirstChild("Damage_Log")
						if damageLog then
							local attackRecord = Instance.new("ObjectValue")
							attackRecord.Name = "GuardTarget"
							attackRecord.Value = character
							attackRecord.Parent = damageLog
						end

						guardsFound = guardsFound + 1
						print(string.format("[GuardSpawner] Guard %s now targeting %s", model.Name, player.Name))
					end
				end
			end
			if guardsFound < GUARDS_PER_SPAWN then
				task.wait(0.5)
			end
		end

		if guardsFound < GUARDS_PER_SPAWN then
			warn("[GuardSpawner] Only found", guardsFound, "guards after", maxWaitTime, "seconds")
		end
	end)

	-- Notify player
	Bridges.UpdateInfluence:Fire(player, {
		reputation = -50,
		wantedLevel = 3,
		jailTime = 0,
		guardsSpawned = true,
	})
end

-- Check if guard killed player (for jail system)
local function onGuardKillPlayer(player: Player, _killerGuard: Model)
	print(string.format("[GuardSpawner] Guard killed %s - marking for jail on respawn!", player.Name))

	-- Calculate jail time
	local playerData = Global.GetData(player)
	if not playerData then return end

	local jailTime = InfluenceManager.calculateJailTime(playerData.Influence)

	-- Mark player for jail on respawn (can't teleport dead character)
	pendingJail[player.UserId] = {
		duration = jailTime,
		reason = "Arrested for crimes against Amestris",
	}

	-- Update player data to reset wanted level
	Global.SetData(player, function(data)
		if data.Influence then
			data.Influence.JailTime = jailTime
			data.Influence.WantedLevel = 0
		end
		return data
	end)

	-- Clean up spawned guards
	if playerGuards[player.UserId] then
		for _, guard in playerGuards[player.UserId] do
			if guard and guard.Parent then
				guard:Destroy()
			end
		end
		playerGuards[player.UserId] = nil
	end
end

-- Get a random jail cell position
local function getJailPosition()
	local jailFolder = workspace.World:FindFirstChild("AreaSpawns")
	local jailCells = jailFolder and jailFolder:FindFirstChild("Jail")

	if not jailCells then
		warn("[GuardSpawner] No jail cells found at workspace.World.AreaSpawns.Jail")
		return nil
	end

	local cells = jailCells:GetChildren()
	if #cells == 0 then
		warn("[GuardSpawner] Jail folder is empty")
		return nil
	end

	local randomCell = cells[math.random(1, #cells)]
	if randomCell:IsA("BasePart") then
		return randomCell.CFrame * CFrame.new(0, 3, 0)
	end

	return nil
end

-- Teleport player to jail (called after character is fully loaded)
local function teleportToJail(player: Player, targetCFrame: CFrame)
	local character = player.Character
	if not character then
		warn("[GuardSpawner] No character for teleport")
		return false
	end

	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		warn("[GuardSpawner] No HumanoidRootPart for teleport")
		return false
	end

	-- Use PivotTo for model teleport (more reliable)
	character:PivotTo(targetCFrame)
	print("[GuardSpawner] Teleported", player.Name, "to", targetCFrame.Position)
	return true
end

-- Monitor player deaths for guard kills and handle jail on respawn
local function setupDeathMonitoring(player: Player)
	player.CharacterAdded:Connect(function(character)
		-- Check if player has pending jail from being killed by guards
		local jailInfo = pendingJail[player.UserId]
		if jailInfo then
			print("[GuardSpawner] Player has pending jail:", player.Name)
			-- Clear pending jail immediately to prevent double processing
			pendingJail[player.UserId] = nil

			-- Get jail position now (before any delays)
			local jailCFrame = getJailPosition()
			if not jailCFrame then
				warn("[GuardSpawner] Could not get jail position")
				return
			end

			-- Set Jailed attribute on the server (required for Deconstruct escape check)
			character:SetAttribute("Jailed", true)

			-- Notify client about jail immediately
			Bridges.JailPlayer:Fire(player, {
				duration = jailInfo.duration,
				reason = jailInfo.reason,
			})

			-- Teleport multiple times to ensure it sticks
			task.spawn(function()
				-- Wait for HumanoidRootPart to exist
				local hrp = character:WaitForChild("HumanoidRootPart", 15)
				if not hrp then
					warn("[GuardSpawner] HumanoidRootPart never appeared")
					return
				end

				-- First teleport attempt
				task.wait(0.5)
				print("[GuardSpawner] First teleport attempt")
				teleportToJail(player, jailCFrame)

				-- Second teleport attempt after character stabilizes more
				task.wait(1)
				print("[GuardSpawner] Second teleport attempt")
				teleportToJail(player, jailCFrame)

				-- Third teleport attempt
				task.wait(1)
				print("[GuardSpawner] Third teleport attempt")
				teleportToJail(player, jailCFrame)
			end)
		end

		-- Set up death monitoring for this character
		local humanoid = character:WaitForChild("Humanoid", 10)
		if humanoid then
			humanoid.Died:Connect(function()
				-- Check if killed by spawned guard by looking at Damage_Log
				local damageLog = character:FindFirstChild("Damage_Log")
				if damageLog then
					-- Get the most recent attacker
					local records = damageLog:GetChildren()
					if #records > 0 then
						-- Sort by name (timestamp) to get most recent
						table.sort(records, function(a, b)
							return a.Name > b.Name
						end)
						local latestRecord = records[1]
						if latestRecord and latestRecord:IsA("ObjectValue") and latestRecord.Value then
							local attacker = latestRecord.Value
							-- Check if attacker is a spawned guard
							if attacker:GetAttribute("IsSpawnedGuard") then
								onGuardKillPlayer(player, attacker)
							end
						end
					end
				end
			end)
		end
	end)
end

-- Clean up when player leaves
Players.PlayerRemoving:Connect(function(player)
	if playerGuards[player.UserId] then
		for _, guard in playerGuards[player.UserId] do
			if guard and guard.Parent then
				guard:Destroy()
			end
		end
		playerGuards[player.UserId] = nil
	end
	guardSpawnCooldowns[player.UserId] = nil
	pendingJail[player.UserId] = nil
end)

-- Set up death monitoring for existing players
for _, player in Players:GetPlayers() do
	setupDeathMonitoring(player)
end
Players.PlayerAdded:Connect(setupDeathMonitoring)

-- Main system loop
return {
	run = function()
		-- Check each player for criminal status
		for _, player in Players:GetPlayers() do
			local playerData = Global.GetData(player)
			if not playerData or not playerData.Influence then continue end

			local influence = playerData.Influence
			local shouldSpawn = InfluenceManager.shouldSpawnGuards(influence)

			if shouldSpawn then
				spawnGuardsOnPlayer(player)
			end
		end
	end,

	settings = {
		phase = "Heartbeat",
		priority = 100,
		rate = 5, -- Run every 5 seconds
		server_only = true,
	}
}
