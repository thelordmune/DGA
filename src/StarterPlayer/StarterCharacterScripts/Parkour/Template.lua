-- // services
local RunService = game:GetService('RunService')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local UIS = game:GetService('UserInputService')

-- // variables
local Utils = ReplicatedStorage.Util
local Camera = workspace.CurrentCamera

-- // requires
local Maid = require(Utils.Maid)
local Raycast = require(Utils.Raycast)

local Template = {}
Template.__index = Template

function Template.new(Parkour)
	local self = setmetatable({}, Template)
	self.Parent = Parkour
	
	self.Character = self.Parent.Character

	return self
end

function Template:Start()
end

function Template:End()
end

return Template
