local VISUALIZE_SPAWN_PART = false

local SPAWN_EFFECT: boolean = true
local DESPAWN_EFFECT: boolean = false

-- Global table to track used spawn locations per NPC type
local usedSpawns = {}

local EquipModule = require(game:GetService("ServerScriptService").ServerConfig.Server.Network.Equip)

-- local AnimateScript = game.ReplicatedStorage.NpcHelper.Animations:Clone()

return function(actor: Actor, mainConfig: table)
	-- ---- print("=== SPAWN_ENTITY CALLED ===")
	-- ---- print("Actor:", actor.Name)
	-- ---- print("NPC Name:", mainConfig.Name or "Unknown")
	-- ---- print("Spawn Locations:", mainConfig.Spawning and #mainConfig.Spawning.Locations or "No locations")

	-- CRITICAL: Check if this actor has already spawned an NPC
	-- Chrono moves NPC models to its camera folder for bandwidth optimization,
	-- so we can't rely on actor:FindFirstChildWhichIsA("Model") alone
	-- Use an attribute to track whether we've spawned
	if actor:GetAttribute("HasSpawnedNPC") then
		return false
	end

	-- Also check for model directly under actor (for non-Chrono NPCs)
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

	------ print(npcName,regionName)
	-- Use the shared Bandit DataModel for all NPCs
	local dataModel = game.ReplicatedStorage.Assets.NPC.Bandit
	if not dataModel then
		--warn(`Failed to find Bandit data model in ReplicatedStorage.Assets.NPC.Bandit`)
		return false
	end

	-- ---- print("Using shared Bandit DataModel for", npcName)

	-- ---- print(math.random(1, 2))

	mainConfig.cleanup()

	local spawnLocations = {}
	if mainConfig.Spawning and mainConfig.Spawning.Locations then
		for _, location in mainConfig.Spawning.Locations do
			table.insert(spawnLocations, location)
		end
	end

	-- Special handling for Wanderers - dynamically fetch from workspace.Wanderers if empty
	-- Use case-insensitive check since NPC name might be "Wanderer", "wanderer", etc.
	local isWanderer = npcName:lower():find("wanderer") ~= nil
	if #spawnLocations == 0 and isWanderer then
		local wanderersFolder = workspace:FindFirstChild("Wanderers")
		if wanderersFolder then
			print(`[spawn_entity] Dynamically fetching spawn locations from workspace.Wanderers for {npcName}`)
			for _, part in pairs(wanderersFolder:GetChildren()) do
				if part:IsA("BasePart") then
					table.insert(spawnLocations, part.Position)
				end
			end
			-- Update mainConfig so future spawns don't need to re-fetch
			if #spawnLocations > 0 then
				mainConfig.Spawning.Locations = spawnLocations
				print(`[spawn_entity] Found {#spawnLocations} spawn locations for {npcName}`)
			end
		else
			warn(`[spawn_entity] workspace.Wanderers folder not found for {npcName}!`)
		end
	end

	-- Guard: No spawn locations defined
	if #spawnLocations == 0 then
		warn(`[spawn_entity] No spawn locations defined for {npcName} in region {regionName}`)
		return false
	end

	local npcModel = dataModel:Clone()
	npcModel.Name = actor.Parent:GetAttribute("SetName") .. tostring(math.random(1, 1000))

	local hrp = npcModel:FindFirstChild("HumanoidRootPart")
	if hrp then
		npcModel.PrimaryPart = hrp
	end

	local clonedHumanoid = npcModel:FindFirstChild("Humanoid")
	if clonedHumanoid then
		clonedHumanoid.RequiresNeck = false
		clonedHumanoid.BreakJointsOnDeath = false
		if clonedHumanoid.Health <= 1 or clonedHumanoid.MaxHealth <= 0 then
			clonedHumanoid.MaxHealth = 100
			clonedHumanoid.Health = 100
		end
	end

	-- Set weapon based on NPC configuration
	local randomWeapon = "Fist" -- Default to Fist
	local shouldEquip = false

	-- Check if NPC has weapon configuration in mainConfig
	if mainConfig.Weapons and mainConfig.Weapons.Enabled and mainConfig.Weapons.WeaponList and #mainConfig.Weapons.WeaponList > 0 then
		-- Pick a random weapon from the NPC's weapon list
		randomWeapon = mainConfig.Weapons.WeaponList[math.random(1, #mainConfig.Weapons.WeaponList)]
		shouldEquip = true
		---- print("NPC", npcName, "assigned weapon from config:", randomWeapon)
	else
		---- print("NPC", npcName, "has no weapon config, defaulting to Fist")
	end

	npcModel:SetAttribute("Weapon", randomWeapon)
	npcModel:SetAttribute("Equipped", false) -- Always start unequipped, let EquipWeapon handle it
	npcModel:SetAttribute("IsNPC", true) -- Mark as NPC for damage system

	-- Copy display name from NpcFile for death screen display
	local defaultName = actor.Parent:GetAttribute("DefaultName")
	if defaultName then
		npcModel:SetAttribute("DisplayName", defaultName)
	end

	-- Copy spawned guard attributes from NpcFile to model
	if actor.Parent:GetAttribute("IsSpawnedGuard") or actor.Parent:GetAttribute("SpawnedBySystem") then
		npcModel:SetAttribute("IsSpawnedGuard", true)
		npcModel:SetAttribute("TargetPlayerId", actor.Parent:GetAttribute("TargetPlayerId"))
	end

	---- print("Spawning NPC:", npcModel.Name, "Weapon:", randomWeapon, "ShouldEquip:", shouldEquip)

	-- ---- print("Spawning NPC:", npcModel.Name, "with IsNPC attribute:", npcModel:GetAttribute("IsNPC"))

	-- Determine spawn location with improved distribution
	local spawn_
	local spawnIndex -- Declare spawnIndex in the outer scope
	local npcTypeKey = regionName .. "_" .. npcName

	---- print("=== SPAWN DISTRIBUTION DEBUG ===")
	---- print("NPC Type Key:", npcTypeKey)
	---- print("Available spawn locations:", #spawnLocations)
	for i, loc in pairs(spawnLocations) do
		---- print("- Spawn", i .. ":", loc)
	end

	-- Special handling for wanderers - use assigned spawn from regions
	-- Reuse the isWanderer check from above
	if isWanderer then
		-- Check if this wanderer has an assigned spawn from regions
		local assignedSpawnIndex = actor.Parent:GetAttribute("AssignedSpawn")
		if assignedSpawnIndex and assignedSpawnIndex <= #spawnLocations then
			spawnIndex = assignedSpawnIndex
			spawn_ = spawnLocations[spawnIndex]
			---- print("Wanderer", actor.Parent.Name, "using assigned spawn", spawnIndex, "at position:", spawn_)
		else
			-- Fallback to first spawn if no assignment
			spawnIndex = 1
			spawn_ = spawnLocations[1]
			---- print("Wanderer", actor.Parent.Name, "using fallback spawn 1 at position:", spawn_)
		end
	else
		-- For other NPCs, use round-robin distribution
		if not usedSpawns[npcTypeKey] then
			usedSpawns[npcTypeKey] = {
				currentIndex = 0,
			}
			---- print("Initialized new spawn tracking for:", npcTypeKey)
		end

		-- Simple round-robin distribution
		if #spawnLocations > 1 then
			-- Get next spawn index using simple round-robin
			local currentSpawnIndex = (usedSpawns[npcTypeKey].currentIndex % #spawnLocations) + 1
			spawn_ = spawnLocations[currentSpawnIndex]
			usedSpawns[npcTypeKey].currentIndex = currentSpawnIndex

			-- ---- print("Round-robin spawn:", npcName, "at spawn point", currentSpawnIndex, "of", #spawnLocations)
			-- ---- print("Spawn position:", spawn_)
			-- ---- print("Updated currentIndex to:", currentSpawnIndex)
		else
			-- Only one spawn location available
			spawn_ = spawnLocations[1]
			-- ---- print("Single spawn point for", npcName, "at:", spawn_)
		end
	end
	---- print("=== END SPAWN DEBUG ===")
	---- print()

	-- Add small random offset to prevent exact overlap
	local offsetX = (math.random() - 0.5) * 4 -- Random offset between -2 and 2 studs
	local offsetZ = (math.random() - 0.5) * 4
	spawn_ = spawn_ + Vector3.new(offsetX, 0, offsetZ)

	mainConfig.Spawning.SpawnedAt = spawn_

	-- CRITICAL: Store the intended spawn position as an attribute so mobs.luau can use it
	-- for ECS components (NPCWander.center, Transform, etc.) instead of the hidden Y position
	npcModel:SetAttribute("IntendedSpawnPosition", spawn_)

	-- Position NPC far ABOVE the map initially so it's not visible while appearance loads
	-- IMPORTANT: Using Y=10000 instead of Y=-500 because Roblox's FallenPartsDestroyHeight
	-- defaults to -500, which was causing body parts to be destroyed after ~4 seconds
	local hiddenPosition = spawn_ + Vector3.new(0, 10000, 0)
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
	--warn(`[spawn_entity] 🔍 After parenting to actor - HumanoidRootPart exists: {npcModel:FindFirstChild("HumanoidRootPart") ~= nil}`)

	-- CRITICAL: Mark that this actor has spawned its NPC
	-- This prevents re-spawning when Chrono moves the model to its camera folder
	actor:SetAttribute("HasSpawnedNPC", true)

	-- Store AncestryChanged connection to prevent memory leak
	table.insert(
		mainConfig.SpawnConnections,
		npcModel.AncestryChanged:Connect(function(_, parent)
			-- if parent.Name ~= "DataModels" then
			-- 	npcModel:FindFirstChild("hi").Enabled = true
			-- end
		end)
	)

	--warn(`[spawn_entity] 🔍 Before LoadAppearance - HumanoidRootPart exists: {npcModel:FindFirstChild("HumanoidRootPart") ~= nil}`)

	-- Load appearance and wait for it to complete
	local appearanceLoadedSignal = mainConfig.LoadAppearance()

	--warn(`[spawn_entity] 🔍 After LoadAppearance - HumanoidRootPart exists: {npcModel:FindFirstChild("HumanoidRootPart") ~= nil}`)

	-- Entity creation will be handled automatically by Startup.lua when NPC is added to workspace.World.Live
	-- ---- print("Spawned NPC:", npcModel.Name, "- entity creation will be handled by monitoring system")

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
		-- Verify the cloned model has essential parts immediately
		local root = npcModel:FindFirstChild("HumanoidRootPart")
		local humanoid = npcModel:FindFirstChild("Humanoid")

		if not root or not humanoid then
			--warn(`[spawn_entity] ❌ Cloned NPC model missing essential parts!`)
			--warn(`[spawn_entity]   - NPC Name: {npcModel.Name}`)
			--warn(`[spawn_entity]   - Region: {regionName}`)
			--warn(`[spawn_entity]   - Has HumanoidRootPart: {root ~= nil}`)
			--warn(`[spawn_entity]   - Has Humanoid: {humanoid ~= nil}`)
			--warn(`[spawn_entity]   - DataModel source: {dataModel:GetFullName()}`)
			--warn(`[spawn_entity]   - DataModel has {#dataModel:GetChildren()} children:`)
			for i, child in dataModel:GetChildren() do
				if i <= 10 then -- Only show first 10 to avoid spam
					--warn(`[spawn_entity]     - {child.Name} ({child.ClassName})`)
				end
			end
			return false
		end

		local function cleanSweep()
			-- Clear the used spawn when NPC is cleaned up
			if usedSpawns[npcTypeKey] then
				-- For other NPCs, use the old system
				for i, location in ipairs(spawnLocations) do
					if (location - spawn_).Magnitude < 10 then -- Within 10 studs of original spawn
						if usedSpawns[npcTypeKey].occupiedSpawns then
							usedSpawns[npcTypeKey].occupiedSpawns[i] = nil
							-- ---- print("Freed spawn point", i, "for", npcName)
						end
						break
					end
				end
			end

			-- CRITICAL: Clear the HasSpawnedNPC attribute so this actor can respawn
			actor:SetAttribute("HasSpawnedNPC", nil)

			-- CRITICAL: Delete ECS entity BEFORE destroying model to prevent memory leak
			if npcModel then
				local RefManager = require(game.ReplicatedStorage.Modules.ECS.jecs_ref_manager)
				local entity = RefManager.entity.find(npcModel)
				if entity then
					RefManager.entity.delete(npcModel)
					---- print(`[NPC Cleanup] Deleted ECS entity {entity} for {npcModel.Name}`)
				end
			end

			if npcModel then
				npcModel:Destroy()
				npcModel = nil
			end

			-- State cleanup is now handled by ECS - no StringValue to destroy

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

		-- IMPORTANT: Capture model reference and position BEFORE Chrono might move it
		-- mainConfig.getNpc() returns nil after Chrono moves the model to its camera folder
		local capturedNpcModel = npcModel
		local capturedSpawnPosition = spawn_

		table.insert(
			mainConfig.SpawnConnections,
			humanoid.Died:Connect(function()
				-- Log death for debugging - helps trace why NPCs are dying
				warn(`[spawn_entity] ⚠️ NPC Died: {capturedNpcModel and capturedNpcModel.Name or "unknown"}`)
				warn(`[spawn_entity]   Humanoid Health: {humanoid and humanoid.Health or "N/A"}`)
				warn(`[spawn_entity]   Humanoid MaxHealth: {humanoid and humanoid.MaxHealth or "N/A"}`)

				-- Use captured spawn position instead of trying to get CFrame from moved model
				local diedAt: CFrame = CFrame.new(capturedSpawnPosition)
				if capturedNpcModel and capturedNpcModel.PrimaryPart then
					pcall(function()
						diedAt = capturedNpcModel:GetPivot()
					end)
				end

				-- State cleanup is now handled by ECS - no StringValue to destroy
				-- The character model destruction handles all cleanup

				task.wait(mainConfig.Spawning.DespawnTime)

				local _ = DESPAWN_EFFECT and mainConfig.DespawnEffect(diedAt)
				cleanSweep()
			end)
		)
	end

	---- print("Setting up NPC:", npcModel.Name, "Type:", npcName, "Weapon:", randomWeapon, "ShouldEquip:", shouldEquip)

	-- CRITICAL: Add animation script IMMEDIATELY before Chrono clones the model
	-- This ensures the clone sent to clients has the animation script
	local AnimateScript = game.ReplicatedStorage.NpcHelper.Animations:Clone()
	AnimateScript.Parent = npcModel
	AnimateScript.Enabled = true

	-- Setup NPC weapons (delayed for visual reasons, but animation is already added)
	task.delay(2, function()
		-- Equip weapons if configured to do so
		if shouldEquip and randomWeapon ~= "Fist" then
			---- print("Equipping weapon for NPC:", npcModel.Name, "Weapon:", randomWeapon)
			-- Skip animation for NPCs (3rd parameter = true)
			EquipModule.EquipWeapon(npcModel, randomWeapon, true)
			---- print("NPC weapon equipped. Equipped attribute:", npcModel:GetAttribute("Equipped"))
		else
			---- print("Skipping weapon equip for NPC:", npcModel.Name)
		end
	end)

	return true
end