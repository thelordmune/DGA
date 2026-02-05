local RunService = game:GetService("RunService")
-- SPARKS IS BROKEN RN DO NOT USEEE
-- Botom of the script is rpetty scary
local AymanBolt = {}
AymanBolt.__index = AymanBolt
AymanBolt.ActiveBolts = {}
AymanBolt.ActiveSparks = {}
AymanBolt.Modules = {}

local function CreateFakeAttachment(input)
	if typeof(input) == "table" and input.WorldPosition then
		return input
	end

	if typeof(input) == "CFrame" then
		return {
			WorldPosition = input.Position,
			WorldAxis = input.LookVector,
		}
	end

	if typeof(input) == "Vector3" then
		return {
			WorldPosition = input,
			WorldAxis = Vector3.new(0, 0, 0),
		}
	end

	return input
end

function AymanBolt.new(Attachment0, Attachment1, Settings)
	local self = setmetatable({}, AymanBolt)
	Settings = Settings or {}

	local A0 = CreateFakeAttachment(Attachment0)
	local A1 = CreateFakeAttachment(Attachment1)

	self.Bolt = AymanBolt.Modules.Bolts.Create(A0, A1, Settings)
	self.Spark = nil
	self.Id = tostring(self)

	self.Bolt._wrapperId = self.Id
	self.Bolt._wrapper = self

	AymanBolt.ActiveBolts[self.Id] = self.Bolt

	self.Bolt.Destroy = function()
		self:Destroy()
	end

	return self
end

function AymanBolt:Sparks(settings)
	settings = settings or {}

	self.Spark = AymanBolt.Modules.Sparks.Create(self.Bolt, settings)

	AymanBolt.ActiveSparks[self.Id] = self.Spark

	return self
end

function AymanBolt:Destroy()
	if self.Bolt then
		for i = 1, #self.Bolt.Parts do
			self.Bolt.Parts[i]:Destroy()
			if i % 100 == 0 then
				task.wait()
			end
		end
	end

	if self.Spark then
		for i, v in self.Spark.SlotTable do
			if v.Parts[1].Parent == nil then
				self.Spark.SlotTable[i] = nil
			end
		end
	end

	AymanBolt.ActiveBolts[self.Id] = nil
	AymanBolt.ActiveSparks[self.Id] = nil
end

function AymanBolt.Init()
	for _, Module in script:GetChildren() do
		local RequiredModule = require(Module)
		AymanBolt.Modules[Module.Name] = RequiredModule

		RunService.RenderStepped:Connect(function(dt)
			RequiredModule.Init(AymanBolt[`Active{Module.Name}`], dt)
		end)
	end
end



return AymanBolt
