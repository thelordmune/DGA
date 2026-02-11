--!strict
-- Nen Basics Input Handler (C Key)
-- Activates nen mode and enables secondary key inputs for nen techniques
-- Key Combinations:
--   C = Toggle Nen mode (tap to activate/deactivate)
--   While Nen active: V = Ten (basic) / V again = En (advanced)
--   While Nen active: B = Zetsu (basic) / B again = Ken (advanced)
--   While Nen active: G = Ren (basic) / G again = Gyo (advanced)
--   While Nen active: H = Hatsu (basic) / H again = Ryu (advanced)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local NenAbilities = require(ReplicatedStorage.Modules.NenAbilities)
local EmitModule = require(ReplicatedStorage.Modules.Utils.EmitModule)
local Global = require(ReplicatedStorage.Modules.Shared.Global)

local InputModule = {}
InputModule.__index = InputModule
local self = setmetatable({}, InputModule)

-- Constants
local MODE_SWITCH_COOLDOWN = 10 -- 10 second cooldown between mode switches
local ANIMATION_FPS = 30 -- Roblox animation default FPS

-- Animation startup frame timings (frame when effects should start)
local AnimationStartupFrames = {
	Ren = 32,    -- f32
	Zetsu = 28,  -- f28
	Hatsu = 30,  -- f30
	Ten = 29,    -- f29
	-- Advanced abilities use same timings as their base
	Gyo = 32,
	Ken = 28,
	Ryu = 30,
	En = 29,
}

-- State management
self.NenActive = false -- Is nen mode toggled on
self.CurrentAbility = nil -- Currently active nen ability
self.LastSecondaryKey = nil -- Last secondary key pressed (for advanced toggle)
self.LastSecondaryTime = 0 -- Timestamp of last secondary key press
self.LastModeSwitchTime = 0 -- Timestamp of last mode switch (for cooldown)
self.ActiveSounds = {} :: {[string]: Sound} -- Currently playing sounds
self.ActiveAuraVFX = {} :: {Instance} -- Currently active aura VFX instances
self.ActiveAnimations = {} :: {[string]: AnimationTrack} -- Currently playing Nen animations

-- Ability mappings (V freed up - Ten is now activated directly via C key)
local BasicAbilities = {
	[Enum.KeyCode.B] = "Zetsu",
	[Enum.KeyCode.G] = "Ren",
	[Enum.KeyCode.H] = "Hatsu",
}

local AdvancedAbilities = {
	[Enum.KeyCode.B] = "Ken",   -- Advanced Zetsu
	[Enum.KeyCode.G] = "Gyo",   -- Advanced Ren
	[Enum.KeyCode.H] = "Ryu",   -- Advanced Hatsu
}

-- Map abilities to their loop sound names
local AbilityLoopSounds = {
	Ten = "Ten",
	Zetsu = "Zetsu",
	Ren = "Ren",
	Hatsu = "Hatsu",
	-- Advanced abilities use their base ability's loop sound
	En = "Ten",
	Ken = "Zetsu",
	Gyo = "Ren",
	Ryu = "Hatsu",
}

-- Default colors for each ability (used for VFX and indicator)
-- These are overridden by player's custom NenColor if they have Nen unlocked
local AbilityColors = {
	Ten = Color3.fromRGB(100, 200, 255),   -- Light blue
	Zetsu = Color3.fromRGB(100, 100, 100), -- Gray
	Ren = Color3.fromRGB(255, 100, 100),   -- Red
	Hatsu = Color3.fromRGB(255, 200, 50),  -- Gold
	En = Color3.fromRGB(50, 150, 255),     -- Deep blue
	Ken = Color3.fromRGB(200, 200, 200),   -- Silver
	Gyo = Color3.fromRGB(255, 50, 150),    -- Magenta
	Ryu = Color3.fromRGB(255, 150, 0),     -- Orange
}

-- Threshold for checking if effects should be tinted (how close to white)
local WHITE_THRESHOLD = 0.9 -- (0-1)

-- Secondary key connection (declared early for ResetState access)
local secondaryKeyConnection = nil

-- Ensure Nen color is always bright and vibrant (no dark or desaturated colors)
-- Enforces minimum saturation and brightness for visibility
local function ensureBrightColor(color: Color3): Color3
	local h, s, v = color:ToHSV()
	-- Enforce minimum saturation (at least 0.5 for vibrant colors)
	-- Enforce minimum brightness (at least 0.7 for visibility)
	local newS = math.max(s, 0.5)
	local newV = math.max(v, 0.7)
	return Color3.fromHSV(h, newS, newV)
end

