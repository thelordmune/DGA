--!strict
local RegionSystem = {}
RegionSystem.__index = RegionSystem

local seralizer = require(game.ReplicatedStorage.Seralizer)
local toPath: Folder = game.ReplicatedStorage

local Server = require(game:GetService("ServerScriptService").ServerConfig.Server)
local Entities = Server.Modules.Entities

export type NPCData = {
	Name: string,
	Quantity: number,
	SpawnCooldown: number,
	LoadDistance: number?, -- Optional
	DataToSendOverAndUdpate: {
		EnemyDetection: {
			CaptureDistance: number,
			LetGoDistance: number,
			MaxPerPlayer: number,
			RunAwayHP: number,
			CaptureOnStun: number
		},
		Spawning: {
			Enabled: boolean,
			CoolDown: number,
			LastSpawned: number,
			Locations: {Vector3},
			Despawning: {
				Enabled: boolean,
				DespawnDistance: number
			}
		},
		Accessories: {}
	},
}

export type RegionData = {[string]: any}
type RegionModuleData = {[string]: NPCData}

function RegionSystem.new()
	local self = setmetatable({
		regions = {},
		_loaded = {}
	}, RegionSystem)

	self:init()
	self:handleDistanceLoading()
	return self :: any
end

function RegionSystem:init()
	local regionsFolder = toPath:FindFirstChild("Regions") :: ModuleScript
	if not regionsFolder then
		warn(`regions folder doesnt exist?`)
		return
	end
	-- only doing it like this instead of directly referencing table is so i dont make this too hardwired around my framework
	for _, region in regionsFolder:GetChildren() do
		if region:IsA("ModuleScript") then
			local success, regionData = pcall(require, region)
			if success then
				self.regions[region.Name] = regionData

				for moduleName, moduleData in regionData do
					if typeof(moduleData) == "table" and moduleData.Quantity and moduleData.Quantity > 0 then
						-- -- print("Loading NPC:", moduleName, "with quantity:", moduleData.Quantity)
						self:prepareNPCFiles(region.Name, moduleData)
					elseif typeof(moduleData) == "table" and moduleData.Quantity and moduleData.Quantity <= 0 then
						-- -- print("Skipping disabled NPC:", moduleName, "with quantity:", moduleData.Quantity)
					end
				end
			else
				warn(`Failed to load region module {region.Name}`)
			end
		end
	end
end

