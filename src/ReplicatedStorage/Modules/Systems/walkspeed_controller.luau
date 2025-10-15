--[[
	Walkspeed Controller System

	Directly modifies Humanoid.WalkSpeed based on Speeds StringValue.
	Runs on PreRender (client-only) to ensure immediate response.

	This system reads the Speeds StringValue directly (same as the old listener)
	and immediately applies walkspeed changes every frame.

	This is how Running works - it adds "RunSpeedSet24" to the StringValue,
	and this system reads it and applies the walkspeed change.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local DEBUG = true -- Enable debug logging

-- Convert state name to number (e.g., "M1Speed12" -> 12, "RunSpeedSet24" -> 24)
local function ConvertToNumber(String)
	local Number = string.match(String, "%d+$") -- Match digits at end of string
	local IsNegative = string.match(String, "[-]%d+$") ~= nil

	if IsNegative and Number then
		Number = "-" .. Number
	end

	return Number and tonumber(Number) or 0
end

local lastWalkSpeed = nil
local lastJumpPower = nil

local hasLoggedStartup = false

local function walkspeed_controller()
	-- Only run on client
	if RunService:IsServer() then return end

	local player = Players.LocalPlayer
	if not player then
		if DEBUG and not hasLoggedStartup then
			warn("[WalkspeedController] No LocalPlayer found!")
			hasLoggedStartup = true
		end
		return
	end

	if not player.Character then
		if DEBUG and not hasLoggedStartup then
			warn("[WalkspeedController] No character found!")
			hasLoggedStartup = true
		end
		return
	end

	if not hasLoggedStartup then
		print("[WalkspeedController] ✅ System started successfully!")
		hasLoggedStartup = true
	end

	local character = player.Character
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		warn("[WalkspeedController] No humanoid found!")
		return
	end

	-- Get Speeds StringValue (same as Running system uses!)
	local speedsStringValue = character:FindFirstChild("Speeds")
	if not speedsStringValue then
		warn("[WalkspeedController] No Speeds StringValue found!")
		return
	end

	-- Parse JSON array from StringValue (same as old listener)
	local success, speedStates = pcall(function()
		return HttpService:JSONDecode(speedsStringValue.Value)
	end)

	if not success then
		warn("[WalkspeedController] Failed to parse Speeds JSON:", speedsStringValue.Value)
		speedStates = {}
	end

	if not speedStates then
		speedStates = {}
	end

	local DeltaSpeed = 16 -- Default speed
	local DeltaJump = 50 -- Default jump

	-- First find all speed modifications
	local speedModifiers = {}
	for _, state in ipairs(speedStates) do
		if string.match(state, "Jump") then
			local Number = ConvertToNumber(state)
			DeltaJump += Number
		elseif string.match(state, "Speed") then
			local Number = ConvertToNumber(state)
			table.insert(speedModifiers, Number)
		end
	end

	-- Apply speed modifications with priority to lowest values
	for _, modifier in pairs(speedModifiers) do
		-- For negative modifiers (like -0), use them directly
		if modifier <= 0 then
			DeltaSpeed = modifier
			break -- Negative/zero speeds take priority
		else
			DeltaSpeed = math.min(DeltaSpeed + modifier, modifier) -- Cap at modifier if it's a "Set"
		end
	end

	-- Final speed assignment
	local finalWalkSpeed = math.max(0, DeltaSpeed) -- Ensure never negative
	local finalJumpPower = math.max(0, DeltaJump) -- Ensure never negative

	-- ALWAYS update walkspeed (remove the "only if changed" check for debugging)
	humanoid.WalkSpeed = finalWalkSpeed

	if finalWalkSpeed ~= lastWalkSpeed then
		lastWalkSpeed = finalWalkSpeed
		if DEBUG then
			print(`[WalkspeedController] WalkSpeed set to {finalWalkSpeed} (states: {table.concat(speedStates, ", ")})`)
		end
	end

	humanoid.JumpPower = finalJumpPower

	if finalJumpPower ~= lastJumpPower then
		lastJumpPower = finalJumpPower
		if DEBUG and #speedStates > 0 then
			print(`[WalkspeedController] JumpPower set to {finalJumpPower}`)
		end
	end
end

return {
	run = walkspeed_controller,
	settings = {
		phase = "PreRender",
		client_only = true,
		priority = 50 -- Run before movement_lock (which is priority 100)
	}
}

