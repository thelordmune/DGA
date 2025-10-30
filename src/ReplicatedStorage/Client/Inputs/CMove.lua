--[[
	C Input - Alchemy Casting System
	
	C key adds "C" to the casting sequence when casting is active.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InputModule = {}
InputModule.__index = InputModule
local self = setmetatable({}, InputModule)

InputModule.InputBegan = function(_, Client)
	-- Get the ZMove module to access casting state and API
	local ZMove = require(script.Parent.ZMove)
	
	-- Add "C" to the sequence
	ZMove.AddKey("C")
	
	-- Update the casting UI to show the key
	local castingAPI = ZMove.GetCastingAPI and ZMove.GetCastingAPI(Client)
	if castingAPI and ZMove.IsCasting and ZMove.IsCasting() then
		castingAPI.StopRotation("C")
	end
end

InputModule.InputEnded = function(_, Client)
	-- C key uses press-to-add, so InputEnded doesn't do anything
end

InputModule.InputChanged = function()
	-- No input changes to handle
end

return InputModule

