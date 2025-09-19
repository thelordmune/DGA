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
					if typeof(moduleData) == "table" and moduleData.Quantity then
						self:prepareNPCFiles(region.Name, moduleData)
					end
				end
			else
				warn(`Failed to load region module {region.Name}`)
			end
		end
	end
end

function RegionSystem:prepareNPCFiles(regionName: string, npcData: NPCData)
	local regionContainer = workspace.World.Live:FindFirstChild(regionName) or 
		Instance.new("Folder", workspace.World.Live)
	regionContainer.Name = regionName

	-- Check if NPCs already exist for this region
	local npcsContainer = regionContainer:FindFirstChild("NPCs")
	if npcsContainer and #npcsContainer:GetChildren() > 0 then
		return -- NPCs already exist, don't spawn more
	end

	regionContainer:SetAttribute("LastSpawned",os.clock())

	local npcsContainer = regionContainer:FindFirstChild("NPCs") or 
		Instance.new("Folder", regionContainer)
	npcsContainer.Name = "NPCs"

	local spawnTask = task.spawn(function()
		for i = 1, npcData.Quantity do
			--if os.clock() - 
			if not npcData then
				warn(`Somehow npcData returned: {npcData}, check if it was deleted in {regionName} region.`)
				continue
			end

			local npcFile = toPath:FindFirstChild("NpcFile")
			if not npcData then
				continue
			end

			local npcFile = npcFile:Clone()

			npcFile.Name = npcData.Name--`{npcData.Name}_NpcFile_{i}`

			local _= npcData.Quantity > 1 and npcFile:SetAttribute("SetName",`{npcData.Name}{i}`) or npcFile:SetAttribute("SetName",npcData.Name)
			npcFile:SetAttribute("DefaultName",`{npcData.Name}`)
			--npcFile:SetAttribute("SetName", npcData.Name .. (npcData.Quantity > 1 and i or ""))

			local dataFolder = Instance.new("Folder")
			dataFolder.Name = `{npcData.Name}_NpcFile_{i}Data`; dataFolder.Name = "Data"
			seralizer.LoadTableThroughInstance(dataFolder,npcData.DataToSendOverAndUdpate)

			dataFolder.Parent = npcFile

			npcFile.Parent = npcsContainer
			--task.wait(1)
		end
	end)

	self._loaded[regionName] = self._loaded[regionName] or {}
	self._loaded[regionName][npcData.Name] = spawnTask
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

	task.spawn(function()

		while true do
			for regionName, regionData in self.regions :: {[string]: RegionModuleData} do
				local regionContainer = workspace.World.Live:FindFirstChild(regionName)
				if not regionContainer then
					continue
				end

				for npcName, npcData in regionData do
					if typeof(npcData) ~= "table" 
						or not npcData.LoadDistance
					then
						continue
					end

					local spawnLocations = npcData.DataToSendOverAndUdpate.Spawning.Locations
					local center = Vector3.new(0, 0, 0)
					for _, location in spawnLocations do
						center += location
					end
					center /= #spawnLocations

					if DEBUG_CENTER_PART then
						local debuggingPart = workspace.World.Visuals:FindFirstChild("DebugCenterPart") or Instance.new("Part") do
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
					for _, player in game.Players:GetPlayers() do
						local character = player.Character
						if character and character:FindFirstChild("HumanoidRootPart") then
							if (character.HumanoidRootPart.Position - center).Magnitude <= npcData.LoadDistance then
								playerInRange = true
								break
							end
						end
					end

					if playerInRange then
						if not self._loaded[regionName] or not self._loaded[regionName][npcData.Name] then
							local nameIndex = regionName :: string
							self:prepareNPCFiles(nameIndex, npcData)
						end
					else
						if self._loaded[regionName] and self._loaded[regionName][npcData.Name] then
							--warn"CLEANING REGION"
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
				end
			end
			task.wait(INTERVAL)	
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