-- Get player's custom Nen color (stored in player data via Replion)
-- Returns a default light blue if player has no custom color or color is white
-- Always returns a bright, vibrant color (no dark colors allowed)
-- Note: Returns color regardless of Nen unlock status (for VFX coloring)
local function getPlayerNenColor(): Color3?
	local player = Players.LocalPlayer
	if not player then return nil end

	-- Default light blue color for Nen effects
	local defaultNenColor = Color3.fromRGB(100, 200, 255)

	-- Get Nen data from player's replicated data
	local nenData = Global.GetData(player, "Nen")
	if not nenData then return defaultNenColor end

	-- Get custom color (stored as {R, G, B} table)
	local colorData = nenData.Color
	if colorData and colorData.R and colorData.G and colorData.B then
		local r, g, b = colorData.R, colorData.G, colorData.B
		-- If color is white (default), use the default light blue
		if r >= 250 and g >= 250 and b >= 250 then
			return defaultNenColor
		end
		local rawColor = Color3.fromRGB(r, g, b)
		-- Ensure the color is bright and vibrant
		return ensureBrightColor(rawColor)
	end

	-- Return default color if no color data
	return defaultNenColor
end

-- Generate a color variation (lighter or darker) of the base color
-- Keeps colors bright - only varies within the bright range
local function getColorVariation(baseColor: Color3, variation: number?): Color3
	local variationAmount = variation or (math.random() * 0.2 - 0.1) -- -0.1 to +0.1 (smaller range)
	local h, s, v = baseColor:ToHSV()

	-- Keep brightness high (0.7 to 1.0) and saturation strong (0.4 to 1.0)
	local newV = math.clamp(v + variationAmount, 0.7, 1.0)
	local newS = math.clamp(s + (variationAmount * 0.3), 0.4, 1.0)

	return Color3.fromHSV(h, newS, newV)
end

-- Check if a color is white or nearly white
local function isWhiteColor(color: Color3): boolean
	local r, g, b = color.R, color.G, color.B
	return r >= WHITE_THRESHOLD and g >= WHITE_THRESHOLD and b >= WHITE_THRESHOLD
end

-- Apply Nen color to a ParticleEmitter if it has white color
local function applyNenColorToParticle(particle: ParticleEmitter, nenColor: Color3, useVariation: boolean?)
	-- Check if the particle's color is white
	local colorSeq = particle.Color
	local keypoints = colorSeq.Keypoints

	local hasWhite = false
	for _, kp in keypoints do
		if isWhiteColor(kp.Value) then
			hasWhite = true
			break
		end
	end

	if hasWhite then
		local targetColor = useVariation and getColorVariation(nenColor) or nenColor

		-- Create new color sequence with the Nen color
		local newKeypoints = {}
		for _, kp in keypoints do
			if isWhiteColor(kp.Value) then
				table.insert(newKeypoints, ColorSequenceKeypoint.new(kp.Time, targetColor))
			else
				table.insert(newKeypoints, kp)
			end
		end

		particle.Color = ColorSequence.new(newKeypoints)
	end
end

-- Apply Nen color to a Beam if it has white color
local function applyNenColorToBeam(beam: Beam, nenColor: Color3, useVariation: boolean?)
	local colorSeq = beam.Color
	local keypoints = colorSeq.Keypoints

	local hasWhite = false
	for _, kp in keypoints do
		if isWhiteColor(kp.Value) then
			hasWhite = true
			break
		end
	end

	if hasWhite then
		local targetColor = useVariation and getColorVariation(nenColor) or nenColor

		local newKeypoints = {}
		for _, kp in keypoints do
			if isWhiteColor(kp.Value) then
				table.insert(newKeypoints, ColorSequenceKeypoint.new(kp.Time, targetColor))
			else
				table.insert(newKeypoints, kp)
			end
		end

		beam.Color = ColorSequence.new(newKeypoints)
	end
end

-- Apply Nen color to a Trail if it has white color
local function applyNenColorToTrail(trail: Trail, nenColor: Color3, useVariation: boolean?)
	local colorSeq = trail.Color
	local keypoints = colorSeq.Keypoints

	local hasWhite = false
	for _, kp in keypoints do
		if isWhiteColor(kp.Value) then
			hasWhite = true
			break
		end
	end

	if hasWhite then
		local targetColor = useVariation and getColorVariation(nenColor) or nenColor

		local newKeypoints = {}
		for _, kp in keypoints do
			if isWhiteColor(kp.Value) then
				table.insert(newKeypoints, ColorSequenceKeypoint.new(kp.Time, targetColor))
			else
				table.insert(newKeypoints, kp)
			end
		end

		trail.Color = ColorSequence.new(newKeypoints)
	end
end

-- Apply Nen color to all applicable effects in an instance tree
local function applyNenColorToEffects(instance: Instance, nenColor: Color3, useVariation: boolean?)
	for _, descendant in instance:GetDescendants() do
		if descendant:IsA("ParticleEmitter") then
			applyNenColorToParticle(descendant, nenColor, useVariation)
		elseif descendant:IsA("Beam") then
			applyNenColorToBeam(descendant, nenColor, useVariation)
		elseif descendant:IsA("Trail") then
			applyNenColorToTrail(descendant, nenColor, useVariation)
		end
	end

	-- Also check the instance itself
	if instance:IsA("ParticleEmitter") then
		applyNenColorToParticle(instance, nenColor, useVariation)
	elseif instance:IsA("Beam") then
		applyNenColorToBeam(instance, nenColor, useVariation)
	elseif instance:IsA("Trail") then
		applyNenColorToTrail(instance, nenColor, useVariation)
	end
