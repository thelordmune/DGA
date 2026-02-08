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

local Fusion = require(Replicated.Modules.Fusion)
local Children, scoped, peek, out = Fusion.Children, Fusion.scoped, Fusion.peek, Fusion.Out

local TInfo = TweenInfo.new(0.35, Enum.EasingStyle.Circular, Enum.EasingDirection.Out, 0)

local Misc = {}

-- Check if a model is inside any NpcRegistryCamera
local function isInNpcRegistryCamera(inst)
	if typeof(inst) ~= "Instance" then return false end
	local parent = inst.Parent
	while parent do
		if parent.Name == "NpcRegistryCamera" then
			return true
		end
		parent = parent.Parent
	end
	return false
end

-- Resolve Chrono NPC server model references to client clones
local function resolveChronoModel(model: Model?): Model?
	if not model or typeof(model) ~= "Instance" then return model end

	-- Player characters are never Chrono NPCs
	if model:IsA("Model") and Players:GetPlayerFromCharacter(model) then
		return model
	end

	if not model:IsA("Model") then return model end

	-- If the model is NOT inside a NpcRegistryCamera, it's a normal model (use as-is)
	if not isInNpcRegistryCamera(model) then
		return model
	end

	-- Model is inside a NpcRegistryCamera - find the client's own camera (tagged ClientOwned)
	local clientCamera = nil
	for _, child in workspace:GetChildren() do
		if child.Name == "NpcRegistryCamera" and child:IsA("Camera") and child:GetAttribute("ClientOwned") then
			clientCamera = child
			break
		end
	end

	-- Try ChronoId attribute
	local chronoId = model:GetAttribute("ChronoId")
	if chronoId and clientCamera then
		local clientClone = clientCamera:FindFirstChild(tostring(chronoId), true)
		if clientClone and clientClone:IsA("Model") then
			return clientClone
		end
	end

	-- Try by name
	if clientCamera and model.Name then
		local byName = clientCamera:FindFirstChild(model.Name, true)
		if byName and byName:IsA("Model") then
			return byName
		end
	end

	return model
end

function Misc.DoEffect(Character: Model, FX: Part?)
	Character = resolveChronoModel(Character)
	if not Character or not Character:FindFirstChild("HumanoidRootPart") then return end

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
	Character = resolveChronoModel(Character)
	if not Character then return end

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

local CameraShakePresets = {
	["Small"] = { Magnitude = 0.3, Damp = 0.01, Frequency = 20, Falloff = 50 },
	["RightSmall"] = { Magnitude = 0.2, Damp = 0.015, Frequency = 18, Falloff = 50, Influence = Vector3.new(0.5, 1, 0) },
	["Medium"] = { Magnitude = 0.6, Damp = 0.008, Frequency = 18, Falloff = 50 },
	["Large"] = { Magnitude = 1.0, Damp = 0.006, Frequency = 16, Falloff = 60 },
}

function Misc.CameraShake(State)
	local preset = CameraShakePresets[State]
	if not preset then return end

	local character = Player and Player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then return end

	local settings = table.clone(preset)
	settings.Location = character.HumanoidRootPart.Position
	CamShake(settings)
end

-- Hyperarmor visual indicator system
function Misc.StartHyperarmor(Character: Model)
	Character = resolveChronoModel(Character)
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
	Character = resolveChronoModel(Character)
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
	Character = resolveChronoModel(Character)
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
	Character = resolveChronoModel(Character)
	if not Character then return end
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
	Character = resolveChronoModel(Character)
	if not Character then return end
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

-- ============================================
-- QUEST/DIALOGUE FUNCTIONS (moved from Base.lua)
-- ============================================

-- Track active dialogue sessions to prevent duplicates
local activeDialogueSessions = {}

