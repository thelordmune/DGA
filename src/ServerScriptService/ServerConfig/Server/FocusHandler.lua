--[[
	FocusHandler - Server-Side Focus Modification API

	Centralized module for all focus changes. Called by:
	- Combat.lua (hit/whiff)
	- Damage.lua (parry/damage/skill)
	- Dodge.lua (successful dodge)
	- focus_system.luau (decay, mode transitions)
]]

local FocusHandler = {}
local Server = require(script.Parent)

local Replicated = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")

local world = require(Replicated.Modules.ECS.jecs_world)
local comps = require(Replicated.Modules.ECS.jecs_components)
local ref = require(Replicated.Modules.ECS.jecs_ref)
local StateManager = require(Replicated.Modules.ECS.StateManager)
local Packets = require(Replicated.Modules.Packets)
local Visuals = require(Replicated.Modules.Visuals)

--------------------------------------------------------------------------------
-- Focus Change Amounts (tunable)
--------------------------------------------------------------------------------

FocusHandler.Amounts = {
	-- Good actions
	M1_HIT = 6,
	COMBO_BONUS = 8,         -- extra for combo 3+
	SKILL_HIT = 12,
	PARRY_SUCCESS = 15,
	DODGE_SUCCESS = 8,

	-- Bad actions
	WHIFF_ATTACK = 3,
	WHIFF_PARRY = 2,
	GOT_PARRIED = 4,
	LIGHT_DAMAGE = 2,
	HEAVY_DAMAGE = 5,        -- >10% HP

	-- Per-second rates (applied in focus_system.luau)
	PASSIVE_DECAY = 0.3,     -- always
	RUNNING_IN_COMBAT = 0.5, -- while running + InCombat
	BLOCKING_IN_COMBAT = 0.5,-- while blocking + InCombat
}

--------------------------------------------------------------------------------
-- Training Levels
--------------------------------------------------------------------------------

local TRAINING_LEVELS = {
	-- { requiredXP, maxFocus, permanentFloor }
	[0] = { xp = 0,     max = 50,  floor = 0  },
	[1] = { xp = 1000,  max = 55,  floor = 5  },
	[2] = { xp = 3000,  max = 60,  floor = 10 },
	[3] = { xp = 6000,  max = 65,  floor = 15 },
	[4] = { xp = 10000, max = 70,  floor = 20 },
	[5] = { xp = 16000, max = 75,  floor = 25 },
	[6] = { xp = 25000, max = 80,  floor = 30 },
	[7] = { xp = 36000, max = 90,  floor = 35 },
	[8] = { xp = 50000, max = 100, floor = 40 },
}

local MAX_TRAINING_LEVEL = 8

--------------------------------------------------------------------------------
-- Voicelines for Absolute Focus
--------------------------------------------------------------------------------

local VOICELINES = {
	"Don't hesitate to kill.",
	"Very well...",
	"I'll give you all I got.",
	"Nah, I'd win.",
}

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local function getPlayerAndEntity(character: Model)
	local player = Players:GetPlayerFromCharacter(character)
	if not player then return nil, nil end

	local entity = ref.get("player", player)
	if not entity then return player, nil end

	return player, entity
end

local function getFocusData(entity)
	if not entity then return nil end
	return world:get(entity, comps.Focus)
end

--------------------------------------------------------------------------------
-- Core API
--------------------------------------------------------------------------------

function FocusHandler.AddFocus(character: Model, amount: number, reason: string?)
	local player, entity = getPlayerAndEntity(character)
	if not entity then return end

	local focus = getFocusData(entity)
	if not focus then return end

	local oldValue = focus.current
	focus.current = math.min(focus.current + amount, focus.max)

	-- Grant training XP for good actions
	if amount > 0 and focus.current > 0 then
		FocusHandler.AddTrainingXP(character, math.ceil(amount * 0.5))
	end
end

function FocusHandler.RemoveFocus(character: Model, amount: number, reason: string?)
	local player, entity = getPlayerAndEntity(character)
	if not entity then return end

	local focus = getFocusData(entity)
	if not focus then return end

	local floor = math.max(focus.permanentFloor, focus.tempFloor)
	focus.current = math.max(focus.current - amount, floor)
end

function FocusHandler.GetFocus(character: Model): number
	local player, entity = getPlayerAndEntity(character)
	if not entity then return 0 end

	local focus = getFocusData(entity)
	if not focus then return 0 end

	return focus.current
end

function FocusHandler.GetFocusPercent(character: Model): number
	local player, entity = getPlayerAndEntity(character)
	if not entity then return 0 end

	local focus = getFocusData(entity)
	if not focus then return 0 end

	if focus.max <= 0 then return 0 end
	return focus.current / focus.max
end