end

-- Exported for other modules to access
InputModule.AbilityColors = AbilityColors
InputModule.GetPlayerNenColor = getPlayerNenColor
InputModule.EnsureBrightColor = ensureBrightColor
InputModule.GetColorVariation = getColorVariation
InputModule.IsWhiteColor = isWhiteColor
InputModule.ApplyNenColorToEffects = applyNenColorToEffects
InputModule.ApplyNenColorToParticle = applyNenColorToParticle
InputModule.ApplyNenColorToBeam = applyNenColorToBeam
InputModule.ApplyNenColorToTrail = applyNenColorToTrail
InputModule.IsNenActive = function()
	return self.NenActive
end
InputModule.GetCurrentAbility = function()
	return self.CurrentAbility
end

-- Get player's current level (for requirements check)
local function getPlayerLevel(): number
	local player = Players.LocalPlayer
	if not player then return 1 end

	-- Try to get level from leaderstats or player data
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local level = leaderstats:FindFirstChild("Level")
		if level and level:IsA("IntValue") then
			return level.Value
		end
	end

	-- Fallback to checking _G or player attributes
	if player:GetAttribute("Level") then
		return player:GetAttribute("Level") :: number
	end

	return 1
end

-- Check if player meets requirements for an ability
local function meetsAbilityRequirements(abilityName: string): (boolean, string?)
	local abilityData = NenAbilities[abilityName]
	if not abilityData then
		return false, "Unknown ability"
	end

	-- Check minimum level requirement
	if abilityData.minimumLevel then
		local playerLevel = getPlayerLevel()
		if playerLevel < abilityData.minimumLevel then
			return false, string.format("Requires level %d (you are level %d)", abilityData.minimumLevel, playerLevel)
		end
	end

	return true, nil
end

-- Play Nen activation sounds
-- Sound structure: ReplicatedStorage.SFX.Nen contains Activate, Ten, Ren, Zetsu, Hatsu, Loop (all in same folder)
local function playNenSounds(abilityName: string)
	local player = Players.LocalPlayer
	if not player then return end
	local character = player.Character
	if not character then return end

	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then return end

	-- Find SFX folder
	local sfxFolder = ReplicatedStorage.Assets:FindFirstChild("SFX")
	if not sfxFolder then
		warn("[NenBasics] SFX folder not found in ReplicatedStorage")
		return
	end

	local nenSfxFolder = sfxFolder:FindFirstChild("Nen")
	if not nenSfxFolder then
		warn("[NenBasics] Nen folder not found in SFX")
		return
	end

	-- Play Activate sound
	local activateSound = nenSfxFolder:FindFirstChild("Activate")
	if activateSound and activateSound:IsA("Sound") then
		local activateClone = activateSound:Clone()
		activateClone.Parent = humanoidRootPart
		activateClone:Play()
		activateClone.Ended:Once(function()
			activateClone:Destroy()
		end)
	end

	-- Play ability-specific sound (Ten, Ren, Zetsu, Hatsu - all directly in Nen folder)
	local loopSoundName = AbilityLoopSounds[abilityName]
	if loopSoundName then
		local abilitySound = nenSfxFolder:FindFirstChild(loopSoundName)
		if abilitySound and abilitySound:IsA("Sound") then
			local abilityClone = abilitySound:Clone()
			abilityClone.Parent = humanoidRootPart
			abilityClone:Play()
			abilityClone.Ended:Once(function()
				abilityClone:Destroy()
			end)
		end
	end

	-- Play Loop sound (looped background sound)
	local loopSound = nenSfxFolder:FindFirstChild("Loop")
	if loopSound and loopSound:IsA("Sound") then
		-- Stop any existing loop sound
		if self.ActiveSounds.Loop then
			self.ActiveSounds.Loop:Stop()
			self.ActiveSounds.Loop:Destroy()
		end

		local loopClone = loopSound:Clone()
		loopClone.Looped = true -- Ensure it loops
		loopClone.Parent = humanoidRootPart
		loopClone:Play()
		self.ActiveSounds.Loop = loopClone
	end
end

-- Stop all Nen sounds
local function stopNenSounds()
	for _, sound in pairs(self.ActiveSounds) do
		if sound and sound.Parent then
			sound:Stop()
			sound:Destroy()
		end
	end
	self.ActiveSounds = {}
end

