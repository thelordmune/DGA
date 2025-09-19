local InputModule = {}
InputModule.__index = InputModule
local self = setmetatable({}, InputModule)
local Moves = require(game:GetService("ReplicatedStorage").Modules.Shared.Skills)

self.LastInput = 0
self.InputEndedManually = false

InputModule.InputBegan = function(_, Client)
local alchemy = Client.Alchemy
print(alchemy)
local Skill = Moves[alchemy][script.Name]
print(Skill)
	Client.Packets[Skill].send({
		Air = Client.InAir,
	})
end

InputModule.InputEnded = function(_, Client)
end

InputModule.InputChanged = function() end

return InputModule
