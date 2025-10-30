--[[
	G Input - Alchemy Casting System

	G key now starts casting or confirms combinations for alchemy moves.
	- Press G to start casting (moves UI to side)
	- Press Z/X/C to build sequence
	- Press G again to confirm the combination
	Uses the Casting component integrated into the Health UI.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Combinations = require(ReplicatedStorage.Modules.Shared.Combinations)
local Library = require(ReplicatedStorage.Modules.Library)

local InputModule = {}
InputModule.__index = InputModule
local self = setmetatable({}, InputModule)

-- Track casting state
local isCasting = false
local keySequence = ""
local lastCastTime = 0
local CAST_COOLDOWN = 3.5 -- Cooldown between casts

-- Get the casting API from the Health component
local function getCastingAPI(Client)
	-- Access through Client.Modules.Interface.Modules.Stats
	if Client.Modules and Client.Modules.Interface then
		local Interface = Client.Modules.Interface
		if Interface.Modules and Interface.Modules.Stats then
			local Stats = Interface.Modules.Stats
			if Stats.healthComponentData and Stats.healthComponentData.castingAPI then
				return Stats.healthComponentData.castingAPI
			end
		end
	end
	return nil
end

-- Check combination and execute move
local function checkAndExecuteMove(Client, sequence)
	print("[ZMove] Checking sequence:", sequence)

	-- Check for matching combination
	local matchedMove = Combinations[sequence]
	print("[ZMove] Matched move:", matchedMove)

	if matchedMove then
		-- Check if the skill is on cooldown
		local character = Client.Character
		if character and Library.CheckCooldown(character, matchedMove) then
			print("[ZMove] Move on cooldown:", matchedMove)
			-- Show cooldown feedback
			local castingAPI = getCastingAPI(Client)
			if castingAPI then
				castingAPI.ShowCooldownFeedback()
			end
			return
		end

		-- Send the alchemy move to server
		print("[ZMove] Attempting to send packet for:", matchedMove)
		if Client.Packets[matchedMove] then
			-- Get mouse position for moves that need it
			local mousePos = Vector3.zero
			if matchedMove == "Sky Arc" or matchedMove == "Rock Skewer" then
				local mouse = Client.Player:GetMouse()
				if mouse.Hit then
					mousePos = mouse.Hit.Position
				end
			end

			-- Set client-side cooldown immediately to prevent spam
			if character then
				Library.SetCooldown(character, matchedMove, 8)
			end

			print("[ZMove] Sending packet with data:", {
				Held = false,
				Air = Client.InAir,
				Duration = 0,
				MousePosition = mousePos
			})
			Client.Packets[matchedMove].send({
				Held = false,
				Air = Client.InAir,
				Duration = 0,
				MousePosition = mousePos
			})
			print("[ZMove] ✅ Packet sent successfully!")
		else
			warn("⚠️ No packet handler found for move:", matchedMove)
		end
	else
		print("[ZMove] ⚠️ No matching move found for sequence:", sequence)
	end
end

InputModule.InputBegan = function(_, Client)
	local castingAPI = getCastingAPI(Client)
	if not castingAPI then
		warn("[ZMove] Casting API not found!")
		return
	end

	-- Check cooldown
	if tick() - lastCastTime < CAST_COOLDOWN then
		return
	end

	-- Check if already casting
	if isCasting then
		print("[ZMove] Confirming cast with sequence:", keySequence)

		-- Confirm the combination (triggers animation)
		castingAPI.Confirm()

		-- Execute the move
		checkAndExecuteMove(Client, keySequence)

		-- Reset state
		isCasting = false
		keySequence = ""
		lastCastTime = tick()
	else
		print("[ZMove] Starting new cast")

		-- Start new casting session
		castingAPI.Start()
		isCasting = true
		keySequence = ""
	end
end

InputModule.InputEnded = function(_, Client)
	-- G key uses press-to-toggle, so InputEnded doesn't do anything
end

InputModule.InputChanged = function()
	-- No input changes to handle
end

-- Expose function to add keys to sequence (called by Z/X/C inputs)
InputModule.AddKey = function(key)
	if isCasting then
		keySequence = keySequence .. key
	end
end

-- Expose function to check if casting
InputModule.IsCasting = function()
	return isCasting
end

-- Expose function to get casting API
InputModule.GetCastingAPI = getCastingAPI

return InputModule