-- Helper function to fade in particle emitters
local function fadeInParticleEmitter(emitter: ParticleEmitter, duration: number)
	-- Store original transparency
	local originalTransparency = emitter.Transparency

	-- Start fully transparent
	emitter.Transparency = NumberSequence.new(1)

	-- Tween to original transparency
	local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	-- Create a NumberValue to tween and update the emitter
	local tweenValue = Instance.new("NumberValue")
	tweenValue.Value = 1

	local tween = TweenService:Create(tweenValue, tweenInfo, {Value = 0})

	local connection
	connection = tweenValue.Changed:Connect(function()
		-- Interpolate between full transparency and original
		local t = 1 - tweenValue.Value
		local keypoints = originalTransparency.Keypoints
		local newKeypoints = {}

		for _, keypoint in keypoints do
			local newValue = 1 - (1 - keypoint.Value) * t
			table.insert(newKeypoints, NumberSequenceKeypoint.new(keypoint.Time, newValue, keypoint.Envelope * t))
		end

		emitter.Transparency = NumberSequence.new(newKeypoints)
	end)

	tween.Completed:Once(function()
		connection:Disconnect()
		tweenValue:Destroy()
		emitter.Transparency = originalTransparency
	end)

	tween:Play()
end

-- Clone and attach aura VFX to character body parts
local function applyAuraVFX(abilityName: string)
	local player = Players.LocalPlayer
	if not player then return end
	local character = player.Character
	if not character then return end

	-- Clean up existing VFX first
	for _, vfx in ipairs(self.ActiveAuraVFX) do
		if vfx and vfx.Parent then
			vfx:Destroy()
		end
	end
	self.ActiveAuraVFX = {}

	-- Safety: destroy any orphaned aura parts on the character (highlights)
	for _, child in character:GetChildren() do
		if child.Name == "NenAuraHighlight" then
			child:Destroy()
		end
	end
	-- Check visuals folder for orphaned Ten aura parts
	local visualsFolder = workspace:FindFirstChild("World") and workspace.World:FindFirstChild("Visuals")
	if visualsFolder then
		for _, child in visualsFolder:GetChildren() do
			if child.Name:find("^TenAura_") then
				child:Destroy()
			end
		end
	end
	-- Check workspace.Terrain for orphaned Ren auras
	for _, child in workspace.Terrain:GetChildren() do
		if child.Name == "RenAura" then
			child:Destroy()
		end
	end

	-- Get player's custom Nen color (if they have Nen unlocked)
	local customNenColor = getPlayerNenColor()

	-- Find Auras VFX folder
	local assetsFolder = ReplicatedStorage:FindFirstChild("Assets")
	if not assetsFolder then return end

	local vfxFolder = assetsFolder:FindFirstChild("VFX")
	if not vfxFolder then return end

	local aurasFolder = vfxFolder:FindFirstChild("Auras")
	if not aurasFolder then
		warn("[NenBasics] Auras folder not found at ReplicatedStorage.Assets.VFX.Auras")
		return
	end

	-- Body part mappings for R6
	local bodyParts = {
		Torso = character:FindFirstChild("Torso"),
		Head = character:FindFirstChild("Head"),
		["Left Arm"] = character:FindFirstChild("Left Arm"),
		["Right Arm"] = character:FindFirstChild("Right Arm"),
		["Left Leg"] = character:FindFirstChild("Left Leg"),
		["Right Leg"] = character:FindFirstChild("Right Leg"),
	}

	-- Create character highlight (occluded, use custom Nen color or white)
	local highlight = Instance.new("Highlight")
	highlight.Name = "NenAuraHighlight"
	highlight.Adornee = character
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.FillTransparency = 1
	highlight.OutlineTransparency = 0.5
	-- Use custom Nen color if available
	local highlightColor = customNenColor or Color3.new(1, 1, 1)
	highlight.FillColor = highlightColor
	highlight.OutlineColor = highlightColor
	highlight.Parent = character
	table.insert(self.ActiveAuraVFX, highlight)

	-- Fade in the highlight outline
	local highlightTweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	highlight.OutlineTransparency = 1
	local highlightTween = TweenService:Create(highlight, highlightTweenInfo, {OutlineTransparency = 0.5})
	highlightTween:Play()

	-- Helper to apply Nen color and fade in a cloned VFX
	local function processClonedVFX(clone: Instance)
		-- Apply custom Nen color to white effects with variation
		if customNenColor then
			applyNenColorToEffects(clone, customNenColor, true)
		end

		-- Fade in particle emitters
		if clone:IsA("ParticleEmitter") then
			fadeInParticleEmitter(clone, 0.5)
		end
		for _, descendant in clone:GetDescendants() do
			if descendant:IsA("ParticleEmitter") then
				fadeInParticleEmitter(descendant, 0.5)
			end
		end
	end

	if abilityName == "Ten" or abilityName == "En" then
		-- Ten/En: Clone Limbs part per limb, parent under character, weld with Motor6D
		-- Only alter Size to match each limb. Bottom-to-top stagger.
		local tenFolder = aurasFolder:FindFirstChild("Ten")
		if not tenFolder then return end

		local limbsTemplate = tenFolder:FindFirstChild("Limbs")
		if not limbsTemplate or not limbsTemplate:IsA("BasePart") then return end

		-- R6 body parts ordered bottom-to-top for staggered transition (no Head)
		local limbOrder = {
			{ name = "Left Leg",  delay = 0.0 },
			{ name = "Right Leg", delay = 0.05 },
			{ name = "Torso",     delay = 0.15 },
			{ name = "Left Arm",  delay = 0.25 },
			{ name = "Right Arm", delay = 0.30 },
		}

		for _, limbInfo in ipairs(limbOrder) do
			local part = character:FindFirstChild(limbInfo.name)
			if not part then continue end

			task.delay(limbInfo.delay, function()
				-- Abort if ability changed during stagger
				if self.CurrentAbility ~= abilityName then return end

				local clone = limbsTemplate:Clone()
				clone.Name = "TenAura_" .. limbInfo.name
				clone.CanCollide = false
				clone.Massless = true

				-- Torso needs more coverage than limbs
				local sizeOffset = limbInfo.name == "Torso"
					and Vector3.new(1.2, 1.2, 1.2)
					or Vector3.new(0.8, 0.8, 0.8)
				clone.Size = part.Size + sizeOffset

				-- Set the part color to the player's nen color
				local auraColor = customNenColor or Color3.fromRGB(100, 200, 255)
				clone.Color = auraColor

				-- Set VertexColor on SpecialMesh to match nen color
				for _, desc in clone:GetDescendants() do
					if desc:IsA("SpecialMesh") then
						desc.VertexColor = Vector3.new(auraColor.R, auraColor.G, auraColor.B)
					end
				end

				-- Create Motor6D to weld to limb
				local motor = Instance.new("Motor6D")
				motor.Name = "TenAuraMotor"
				motor.Part0 = part
				motor.Part1 = clone
				motor.Parent = clone

				local visualsFolder = workspace:FindFirstChild("World") and workspace.World:FindFirstChild("Visuals")
				clone.Parent = visualsFolder or workspace

				-- Apply Nen color to descendant effects (particles, etc.)
				if customNenColor then
					applyNenColorToEffects(clone, customNenColor, true)
				end

				-- Fade in any descendant ParticleEmitters
				for _, descendant in clone:GetDescendants() do
					if descendant:IsA("ParticleEmitter") then
						fadeInParticleEmitter(descendant, 0.4)
					end
				end

				table.insert(self.ActiveAuraVFX, clone)
			end)
		end

	elseif abilityName == "Ren" or abilityName == "Gyo" then
		-- Ren/Gyo: Clone Aura part and keep at character's feet, centered
		local renFolder = aurasFolder:FindFirstChild("Ren")
		if not renFolder then return end

		local auraTemplate = renFolder:FindFirstChild("Aura")
		if not auraTemplate then return end

		local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
		if not humanoidRootPart then return end

		local clone = auraTemplate:Clone()
		clone.Name = "RenAura"
		clone.CanCollide = false
		clone.Anchored = true

		-- Calculate feet offset (HumanoidRootPart center is ~3 studs above feet in R6)
		local leftLeg = character:FindFirstChild("Left Leg")
		local legHeight = leftLeg and leftLeg.Size.Y or 2
		local feetOffset = -(humanoidRootPart.Size.Y / 2 + legHeight)

		-- Position at feet, flat on the ground (only use Y rotation, no pitch/roll)
		local pos = humanoidRootPart.Position + Vector3.new(0, feetOffset, 0)
		local _, yRot, _ = humanoidRootPart.CFrame:ToEulerAnglesYXZ()
		clone.CFrame = CFrame.new(pos) * CFrame.Angles(0, yRot, 0)
		clone.Parent = workspace.Terrain

		-- Apply Nen color
		if customNenColor then
			applyNenColorToEffects(clone, customNenColor, true)
		end

		-- Fade in
		processClonedVFX(clone)

		table.insert(self.ActiveAuraVFX, clone)

		-- Follow character every frame (keep flat, only Y rotation)
		local followConnection = RunService.RenderStepped:Connect(function()
			if not clone or not clone.Parent then return end
			if not humanoidRootPart or not humanoidRootPart.Parent then return end
			local feetPos = humanoidRootPart.Position + Vector3.new(0, feetOffset, 0)
			local _, yAngle, _ = humanoidRootPart.CFrame:ToEulerAnglesYXZ()
			clone.CFrame = CFrame.new(feetPos) * CFrame.Angles(0, yAngle, 0)
		end)

		-- Clean up follow connection when clone is destroyed
		clone.Destroying:Connect(function()
			followConnection:Disconnect()
		end)

	elseif abilityName == "Zetsu" or abilityName == "Ken" then
		-- Zetsu/Ken: Check if there's a Zetsu folder
		local zetsuFolder = aurasFolder:FindFirstChild("Zetsu")
		if zetsuFolder then
			local allVFX = zetsuFolder:FindFirstChild("All")
			if allVFX then
				for _, part in pairs(bodyParts) do
					if part then
						for _, vfx in allVFX:GetChildren() do
							local clone = vfx:Clone()
							clone.Parent = part
							table.insert(self.ActiveAuraVFX, clone)
							processClonedVFX(clone)
						end
					end
				end
			end
		end

	elseif abilityName == "Hatsu" or abilityName == "Ryu" then
		-- Hatsu/Ryu: Check if there's a Hatsu folder
		local hatsuFolder = aurasFolder:FindFirstChild("Hatsu")
		if hatsuFolder then
			local allVFX = hatsuFolder:FindFirstChild("All")
			if allVFX then
				for _, part in pairs(bodyParts) do
					if part then
						for _, vfx in allVFX:GetChildren() do
							local clone = vfx:Clone()
							clone.Parent = part
							table.insert(self.ActiveAuraVFX, clone)
							processClonedVFX(clone)
						end
					end
				end
			end
		end
	end