function FocusHandler.SyncToClient(player: Player, entity)
	local focus = getFocusData(entity)
	if not focus then return end

	Packets.FocusSync.sendTo({
		Current = math.clamp(math.floor(focus.current + 0.5), 0, 255),
		Max = math.clamp(math.floor(focus.max + 0.5), 0, 255),
	}, player)
end

--------------------------------------------------------------------------------
-- Training
--------------------------------------------------------------------------------

function FocusHandler.AddTrainingXP(character: Model, amount: number)
	local player, entity = getPlayerAndEntity(character)
	if not entity then return end

	local focus = getFocusData(entity)
	if not focus then return end

	focus.trainingXP = focus.trainingXP + amount

	-- Check for level up
	local nextLevel = focus.trainingLevel + 1
	if nextLevel <= MAX_TRAINING_LEVEL then
		local nextData = TRAINING_LEVELS[nextLevel]
		if focus.trainingXP >= nextData.xp then
			focus.trainingLevel = nextLevel
			focus.max = nextData.max
			focus.permanentFloor = nextData.floor

			-- Save to DataStore
			FocusHandler.SaveTrainingData(player, focus)
		end
	end
end

function FocusHandler.SaveTrainingData(player: Player, focus)
	local Global = require(Replicated.Modules.Shared.Global)
	pcall(function()
		Global.SetData(player, function(data)
			data.FocusTraining = {
				trainingXP = focus.trainingXP,
				trainingLevel = focus.trainingLevel,
				permanentFloor = focus.permanentFloor,
			}
			return data
		end)
	end)
end

function FocusHandler.LoadTrainingData(player: Player, entity)
	local Global = require(Replicated.Modules.Shared.Global)
	local saved = nil
	pcall(function()
		saved = Global.GetData(player, "FocusTraining", 5)
	end)

	local focus = getFocusData(entity)
	if not focus then return end

	if saved then
		focus.trainingXP = saved.trainingXP or 0
		focus.trainingLevel = saved.trainingLevel or 0
		focus.permanentFloor = saved.permanentFloor or 0

		-- Apply training level data
		local levelData = TRAINING_LEVELS[focus.trainingLevel]
		if levelData then
			focus.max = levelData.max
			focus.permanentFloor = levelData.floor
		end
	end
end

--------------------------------------------------------------------------------
-- Absolute Focus Trigger
--------------------------------------------------------------------------------

function FocusHandler.TriggerAbsoluteFocus(character: Model)
	local player, entity = getPlayerAndEntity(character)
	if not entity then return end

	local focus = getFocusData(entity)
	if not focus then return end

	if focus.inAbsoluteMode then return end -- Already active

	focus.inAbsoluteMode = true
	focus.tempFloor = focus.current -- Lock current as floor

	-- Brief iframes (no pose)
	StateManager.TimedState(character, "IFrames", "AbsoluteFocusIFrame", 0.5)

	-- Voiceline in chat
	if player then
		local voiceline = VOICELINES[math.random(1, #VOICELINES)]
		pcall(function()
			local channels = TextChatService:FindFirstChild("TextChannels")
			if channels then
				local general = channels:FindFirstChild("RBXGeneral")
				if general then
					general:DisplaySystemMessage(`<b>{player.DisplayName}:</b> "{voiceline}"`)
				end
			end
		end)
	end

	-- Aura VFX to nearby players
	if character:FindFirstChild("HumanoidRootPart") then
		Visuals.Ranged(character.HumanoidRootPart.Position, 300, {
			Module = "Base",
			Function = "AbsoluteFocusVFX",
			Arguments = { character },
		})
	end

	-- Clear absolute mode flag after brief window but keep tempFloor
	task.delay(0.5, function()
		if entity and world:contains(entity) then
			local f = getFocusData(entity)
			if f then
				f.inAbsoluteMode = false
			end
		end
	end)
end

--------------------------------------------------------------------------------
-- Mini Mode Management (called from focus_system.luau)
--------------------------------------------------------------------------------

function FocusHandler.EnterMiniMode(character: Model)
	local player, entity = getPlayerAndEntity(character)
	if not entity then return end

	local focus = getFocusData(entity)
	if not focus or focus.inMiniMode then return end

	focus.inMiniMode = true

	-- Server buffs (20 walkspeed = slight boost from default 16)
	StateManager.AddState(character, "Speeds", "FocusMiniSpeed20")
	character:SetAttribute("FocusMiniMode", true)
end

function FocusHandler.ExitMiniMode(character: Model)
	local player, entity = getPlayerAndEntity(character)
	if not entity then return end

	local focus = getFocusData(entity)
	if not focus or not focus.inMiniMode then return end

	focus.inMiniMode = false

	-- Remove server buffs
	StateManager.RemoveState(character, "Speeds", "FocusMiniSpeed20")
	character:SetAttribute("FocusMiniMode", false)

	-- Also clear absolute mode if dropping below mini
	focus.inAbsoluteMode = false
	focus.tempFloor = 0
end

return FocusHandler
