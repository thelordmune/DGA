-- Services
local Players = game:GetService("Players")
local Replicated = game:GetService("ReplicatedStorage")

-- Modules
local Utilities = require(Replicated.Modules.Utilities)
local Library = require(Replicated.Modules.Library)
local Debris = Utilities.Debris

-- Variables
local Player = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local CamShake = require(Replicated.Modules.Utils.CamShake)

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
	
	for _,v in pairs(Object:GetDescendants()) do
		if v:IsA("ParticleEmitter") then
			if v.Lifetime.Max > DebrisTimer then
				DebrisTimer = v.Lifetime.Max
			end
		end
	end
	
	if Descendants then
		for _, Emitter in pairs(Object:GetDescendants()) do
			if Emitter:IsA("ParticleEmitter") then
				task.delay(Emitter:GetAttribute("EmitDelay"),function()
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
		for _,Emitter in pairs(Object:GetChildren()) do
			if Emitter:IsA("ParticleEmitter") then
				task.delay(Emitter:GetAttribute("EmitDelay"),function()
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
	
	Debris:AddItem(Object,DebrisTimer)
	
	return DebrisTimer
end

function Misc.EnableStatus(Character: Model, FXName: string, FXDuration: number)
    local humanoidRootPart = Character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then return end
    
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
    
    Debris:AddItem(FX, FXDuration + .25)
end

function Misc.CameraShake(State)
	camShake:Shake(CameraShaker.Presets[State])
end

-- Hyperarmor visual indicator system
function Misc.StartHyperarmor(Character: Model)
	if not Character or not Character:FindFirstChild("HumanoidRootPart") then return end

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

	-- print("Hyperarmor visual started for", Character.Name)
end

function Misc.UpdateHyperarmor(Character: Model, damagePercent: number)
	if not Character then return end

	local highlight = Character:FindFirstChild("HyperarmorHighlight")
	if not highlight then return end

	-- Interpolate color from white (0% damage) to red (100% damage)
	local white = Color3.fromRGB(255, 255, 255)
	local red = Color3.fromRGB(255, 0, 0)
	local currentColor = white:Lerp(red, damagePercent)

	-- Update highlight color
	highlight.FillColor = currentColor
	highlight.OutlineColor = currentColor

	-- Increase intensity as damage increases
	highlight.FillTransparency = 0.3 - (damagePercent * 0.2) -- Gets more opaque as damage increases

	-- print(string.format("Hyperarmor visual updated for %s: %.0f%% damage (Color: R%.0f G%.0f B%.0f)",
		--Character.Name, damagePercent * 100, currentColor.R * 255, currentColor.G * 255, currentColor.B * 255))
end

function Misc.RemoveHyperarmor(Character: Model)
	if not Character then return end

	local highlight = Character:FindFirstChild("HyperarmorHighlight")
	if highlight then
		-- Fade out the highlight
		local TweenService = game:GetService("TweenService")
		local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
		local tween = TweenService:Create(highlight, tweenInfo, {
			FillTransparency = 1,
			OutlineTransparency = 1
		})
		tween:Play()
		tween.Completed:Connect(function()
			highlight:Destroy()
		end)

		-- print("Hyperarmor visual removed for", Character.Name)
	end
end

function Misc.AdrenalineFX(Character: Model)
	if not Character then return end
	local ADVfx = Replicated.Assets.VFX.Adrenaline:Clone()
	ADVfx.Anchored = true
	ADVfx.CanCollide = false
	ADVfx.Parent = workspace.World.Visuals
	ADVfx.CFrame = Character.HumanoidRootPart.CFrame

	for _, particleEmitter in ipairs(ADVfx:GetDescendants()) do
		if particleEmitter:IsA("ParticleEmitter") then
	particleEmitter:Emit(particleEmitter:GetAttribute("EmitCount"))
		end
	end

	-- Brief up-and-down screen shake for adrenaline level up
	CamShake({
		Magnitude = 15, -- High magnitude for adrenaline level up
		Frequency = 28,
		Damp = 0.006,
		Influence = Vector3.new(0.3, 1.5, 0.3), -- Emphasize vertical movement
		Location = Character.HumanoidRootPart.Position,
		Falloff = 100
	})

	Debris:AddItem(ADVfx, 1)
end

return Misc