function Misc.Commence(Dialogue: { npc: Model, name: string, inrange: boolean, state: string })
	---- print("🎭 [Effects.Base] COMMENCE FUNCTION CALLED")
	---- print("📋 Dialogue data received:", Dialogue)

	-- Validate dialogue data
	if not Dialogue then
		---- print("❌ [Effects.Base] ERROR: No dialogue data provided!")
		return
	end

	if not Dialogue.npc then
		---- print("❌ [Effects.Base] ERROR: No NPC model in dialogue data!")
		return
	end

	if not Dialogue.name then
		---- print("❌ [Effects.Base] ERROR: No NPC name in dialogue data!")
		return
	end

	---- print("✅ [Effects.Base] Dialogue validation passed")
	---- print("🎯 [Effects.Base] NPC:", Dialogue.name, "| In Range:", Dialogue.inrange, "| State:", Dialogue.state)

	local npcId = Dialogue.npc:GetDebugId() -- Unique identifier for this NPC instance

	if Dialogue.inrange then
		-- Check if we already have an active session for this NPC
		if activeDialogueSessions[npcId] then
			---- print("⚠️ [Effects.Base] Dialogue session already active for", Dialogue.name, "- skipping")
			return
		end

		---- print("🎯 [Effects.Base] Player is in range, creating proximity UI...")
		activeDialogueSessions[npcId] = true

		-- Check if highlight already exists
		local highlight = Dialogue.npc:FindFirstChild("Highlight")
		if not highlight then
			---- print("✨ [Effects.Base] Creating new highlight for NPC")
			highlight = Instance.new("Highlight")
			highlight.Name = "Highlight"
			highlight.DepthMode = Enum.HighlightDepthMode.Occluded
			highlight.FillTransparency = 1
			highlight.OutlineTransparency = 1
			highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
			highlight.Parent = Dialogue.npc

			local hTween = TweenService:Create(highlight, TInfo, { OutlineTransparency = 0 })
			hTween:Play()
			---- print("🎬 [Effects.Base] Highlight tween started")
		else
			---- print("♻️ [Effects.Base] Highlight already exists, reusing it")
			-- Make sure it's visible
			if highlight.OutlineTransparency > 0.5 then
				local hTween = TweenService:Create(highlight, TInfo, { OutlineTransparency = 0 })
				hTween:Play()
			end
		end

		---- print("📦 [Effects.Base] Loading Fusion scope and Proximity component...")
		local scope = scoped(Fusion, {
			Proximity = require(Replicated.Client.Components.Proximity),
		})
		local start = scope:Value(false)
		---- print("✅ [Effects.Base] Fusion scope created successfully")

		local Target = scope:New("ScreenGui")({
			Name = "ScreenGui",
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
			Parent = Player.PlayerGui,
		})
		---- print("🖥️ [Effects.Base] ScreenGui created and parented to PlayerGui")

		local parent = Target

		---- print("🔗 [Effects.Base] Creating Proximity component...")
		scope:Proximity({
			begin = start,
			par = parent,
		})
		---- print("✅ [Effects.Base] Proximity component created")

		---- print("⏱️ [Effects.Base] Starting proximity animation sequence...")
		task.wait(0.3)
		---- print("🎬 [Effects.Base] Setting start to true")
		start:set(true)
		task.wait(2.5)
		---- print("🎬 [Effects.Base] Setting start to false")
		start:set(false)
		task.wait(0.5)
		---- print("🧹 [Effects.Base] Cleaning up scope")
		scope:doCleanup()

		-- Clear the active session
		activeDialogueSessions[npcId] = nil
		---- print("✅ [Effects.Base] Proximity effect complete")
	else
		---- print("🚫 [Effects.Base] Player not in range, removing highlight...")

		-- Clear any active session
		activeDialogueSessions[npcId] = nil

		local highlight = Dialogue.npc:FindFirstChild("Highlight")
		if highlight then
			---- print("✨ [Effects.Base] Found existing highlight, fading out...")
			local hTween = TweenService:Create(highlight, TInfo, { OutlineTransparency = 1 })
			hTween:Play()
			hTween.Completed:Connect(function()
				if highlight and highlight.Parent then
					highlight:Destroy()
					---- print("🗑️ [Effects.Base] Highlight destroyed")
				end
			end)
		else
			---- print("⚠️ [Effects.Base] No highlight found to remove")
		end
	end

	---- print("✅ [Effects.Base] COMMENCE FUNCTION COMPLETE")
end

function Misc.ScreenFadeWhiteOut()
	local PlayerGui = Player:WaitForChild("PlayerGui")

	-- Create or get the fade screen GUI
	local fadeScreen = PlayerGui:FindFirstChild("TeleportFadeScreen")
	if not fadeScreen then
		fadeScreen = Instance.new("ScreenGui")
		fadeScreen.Name = "TeleportFadeScreen"
		fadeScreen.DisplayOrder = 1000 -- High display order to be on top
		fadeScreen.IgnoreGuiInset = true
		fadeScreen.Parent = PlayerGui

		local fadeFrame = Instance.new("Frame")
		fadeFrame.Name = "FadeFrame"
		fadeFrame.Size = UDim2.new(1, 0, 1, 0)
		fadeFrame.Position = UDim2.new(0, 0, 0, 0)
		fadeFrame.BackgroundColor3 = Color3.new(1, 1, 1) -- White
		fadeFrame.BackgroundTransparency = 1
		fadeFrame.BorderSizePixel = 0
		fadeFrame.Parent = fadeScreen
	end

	local fadeFrame = fadeScreen.FadeFrame
	fadeFrame.BackgroundTransparency = 1

	-- Fade to white
	local fadeTween = TweenService:Create(
		fadeFrame,
		TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ BackgroundTransparency = 0 }
	)
	fadeTween:Play()
end

-- Screen fade from white back to normal
function Misc.ScreenFadeWhiteIn()
	local PlayerGui = Player:WaitForChild("PlayerGui")
	local fadeScreen = PlayerGui:FindFirstChild("TeleportFadeScreen")

	if fadeScreen then
		local fadeFrame = fadeScreen.FadeFrame

		-- Fade from white back to transparent
		local fadeTween = TweenService:Create(
			fadeFrame,
			TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ BackgroundTransparency = 1 }
		)
		fadeTween:Play()

		-- Clean up after fade completes
		fadeTween.Completed:Connect(function()
			task.wait(0.1)
			if fadeScreen and fadeScreen.Parent then
				fadeScreen:Destroy()
			end
		end)
	end
end