end

-- Remove all aura VFX
local function removeAuraVFX()
	for _, vfx in ipairs(self.ActiveAuraVFX) do
		if vfx and vfx.Parent then
			vfx:Destroy()
		end
	end
	self.ActiveAuraVFX = {}

	-- Safety: destroy any orphaned aura parts
	local player = Players.LocalPlayer
	local character = player and player.Character
	if character then
		for _, child in character:GetChildren() do
			if child.Name == "NenAuraHighlight" then
				child:Destroy()
			end
		end
	end
	local visualsFolder = workspace:FindFirstChild("World") and workspace.World:FindFirstChild("Visuals")
	if visualsFolder then
		for _, child in visualsFolder:GetChildren() do
			if child.Name:find("^TenAura_") then
				child:Destroy()
			end
		end
	end
	for _, child in workspace.Terrain:GetChildren() do
		if child.Name == "RenAura" then
			child:Destroy()
		end
	end
end

-- Screen shake effect when entering nen mode (increased intensity)
local function playScreenShake(intensity: number?, duration: number?)
	local shakeIntensity = intensity or 0.35 -- Increased from 0.15
	local shakeDuration = duration or 0.5 -- Increased from 0.3
	local camera = workspace.CurrentCamera
	if not camera then return end

	local startTime = os.clock()

	local shakeConnection
	shakeConnection = RunService.RenderStepped:Connect(function()
		local elapsed = os.clock() - startTime
		if elapsed >= shakeDuration then
			shakeConnection:Disconnect()
			return
		end

		-- Decay the shake over time with easing
		local progress = elapsed / shakeDuration
		local decay = 1 - (progress * progress) -- Quadratic decay for snappier feel

		local currentIntensity = shakeIntensity * decay

		-- Random offset for shake with some directional bias
		local offsetX = (math.random() - 0.5) * 2 * currentIntensity
		local offsetY = (math.random() - 0.5) * 2 * currentIntensity
		local offsetZ = (math.random() - 0.5) * currentIntensity * 0.3 -- Slight roll

		-- Apply shake as rotation offset
		camera.CFrame = camera.CFrame * CFrame.Angles(
			math.rad(offsetY),
			math.rad(offsetX),
			math.rad(offsetZ)
		)
	end)
