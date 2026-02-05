local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CacheFolder = Instance.new("Folder")
CacheFolder.Name = "PartCacheFolder"
CacheFolder.Parent = workspace

local PartCache = require(script.PartCache).new(Instance.new("Part"), 500, workspace.World.Visuals) -- prolly gon make a seperate folder for the cached parts

local Debris = require(script.Debris)
local Craters = require(script.Craters)
local Default = require(script.DEFAULT)
local Modes = require(script.Modes)

local random = Random.new()

local function getXAndZPositions(angle, radius)
	local x = math.cos(angle) * radius
	local z = math.sin(angle) * radius
	return x, z
end

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.FilterDescendantsInstances = { workspace.Entities, workspace.World.Live}

local Returned = 0

local RockMod = {
	State = {
		Destroy = function(Part: BasePart, Time: number)
			if not Time then
				-- Immediate return to cache
				PartCache:ReturnPart(Part)
			else
				-- Delayed return to cache
				task.delay(Time, PartCache.ReturnPart, PartCache, Part)
			end
		end,

		-- Batch destroy multiple parts at once - more efficient than individual Destroy calls
		DestroyBatch = function(Parts: {BasePart}, Time: number)
			if not Time then
				-- Immediate return to cache
				for _, part in Parts do
					PartCache:ReturnPart(part)
				end
			else
				-- Single delayed task for all parts
				task.delay(Time, function()
					for _, part in Parts do
						PartCache:ReturnPart(part)
					end
				end)
			end
		end,
		
		ReturnPart = function(Part)
			PartCache:ReturnPart(Part)
		end,

		CreatePart = function(Raycast, includeAttachment)
			local Part = PartCache:GetPart()
			--task.delay(10, PartCache.ReturnPart, PartCache, Part)
			Part.CanCollide = true
			Part.CanQuery = false
			Part.Anchored = true
			Part.CollisionGroup = "CharactersOff"
			Part.MaterialVariant = Raycast.Instance.MaterialVariant
			Part.Material = if Raycast.Material == Enum.Material.Grass then Enum.Material.Sand else Raycast.Material
			Part.Transparency = Raycast.Instance.Transparency
			Part.Color = if Raycast.Material == Enum.Material.Grass
				then Color3.fromRGB(154, 143, 109)
				else Raycast.Instance.Color
			Part.CFrame = CFrame.new(Raycast.Position)

			if includeAttachment then
				local Attachment = Instance.new("Attachment")
				Attachment.Parent = Part
			end
			return Part
		end,

		MergeTables = function(Original: {}, Merge: {})
			local new = table.clone(Original)
			for k, v in next, Merge do
				if not new[k] then
					new[k] = v
				end
			end
			return new :: any
		end,

		randInt = function(min, max)
			return random:NextNumber(min, max)
		end,

		CircleMath = function(AnchorPoint, Radius, PartCount)
			local Offsets = {}
			for i = 1, PartCount + 1 do
				local angle = i * (2 * math.pi / PartCount)
				local x, z = getXAndZPositions(angle, Radius)
				local Offset = AnchorPoint * Vector3.new(x, 0, z)
				Offsets[i] = Offset
			end
			return Offsets
		end,

		ApplyMode = function(Part, Mode, Settings, Properties)
			if not Modes[Mode] then
				warn(`Debris {Mode} does not exist`)
				return
			end

			Modes[Mode](Part, Settings, Properties)
		end,
	},
}

RockMod.__index = RockMod

RockMod.State.effect_params = params
RockMod.State.DebrisFolder = CacheFolder

function RockMod.New(CraterType: string, AnchorPoint: CFrame | Part, Settings: {})
	print("[RockMod.New] Called with CraterType:", CraterType)
	-- Validate crater type exists
	if not Craters[CraterType] then
		warn("[RockMod] Invalid CraterType: " .. tostring(CraterType) .. ". Available types: Orbit, Crater, Forward, Path")
		return nil
	end

	-- Validate Settings table exists
	if not Settings then
		warn("[RockMod] Settings table is nil for CraterType: " .. CraterType)
		return nil
	end

	-- Validate Normal exists (required for proper raycast direction)
	if not Settings.Normal then
		warn("[RockMod] Settings.Normal is missing for CraterType: " .. CraterType .. ". This is required for proper surface alignment.")
		return nil
	end

	print("[RockMod.New] All validations passed, creating", CraterType)

	local self = setmetatable({}, RockMod)
	self.AnchorPoint = AnchorPoint
	self.Normal = Settings.Normal
	self.ExtraData = nil
	self._craterReady = false

	task.spawn(function()
		print("[RockMod.New] task.spawn running Craters[" .. CraterType .. "]")
		local success, result = pcall(function()
			return Craters[CraterType](AnchorPoint, Settings or {}, RockMod.State)
		end)

		if success then
			print("[RockMod.New] Craters[" .. CraterType .. "] completed successfully")
			if result then
				self.ExtraData = result
			end
			self._craterReady = true
		else
			warn("[RockMod] Error creating crater '" .. CraterType .. "': " .. tostring(result))
			self._craterReady = true -- Mark as ready even on error so Debris doesn't wait forever
		end
	end)

	return self
end

function RockMod:Debris(DebrisType: string, Settings: {}, AnchorPoint: CFrame)
	if not Debris[DebrisType] then
		warn("[RockMod] Invalid DebrisType: " .. tostring(DebrisType) .. ". Available types: Rising, Normal")
		return self
	end

	-- Pass along the Normal from the crater
	if self.Normal then
		Settings.Normal = self.Normal
	end

	-- Wait briefly for ExtraData if crater is still being created (fixes race condition)
	if not self._craterReady then
		local waitStart = os.clock()
		while not self._craterReady and (os.clock() - waitStart) < 0.5 do
			task.wait()
		end
	end

	-- If ExtraData exists (from Forward/Path), use it as the anchor point
	local debrisAnchor = AnchorPoint
	if self.ExtraData then
		debrisAnchor = self.ExtraData
	elseif self.AnchorPoint then
		debrisAnchor = self.AnchorPoint
	end

	task.spawn(function()
		local success, err = pcall(function()
			Debris[DebrisType](debrisAnchor, Settings, RockMod.State)
		end)

		if not success then
			warn("[RockMod] Error creating debris '" .. DebrisType .. "': " .. tostring(err))
		end
	end)

	return self
end

function RockMod:Stop()
	if self.ExtraData and self.ExtraData.Stop then
		self.ExtraData.Stop()
	end
	return self
end

return RockMod
