--[[
	Z Input - Alchemy Casting System
	
	Z key adds "Z" to the casting sequence when casting is active.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InputModule = {}
InputModule.__index = InputModule
local self = setmetatable({}, InputModule)

InputModule.InputBegan = function(_, Client)
	-- Get the ZMove module to access casting state and API
	local ZMove = require(script.Parent.ZMove)
	
	-- Add "Z" to the sequence
	ZMove.AddKey("Z")
	
	-- Update the casting UI to show the key
	local castingAPI = ZMove.GetCastingAPI and ZMove.GetCastingAPI(Client)
	if castingAPI and ZMove.IsCasting and ZMove.IsCasting() then
		castingAPI.StopRotation("Z")
	end
end

InputModule.InputEnded = function(_, Client)
	-- No action needed
end

InputModule.InputChanged = function()
	-- No action needed
end

return InputModule

