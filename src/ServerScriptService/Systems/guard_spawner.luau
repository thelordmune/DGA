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

local Global = require(ReplicatedStorage.Modules.Shared.Global)
local CustomizationData = require(ReplicatedStorage.Modules.CustomizationData)
local InfluenceManager = require(ReplicatedStorage.Modules.Utils.InfluenceManager)
local Bridges = require(ReplicatedStorage.Modules.Bridges)

-- Track spawned guards per player
local playerGuards: {[number]: {Model}} = {}
local guardSpawnCooldowns: {[number]: number} = {}

local GUARD_SPAWN_COOLDOWN = 60 -- Seconds between guard spawns
local GUARDS_PER_SPAWN = 2

-- Preloaded guard template (from workspace or ReplicatedStorage)
local function getGuardTemplate(): Model?
	-- Try to find existing guard template
	local npcFile = ReplicatedStorage:FindFirstChild("NpcFile")
	if npcFile then
		return npcFile:Clone()
	end
	return nil
end

-- Apply alchemist outfit and appearance to guard
local function applyGuardAppearance(guardModel: Model)
	-- Get alchemist outfit (outfit 1 is typically military/alchemist)
	local outfitId = 1
	local outfit = CustomizationData.Clothes[outfitId]

	if not outfit then return end

	-- Delete existing clothes and accessories
	for _, child in guardModel:GetChildren() do
		if child:IsA("Shirt") or child:IsA("Pants") or child:IsA("Accessory") then
			child:Destroy()
		end
	end

	task.wait()

	-- Apply shirt
	local shirt = Instance.new("Shirt")
	shirt.Name = "Shirt"
	shirt.ShirtTemplate = outfit.shirt
	shirt.Parent = guardModel

	-- Apply pants
	local pants = Instance.new("Pants")
	pants.Name = "Pants"
	pants.PantsTemplate = outfit.pants
	pants.Parent = guardModel

	-- Pick random race for skin color (mostly Amestrian for guards)
	local race = math.random() > 0.8 and "Xing" or "Amestrian"
	local raceData = CustomizationData.Races[race]
	local variants = {"variant1", "variant2", "variant3"}
	local skinColor = raceData[variants[math.random(1, 3)]]
	local skinBrickColor = BrickColor.new(skinColor)

	-- Apply skin color to BodyColors
	local bodyColors = guardModel:FindFirstChild("Body Colors")
	if bodyColors then
		bodyColors.HeadColor = skinBrickColor
		bodyColors.LeftArmColor = skinBrickColor
		bodyColors.RightArmColor = skinBrickColor
		bodyColors.LeftLegColor = skinBrickColor
		bodyColors.RightLegColor = skinBrickColor
		bodyColors.TorsoColor = skinBrickColor
	end

	-- Also apply to individual body parts for R15 mesh characters
	for _, part in guardModel:GetDescendants() do
		if part:IsA("BasePart") then
			local partName = part.Name:lower()
			if partName:find("head") or partName:find("arm") or partName:find("leg") or partName:find("hand") or partName:find("foot") or partName:find("torso") then
				part.BrickColor = skinBrickColor
			end
		end
	end

	-- Apply random hair from CustomizationData
	local gender = math.random() > 0.3 and "Male" or "Female"
	local hairOptions = CustomizationData.Hair[gender]
	if hairOptions and #hairOptions > 0 then
		local hairData = hairOptions[math.random(1, #hairOptions)]
		if hairData and hairData.asset then
			local hairClone = hairData.asset:Clone()
			if hairClone then
				-- Get hair color based on race
				local hairColorData = CustomizationData.HairColor[race]
				local hairColor = hairColorData and hairColorData[1] or Color3.fromHSV(0, 0, 0.2)

				-- Apply hair color to all mesh parts in hair accessory
				for _, part in hairClone:GetDescendants() do
					if part:IsA("BasePart") then
						part.Color = hairColor
					end
				end

				hairClone.Parent = guardModel
			end
		end
	end

	-- Apply face from CustomizationData
	local faceOptions = CustomizationData.Face[gender]
	if faceOptions and #faceOptions > 0 then
		local faceData = faceOptions[1]
		if faceData and faceData.assets then
			local faceAssets = faceData.assets:GetChildren()
			if #faceAssets > 0 then
				local randomFace = faceAssets[math.random(1, #faceAssets)]
				if randomFace then
					local faceClone = randomFace:Clone()
					local head = guardModel:FindFirstChild("Head")
					if head then
						-- Remove existing face
						local existingFace = head:FindFirstChild("face") or head:FindFirstChildOfClass("Decal")
						if existingFace then
							existingFace:Destroy()
						end
						faceClone.Parent = head
					end
				end
			end
		end
	end

	-- Set guard attributes
	guardModel:SetAttribute("IsGuard", true)
	guardModel:SetAttribute("SpawnedBySystem", true)
	guardModel:SetAttribute("Weapon", "Spear") -- Guards use spears

	-- Give guard a random name
	local firstName = CustomizationData.FirstNames[math.random(1, #CustomizationData.FirstNames)]
	local lastName = CustomizationData.LastNames[math.random(1, #CustomizationData.LastNames)]
	guardModel:SetAttribute("GuardName", firstName .. " " .. lastName)
	guardModel:SetAttribute("Occupation", "Military Police")
end

-- Spawn guards near a player
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

	-- Clean up old guards
	if playerGuards[player.UserId] then
		for _, guard in playerGuards[player.UserId] do
			if guard and guard.Parent then
				guard:Destroy()
			end
		end
	end
	playerGuards[player.UserId] = {}

	-- Spawn new guards
	local spawnPositions = {
		hrp.Position + Vector3.new(10, 0, 10),
		hrp.Position + Vector3.new(-10, 0, -10),
	}

	for i = 1, GUARDS_PER_SPAWN do
		local spawnPos = spawnPositions[i] or (hrp.Position + Vector3.new(math.random(-15, 15), 0, math.random(-15, 15)))

		-- Create guard from template
		local guardTemplate = getGuardTemplate()
		if not guardTemplate then
			warn("[GuardSpawner] No guard template found!")
			return
		end

		local guard = guardTemplate:Clone()
		guard.Name = "SpawnedGuard_" .. player.UserId .. "_" .. i

		-- Position guard
		local guardHRP = guard:FindFirstChild("HumanoidRootPart")
		if guardHRP then
			guardHRP.CFrame = CFrame.new(spawnPos + Vector3.new(0, 3, 0))
		end

		-- Apply appearance
		applyGuardAppearance(guard)

		-- Set target to criminal player
		guard:SetAttribute("TargetPlayerId", player.UserId)
		guard:SetAttribute("IsHostile", true)

		-- Parent to Live folder
		local liveFolder = workspace.World:FindFirstChild("Live")
		if liveFolder then
			guard.Parent = liveFolder
		else
			guard.Parent = workspace
		end

		table.insert(playerGuards[player.UserId], guard)

		print(string.format("[GuardSpawner] Spawned guard %d for criminal %s", i, player.Name))
	end

	-- Notify player
	Bridges.UpdateInfluence:FireTo(player, {
		reputation = -50,
		wantedLevel = 3,
		jailTime = 0,
		guardsSpawned = true,
	})
end

-- Check if guard killed player (for jail system)
local function onGuardKillPlayer(player: Player, _killerGuard: Model)
	print(string.format("[GuardSpawner] Guard killed %s - sending to jail!", player.Name))

	-- Calculate jail time
	local playerData = Global.GetData(player)
	if not playerData then return end

	local jailTime = InfluenceManager.calculateJailTime(playerData.Influence)

	-- Send to jail
	local success = InfluenceManager.jailPlayer(player, jailTime)
	if success then
		-- Notify client
		Bridges.JailPlayer:FireTo(player, {
			duration = jailTime,
			reason = "Arrested for crimes against Amestris",
		})
	end

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

-- Monitor player deaths for guard kills
local function setupDeathMonitoring(player: Player)
	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if humanoid then
			humanoid.Died:Connect(function()
				-- Check if killed by spawned guard
				-- Look at damage log or last attacker
				local lastDamager = character:GetAttribute("LastDamager")
				if lastDamager and typeof(lastDamager) == "Instance" and lastDamager:GetAttribute("SpawnedBySystem") then
					onGuardKillPlayer(player, lastDamager)
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
