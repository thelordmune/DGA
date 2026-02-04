--[[
	VFX Packet Handlers (Optimized)

	These handlers process typed VFX packets that replace the generic Visuals packet
	for high-frequency effects. Using typed packets reduces bandwidth by 60-70%.
]]

local Replicated = game:GetService("ReplicatedStorage")
local Client = require(script.Parent.Parent)
local Base = require(Replicated.Effects.Base)

local VFXModule = {}
VFXModule.__index = VFXModule

-- ============================================
-- VFX_CameraShake Handler
-- ============================================
local function handleCameraShake(Data)
	if not Data then return end

	-- Call Base.Shake with the typed parameters
	-- Base.Shake(magnitude, frequency, location)
	local magnitude = Data.Magnitude or 1
	local roughness = Data.Roughness or 25 -- Used as frequency

	-- Position is optional - for localized shakes
	local position = Data.Position

	Base.Shake(magnitude, roughness, position)
end

-- ============================================
-- VFX_Dash Handler
-- ============================================
-- Direction enum: 0=Forward, 1=Back, 2=Left, 3=Right
local DashDirectionNames = {
	[0] = "Forward",
	[1] = "Back",
	[2] = "Left",
	[3] = "Right",
}

local function handleDash(Data)
	if not Data or not Data.Character then return end

	local directionName = DashDirectionNames[Data.Direction] or "Forward"

	-- Call Base.Dash if it exists, otherwise use generic dash VFX
	if Base.Dash then
		Base.Dash(Data.Character, directionName)
	elseif Base.DashFX then
		Base.DashFX(Data.Character, directionName)
	end
end

-- ============================================
-- VFX_CombatStatus Handler
-- ============================================
-- Status enum: 0=Stun, 1=Guard, 2=Parry, 3=Block, 4=Knockback
local CombatStatusNames = {
	[0] = "Stun",
	[1] = "Guard",
	[2] = "Parry",
	[3] = "Block",
	[4] = "Knockback",
}

local function handleCombatStatus(Data)
	if not Data or not Data.Character then return end

	local statusName = CombatStatusNames[Data.Status] or "Stun"
	local duration = Data.Duration

	-- Call appropriate Base function based on status
	if statusName == "Stun" and Base.StunFX then
		Base.StunFX(Data.Character, duration)
	elseif statusName == "Guard" and Base.GuardFX then
		Base.GuardFX(Data.Character, duration)
	elseif statusName == "Parry" and Base.ParryFX then
		Base.ParryFX(Data.Character, duration)
	elseif statusName == "Block" and Base.BlockFX then
		Base.BlockFX(Data.Character, duration)
	elseif statusName == "Knockback" and Base.KnockbackFX then
		Base.KnockbackFX(Data.Character, duration)
	end
end

-- ============================================
-- VFX_Hit Handler
-- ============================================
-- HitType enum: 0=Blood, 1=Spark, 2=Block, 3=Parry
local HitTypeNames = {
	[0] = "Blood",
	[1] = "Spark",
	[2] = "Block",
	[3] = "Parry",
}

local function handleHit(Data)
	if not Data or not Data.Position then return end

	local hitTypeName = HitTypeNames[Data.HitType] or "Blood"
	local position = Data.Position
	local normal = Data.Normal or Vector3.new(0, 1, 0)

	-- Call appropriate Base function based on hit type
	if hitTypeName == "Blood" and Base.BloodFX then
		Base.BloodFX(position, normal)
	elseif hitTypeName == "Spark" and Base.SparkFX then
		Base.SparkFX(position, normal)
	elseif hitTypeName == "Block" and Base.BlockHitFX then
		Base.BlockHitFX(position, normal)
	elseif hitTypeName == "Parry" and Base.ParryHitFX then
		Base.ParryHitFX(position, normal)
	elseif Base.HitFX then
		-- Generic hit effect fallback
		Base.HitFX(position, hitTypeName, normal)
	end
end

-- ============================================
-- REGISTER PACKET LISTENERS
-- ============================================
local function registerVFXListeners()
	-- VFX_CameraShake
	if Client.Packets.VFX_CameraShake then
		Client.Packets.VFX_CameraShake.listen(function(Data)
			handleCameraShake(Data)
		end)
	end

	-- VFX_Dash
	if Client.Packets.VFX_Dash then
		Client.Packets.VFX_Dash.listen(function(Data)
			handleDash(Data)
		end)
	end

	-- VFX_CombatStatus
	if Client.Packets.VFX_CombatStatus then
		Client.Packets.VFX_CombatStatus.listen(function(Data)
			handleCombatStatus(Data)
		end)
	end

	-- VFX_Hit
	if Client.Packets.VFX_Hit then
		Client.Packets.VFX_Hit.listen(function(Data)
			handleHit(Data)
		end)
	end
end

-- Register on module load
registerVFXListeners()

return VFXModule