end

-- Emit Ground VFX at player's feet
local function emitGroundVFX()
	local player = Players.LocalPlayer
	if not player then return end
	local character = player.Character
	if not character then return end

	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then return end

	-- Find Zetsu VFX folder in ReplicatedStorage.Assets.VFX
	local assetsFolder = ReplicatedStorage:FindFirstChild("Assets")
	if not assetsFolder then return end

	local vfxFolder = assetsFolder:FindFirstChild("VFX")
	if not vfxFolder then return end

	local zetsuFolder = vfxFolder:FindFirstChild("Zetsu")
	if not zetsuFolder then return end

	local groundVFX = zetsuFolder:FindFirstChild("Ground")
	if not groundVFX then return end

	local groundClone = groundVFX:Clone()

	-- Position at player's feet (below HumanoidRootPart)
	local feetOffset = -3
	local groundPosition = humanoidRootPart.CFrame * CFrame.new(0, feetOffset, 0) * CFrame.Angles(0,0,math.rad(90))

	if groundClone:IsA("Model") then
		groundClone:PivotTo(groundPosition)
	elseif groundClone:IsA("BasePart") then
		groundClone.CFrame = groundPosition
	end

	groundClone.Parent = workspace.Terrain
	EmitModule.emit(groundClone)

	-- Clean up after effect
	task.delay(8, function()
		if groundClone and groundClone.Parent then
			groundClone:Destroy()
		end
	end)
end

