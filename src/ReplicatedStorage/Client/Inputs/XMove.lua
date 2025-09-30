--[[
	X Input - Alchemy Modifier System

	X key now controls modifier mode for directional casting.
	- If not casting: Does nothing
	- If casting: Enters modifier mode or stops everything
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Library = require(ReplicatedStorage.Modules.Library)

local InputModule = {}
InputModule.__index = InputModule
local self = setmetatable({}, InputModule)

InputModule.InputBegan = function(_, Client)
	-- Get the current casting instance from ZMove
	local ZMove = require(script.Parent.ZMove)
	local castingInstance = ZMove.castingInstance

	if not castingInstance or not castingInstance.isCasting then
		-- Not currently casting, X does nothing
		-- print("❌ Not currently casting - X key has no effect")
		return
	end

	if castingInstance.isModifying then
		-- Already in modifier mode - stop everything
		-- print("🛑 Stopping casting from modifier mode")
		castingInstance:StopCasting()
	else
		-- Enter modifier mode
		-- print("🔧 Entering modifier mode")
		castingInstance:EnterModifierMode()
	end
end

InputModule.InputEnded = function(_, Client)
	-- X key uses press-to-toggle, so InputEnded doesn't do anything
end

InputModule.InputChanged = function()
	-- No input changes to handle
end

return InputModule
