-- Services
local Players = game:GetService("Players")
local Replicated = game:GetService("ReplicatedStorage")

-- Modules
local Utilities = require(Replicated.Modules.Utilities)
local Library = require(Replicated.Modules.Library)
local Debris = Utilities.Debris
local AB = require(Replicated.Modules.Utils.AymanBolt)

-- Variables
local Player = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local CamShake = require(Replicated.Modules.Utils.CamShake)
local EmitModule = require(game.ReplicatedStorage.Modules.Utils.EmitModule)
local TweenService = game:GetService("TweenService")

local Misc = {}

function Misc.DoEffect(Character: Model, FX: Part?)
	local Effect = FX:Clone()

	if Effect:IsA("Part") then
		Effect.CFrame = Character.HumanoidRootPart
		Misc.Emit(Effect)
	elseif Effect:IsA("Attachment") then
		Effect.Parent = Character.HumanoidRootPart
		Misc.Emit(Effect)
	end
end

function Misc.Emit(Object: Part?, Descendants: boolean)
	local DebrisTimer = 0

	for _, v in pairs(Object:GetDescendants()) do
		if v:IsA("ParticleEmitter") then
			if v.Lifetime.Max > DebrisTimer then
				DebrisTimer = v.Lifetime.Max
			end
		end
	end

	if Descendants then
		for _, Emitter in pairs(Object:GetDescendants()) do
			if Emitter:IsA("ParticleEmitter") then
				task.delay(Emitter:GetAttribute("EmitDelay"), function()
					if Emitter:GetAttribute("EmitDuration") and Emitter:GetAttribute("EmitDuration") > 0 then
						Emitter.Enabled = true
						task.wait(Emitter:GetAttribute("EmitDuration"))
						Emitter.Enabled = false
					else
						Emitter:Emit(Emitter:GetAttribute("EmitCount"))
					end
				end)
			end
		end
	else
		for _, Emitter in pairs(Object:GetChildren()) do
			if Emitter:IsA("ParticleEmitter") then
				task.delay(Emitter:GetAttribute("EmitDelay"), function()
					if Emitter:GetAttribute("EmitDuration") and Emitter:GetAttribute("EmitDuration") > 0 then
						Emitter.Enabled = true
						task.wait(Emitter:GetAttribute("EmitDuration"))
						Emitter.Enabled = false
					else
						Emitter:Emit(Emitter:GetAttribute("EmitCount"))
					end
				end)
			end
		end
	end

	Debris:AddItem(Object, DebrisTimer)

	return DebrisTimer
end

function Misc.EnableStatus(Character: Model, FXName: string, FXDuration: number)
	local humanoidRootPart = Character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then
		return
	end

	local rootAttachment = humanoidRootPart:FindFirstChild("RootAttachment")
	if not rootAttachment then
		rootAttachment = Instance.new("Attachment")
		rootAttachment.Name = "RootAttachment"
		rootAttachment.Parent = humanoidRootPart
	end

	local FX = Replicated.Assets.VFX[FXName]:Clone()
	FX.CFrame = humanoidRootPart.CFrame
	FX.Anchored = false
	FX.CanCollide = false
	FX.CanQuery = false
	FX.Transparency = 1
	FX.Parent = workspace.World.Visuals
	Misc.Emit(FX)

	for _, v in pairs(FX:GetDescendants()) do
		if v:IsA("ParticleEmitter") then
			v.Enabled = true
			v.Parent = rootAttachment
		end
	end

	task.delay(FXDuration, function()
		for _, v in pairs(rootAttachment:GetChildren()) do
			if v:IsA("ParticleEmitter") then
				v.Enabled = false
			end
		end
	end)

	Debris:AddItem(FX, FXDuration + 0.25)
end

function Misc.CameraShake(State)
	camShake:Shake(CameraShaker.Presets[State])
end

-- Hyperarmor visual indicator system
function Misc.StartHyperarmor(Character: Model)
	if not Character or not Character:FindFirstChild("HumanoidRootPart") then
		return
	end

	-- Remove any existing hyperarmor highlight
	local existingHighlight = Character:FindFirstChild("HyperarmorHighlight")
	if existingHighlight then
		existingHighlight:Destroy()
	end

	-- Create white highlight for hyperarmor
	local highlight = Instance.new("Highlight")
	highlight.Name = "HyperarmorHighlight"
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.FillColor = Color3.fromRGB(255, 255, 255) -- Start white
	highlight.OutlineColor = Color3.fromRGB(200, 200, 200)
	highlight.FillTransparency = 0.3
	highlight.OutlineTransparency = 0
	highlight.Parent = Character

	---- print("Hyperarmor visual started for", Character.Name)
end

function Misc.UpdateHyperarmor(Character: Model, damagePercent: number)
	if not Character then
		return
	end

	local highlight = Character:FindFirstChild("HyperarmorHighlight")
	if not highlight then
		return
	end

	-- Interpolate color from white (0% damage) to red (100% damage)
	local white = Color3.fromRGB(255, 255, 255)
	local red = Color3.fromRGB(255, 0, 0)
	local currentColor = white:Lerp(red, damagePercent)

	-- Update highlight color
	highlight.FillColor = currentColor
	highlight.OutlineColor = currentColor

	-- Increase intensity as damage increases
	highlight.FillTransparency = 0.3 - (damagePercent * 0.2) -- Gets more opaque as damage increases

	---- print(string.format("Hyperarmor visual updated for %s: %.0f%% damage (Color: R%.0f G%.0f B%.0f)",
	--Character.Name, damagePercent * 100, currentColor.R * 255, currentColor.G * 255, currentColor.B * 255))
