--!strict
-- Client-side Nen Visual Effects Handler
-- Creates visual effects for active Nen abilities

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NenAbilities = require(ReplicatedStorage.Modules.NenAbilities)

local NenVisualEffects = {}
NenVisualEffects.__index = NenVisualEffects

-- Active aura effects per character
local activeEffects = {}

-- Create aura effect for character
function NenVisualEffects.CreateAuraEffect(character: Model, abilityName: string)
	-- Clean up any existing effect first
	NenVisualEffects.RemoveAuraEffect(character)

	local abilityData = NenAbilities[abilityName]
	if not abilityData then
		return
	end

	local visualEffect = abilityData.effects.visualEffect
	if not visualEffect then
		return
	end

	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then
		return
	end

	local effectData = {
		character = character,
		abilityName = abilityName,
		particles = {},
		highlights = {},
		connections = {},
	}

	-- Apply visual effect based on type
	if visualEffect == "FaintAuraShimmer" then
		-- Ten: Faint aura shimmer
		local highlight = Instance.new("Highlight")
		highlight.Name = "NenAura_Ten"
		highlight.Adornee = character
		highlight.FillColor = Color3.fromRGB(150, 200, 255)
		highlight.FillTransparency = 0.85
		highlight.OutlineColor = Color3.fromRGB(100, 150, 255)
		highlight.OutlineTransparency = 0.7
		highlight.Parent = character
		table.insert(effectData.highlights, highlight)

	elseif visualEffect == "IntensePulsingAura" then
		-- Ren: Intense, pulsing aura
		local highlight = Instance.new("Highlight")
		highlight.Name = "NenAura_Ren"
		highlight.Adornee = character
		highlight.FillColor = Color3.fromRGB(255, 100, 100)
		highlight.FillTransparency = 0.5
		highlight.OutlineColor = Color3.fromRGB(255, 50, 50)
		highlight.OutlineTransparency = 0.3
		highlight.Parent = character
		table.insert(effectData.highlights, highlight)

		-- Pulsing animation
		local pulseTime = 0
		local connection = RunService.RenderStepped:Connect(function(dt)
			pulseTime = pulseTime + dt
			local pulse = (math.sin(pulseTime * 5) + 1) / 2
			highlight.FillTransparency = 0.3 + (pulse * 0.3)
			highlight.OutlineTransparency = 0.1 + (pulse * 0.3)
		end)
		table.insert(effectData.connections, connection)

		-- Add particles for dramatic effect
		local attachment = Instance.new("Attachment")
		attachment.Name = "NenAuraAttachment"
		attachment.Parent = humanoidRootPart

		local particleEmitter = Instance.new("ParticleEmitter")
		particleEmitter.Name = "RenAuraParticles"
		particleEmitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
		particleEmitter.Color = ColorSequence.new(Color3.fromRGB(255, 100, 100))
		particleEmitter.Size = NumberSequence.new(1, 2)
		particleEmitter.Transparency = NumberSequence.new(0.7, 1)
		particleEmitter.Lifetime = NumberRange.new(0.5, 1)
		particleEmitter.Rate = 20
		particleEmitter.Speed = NumberRange.new(2, 4)
		particleEmitter.SpreadAngle = Vector2.new(360, 360)
		particleEmitter.Parent = attachment
		table.insert(effectData.particles, particleEmitter)

	elseif visualEffect == "Translucent" then
		-- Zetsu: Character becomes translucent
		for _, part in character:GetDescendants() do
			if part:IsA("BasePart") then
				part.Transparency = math.min(1, part.Transparency + 0.7)
			end
		end

	elseif visualEffect == "GlowingEyes" then
		-- Gyo: Eyes glow
		local head = character:FindFirstChild("Head")
		if head then
			local pointLight = Instance.new("PointLight")
			pointLight.Name = "GyoEyeGlow"
			pointLight.Color = Color3.fromRGB(100, 200, 255)
			pointLight.Brightness = 2
			pointLight.Range = 10
			pointLight.Parent = head
			table.insert(effectData.particles, pointLight)
		end

	elseif visualEffect == "InvisibleAura" then
		-- In: Subtle aura (only visible to user)
		local highlight = Instance.new("Highlight")
		highlight.Name = "NenAura_In"
		highlight.Adornee = character
		highlight.FillColor = Color3.fromRGB(200, 100, 255)
		highlight.FillTransparency = 0.9
		highlight.OutlineColor = Color3.fromRGB(150, 50, 255)
		highlight.OutlineTransparency = 0.85
		highlight.Parent = character
		table.insert(effectData.highlights, highlight)

	elseif visualEffect == "TransparentDome" then
		-- En: Transparent dome effect
		local sphere = Instance.new("Part")
		sphere.Name = "EnDome"
		sphere.Shape = Enum.PartType.Ball
		sphere.Size = Vector3.new(50, 50, 50) -- Will scale with mastery
		sphere.Transparency = 0.95
		sphere.Color = Color3.fromRGB(100, 200, 255)
		sphere.Material = Enum.Material.ForceField
		sphere.CanCollide = false
		sphere.Anchored = true
		sphere.CFrame = humanoidRootPart.CFrame
		sphere.Parent = workspace

		-- Follow character
		local connection = RunService.Heartbeat:Connect(function()
			if sphere.Parent and humanoidRootPart.Parent then
				sphere.CFrame = humanoidRootPart.CFrame
			end
		end)
		table.insert(effectData.connections, connection)
		table.insert(effectData.particles, sphere)

	elseif visualEffect == "GlowingWeapon" then
		-- Shu: Weapon glows
		local weapon = character:FindFirstChildWhichIsA("Tool")
		if weapon then
			local highlight = Instance.new("Highlight")
			highlight.Name = "ShuWeaponGlow"
			highlight.Adornee = weapon
			highlight.FillColor = Color3.fromRGB(255, 255, 100)
			highlight.FillTransparency = 0.5
			highlight.OutlineColor = Color3.fromRGB(255, 200, 0)
			highlight.OutlineTransparency = 0.3
			highlight.Parent = weapon
			table.insert(effectData.highlights, highlight)
		end

	elseif visualEffect == "MassiveAuraConcentration" then
		-- Ko: Massive aura concentration on one limb
		local rightArm = character:FindFirstChild("Right Arm") or character:FindFirstChild("RightHand")
		if rightArm then
			local highlight = Instance.new("Highlight")
			highlight.Name = "KoAura"
			highlight.Adornee = rightArm
			highlight.FillColor = Color3.fromRGB(255, 255, 255)
			highlight.FillTransparency = 0.2
			highlight.OutlineColor = Color3.fromRGB(200, 200, 255)
			highlight.OutlineTransparency = 0
			highlight.Parent = rightArm
			table.insert(effectData.highlights, highlight)
		end

	elseif visualEffect == "StableAuraCoating" then
		-- Ken: Stable, even aura coating
		local highlight = Instance.new("Highlight")
		highlight.Name = "NenAura_Ken"
		highlight.Adornee = character
		highlight.FillColor = Color3.fromRGB(200, 200, 255)
		highlight.FillTransparency = 0.7
		highlight.OutlineColor = Color3.fromRGB(150, 150, 255)
		highlight.OutlineTransparency = 0.5
		highlight.Parent = character
		table.insert(effectData.highlights, highlight)

	elseif visualEffect == "FlowingAura" then
		-- Ryu: Flowing aura (dynamic, shifts between limbs)
		local highlight = Instance.new("Highlight")
		highlight.Name = "NenAura_Ryu"
		highlight.Adornee = character
		highlight.FillColor = Color3.fromRGB(100, 255, 200)
		highlight.FillTransparency = 0.75
		highlight.OutlineColor = Color3.fromRGB(50, 255, 150)
		highlight.OutlineTransparency = 0.6
		highlight.Parent = character
		table.insert(effectData.highlights, highlight)

		-- Flowing animation (color shifts)
		local flowTime = 0
		local connection = RunService.RenderStepped:Connect(function(dt)
			flowTime = flowTime + dt
			local hue = (flowTime * 0.5) % 1
			local color = Color3.fromHSV(hue, 0.7, 1)
			highlight.FillColor = color
			highlight.OutlineColor = color
		end)
		table.insert(effectData.connections, connection)
	end

	activeEffects[character] = effectData
end

-- Remove aura effect from character
function NenVisualEffects.RemoveAuraEffect(character: Model)
	local effectData = activeEffects[character]
	if not effectData then
		return
	end

	-- Clean up particles
	for _, particle in effectData.particles do
		if particle.Parent then
			particle:Destroy()
		end
	end

	-- Clean up highlights
	for _, highlight in effectData.highlights do
		if highlight.Parent then
			highlight:Destroy()
		end
	end

	-- Disconnect connections
	for _, connection in effectData.connections do
		connection:Disconnect()
	end

	-- Restore transparency for Zetsu
	if effectData.abilityName == "Zetsu" then
		for _, part in character:GetDescendants() do
			if part:IsA("BasePart") and part.Transparency > 0.7 then
				part.Transparency = math.max(0, part.Transparency - 0.7)
			end
		end
	end

	activeEffects[character] = nil
end

-- Get active effect for character
function NenVisualEffects.GetActiveEffect(character: Model)
	return activeEffects[character]
end

return NenVisualEffects
