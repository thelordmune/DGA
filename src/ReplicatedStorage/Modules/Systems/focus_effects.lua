--[[
	Focus Effects System - Client ECS System

	Handles visual effects for Focus Mini Mode:
	- Breath VFX attachment on head (mouth breathing particles)
	- Nen aura VFX on body parts (colored to player's Nen type)

	Listens for "FocusMiniMode" attribute on local player character.
	Note: Body flicker only happens during teleport dash (handled in Movement.lua).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local EmitModule = require(ReplicatedStorage.Modules.Utils.EmitModule)
local Global = require(ReplicatedStorage.Modules.Shared.Global)

--------------------------------------------------------------------------------
-- Voicelines by Nen Type
--------------------------------------------------------------------------------

local ENHANCEMENT_LINES = {
	"Full output.",
	"No holding back.",
	"Feel this.",
}

local VOICELINES = {
	Enhancement = ENHANCEMENT_LINES,
	Enhance = ENHANCEMENT_LINES,
	Emission = {
		"Stay right there.",
		"One shot.",
		"Distance means nothing.",
	},
	Conjuration = {
		"Conditions met.",
		"The contract is sealed.",
		"I've prepared for this.",
	},
	Manipulation = {
		"Too late.",
		"Dance for me.",
		"You're already moving wrong.",
	},
	Transmutation = {
		"Don't blink.",
		"Catch me.",
		"Guess what this does.",
	},
	Specialization = {
		"You wouldn't understand.",
		"Shall we begin?",
		"How interesting.",
	},
}

local GENERAL_VOICELINES = {
	"I can see it now.",
	"So this is my resolve.",
	"Finally...",
	"Come, then.",
	"There it is.",
}

local lastVoicelineIndex = {} -- [pool table ref] = last index used

local VOICELINE_FONT = Font.new(
	"rbxasset://fonts/families/Jura.json",
	Enum.FontWeight.Bold,
	Enum.FontStyle.Normal
)

-- State tracking
local miniModeActive = false
local breathVFXClone = nil
local nenAuraClones = {} -- { Instance } cloned VFX to destroy on exit

local function cleanupBreathVFX()
	if breathVFXClone then
		breathVFXClone:Destroy()
		breathVFXClone = nil
	end
end

local function startBreathVFX(character)
	cleanupBreathVFX()

	local head = character:FindFirstChild("Head")
	if not head then return end

	local breathTemplate = ReplicatedStorage:FindFirstChild("Assets")
		and ReplicatedStorage.Assets:FindFirstChild("VFX")
		and ReplicatedStorage.Assets.VFX:FindFirstChild("Focus")
		and ReplicatedStorage.Assets.VFX.Focus:FindFirstChild("Breath")

	if not breathTemplate then return end

	breathVFXClone = breathTemplate:Clone()

	if breathVFXClone:IsA("Attachment") then
		breathVFXClone.Parent = head
		-- Enable all particle emitters
		for _, emitter in breathVFXClone:GetDescendants() do
			if emitter:IsA("ParticleEmitter") then
				emitter.Enabled = true
			end
		end
	elseif breathVFXClone:IsA("BasePart") then
		breathVFXClone.CFrame = head.CFrame * CFrame.new(0, -0.3, -0.5)
		breathVFXClone.Parent = head
	end
end

local function spawnPopVFX(character)
	local torso = character:FindFirstChild("Torso")
	if not torso then return end

	local popTemplate = ReplicatedStorage:FindFirstChild("Assets")
		and ReplicatedStorage.Assets:FindFirstChild("VFX")
		and ReplicatedStorage.Assets.VFX:FindFirstChild("Focus")
		and ReplicatedStorage.Assets.VFX.Focus:FindFirstChild("Pop")

	if not popTemplate then return end

	local popClone = popTemplate:Clone()

	-- Position at torso using CFrame
	if popClone:IsA("Model") then
		popClone:PivotTo(character.HumanoidRootPart.CFrame)
	elseif popClone:IsA("BasePart") then
		popClone.CFrame = torso.CFrame
	end
	popClone.Parent = workspace.World and workspace.World.Visuals or workspace

	-- Emit with EmitModule
	EmitModule.emit(popClone)

	-- Cleanup after 5 seconds
	Debris:AddItem(popClone, 5)
end

local function cleanupNenAura()
	for _, clone in nenAuraClones do
		if clone and clone.Parent then
			clone:Destroy()
		end
	end
	table.clear(nenAuraClones)
end

local NEN_PART_MAPPING = {
	RightArm = "Right Arm",
	LeftArm = "Left Arm",
	RightLeg = "Right Leg",
	LeftLeg = "Left Leg",
	Torso = "Torso",
	Head = "Head",
}

local function startNenAura(character)
	cleanupNenAura()

	local player = Players.LocalPlayer
	if not player then return end

	-- Get Nen color from player data (same pattern as NenBasics.lua)
	local defaultNenColor = Color3.fromRGB(100, 200, 255)
	local nenColor = defaultNenColor

	local nenData = Global.GetData(player, "Nen")
	if nenData then
		local colorData = nenData.Color
		if colorData and colorData.R and colorData.G and colorData.B then
			local r, g, b = colorData.R, colorData.G, colorData.B
			if r >= 250 and g >= 250 and b >= 250 then
				nenColor = defaultNenColor
			else
				nenColor = Color3.fromRGB(r, g, b)
			end
		end
	end

	-- Clone VFX.Nen subfolders to body parts
	local nenFolder = ReplicatedStorage:FindFirstChild("Assets")
		and ReplicatedStorage.Assets:FindFirstChild("VFX")
		and ReplicatedStorage.Assets.VFX:FindFirstChild("Nen")

	if not nenFolder then return end

	-- Helper to recolor a single effect instance
	local function recolorEffect(effect)
		if effect:IsA("ParticleEmitter") or effect:IsA("Beam") or effect:IsA("Trail") then
			local cs = effect.Color
			if typeof(cs) == "ColorSequence" then
				local newKPs = {}
				for _, kp in cs.Keypoints do
					table.insert(newKPs, ColorSequenceKeypoint.new(kp.Time, nenColor))
				end
				effect.Color = ColorSequence.new(newKPs)
			end
		end
	end

	for folderName, partName in NEN_PART_MAPPING do
		local vfxPartFolder = nenFolder:FindFirstChild(folderName)
		local bodyPart = character:FindFirstChild(partName)

		if vfxPartFolder and bodyPart then
			for _, vfx in vfxPartFolder:GetChildren() do
				local cloned = vfx:Clone()

				-- Recolor the cloned item itself and all its descendants
				recolorEffect(cloned)
				for _, desc in cloned:GetDescendants() do
					recolorEffect(desc)
				end

				cloned.Parent = bodyPart
				table.insert(nenAuraClones, cloned)
			end
		end
	end
end

local function showVoiceline(character)
	local head = character:FindFirstChild("Head")
	if not head then return end

	local player = Players.LocalPlayer
	if not player then return end

	-- Pick voiceline based on Nen type, never repeat the last one
	local nenData = Global.GetData(player, "Nen")
	local nenType = nenData and nenData.Type or nil
	local pool = (nenType and VOICELINES[nenType]) or GENERAL_VOICELINES

	local lastIdx = lastVoicelineIndex[pool]
	local idx
	if #pool <= 1 then
		idx = 1
	else
		repeat
			idx = math.random(1, #pool)
		until idx ~= lastIdx
	end
	lastVoicelineIndex[pool] = idx
	local text = pool[idx]

	-- Create BillboardGui above head
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "FocusVoiceline"
	billboard.Adornee = head
	billboard.Size = UDim2.fromOffset(200, 30)
	billboard.StudsOffset = Vector3.new(0, 2.5, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 50
	billboard.Parent = player.PlayerGui

	local label = Instance.new("TextLabel")
	label.Name = "VoiceText"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = ""
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 0.3
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.FontFace = VOICELINE_FONT
	label.TextSize = 14
	label.TextTransparency = 0
	label.Parent = billboard

	-- Typewriter effect
	task.spawn(function()
		for i = 1, #text do
			if not billboard.Parent then return end
			label.Text = string.sub(text, 1, i)
			task.wait(0.03)
		end

		-- Hold for a moment
		task.wait(1.5)

		if not billboard.Parent then return end

		-- Fade out
		local fadeInfo = TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		local fadeTween = TweenService:Create(label, fadeInfo, { TextTransparency = 1, TextStrokeTransparency = 1 })
		fadeTween:Play()
		fadeTween.Completed:Wait()

		if billboard.Parent then
			billboard:Destroy()
		end
	end)

	-- Safety cleanup
	Debris:AddItem(billboard, 5)
end

local function enterMiniMode(character)
	if miniModeActive then return end
	miniModeActive = true
	startBreathVFX(character)
	spawnPopVFX(character)
	startNenAura(character)
	showVoiceline(character)
end

local function exitMiniMode()
	if not miniModeActive then return end
	miniModeActive = false
	cleanupBreathVFX()
	cleanupNenAura()
end

local function focus_effects(_world, _dt)
	if RunService:IsServer() then return end

	local player = Players.LocalPlayer
	if not player then return end

	local character = player.Character
	if not character then
		if miniModeActive then exitMiniMode() end
		return
	end

	-- Check mini mode attribute
	local isMini = character:GetAttribute("FocusMiniMode") == true

	if isMini and not miniModeActive then
		enterMiniMode(character)
	elseif not isMini and miniModeActive then
		exitMiniMode()
	end
end

return {
	run = focus_effects,
	settings = {
		phase = "Heartbeat",
		client_only = true,
	},
}
