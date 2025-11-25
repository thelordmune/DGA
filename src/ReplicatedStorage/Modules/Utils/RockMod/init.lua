local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PartCache = require(script.PartCache).new(Instance.new("Part"), 500, workspace.World.Visuals.Projectiles) -- prolly gon make a seperate folder for the cached parts

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
params.FilterDescendantsInstances = { workspace.Entities, workspace.World.Visuals}

local RockMod = {
	State = {
		Destroy = function(Part: BasePart, Time: number)
			task.delay(Time, PartCache.ReturnPart, PartCache, Part)
		end,

		CreatePart = function(Raycast)
			local Part = PartCache:GetPart()
			--task.delay(10, PartCache.ReturnPart, PartCache, Part)
			Part.CanCollide = false  -- Changed to false to prevent flinging players
			Part.CanQuery = false
			Part.Anchored = true
			Part.CollisionGroup = "CharactersOff"
			Part.Material = if Raycast.Material == Enum.Material.Grass  then Enum.Material.Sand else Raycast.Material
			Part.MaterialVariant = Raycast.Instance.MaterialVariant -- Copy material variant from ground
			Part.Transparency = Raycast.Instance.Transparency
			Part.Color = if Raycast.Material == Enum.Material.Grass  then Color3.fromRGB(154, 143, 109)  else Raycast.Instance.Color
			Part.CFrame = CFrame.new(Raycast.Position)

			local Attachment = Instance.new("Attachment")
			Attachment.Parent = Part
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
RockMod.State.DebrisFolder = workspace.World.Visuals

function RockMod.New(CraterType: string, AnchorPoint: CFrame, Settings: {}) -- i thought making rockmod  a class would be tuff but ngl im thinking of jst  making it a  wrapper isntead of all this bs also i stopped type checking since im
	if not Craters[CraterType] then
		return
	end
	local self = setmetatable({}, RockMod)
	self.AnchorPoint = AnchorPoint
	self.Normal = Settings.Normal

	task.spawn(function()
		Craters[CraterType](AnchorPoint, Settings or {}, RockMod.State)
	end)

	return self
end

function RockMod:Debris(DebrisType: string, Settings: {}, AnchorPoint: CFrame)
	if not Debris[DebrisType] then
		return
	end
	if self.AnchorPoint then
		Settings.Normal = self.Normal
	end
	task.spawn(function()
		Debris[DebrisType](if self.AnchorPoint then self.AnchorPoint else AnchorPoint, Settings, RockMod.State)
	end)
end

return RockMod
