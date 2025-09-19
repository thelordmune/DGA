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
local CameraShaker = require(Replicated.Modules._CameraShake)
local CameraPresets = require(Replicated.Modules._CameraShake.CameraShakePresets)

local Misc = {}

local camShake = CameraShaker.new(Enum.RenderPriority.Camera.Value, function(shakeCf)
	Camera.CFrame = Camera.CFrame * shakeCf
end)

camShake:Start()

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

return Misc