-- Play Nen mode animation with startup frame timing
local function playNenAnimation(abilityName: string, onStartupFrame: () -> ())
	local player = Players.LocalPlayer
	if not player then return end
	local character = player.Character
	if not character then return end

	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid then return end

	local animator = humanoid:FindFirstChild("Animator")
	if not animator then return end

	-- Stop any existing Nen animation
	for animName, track in pairs(self.ActiveAnimations) do
		if track and track.IsPlaying then
			track:Stop(0.1)
		end
	end
	self.ActiveAnimations = {}

	-- Get the base ability name for animation lookup (advanced abilities use base animation)
	local baseAbilityName = abilityName
	if abilityName == "Gyo" then baseAbilityName = "Ren"
	elseif abilityName == "Ken" then baseAbilityName = "Zetsu"
	elseif abilityName == "Ryu" then baseAbilityName = "Hatsu"
	elseif abilityName == "En" then baseAbilityName = "Ten"
	end

	-- Find the animation in ReplicatedStorage.Assets.Animations.Nen
	local assetsFolder = ReplicatedStorage:FindFirstChild("Assets")
	if not assetsFolder then
		warn("[NenBasics] Assets folder not found")
		return
	end

	local animationsFolder = assetsFolder:FindFirstChild("Animations")
	if not animationsFolder then
		warn("[NenBasics] Animations folder not found")
		return
	end

	local nenAnimationsFolder = animationsFolder:FindFirstChild("Nen")
	if not nenAnimationsFolder then
		warn("[NenBasics] Nen animations folder not found at Assets.Animations.Nen")
		return
	end

	local animationInstance = nenAnimationsFolder:FindFirstChild(baseAbilityName)
	if not animationInstance or not animationInstance:IsA("Animation") then
		warn("[NenBasics] Animation not found for: " .. baseAbilityName)
		return
	end

	-- Load and play the animation
	local animTrack = animator:LoadAnimation(animationInstance)
	animTrack.Priority = Enum.AnimationPriority.Action2
	animTrack:Play(0.1)
	emitGroundVFX()

	self.ActiveAnimations[abilityName] = animTrack

	-- Get startup frame timing
	local startupFrame = AnimationStartupFrames[abilityName] or AnimationStartupFrames[baseAbilityName] or 30
	local startupTime = startupFrame / ANIMATION_FPS

	-- Use RenderStepped for precise timing based on animation's actual TimePosition
	local startupFired = false
	local startupConnection: RBXScriptConnection? = nil
	startupConnection = RunService.RenderStepped:Connect(function()
		if not animTrack or not animTrack.IsPlaying then
			if startupConnection then
				startupConnection:Disconnect()
			end
			startupConnection = nil
			return
		end

		-- Check if we've reached or passed the startup time
		if not startupFired and animTrack.TimePosition >= startupTime then
			startupFired = true
			if startupConnection then
				startupConnection:Disconnect()
			end
			startupConnection = nil
			if self.CurrentAbility == abilityName and onStartupFrame then
				onStartupFrame()
			end
		end
	end)

	-- Handle animation end
	animTrack.Stopped:Once(function()
		if self.ActiveAnimations[abilityName] == animTrack then
			self.ActiveAnimations[abilityName] = nil
		end
	end)

	return animTrack
end

-- Stop all Nen animations
local function stopNenAnimations()
	for animName, track in pairs(self.ActiveAnimations) do
		if track and track.IsPlaying then
			track:Stop(0.2)
		end
	end
	self.ActiveAnimations = {}
end

-- Reset state (called when nen is exhausted from server)
InputModule.ResetState = function()
	self.NenActive = false
	self.CurrentAbility = nil
	self.LastSecondaryKey = nil
	self.LastSecondaryTime = 0

	-- Stop listening for secondary keys
	if secondaryKeyConnection then
		secondaryKeyConnection:Disconnect()
		secondaryKeyConnection = nil
	end

	-- Stop sounds, animations, and remove VFX
	stopNenSounds()
	stopNenAnimations()
	removeAuraVFX()

	-- Also stop En sphere if active
	local EnInput = require(script.Parent.En)
	if EnInput and EnInput.IsEnActive and EnInput.IsEnActive() then
		EnInput.StopEn(require(ReplicatedStorage.Client))
	end

	print("[NenBasics] State reset due to exhaustion")
end

