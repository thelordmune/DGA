local VISUALIZE_SPAWN_PART = false

local SPAWN_EFFECT: boolean = true
local DESPAWN_EFFECT: boolean = false

-- Global table to track used spawn locations per NPC type
local usedSpawns = {}

local EquipModule = require(game:GetService("ServerScriptService").ServerConfig.Server.Network.Equip)

-- local AnimateScript = game.ReplicatedStorage.NpcHelper.Animations:Clone()

return function(actor: Actor, mainConfig: table)
	-- -- print("=== SPAWN_ENTITY CALLED ===")
	-- -- print("Actor:", actor.Name)
	-- -- print("NPC Name:", mainConfig.Name or "Unknown")
	-- -- print("Spawn Locations:", mainConfig.Spawning and #mainConfig.Spawning.Locations or "No locations")

	-- More thorough check for existing NPC
	if actor:FindFirstChildWhichIsA("Model") then
		return false
	end

	-- Enforce cooldown more strictly
	local currentTime = os.clock()
	if currentTime - mainConfig.Spawning.LastSpawned < mainConfig.Spawning.Cooldown then
		return
	end

	local npcName = actor.Parent.Name
	local regionName = actor.Parent.Parent.Parent.Name

	---- print(npcName,regionName)
	-- Use the shared Bandit DataModel for all NPCs
	local dataModel = game.ReplicatedStorage.Assets.NPC.Bandit
	if not dataModel then
		warn(`Failed to find Bandit data model in ReplicatedStorage.Assets.NPC.Bandit`)
		return false
	end

	-- -- print("Using shared Bandit DataModel for", npcName)

	-- -- print(math.random(1, 2))

	mainConfig.cleanup()

	local spawnLocations = {}
	for _, location in mainConfig.Spawning.Locations do
		table.insert(spawnLocations, location)
	end

	-- -- print("Spawn locations for", npcName .. ":", #spawnLocations, "locations")
	-- for i, loc in pairs(spawnLocations) do
	-- 	-- -- print("- Spawn", i .. ":", loc)
	-- end

	local npcModel = dataModel:Clone()
	npcModel.Name = actor.Parent:GetAttribute("SetName") .. tostring(math.random(1, 1000))

	-- Set weapon based on NPC configuration
	local randomWeapon = "Fist" -- Default to Fist
	local shouldEquip = false

	-- Check if NPC has weapon configuration in mainConfig
	if mainConfig.Weapons and mainConfig.Weapons.Enabled and mainConfig.Weapons.WeaponList and #mainConfig.Weapons.WeaponList > 0 then
		-- Pick a random weapon from the NPC's weapon list
		randomWeapon = mainConfig.Weapons.WeaponList[math.random(1, #mainConfig.Weapons.WeaponList)]
		shouldEquip = true
		-- print("NPC", npcName, "assigned weapon from config:", randomWeapon)
	else
		-- print("NPC", npcName, "has no weapon config, defaulting to Fist")
	end

	npcModel:SetAttribute("Weapon", randomWeapon)
	npcModel:SetAttribute("Equipped", false) -- Always start unequipped, let EquipWeapon handle it
	npcModel:SetAttribute("IsNPC", true) -- Mark as NPC for damage system

	-- print("Spawning NPC:", npcModel.Name, "Weapon:", randomWeapon, "ShouldEquip:", shouldEquip)

	-- -- print("Spawning NPC:", npcModel.Name, "with IsNPC attribute:", npcModel:GetAttribute("IsNPC"))

	-- Determine spawn location with improved distribution
	local spawn_
	local spawnIndex -- Declare spawnIndex in the outer scope
	local npcTypeKey = regionName .. "_" .. npcName

	-- print("=== SPAWN DISTRIBUTION DEBUG ===")
	-- print("NPC Type Key:", npcTypeKey)
	-- print("Available spawn locations:", #spawnLocations)
	for i, loc in pairs(spawnLocations) do
		-- print("- Spawn", i .. ":", loc)
	end

	-- Special handling for wanderers - use assigned spawn from regions
	if npcName == "Wanderer" then
		-- Check if this wanderer has an assigned spawn from regions
		local assignedSpawnIndex = actor.Parent:GetAttribute("AssignedSpawn")
		if assignedSpawnIndex and assignedSpawnIndex <= #spawnLocations then
			spawnIndex = assignedSpawnIndex
			spawn_ = spawnLocations[spawnIndex]
			-- print("Wanderer", actor.Parent.Name, "using assigned spawn", spawnIndex, "at position:", spawn_)
		else
			-- Fallback to first spawn if no assignment
			spawnIndex = 1
			spawn_ = spawnLocations[1]
			-- print("Wanderer", actor.Parent.Name, "using fallback spawn 1 at position:", spawn_)
		end
	else
		-- For other NPCs, use round-robin distribution
		if not usedSpawns[npcTypeKey] then
			usedSpawns[npcTypeKey] = {
				currentIndex = 0,
			}
			-- print("Initialized new spawn tracking for:", npcTypeKey)
		end

		-- Simple round-robin distribution
		if #spawnLocations > 1 then
			-- Get next spawn index using simple round-robin
			local currentSpawnIndex = (usedSpawns[npcTypeKey].currentIndex % #spawnLocations) + 1
			spawn_ = spawnLocations[currentSpawnIndex]
			usedSpawns[npcTypeKey].currentIndex = currentSpawnIndex

			-- -- print("Round-robin spawn:", npcName, "at spawn point", currentSpawnIndex, "of", #spawnLocations)
			-- -- print("Spawn position:", spawn_)
			-- -- print("Updated currentIndex to:", currentSpawnIndex)
		else
			-- Only one spawn location available
			spawn_ = spawnLocations[1]
			-- -- print("Single spawn point for", npcName, "at:", spawn_)
		end
	end
	-- print("=== END SPAWN DEBUG ===")
	-- print()

	-- Add small random offset to prevent exact overlap
	local offsetX = (math.random() - 0.5) * 4 -- Random offset between -2 and 2 studs
	local offsetZ = (math.random() - 0.5) * 4
	spawn_ = spawn_ + Vector3.new(offsetX, 0, offsetZ)

	mainConfig.Spawning.SpawnedAt = spawn_

	-- Position NPC far below the map initially so it's not visible while appearance loads
	local hiddenPosition = spawn_ + Vector3.new(0, -500, 0)
	if npcModel.PrimaryPart then
		npcModel:SetPrimaryPartCFrame(CFrame.new(hiddenPosition) * CFrame.Angles(0, math.rad(90), 0))
	end
	npcModel:MoveTo(hiddenPosition)

	if VISUALIZE_SPAWN_PART then
		local visualziedPart = Instance.new("Part")
		visualziedPart.Anchored = true
		visualziedPart.CanCollide = false
		visualziedPart.Material = "Neon"
		visualziedPart.Color = Color3.fromRGB(255, 0, 0)
		visualziedPart.CFrame = CFrame.new(spawn_)
		visualziedPart.Parent = workspace
	end

	local function findExistingNPC(actor)
		-- Check under actor first
		local npc = actor:FindFirstChildWhichIsA("Model")
		if npc then
			return npc
		end

		-- Check in world live as fallback
		for _, child in ipairs(workspace.World.Live:GetChildren()) do
			if child:IsA("Model") and child.Name == actor.Parent:GetAttribute("SetName") then
				return child
			end
		end
		return nil
	end

	local existingNPC = findExistingNPC(actor)
	if existingNPC then
		return false
	end

	for _, specificTag in mainConfig.Spawning.Tags do
		game.CollectionService:AddTag(npcModel, specificTag)
	end

	npcModel.Parent = actor

	-- Store AncestryChanged connection to prevent memory leak
	table.insert(
		mainConfig.SpawnConnections,
		npcModel.AncestryChanged:Connect(function(_, parent)
			if parent.Name ~= "DataModels" then
				npcModel:FindFirstChild("hi").Enabled = true
			end
		end)
	)

	-- Load appearance and wait for it to complete
	local appearanceLoadedSignal = mainConfig.LoadAppearance()

	-- Entity creation will be handled automatically by Startup.lua when NPC is added to workspace.World.Live
	-- -- print("Spawned NPC:", npcModel.Name, "- entity creation will be handled by monitoring system")

	-- skillSystem:setUp(npcModel)

	for _, basepart: BasePart in npcModel:GetChildren() do
		if basepart:IsA("BasePart") or basepart:IsA("MeshPart") then
			basepart:SetNetworkOwner(nil)
		end
	end

	-- Wait for appearance to load, then move NPC to final position and trigger spawn effect
	if appearanceLoadedSignal then
		task.spawn(function()
			appearanceLoadedSignal:Wait()

			-- Move NPC to final spawn position
			if npcModel and npcModel.PrimaryPart then
				npcModel:SetPrimaryPartCFrame(CFrame.new(spawn_) * CFrame.Angles(0, math.rad(90), 0))
			end
			if npcModel then
				npcModel:MoveTo(spawn_)
			end

			-- Trigger spawn effect now that appearance is loaded
			local _ = SPAWN_EFFECT and mainConfig.SpawnEffect(mainConfig.Spawning.SpawnedAt)
		end)
	else
		-- Fallback if signal is nil
		local _ = SPAWN_EFFECT and mainConfig.SpawnEffect(mainConfig.Spawning.SpawnedAt)
	end

	local damageLog = Instance.new("Folder")
	damageLog.Name = "Damage_Log"
	damageLog.Parent = npcModel

	mainConfig.Spawning.LastSpawned = os.clock()

	-- Store spawn info for cleanup (before adding random offset)

	-- connectors (adjust to game framework)
	-- local statesFolder = game.ReplicatedStorage.PlayerStates:WaitForChild(npcModel.Name)
	do
		local root, humanoid = npcModel.HumanoidRootPart, npcModel.Humanoid

		local function cleanSweep()
			-- Clear the used spawn when NPC is cleaned up
			if usedSpawns[npcTypeKey] then
				-- For other NPCs, use the old system
				for i, location in ipairs(spawnLocations) do
					if (location - spawn_).Magnitude < 10 then -- Within 10 studs of original spawn
						if usedSpawns[npcTypeKey].occupiedSpawns then
							usedSpawns[npcTypeKey].occupiedSpawns[i] = nil
							-- -- print("Freed spawn point", i, "for", npcName)
						end
						break
					end
				end
			end

			-- CRITICAL: Delete ECS entity BEFORE destroying model to prevent memory leak
			if npcModel then
				local RefManager = require(game.ReplicatedStorage.Modules.ECS.jecs_ref_manager)
				local entity = RefManager.entity.find(npcModel)
				if entity then
					RefManager.entity.delete(npcModel)
					-- print(`[NPC Cleanup] Deleted ECS entity {entity} for {npcModel.Name}`)
				end
			end

			if npcModel then
				npcModel:Destroy()
				npcModel = nil
			end

			local _ = npcModel ~= nil and mainConfig.getState(npcModel):Destroy()

			mainConfig.Spawning.LastSpawned = os.clock()

			mainConfig.Idle.PauseDuration.Current = nil
			mainConfig.Idle.NextPause.Current = nil

			mainConfig.EnemyDetection.Current = nil

			for _, specificTag in mainConfig.Spawning.Tags do
				game.CollectionService:RemoveTag(npcModel, specificTag)
			end
			mainConfig.cleanup()

			for _, connection in mainConfig.SpawnConnections do
				connection:Disconnect()
			end
			table.clear(mainConfig.SpawnConnections)
		end

		-- table.insert(
		-- 	mainConfig.SpawnConnections,
		-- 	statesFolder.ChildRemoved:Connect(function(Child)
		-- 		if Child.Name == "Stunned" then
		-- 			root:SetNetworkOwner(nil)
		-- 		end
		-- 	end)
		-- )

		table.insert(
			mainConfig.SpawnConnections,
			humanoid.Died:Connect(function()
				local diedAt: CFrame = mainConfig.getNpcCFrame()

				mainConfig.getState(npcModel):Destroy()

				task.wait(mainConfig.Spawning.DespawnTime)

				local _ = DESPAWN_EFFECT and mainConfig.DespawnEffect(diedAt)
				cleanSweep()
			end)
		)
	end

	-- print("Setting up NPC:", npcModel.Name, "Type:", npcName, "Weapon:", randomWeapon, "ShouldEquip:", shouldEquip)

	-- Setup NPC based on type
	task.delay(2, function()
		-- Equip weapons if configured to do so
		if shouldEquip and randomWeapon ~= "Fist" then
			-- print("Equipping weapon for NPC:", npcModel.Name, "Weapon:", randomWeapon)
			-- Skip animation for NPCs (3rd parameter = true)
			EquipModule.EquipWeapon(npcModel, randomWeapon, true)
			-- print("NPC weapon equipped. Equipped attribute:", npcModel:GetAttribute("Equipped"))
		else
			-- print("Skipping weapon equip for NPC:", npcModel.Name)
		end

		task.wait(1)

		local AnimateScript = game.ReplicatedStorage.NpcHelper.Animations:Clone()
		AnimateScript.Parent = npcModel
		AnimateScript.Enabled = true
	end)

	return true
end