function RegionSystem:prepareNPCFiles(regionName: string, npcData: NPCData, spawnIndex: number?)
	-- print("[PrepareNPC] 📦 === PREPARING NPC FILES ===")
	-- print("[PrepareNPC] Region:", regionName)
	-- print("[PrepareNPC] NPC Name:", npcData.Name)
	-- print("[PrepareNPC] Quantity:", npcData.Quantity)
	-- print("[PrepareNPC] AlwaysSpawn:", npcData.AlwaysSpawn)
	-- print("[PrepareNPC] LoadDistance:", npcData.LoadDistance)

	local regionContainer = workspace.World.Live:FindFirstChild(regionName) or
		Instance.new("Folder", workspace.World.Live)
	regionContainer.Name = regionName
	-- print("[PrepareNPC] Region container:", regionContainer.Name, "created/found")

	-- Check if NPCs already exist for this region
	-- local npcsContainer = regionContainer:FindFirstChild("NPCs")
	-- if npcsContainer and #npcsContainer:GetChildren() > 0 then
	-- 	-- -- print("NPCs already exist for", regionName, "- found", #npcsContainer:GetChildren(), "existing NPCs")
	-- 	return -- NPCs already exist, don't spawn more
	-- end

	regionContainer:SetAttribute("LastSpawned",os.clock())
	-- -- -- print("Set LastSpawned attribute for", regionName)

	local npcsContainer = regionContainer:FindFirstChild("NPCs") or
		Instance.new("Folder", regionContainer)
	npcsContainer.Name = "NPCs"
	-- -- -- print("NPCs container created/found for", regionName)

	local spawnTask = task.spawn(function()
		-- print("[PrepareNPC] Starting spawn task for", npcData.Name, "- creating", npcData.Quantity, "NPC files")
		-- Don't skip if AlwaysSpawn is false - LoadDistance NPCs still need NPC files created
		-- The LoadDistance system will handle spawning/despawning the actual models
		if npcData.AlwaysSpawn == false and not npcData.LoadDistance then
			-- print("[PrepareNPC] ⚠️ Skipping - AlwaysSpawn is false and no LoadDistance set")
			return
		end

		for i = 1, npcData.Quantity do
			-- print("[PrepareNPC] Creating NPC file", i, "of", npcData.Quantity, "for", npcData.Name)
			--if os.clock() -
			if not npcData then
				warn(`[PrepareNPC] ⚠️ Somehow npcData returned: {npcData}, check if it was deleted in {regionName} region.`)
				continue
			end

			local npcFile = toPath:FindFirstChild("NpcFile")
			if not npcFile then
				warn("[PrepareNPC] ❌ NpcFile not found in ReplicatedStorage!")
				continue
			end
			-- print("[PrepareNPC] Found NpcFile template in ReplicatedStorage")

			local npcFile = npcFile:Clone()
			-- print("[PrepareNPC] Cloned NpcFile for", npcData.Name)

			npcFile.Name = npcData.Name--`{npcData.Name}_NpcFile_{i}`

			local setName = npcData.Quantity > 1 and `{npcData.Name}{i}` or npcData.Name
			npcFile:SetAttribute("SetName", setName)
			npcFile:SetAttribute("DefaultName", npcData.Name)

			-- For wanderers, assign a specific spawn index
			if npcData.Name == "Wanderer" then
				local assignedSpawn = spawnIndex or i
				npcFile:SetAttribute("AssignedSpawn", assignedSpawn)
				-- print("[PrepareNPC] Assigned spawn", assignedSpawn, "to wanderer", setName)
			end

			-- -- -- print("Set NPC attributes - SetName:", setName, "DefaultName:", npcData.Name)

			local dataFolder = Instance.new("Folder")
			dataFolder.Name = `{npcData.Name}_NpcFile_{i}Data`; dataFolder.Name = "Data"
			seralizer.LoadTableThroughInstance(dataFolder,npcData.DataToSendOverAndUdpate)
			-- print("[PrepareNPC] Created data folder and loaded NPC configuration")

			dataFolder.Parent = npcFile
			npcFile.Parent = npcsContainer
			-- print("[PrepareNPC] ✅ Added NPC file", setName, "to NPCs container")
			--task.wait(1)
		end
		-- print("[PrepareNPC] ✅ Completed spawn task for", npcData.Name)
	end)

	self._loaded[regionName] = self._loaded[regionName] or {}
	self._loaded[regionName][npcData.Name] = spawnTask
	-- print("[PrepareNPC] Registered spawn task for", regionName, "-", npcData.Name)
	-- print("[PrepareNPC] === END PREPARING NPC FILES ===")
	-- print()
end

function RegionSystem:getRegionData(regionName: string): RegionData?
	return self.regions[regionName]
end

function RegionSystem:getModuleData(regionName: string, moduleName: string): any?
	local region = self.regions[regionName]
	return region and region[moduleName]
end

function RegionSystem:getNPCContainer(regionName: string): Folder?
	local regionFolder = workspace.World.Live:FindFirstChild(`{regionName}Region`)
	return regionFolder and regionFolder:FindFirstChild("NPCs")
end

function RegionSystem:handleDistanceLoading()
	local INTERVAL = 3;
	local DEBUG_CENTER_PART = false;

	-- print("[LoadDistance] 🔧 Distance loading system started")

	task.spawn(function()

		while true do
			for regionName, regionData in self.regions :: {[string]: RegionModuleData} do
				local regionContainer = workspace.World.Live:FindFirstChild(regionName)
				if not regionContainer then
					-- print("[LoadDistance] ⚠️ Region container not found:", regionName)
					continue
				end

				for npcName, npcData in regionData do
					if typeof(npcData) ~= "table"
						or not npcData.LoadDistance
					then
						continue
					end

					-- print("[LoadDistance] 🔍 Checking", npcName, "in", regionName)
					-- print("[LoadDistance]   - LoadDistance:", npcData.LoadDistance, "studs")

					local spawnLocations = npcData.DataToSendOverAndUdpate.Spawning.Locations
					-- print("[LoadDistance]   - Spawn locations count:", #spawnLocations)

					-- For wanderers, spawn them all once and let should_wander handle movement
					if npcName == "Wanderer" then
						-- Get the actual spawn parts from workspace
						local wanderersFolder = workspace:FindFirstChild("Wanderers")
						if wanderersFolder then
							local spawnParts = wanderersFolder:GetChildren()

							-- Only spawn wanderers once, not repeatedly
							if not self._loaded[regionName] or not self._loaded[regionName][npcData.Name] then
								print(`[Wanderer] 🚀 Spawning all {#spawnParts} wanderers (one-time spawn)`)

								-- Spawn all wanderers at once
								local nameIndex = regionName :: string
								self:prepareNPCFiles(nameIndex, npcData)

								-- Mark as loaded
								if not self._loaded[regionName] then
									self._loaded[regionName] = {}
								end
								self._loaded[regionName][npcData.Name] = true

								print(`[Wanderer] ✅ All wanderers spawned. Movement will be controlled by should_wander proximity check.`)
							end
						else
							print(`[Wanderer] ⚠️ workspace.Wanderers folder not found!`)
						end
					else
						-- For non-wanderer NPCs, use center-based detection (original logic)
						local center = Vector3.new(0, 0, 0)
						for _, location in spawnLocations do
							center += location
						end
						center /= #spawnLocations

						-- print("[LoadDistance]   - Center position:", center)

						if DEBUG_CENTER_PART then
							local debuggingPart = workspace.World.Visuals:FindFirstChild("DebugCenterPart") or Instance.new("Part")
							do
								debuggingPart.Color = Color3.fromRGB(255,0,0)
								debuggingPart.Anchored = true;
								debuggingPart.CanCollide = false;
								debuggingPart.Name = "DebugCenterPart"
								debuggingPart.Size = Vector3.new(15,15,15)
								debuggingPart.Position = center
								debuggingPart.Parent = workspace.World.Visuals;
							end
						end

						local playerInRange = false
						local closestDistance = math.huge
						local closestPlayerName = "None"

						for _, player in game.Players:GetPlayers() do
							local character = player.Character
							if character and character:FindFirstChild("HumanoidRootPart") then
								local distance = (character.HumanoidRootPart.Position - center).Magnitude

								if distance < closestDistance then
									closestDistance = distance
									closestPlayerName = player.Name
								end

								if distance <= npcData.LoadDistance then
									playerInRange = true
									-- print("[LoadDistance]   ✅ Player", player.Name, "is in range! Distance:", math.floor(distance), "studs")
									break
								end
							end
						end

						if not playerInRange then
							-- print("[LoadDistance]   ❌ No players in range. Closest:", closestPlayerName, "at", math.floor(closestDistance), "studs")
						end

						local isAlreadyLoaded = self._loaded[regionName] and self._loaded[regionName][npcData.Name] ~= nil
						-- print("[LoadDistance]   - Already loaded:", isAlreadyLoaded)

						if playerInRange then
							if not self._loaded[regionName] or not self._loaded[regionName][npcData.Name] then
								-- print("[LoadDistance]   🚀 SPAWNING", npcData.Name, "in", regionName)
								local nameIndex = regionName :: string
								self:prepareNPCFiles(nameIndex, npcData)
							else
								-- print("[LoadDistance]   ✓ Already spawned, keeping alive")
							end
						else
							if self._loaded[regionName] and self._loaded[regionName][npcData.Name] then
								-- print("[LoadDistance]   🗑️ DESPAWNING", npcData.Name, "in", regionName)
								if self._loaded[regionName][npcData.Name] then
									task.cancel(self._loaded[regionName][npcData.Name])
								end

								local npcsContainer = regionContainer:FindFirstChild("NPCs")
								if npcsContainer then
									for _, npcFile in npcsContainer:GetChildren() do
										if npcFile.Name == npcData.Name then
											npcFile:Destroy()
										end
									end
								end

								self._loaded[regionName][npcData.Name] = nil;
							end
						end

						-- print("[LoadDistance]   ---")
					end
				end
				task.wait(INTERVAL)
			end
		end
	end)
end

function RegionSystem:cleanup()
	for regionName in self.regions do
		local regionFolder = workspace.World.Live:FindFirstChild(`{regionName}Region`)
		if regionFolder then
			regionFolder:Destroy()
		end
	end
	table.clear(self.regions)
	table.clear(self._loaded)
end

local RegionLoader = RegionSystem.new()
return RegionLoader