local function handleSecondaryKey(input, gameProcessed)
	if gameProcessed then return end
	if not self.NenActive then return end
	if input.UserInputState ~= Enum.UserInputState.Begin then return end

	local keyCode = input.KeyCode

	-- Check if this is a valid secondary key
	if not BasicAbilities[keyCode] then return end

	local currentTime = os.clock()
	local abilityToActivate = nil

	-- Check if pressing same key again within 0.5 seconds for advanced version
	if self.LastSecondaryKey == keyCode and (currentTime - self.LastSecondaryTime) < 0.5 then
		-- Upgrade to advanced version (or stay on advanced if already there)
		local advancedAbility = AdvancedAbilities[keyCode]
		abilityToActivate = advancedAbility
		self.LastSecondaryKey = nil -- Reset to prevent triple-press
	else
		-- First press or different key - activate basic version
		local basicAbility = BasicAbilities[keyCode]
		abilityToActivate = basicAbility
		self.LastSecondaryKey = keyCode
		self.LastSecondaryTime = currentTime
	end

	-- Only update if ability changed
	if abilityToActivate and abilityToActivate ~= self.CurrentAbility then
		-- Check mode switch cooldown
		if self.CurrentAbility and (currentTime - self.LastModeSwitchTime) < MODE_SWITCH_COOLDOWN then
			local remainingCooldown = MODE_SWITCH_COOLDOWN - (currentTime - self.LastModeSwitchTime)
			warn(string.format("[NenBasics] Mode switch on cooldown. Wait %.1f seconds.", remainingCooldown))
			-- TODO: Show UI notification for cooldown
			return
		end

		-- Check requirements for advanced abilities
		local meetsReqs, errorMsg = meetsAbilityRequirements(abilityToActivate)
		if not meetsReqs then
			warn("[NenBasics] Cannot activate " .. abilityToActivate .. ": " .. (errorMsg or "Requirements not met"))
			-- TODO: Show UI notification for requirements
			return
		end

		-- Stop previous ability's sounds/VFX/animations
		if self.CurrentAbility then
			stopNenSounds()
			stopNenAnimations()
			removeAuraVFX()
		end

		self.CurrentAbility = abilityToActivate
		self.LastModeSwitchTime = currentTime

		-- Send to server
		local Bridges = require(ReplicatedStorage.Modules.Bridges)
		print("[NenBasics] Activating:", abilityToActivate)
		Bridges.NenAbility:Fire({
			action = "activate",
			abilityName = abilityToActivate,
		})

		-- Play animation with startup frame timing
		-- All effects (sounds, VFX, indicator, screen shake) trigger at the startup frame
		playNenAnimation(abilityToActivate, function()
			-- This fires at the startup frame (when the "burst" happens)
			-- Update nen indicator at startup frame
			local StatsInterface = require(ReplicatedStorage.Client.Interface.Stats)
			if StatsInterface.nenIndicatorData and StatsInterface.nenIndicatorData.setAbility then
				StatsInterface.nenIndicatorData.setAbility(abilityToActivate)
			end

			-- Play sounds at startup frame
			playNenSounds(abilityToActivate)

			-- Apply VFX at startup frame
			applyAuraVFX(abilityToActivate)

			-- Emit ground VFX at startup frame

			-- Screen shake at startup frame
			playScreenShake(0.4, 0.6)
		end)
	end
end

InputModule.InputBegan = function()
	-- Don't activate if loading screen is active
	if _G.LoadingScreenActive then
		return
	end

	-- Toggle Ten on/off (C key directly activates Ten)
	self.NenActive = not self.NenActive

	if self.NenActive then
		print("[NenBasics] Ten activated")

		-- Set Ten as current ability immediately
		self.CurrentAbility = "Ten"
		self.LastModeSwitchTime = os.clock()

		-- Start listening for secondary keys (B/G/H for other abilities)
		if not secondaryKeyConnection then
			secondaryKeyConnection = UserInputService.InputBegan:Connect(handleSecondaryKey)
		end

		-- Send Ten activation to server
		local Bridges = require(ReplicatedStorage.Modules.Bridges)
		Bridges.NenAbility:Fire({
			action = "activate",
			abilityName = "Ten",
		})

		-- Play Ten animation with startup frame timing
		playNenAnimation("Ten", function()
			-- Update nen indicator at startup frame
			local StatsInterface = require(ReplicatedStorage.Client.Interface.Stats)
			if StatsInterface.nenIndicatorData and StatsInterface.nenIndicatorData.setAbility then
				StatsInterface.nenIndicatorData.setAbility("Ten")
			end

			-- Play sounds at startup frame
			playNenSounds("Ten")

			-- Apply VFX at startup frame
			applyAuraVFX("Ten")

			-- Screen shake at startup frame
			playScreenShake(0.4, 0.6)
		end)
	else
		print("[NenBasics] Ten deactivated")
		self.LastSecondaryKey = nil

		-- Stop listening for secondary keys
		if secondaryKeyConnection then
			secondaryKeyConnection:Disconnect()
			secondaryKeyConnection = nil
		end

		-- Deactivate any active ability when exiting
		local abilityToDeactivate = self.CurrentAbility or "Ten"
		self.CurrentAbility = nil

		local Bridges = require(ReplicatedStorage.Modules.Bridges)
		Bridges.NenAbility:Fire({
			action = "deactivate",
			abilityName = abilityToDeactivate,
		})

		-- Update nen indicator
		local StatsInterface = require(ReplicatedStorage.Client.Interface.Stats)
		if StatsInterface.nenIndicatorData and StatsInterface.nenIndicatorData.setAbility then
			StatsInterface.nenIndicatorData.setAbility(nil)
		end

		-- Stop sounds, animations, and remove VFX
		stopNenSounds()
		stopNenAnimations()
		removeAuraVFX()
	end
end

InputModule.InputEnded = function()
	-- No action on key release - C is a toggle now
end

InputModule.InputChanged = function()
	-- No continuous input handling needed
end

return InputModule