-- Truth Move - Gate of Truth sequence from FMA Brotherhood (CHAOTIC VERSION)
function Misc.TruthSequence(Character: Model, Quotes: {string}, TeleportPosition: Vector3?, Duration: number?)
	local PlayerGui = Player:WaitForChild("PlayerGui")
	local Lighting = game:GetService("Lighting")
	local totalDuration = Duration or 8

	-- Track if sequence is active for continuous effects
	local sequenceActive = true

	-- Create the Truth UI screen
	local truthScreen = Instance.new("ScreenGui")
	truthScreen.Name = "TruthScreen"
	truthScreen.DisplayOrder = 999
	truthScreen.IgnoreGuiInset = true
	truthScreen.Parent = PlayerGui

	-- Background that fades to white
	local background = Instance.new("Frame")
	background.Name = "Background"
	background.Size = UDim2.new(1, 0, 1, 0)
	background.BackgroundColor3 = Color3.new(1, 1, 1)
	background.BackgroundTransparency = 1
	background.BorderSizePixel = 0
	background.Parent = truthScreen

	-- Container for cryptic text
	local textContainer = Instance.new("Frame")
	textContainer.Name = "TextContainer"
	textContainer.Size = UDim2.new(1, 0, 1, 0)
	textContainer.BackgroundTransparency = 1
	textContainer.ClipsDescendants = false
	textContainer.Parent = truthScreen

	-- ═══════════════════════════════════════════════════════════════════════════
	-- WHISPERS SOUND - Plays looped while messages are on screen
	-- ═══════════════════════════════════════════════════════════════════════════
	local whispersSound
	local truthSFX = Replicated.Assets.SFX:FindFirstChild("Truth")
	if truthSFX then
		local whispers = truthSFX:FindFirstChild("Whispers")
		if whispers then
			whispersSound = whispers:Clone()
			whispersSound.Looped = true
			whispersSound.Parent = PlayerGui
			whispersSound:Play()
		end
	end

	-- CONTINUOUS SCREEN SHAKE - runs until teleport
	task.spawn(function()
		local shakeIntensity = 5
		while sequenceActive do
			-- Escalating shake intensity
			shakeIntensity = math.min(shakeIntensity + 0.5, 25)

			CamShake({
				Magnitude = shakeIntensity,
				Frequency = 20 + shakeIntensity,
				Damp = 0.01,
				Influence = Vector3.new(1.5, 1.5, 1),
				Location = Camera.CFrame.Position,
				Falloff = 200,
			})
			task.wait(0.3)
		end
	end)

	-- Use Sarpanch for all Truth text
	local fonts = {
		Enum.Font.Unknown, -- Will use FontFace below
	}

	-- Glitch characters
	local glitchChars = {"█", "▓", "▒", "░", "◊", "◆", "●", "○", "▲", "▼", "◀", "▶", "■", "□", "◈", "◉"}

	-- Function to create a CHAOTIC cryptic text label
	local function createChaoticText(text, posX, posY, textSize, delay)
		task.delay(delay, function()
			if not sequenceActive then return end

			local label = Instance.new("TextLabel")
			label.Name = "CrypticText"
			label.Size = UDim2.new(0, textSize * #text * 0.6, 0, textSize * 1.5)
			label.Position = UDim2.new(posX, 0, posY, 0)
			label.AnchorPoint = Vector2.new(0.5, 0.5)
			label.BackgroundTransparency = 1
			label.Text = ""
			label.TextColor3 = Color3.new(0, 0, 0) -- Black text
			label.TextStrokeColor3 = Color3.fromRGB(150, 50, 200) -- Purple stroke
			label.TextStrokeTransparency = 0
			label.FontFace = Font.new("rbxasset://fonts/families/Sarpanch.json") -- Sarpanch font
			label.TextSize = textSize
			label.TextTransparency = 1
			label.Rotation = math.random(-15, 15)
			label.Parent = textContainer

			-- Add UIStroke for purple glow
			local stroke = Instance.new("UIStroke")
			stroke.Color = Color3.fromRGB(math.random(120, 180), math.random(30, 80), math.random(180, 255)) -- Purple variations
			stroke.Thickness = .3
			stroke.Transparency = 1
			stroke.Parent = label

			-- Fade in fast
			local fadeIn = TweenService:Create(label, TweenInfo.new(0.15), { TextTransparency = 0 })
			local strokeFadeIn = TweenService:Create(stroke, TweenInfo.new(0.15), { Transparency = 0.2 })
			fadeIn:Play()
			strokeFadeIn:Play()

			-- Typewriter with glitch
			for i = 1, #text do
				if not sequenceActive then break end
				label.Text = string.sub(text, 1, i)

				-- Random glitch
				if math.random() < 0.25 then
					local originalText = label.Text
					label.Text = originalText .. glitchChars[math.random(1, #glitchChars)]
					task.wait(0.015)
					label.Text = originalText
				end
				task.wait(0.025)
			end

			-- Random movement/drift
			task.spawn(function()
				while label and label.Parent and sequenceActive and not label:GetAttribute("Frozen") do
					local driftTween = TweenService:Create(label, TweenInfo.new(0.5, Enum.EasingStyle.Sine), {
						Position = label.Position + UDim2.new(0, math.random(-20, 20), 0, math.random(-20, 20)),
						Rotation = label.Rotation + math.random(-5, 5)
					})
					driftTween:Play()
					task.wait(0.5)
				end
			end)

			-- Pulse stroke (purple variations)
			task.spawn(function()
				while label and label.Parent and sequenceActive and not label:GetAttribute("Frozen") do
					local pulse = TweenService:Create(stroke, TweenInfo.new(0.3), {
						Thickness = math.random(1,2),
						Color = Color3.fromRGB(math.random(100, 200), math.random(20, 100), math.random(150, 255)) -- Purple pulse
					})
					pulse:Play()
					task.wait(0.3)
				end
			end)
		end)
	end

	-- SPAWN TEXT EVERYWHERE - Chaotic phase
	-- Initial burst of text
	for i = 1, 15 do
		local quote = Quotes[math.random(1, #Quotes)]
		local posX = math.random(5, 95) / 100
		local posY = math.random(5, 95) / 100
		local textSize = math.random(18, 40)
		createChaoticText(quote, posX, posY, textSize, i * 0.15)
	end

	-- Continuous spawning of more text
	task.spawn(function()
		local spawnCount = 0
		while sequenceActive and spawnCount < 30 do
			task.wait(0.25)
			local quote = Quotes[math.random(1, #Quotes)]
			local posX = math.random(5, 95) / 100
			local posY = math.random(5, 95) / 100
			local textSize = math.random(14, 50)
			createChaoticText(quote, posX, posY, textSize, 0)
			spawnCount = spawnCount + 1
		end
	end)

	-- Phase 2: Text exit animation then shattering (after 3 seconds)
	task.delay(3, function()
		if not sequenceActive then return end

		-- First, FREEZE all text in place (stop drift/pulse)
		for _, label in textContainer:GetChildren() do
			if label:IsA("TextLabel") then
				-- Mark as frozen to stop drift loops
				label:SetAttribute("Frozen", true)
			end
		end

		-- EXIT ANIMATION: Text shrinks, vibrates, then pulls toward center before shattering
		for _, label in textContainer:GetChildren() do
			if label:IsA("TextLabel") then
				-- Quick vibration effect
				task.spawn(function()
					for i = 1, 6 do
						if not label or not label.Parent then break end
						local offsetX = math.random(-8, 8)
						local offsetY = math.random(-8, 8)
						label.Position = label.Position + UDim2.new(0, offsetX, 0, offsetY)
						task.wait(0.03)
					end
				end)

				-- Shrink and pull toward center
				local pullTween = TweenService:Create(label, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
					Position = UDim2.new(0.5, 0, 0.5, 0),
					Size = UDim2.new(0, label.TextSize * 0.5, 0, label.TextSize * 0.5),
					TextTransparency = 0.3
				})
				pullTween:Play()
			end
		end

		-- Brief dramatic pause after pull (0.4 seconds)
		task.wait(0.5)

		-- NOW shatter all text explosively from center
		for _, label in textContainer:GetChildren() do
			if label:IsA("TextLabel") then
				task.spawn(function()
					local text = label.Text
					local labelPos = label.AbsolutePosition

					-- Create scattered characters
					for charIndex = 1, math.min(#text, 20) do
						local char = string.sub(text, charIndex, charIndex)
						if char ~= " " then
							local charLabel = Instance.new("TextLabel")
							charLabel.Size = UDim2.new(0, 25, 0, 35)
							charLabel.Position = UDim2.new(0, labelPos.X + (charIndex - 1) * 10, 0, labelPos.Y)
							charLabel.BackgroundTransparency = 1
							charLabel.Text = char
							charLabel.TextColor3 = Color3.new(0, 0, 0) -- Black
							charLabel.FontFace = Font.new("rbxasset://fonts/families/Sarpanch.json") -- Sarpanch font
							charLabel.TextSize = label.TextSize
							charLabel.TextTransparency = 0
							charLabel.TextStrokeTransparency = 0
							charLabel.TextStrokeColor3 = Color3.fromRGB(150, 50, 200) -- Purple
							charLabel.Parent = truthScreen

							-- Explosive scatter from center
							local randomX = math.random(-600, 600)
							local randomY = math.random(-600, 600)
							local randomRot = math.random(-720, 720) -- More rotation

							local scatterTween = TweenService:Create(charLabel, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
								Position = charLabel.Position + UDim2.new(0, randomX, 0, randomY),
								Rotation = randomRot,
								TextTransparency = 1,
								TextStrokeTransparency = 1
							})
							scatterTween:Play()
							scatterTween.Completed:Connect(function()
								charLabel:Destroy()
							end)
						end
					end
					label:Destroy()
				end)
			end
		end
	end)

	-- Phase 3: World turns white (after 2 seconds - faster fade in)
	task.delay(2, function()
		if not sequenceActive then return end

		local whiteFade = TweenService:Create(background, TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundTransparency = 0
		})
		whiteFade:Play()

		-- Bloom effect
		local bloom = Lighting:FindFirstChild("TruthBloom") or Instance.new("BloomEffect")
		bloom.Name = "TruthBloom"
		bloom.Intensity = 0
		bloom.Size = 24
		bloom.Threshold = 0.8
		bloom.Parent = Lighting

		local bloomTween = TweenService:Create(bloom, TweenInfo.new(1.5), {
			Intensity = 4,
			Size = 70
		})
		bloomTween:Play()

		-- ColorCorrection for white out
		local cc = Instance.new("ColorCorrectionEffect")
		cc.Name = "TruthCC"
		cc.Brightness = 0
		cc.Contrast = 0
		cc.Saturation = 0
		cc.Parent = Lighting

		local ccTween = TweenService:Create(cc, TweenInfo.new(1.5), {
			Brightness = 1,
			Contrast = -0.5,
			Saturation = -1
		})
		ccTween:Play()
	end)

	-- Phase 4: Character body parts fade with neon effect (after 4 seconds)
	task.delay(4, function()
		if not sequenceActive or not Character then return end

		local bodyParts = {"Left Leg", "Right Leg", "Left Arm", "Right Arm", "Torso", "Head"}

		for i, partName in ipairs(bodyParts) do
			task.delay((i - 1) * 0.3, function()
				local part = Character:FindFirstChild(partName)
				if part and part:IsA("BasePart") then
					-- Add highlight that flashes
					local highlight = Instance.new("Highlight")
					highlight.FillColor = Color3.new(1, 1, 1)
					highlight.FillTransparency = 0
					highlight.OutlineColor = Color3.new(1, 1, 1)
					highlight.OutlineTransparency = 0
					highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
					highlight.Parent = Character

					-- Flash effect
					task.spawn(function()
						for j = 1, 3 do
							highlight.FillTransparency = 0
							task.wait(0.05)
							highlight.FillTransparency = 0.5
							task.wait(0.05)
						end

						-- Fade out
						local fadeHighlight = TweenService:Create(highlight, TweenInfo.new(0.4), {
							FillTransparency = 1,
							OutlineTransparency = 1
						})
						fadeHighlight:Play()
						fadeHighlight.Completed:Connect(function()
							highlight:Destroy()
						end)
					end)

					-- Extra intense shake for each part
					CamShake({
						Magnitude = 15,
						Frequency = 35,
						Damp = 0.005,
						Influence = Vector3.new(2, 2, 1.5),
						Location = Camera.CFrame.Position,
						Falloff = 200,
					})
				end
			end)
		end
	end)

	-- Final cleanup (after duration) - SHATTER ALL REMAINING TEXT AFTER TELEPORT
	task.delay(totalDuration - 0.5, function()
		sequenceActive = false

		-- Stop whispers sound
		if whispersSound then
			whispersSound:Stop()
			whispersSound:Destroy()
		end

		-- Final intense shake
		CamShake({
			Magnitude = 30,
			Frequency = 50,
			Damp = 0.001,
			Influence = Vector3.new(3, 3, 2),
			Location = Camera.CFrame.Position,
			Falloff = 300,
		})

		-- SHATTER ALL REMAINING TEXT (any text that wasn't shattered in phase 2)
		-- First freeze all text
		for _, label in textContainer:GetChildren() do
			if label:IsA("TextLabel") then
				label:SetAttribute("Frozen", true)
			end
		end

		-- Quick pull to center then shatter
		for _, label in textContainer:GetChildren() do
			if label:IsA("TextLabel") then
				local pullTween = TweenService:Create(label, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
					Position = UDim2.new(0.5, 0, 0.5, 0),
					Size = UDim2.new(0, label.TextSize * 0.5, 0, label.TextSize * 0.5),
					TextTransparency = 0.3
				})
				pullTween:Play()
			end
		end

		task.wait(0.25)

		-- Shatter all text explosively
		for _, label in textContainer:GetChildren() do
			if label:IsA("TextLabel") then
				task.spawn(function()
					local text = label.Text
					local labelPos = label.AbsolutePosition

					-- Create scattered characters
					for charIndex = 1, math.min(#text, 20) do
						local char = string.sub(text, charIndex, charIndex)
						if char ~= " " then
							local charLabel = Instance.new("TextLabel")
							charLabel.Size = UDim2.new(0, 25, 0, 35)
							charLabel.Position = UDim2.new(0, labelPos.X + (charIndex - 1) * 10, 0, labelPos.Y)
							charLabel.BackgroundTransparency = 1
							charLabel.Text = char
							charLabel.TextColor3 = Color3.new(0, 0, 0)
							charLabel.FontFace = Font.new("rbxasset://fonts/families/Sarpanch.json")
							charLabel.TextSize = label.TextSize
							charLabel.TextTransparency = 0
							charLabel.TextStrokeTransparency = 0
							charLabel.TextStrokeColor3 = Color3.fromRGB(150, 50, 200)
							charLabel.Parent = truthScreen

							-- Explosive scatter
							local randomX = math.random(-600, 600)
							local randomY = math.random(-600, 600)
							local randomRot = math.random(-720, 720)

							local scatterTween = TweenService:Create(charLabel, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
								Position = charLabel.Position + UDim2.new(0, randomX, 0, randomY),
								Rotation = randomRot,
								TextTransparency = 1,
								TextStrokeTransparency = 1
							})
							scatterTween:Play()
							scatterTween.Completed:Connect(function()
								charLabel:Destroy()
							end)
						end
					end
					label:Destroy()
				end)
			end
		end

		task.wait(0.25)

		-- Fade out
		local fadeOut = TweenService:Create(background, TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			BackgroundTransparency = 1
		})
		fadeOut:Play()

		-- Cleanup lighting effects
		local bloom = Lighting:FindFirstChild("TruthBloom")
		if bloom then
			local bloomFade = TweenService:Create(bloom, TweenInfo.new(1), { Intensity = 0 })
			bloomFade:Play()
			bloomFade.Completed:Connect(function()
				bloom:Destroy()
			end)
		end

		local cc = Lighting:FindFirstChild("TruthCC")
		if cc then
			local ccFade = TweenService:Create(cc, TweenInfo.new(1), {
				Brightness = 0,
				Contrast = 0,
				Saturation = 0
			})
			ccFade:Play()
			ccFade.Completed:Connect(function()
				cc:Destroy()
			end)
		end

		fadeOut.Completed:Connect(function()
			truthScreen:Destroy()
		end)
	end)
end

-- Truth Consequence - Called after Truth dialogue ends
-- Player gets knocked back/up, parts fly away, screen fades to white, then teleported back
function Misc.TruthConsequence(Character: Model, organMessage: string, debuffMessage: string)
	local PlayerGui = Player:WaitForChild("PlayerGui")
	local Lighting = game:GetService("Lighting")
	local Debris = game:GetService("Debris")

	local HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart")
	local Humanoid = Character:FindFirstChildOfClass("Humanoid")
	if not HumanoidRootPart then return end

	-- Create the consequence UI screen
	local consequenceScreen = Instance.new("ScreenGui")
	consequenceScreen.Name = "TruthConsequenceScreen"
	consequenceScreen.DisplayOrder = 1000
	consequenceScreen.IgnoreGuiInset = true
	consequenceScreen.Parent = PlayerGui

	-- Play Loss sound (toll payment)
	local truthSFX = Replicated.Assets.SFX:FindFirstChild("Truth")
	if truthSFX then
		local lossSound = truthSFX:FindFirstChild("Loss")
		if lossSound then
			local lossClone = lossSound:Clone()
			lossClone.Parent = PlayerGui
			lossClone:Play()
			lossClone.Ended:Connect(function()
				lossClone:Destroy()
			end)
		end
	end

	-- ═══════════════════════════════════════════════════════════════
	-- PHASE 1: KNOCKBACK - Player gets knocked back and upward
	-- ═══════════════════════════════════════════════════════════════

	-- Apply knockback force (up and back)
	local knockbackForce = Instance.new("BodyVelocity")
	knockbackForce.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
	-- Knock upward and slightly backward from where they're facing
	local lookVector = HumanoidRootPart.CFrame.LookVector
	knockbackForce.Velocity = Vector3.new(-lookVector.X * 30, 80, -lookVector.Z * 30)
	knockbackForce.Parent = HumanoidRootPart
	Debris:AddItem(knockbackForce, 0.3)

	-- Intense initial shake
	CamShake({
		Magnitude = 50,
		Frequency = 60,
		Damp = 0.002,
		Influence = Vector3.new(4, 4, 3),
		Location = Camera.CFrame.Position,
		Falloff = 400,
	})

	-- Red flash on impact
	local impactFlash = Instance.new("Frame")
	impactFlash.Name = "ImpactFlash"
	impactFlash.Size = UDim2.new(1, 0, 1, 0)
	impactFlash.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
	impactFlash.BackgroundTransparency = 0.3
	impactFlash.BorderSizePixel = 0
	impactFlash.ZIndex = 10
	impactFlash.Parent = consequenceScreen

	local flashFade = TweenService:Create(impactFlash, TweenInfo.new(0.5, Enum.EasingStyle.Quad), {
		BackgroundTransparency = 1
	})
	flashFade:Play()
	flashFade.Completed:Connect(function()
		impactFlash:Destroy()
	end)

	-- ═══════════════════════════════════════════════════════════════
	-- PHASE 2: PARTS FLY AWAY - Environment parts around player dissolve
	-- ═══════════════════════════════════════════════════════════════

	task.delay(0.2, function()
		local playerPos = HumanoidRootPart.Position
		local EFFECT_RADIUS = 40
		local affectedParts = {}

		-- Find parts around the player
		for _, obj in workspace:GetDescendants() do
			if obj:IsA("BasePart") and not obj:IsDescendantOf(Character) then
				local distance = (obj.Position - playerPos).Magnitude
				if distance <= EFFECT_RADIUS and obj.Anchored and obj.CanCollide then
					-- Skip very large parts (floors, walls)
					local size = obj.Size
					if size.X < 20 and size.Y < 20 and size.Z < 20 then
						-- Skip floor parts (parts that are below and mostly horizontal)
						local relativeY = obj.Position.Y - playerPos.Y
						local isFloorLike = relativeY < -2 and size.Y < 3 and (size.X > 4 or size.Z > 4)

						-- Skip parts in essential folders (terrain, spawn areas, etc.)
						local isEssential = obj:IsDescendantOf(workspace:FindFirstChild("Terrain") or workspace)
							or obj.Name:lower():find("floor")
							or obj.Name:lower():find("ground")
							or obj.Name:lower():find("spawn")

						if not isFloorLike and not isEssential then
							table.insert(affectedParts, {part = obj, distance = distance})
						end
					end
				end
			end
		end

		-- Sort by distance (closest first)
		table.sort(affectedParts, function(a, b) return a.distance < b.distance end)

		-- Limit to prevent performance issues
		local maxParts = math.min(#affectedParts, 30)

		-- Get or create visuals folder for cleanup
		local visualsFolder = workspace:FindFirstChild("World") and workspace.World:FindFirstChild("Visuals")
		if not visualsFolder then
			visualsFolder = workspace
		end

		-- Make parts fade out in place (clones only - originals stay in place)
		for i = 1, maxParts do
			local data = affectedParts[i]
			local part = data.part

			-- Clone the part for the effect (don't destroy originals)
			local clone = part:Clone()
			clone.Name = "TruthVFX_" .. part.Name
			clone.Anchored = true -- Keep anchored so it stays in place
			clone.CanCollide = false
			clone.CanQuery = false
			clone.CanTouch = false
			clone.CastShadow = false
			clone.Parent = visualsFolder

			-- Stagger the fade based on distance (closer parts fade first)
			local fadeDelay = (data.distance / EFFECT_RADIUS) * 0.5

			task.delay(fadeDelay, function()
				-- Fade out the clone in place
				if clone and clone.Parent then
					local fadeTween = TweenService:Create(clone, TweenInfo.new(1.5, Enum.EasingStyle.Quad), {
						Transparency = 1
					})
					fadeTween:Play()
					fadeTween.Completed:Connect(function()
						if clone and clone.Parent then
							clone:Destroy()
						end
					end)
				end
			end)

			-- Cleanup after effect
			Debris:AddItem(clone, 3)
		end
	end)

	-- ═══════════════════════════════════════════════════════════════
	-- PHASE 3: ORGAN LOSS MESSAGE - Show what was taken
	-- ═══════════════════════════════════════════════════════════════

	task.delay(0.5, function()
		-- Organ loss message (what was taken)
		local organLabel = Instance.new("TextLabel")
		organLabel.Name = "OrganMessage"
		organLabel.Size = UDim2.new(0.8, 0, 0, 60)
		organLabel.Position = UDim2.new(0.5, 0, 0.35, 0)
		organLabel.AnchorPoint = Vector2.new(0.5, 0.5)
		organLabel.BackgroundTransparency = 1
		organLabel.Text = organMessage
		organLabel.TextColor3 = Color3.fromRGB(180, 30, 30) -- Dark red
		organLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
		organLabel.TextStrokeTransparency = 0
		organLabel.FontFace = Font.new("rbxasset://fonts/families/Sarpanch.json")
		organLabel.TextSize = 32
		organLabel.TextTransparency = 1
		organLabel.Parent = consequenceScreen

		local organFadeIn = TweenService:Create(organLabel, TweenInfo.new(0.5), {
			TextTransparency = 0
		})
		organFadeIn:Play()
	end)

	-- Show "DEBILITATION EXCHANGED" after 1.5 seconds
	task.delay(1.5, function()
		-- Main notification - DEBILITATION EXCHANGED
		local mainNotif = Instance.new("TextLabel")
		mainNotif.Name = "DebilitationExchanged"
		mainNotif.Size = UDim2.new(0.9, 0, 0, 100)
		mainNotif.Position = UDim2.new(0.5, 0, 0.5, 0)
		mainNotif.AnchorPoint = Vector2.new(0.5, 0.5)
		mainNotif.BackgroundTransparency = 1
		mainNotif.Text = "DEBILITATION EXCHANGED"
		mainNotif.TextColor3 = Color3.fromRGB(120, 0, 0) -- Very dark red
		mainNotif.TextStrokeColor3 = Color3.fromRGB(50, 0, 50) -- Dark purple stroke
		mainNotif.TextStrokeTransparency = 0
		mainNotif.FontFace = Font.new("rbxasset://fonts/families/Sarpanch.json")
		mainNotif.TextSize = 56
		mainNotif.TextTransparency = 1
		mainNotif.Parent = consequenceScreen

		-- UIStroke for extra emphasis
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(80, 20, 80) -- Purple
		stroke.Thickness = .3
		stroke.Transparency = 1
		stroke.Parent = mainNotif

		-- Fade in with impact
		local notifFadeIn = TweenService:Create(mainNotif, TweenInfo.new(0.3), {
			TextTransparency = 0
		})
		local strokeFadeIn = TweenService:Create(stroke, TweenInfo.new(0.3), {
			Transparency = 0
		})
		notifFadeIn:Play()
		strokeFadeIn:Play()

		-- Another shake
		CamShake({
			Magnitude = 30,
			Frequency = 50,
			Damp = 0.003,
			Influence = Vector3.new(3, 3, 2),
			Location = Camera.CFrame.Position,
			Falloff = 300,
		})
	end)

	-- Show debuff message after 2 seconds
	task.delay(2, function()
		local debuffLabel = Instance.new("TextLabel")
		debuffLabel.Name = "DebuffMessage"
		debuffLabel.Size = UDim2.new(0.8, 0, 0, 40)
		debuffLabel.Position = UDim2.new(0.5, 0, 0.65, 0)
		debuffLabel.AnchorPoint = Vector2.new(0.5, 0.5)
		debuffLabel.BackgroundTransparency = 1
		debuffLabel.Text = debuffMessage
		debuffLabel.TextColor3 = Color3.fromRGB(150, 100, 100) -- Muted red
		debuffLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
		debuffLabel.TextStrokeTransparency = 0.3
		debuffLabel.FontFace = Font.new("rbxasset://fonts/families/Sarpanch.json")
		debuffLabel.TextSize = 24
		debuffLabel.TextTransparency = 1
		debuffLabel.Parent = consequenceScreen

		local debuffFadeIn = TweenService:Create(debuffLabel, TweenInfo.new(0.5), {
			TextTransparency = 0
		})
		debuffFadeIn:Play()
	end)

	-- ═══════════════════════════════════════════════════════════════
	-- PHASE 4: FADE TO WHITE - Screen goes white before teleport
	-- ═══════════════════════════════════════════════════════════════

	task.delay(2.5, function()
		-- Create white overlay for fade to white
		local whiteOverlay = Instance.new("Frame")
		whiteOverlay.Name = "WhiteOverlay"
		whiteOverlay.Size = UDim2.new(1, 0, 1, 0)
		whiteOverlay.BackgroundColor3 = Color3.new(1, 1, 1)
		whiteOverlay.BackgroundTransparency = 1
		whiteOverlay.BorderSizePixel = 0
		whiteOverlay.ZIndex = 100
		whiteOverlay.Parent = consequenceScreen

		-- Fade text out as white fades in
		for _, child in consequenceScreen:GetChildren() do
			if child:IsA("TextLabel") then
				local fade = TweenService:Create(child, TweenInfo.new(1), {
					TextTransparency = 1,
					TextStrokeTransparency = 1
				})
				fade:Play()
			end
		end

		-- Fade to white
		local whiteIn = TweenService:Create(whiteOverlay, TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			BackgroundTransparency = 0
		})
		whiteIn:Play()

		-- Add bloom effect for white-out
		local bloom = Instance.new("BloomEffect")
		bloom.Name = "TruthWhiteoutBloom"
		bloom.Intensity = 0
		bloom.Size = 24
		bloom.Threshold = 0.8
		bloom.Parent = Lighting

		local bloomTween = TweenService:Create(bloom, TweenInfo.new(1), {
			Intensity = 3,
			Threshold = 0
		})
		bloomTween:Play()

		-- Cleanup after teleport happens (at 4 seconds from server)
		task.delay(1.5, function()
			-- Fade bloom back
			local bloomFade = TweenService:Create(bloom, TweenInfo.new(0.5), {
				Intensity = 0,
				Threshold = 0.8
			})
			bloomFade:Play()
			bloomFade.Completed:Connect(function()
				bloom:Destroy()
			end)

			-- Fade white overlay out
			local whiteOut = TweenService:Create(whiteOverlay, TweenInfo.new(1, Enum.EasingStyle.Quad), {
				BackgroundTransparency = 1
			})
			whiteOut:Play()
			whiteOut.Completed:Connect(function()
				consequenceScreen:Destroy()
			end)
		end)
	end)
end

-- Truth Room Sounds - Plays Area and Theme sounds (both looped with fade in) when teleported to Truth room
function Misc.TruthRoomSounds(Character: Model)
	local PlayerGui = Player:WaitForChild("PlayerGui")

	-- Set global flag to disable other themes
	_G.TruthActive = true

	-- Get Truth SFX folder
	local truthSFX = Replicated.Assets.SFX:FindFirstChild("Truth")
	if not truthSFX then return end

	-- Fade duration for sounds
	local FADE_DURATION = 2

	-- Play Area sound (looped with fade in)
	local areaSound = truthSFX:FindFirstChild("Area")
	if areaSound then
		-- Stop any existing Area sound first
		if _G.TruthAreaSound then
			_G.TruthAreaSound:Stop()
			_G.TruthAreaSound:Destroy()
		end

		local areaClone = areaSound:Clone()
		areaClone.Looped = true
		areaClone.Volume = 0 -- Start at 0 for fade in
		areaClone.Parent = PlayerGui
		areaClone:Play()
		_G.TruthAreaSound = areaClone

		-- Fade in the area sound
		local targetVolume = areaSound.Volume or 0.5
		local areaFade = TweenService:Create(areaClone, TweenInfo.new(FADE_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Volume = targetVolume
		})
		areaFade:Play()
	end

	-- Play Theme sound (looped with fade in) - stored globally so we can stop it later
	local themeSound = truthSFX:FindFirstChild("Theme")
	if themeSound then
		-- Stop any existing Truth theme first
		if _G.TruthThemeSound then
			_G.TruthThemeSound:Stop()
			_G.TruthThemeSound:Destroy()
		end

		local themeClone = themeSound:Clone()
		themeClone.Looped = true
		themeClone.Volume = 0 -- Start at 0 for fade in
		themeClone.Parent = PlayerGui
		themeClone:Play()
		_G.TruthThemeSound = themeClone

		-- Fade in the theme sound
		local targetVolume = themeSound.Volume or 0.5
		local themeFade = TweenService:Create(themeClone, TweenInfo.new(FADE_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Volume = targetVolume
		})
		themeFade:Play()
	end
end

-- Stop Truth Room Theme - Called when leaving Truth room
function Misc.StopTruthRoomSounds()
	-- Clear the global flag
	_G.TruthActive = false

	-- Stop and cleanup the area sound
	if _G.TruthAreaSound then
		_G.TruthAreaSound:Stop()
		_G.TruthAreaSound:Destroy()
		_G.TruthAreaSound = nil
	end

	-- Stop and cleanup the theme sound
	if _G.TruthThemeSound then
		_G.TruthThemeSound:Stop()
		_G.TruthThemeSound:Destroy()
		_G.TruthThemeSound = nil
	end
end

return Misc
