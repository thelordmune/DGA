-- Services
local Players = game:GetService("Players")
local StarterPack = game:GetService("StarterPack")
local TweenService = game:GetService("TweenService")
local Replicated = game:GetService("ReplicatedStorage")

-- Modules
local Misc = require(script.Parent.Misc)
local Library = require(Replicated.Modules.Library)
local Utilities = require(Replicated.Modules.Utilities)
local Debris = Utilities.Debris

-- Variables
local Player = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local VFX = Replicated:WaitForChild("Assets").VFX
local SFX = Replicated:WaitForChild("Assets").SFX
local CameraShakeModule = require(Replicated.Modules._CameraShake)

local Fusion = require(Replicated.Modules.Fusion)
local Children, scoped, peek, out = Fusion.Children, Fusion.scoped, Fusion.peek, Fusion.Out

local world = require(Replicated.Modules.ECS.jecs_world)
local ref = require(Replicated.Modules.ECS.jecs_ref)
local comps = require(Replicated.Modules.ECS.jecs_components)

local TInfo = TweenInfo.new(0.35, Enum.EasingStyle.Circular, Enum.EasingDirection.Out, 0)

local Weapons = {}

function Weapons.GrandCleave(Character: Model, Frame: string, duration: number?)
    if Frame == "Slash1" then
        local eff = VFX.Cleave.slash:Clone()
        eff.Parent = workspace.World.Visuals
        eff.CFrame = Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, -2) * CFrame.Angles(0,0,math.rad(-15))
        for _, v in eff:GetDescendants() do
            if v:IsA("ParticleEmitter") then
                v:Emit(v:GetAttribute("EmitCount"))
            end
        end
        task.delay(3, function()
            eff:Destroy()
        end)
    elseif Frame == "Drag" then
        for _, v in Character:GetDescendants() do
            if v:GetAttribute("Special") then
                local h = v:GetDescendants()
                for _, p in h do
                    if p:IsA("ParticleEmitter") then
                        p:Emit(p:GetAttribute("EmitCount"))
                        p.Enabled = true
                        task.delay(duration, function()
                            p.Enabled = false
                        end)
                    end
                end
            end
        end
    elseif Frame == "Slash2" then
        local eff = VFX.Cleave.slash:Clone()
        eff.Parent = workspace.World.Visuals
        eff.CFrame = Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, -1) * CFrame.Angles(0,0,math.rad(-15))
        for _, v in eff:GetDescendants() do
            if v:IsA("ParticleEmitter") then
                v:Emit(v:GetAttribute("EmitCount"))
            end
        end
        local geff = VFX.Cleave.swingwooo:Clone()
        geff.Parent = workspace.World.Visuals
        geff.CFrame = Character.HumanoidRootPart.CFrame * CFrame.new(0, -2.5,0)
        for _, v in geff:GetDescendants() do
            if v:IsA("ParticleEmitter") then
                v:Emit(v:GetAttribute("EmitCount"))
            end
        end
        task.delay(3, function()
            eff:Destroy()
            geff:Destroy()
        end)
    elseif Frame == "Slash3" then
        local eff = VFX.Cleave.slash3:Clone()
        eff.Parent = workspace.World.Visuals
        eff.CFrame = Character.HumanoidRootPart.CFrame * CFrame.new(0, .3, -2) * CFrame.Angles(0,0,math.rad(15))
        for _, v in eff:GetDescendants() do
            if v:IsA("ParticleEmitter") then
                v:Emit(v:GetAttribute("EmitCount"))
            end
        end
        task.delay(3, function()
            eff:Destroy()
        end)
    end
end

return Weapons