end

function Misc.RemoveHyperarmor(Character: Model)
	if not Character then
		return
	end

	local highlight = Character:FindFirstChild("HyperarmorHighlight")
	if highlight then
		-- Fade out the highlight
		local TweenService = game:GetService("TweenService")
		local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
		local tween = TweenService:Create(highlight, tweenInfo, {
			FillTransparency = 1,
			OutlineTransparency = 1,
		})
		tween:Play()
		tween.Completed:Connect(function()
			highlight:Destroy()
		end)

		---- print("Hyperarmor visual removed for", Character.Name)
	end
end

-- Wall construction VFX for jail escape system (minimal - no alchemy effects)
function Misc.WallConstruct(position: Vector3, wallWidth: number, wallHeight: number, duration: number)
	-- Screen shake for nearby players as wall rises
	CamShake({
		Location = position,
		Magnitude = 2,
		Damp = 0.0002,
		Frequency = 15,
		Influence = Vector3.new(0.4, 0.6, 0.4),
		Falloff = 40,
	})
end

function Misc.DeconBolt(Character: Model, Position: Vector3 | Vector2)
	local hrp = Character:FindFirstChild("HumanoidRootPart")
	task.spawn(function()
		for _ = 1, 2 do
			AB.new(hrp.CFrame * CFrame.new(0, 0, -2), hrp.CFrame * CFrame.new(0, 0, -6.5), {
				PartCount = 10, -- self explanatory
				CurveSize0 = 5, -- self explanatory
				CurveSize1 = 5, -- self explanatory
				PulseSpeed = 11, -- how fast the bolts will be
				PulseLength = 1, -- how long each bolt is
				FadeLength = 0.25, -- self explanatory
				MaxRadius = 10, -- the zone of the bolts
				Thickness = 0.5, -- self explanatory
				Frequency = 0.85, -- how much it will zap around the less frequency (jitter amp)
				Color = Color3.fromRGB(36, 140, 185),
			})
			task.wait(0.065)
		end
	end)
end

function Misc.Teleport(Character: Model)
	local root = Character:FindFirstChild("HumanoidRootPart")

	local conjure = Replicated.Assets.VFX.TP.conjure:Clone()
	local CircleBreak = Replicated.Assets.VFX.TP.CircleBreak:Clone()
	local h = Replicated.Assets.VFX.TP.Highlight:Clone()
	local f = Replicated.Assets.VFX.TP.Highlight:Clone()
	conjure.Parent = workspace.World.Visuals
	CircleBreak.Parent = workspace.World.Visuals
	conjure.CFrame = root.CFrame * CFrame.new(0, -2.5, 0)
	CircleBreak.CFrame = root.CFrame * CFrame.new(0, -2.5, 0)

	EmitModule.emit(conjure)
	local transmuteSound = Replicated.Assets.SFX.FMAB.Transmute:Clone()
	transmuteSound.Volume = 2
	transmuteSound.Parent = root
	transmuteSound:Play()
	game:GetService("Debris"):AddItem(transmuteSound, transmuteSound.TimeLength)
	-- task.delay(0.05, function()
	-- 	-- for _, v in conjure:GetDescendants() do
	-- 	-- 	if v:IsA("ParticleEmitter") then
	-- 	-- 		local tween = TweenService:Create(
	-- 	-- 			v,
	-- 	-- 			TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	-- 	-- 			{ TimeScale = 0 }
	-- 	-- 		)
	-- 	-- 		tween:Play()
	-- 	-- 	end
	-- 	-- end
	-- 	task.delay(0.1, function()
	-- 		-- for _, v in conjure:GetDescendants() do
	-- 		-- 	if v:IsA("ParticleEmitter") then
	-- 		-- 		local tween = TweenService:Create(
	-- 		-- 			v,
	-- 		-- 			TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	-- 		-- 			{ TimeScale = 1 }
	-- 		-- 		)
	-- 		-- 		tween:Play()
	-- 		-- 	end
	-- 		-- end
	-- 		h.Parent = CircleBreak.Dome.End
	-- 		f.Parent = CircleBreak.Dome.Start
	-- 		EmitModule.emit(CircleBreak)
	-- 		-- for _, v in CircleBreak:GetDescendants() do
	-- 		-- 	if v:IsA("ParticleEmitter") then
	-- 		-- 		local tween = TweenService:Create(
	-- 		-- 			v,
	-- 		-- 			TweenInfo.new(0.01, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	-- 		-- 			{ TimeScale = 0 }
	-- 		-- 		)
	-- 		-- 		tween:Play()
	-- 		-- 	end
	-- 		-- end
	-- 		-- for _, v in CircleBreak:GetDescendants() do
	-- 		-- 	if v:IsA("ParticleEmitter") then
	-- 		-- 		local tween = TweenService:Create(
	-- 		-- 			v,
	-- 		-- 			TweenInfo.new(0.025, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	-- 		-- 			{ TimeScale = 1 }
	-- 		-- 		)
	-- 		-- 		tween:Play()
	-- 		-- 	end
	-- 		-- end
	-- 		CamShake({
	-- 			Location = root.Position,
	-- 			Magnitude = 5.5,
	-- 			Damp = 0.00005,
	-- 			Frequency = 35,
	-- 			Influence = Vector3.new(0.55, 1, 0.55),
	-- 			Falloff = 89,
	-- 		})
	-- 	end)
	-- end)
end

return Misc
