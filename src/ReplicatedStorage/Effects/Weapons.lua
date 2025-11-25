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
local CamShake = require(Replicated.Modules.Utils.CamShake)

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

local function startdkmesh(CF: CFrame, Parent: Instance)
  
	-- Base Setup 

	if CF then
		if typeof(CF) == "Vector3" then
			CF = CFrame.new(CF)
		elseif typeof(CF) ~= "CFrame" then
			CF = nil
		end
	end

	if not Parent then
		local cache = workspace:FindFirstChild("MeshCache")
		if not cache then
			cache = Instance.new("Folder")
			cache.Name = "MeshCache"
			cache.Parent = workspace
		end
		Parent = cache
	end

	local Main_CFrame = CF or CFrame.new(0,0,0)

	-- Settings

	local Visual_Directory = {
		["uhenable"] = Replicated.Assets.VFX.DropKick.Firstmeshwoosh.uhenable,
		["WindShockwaveenable"] = Replicated.Assets.VFX.DropKick.Firstmeshwoosh.WindShockwaveenable,
		["Shockwave2"] = Replicated.Assets.VFX.DropKick.Firstmeshwoosh.Shockwave2,
		["Mesh1"] = Replicated.Assets.VFX.DropKick.Firstmeshwoosh.Mesh1,
		["WindWave2"] = Replicated.Assets.VFX.DropKick.Firstmeshwoosh.WindWave2,
		["Mesh2"] = Replicated.Assets.VFX.DropKick.Firstmeshwoosh.Mesh2,
		["WindShockwave"] = Replicated.Assets.VFX.DropKick.Firstmeshwoosh.WindShockwave,
		["WindCoolSwirlenable"] = Replicated.Assets.VFX.DropKick.Firstmeshwoosh.WindCoolSwirlenable
	} :: {[string] : Instance}

	local Visual_Data = {
		[Visual_Directory["Mesh1"]] = {
			General = {
				Offset = CFrame.new(0.906616211, -1.53215492, -0.56427002, -1, 0, 0, 0, 1, 0, 0, 0, -1),
				Tween_Duration = 0.6,
				Transparency = 0.45,
			},

			Features = {-- !CheckForFeature!
			},-- !CheckForFeature!
			-- !CheckForFeature!
			BasePart = {
				Property = {
					Size = Vector3.new(1.2913484573364258, 0.04084079712629318, 0.6449999809265137),
					CFrame = Main_CFrame * CFrame.new(0.68460083, -3.26126003, -0.406341553, -1, 0, 0, 0, 1, 0, 0, 0, -1),
					Color = Color3.new(0.639216, 0.635294, 0.647059),
					Transparency = 1,
				},
				Tween = {
					Easing_Direction = Enum.EasingDirection.Out,
					Easing_Style = Enum.EasingStyle.Cubic,
				},
			},

			Mesh = {
				Property = {
					Offset = Vector3.new(0, 0, 0),
					Scale = Vector3.new(-0.03228873759508133, -0.012327493168413639, -0.032288748770952225),
					VertexColor = Vector3.new(1, 1, 1),
				},
				Tween = {
					Easing_Direction = Enum.EasingDirection.InOut,
					Easing_Style = Enum.EasingStyle.Linear,
				},
			},

			Decal = {
				Property = {
					Color3 = Color3.new(3.92157, 3.92157, 3.92157),
					Transparency = 1,
				},
				Tween = {
					Easing_Direction = Enum.EasingDirection.InOut,
					Easing_Style = Enum.EasingStyle.Linear,
				},
			},
		},

		[Visual_Directory["Mesh2"]] = {
			General = {
				Offset = CFrame.new(0.020111084, 6.15884256, -0.749298096, -1, 0, 0, 0, 1, 0, 0, 0, -1),
				Tween_Duration = 0.4,
				Transparency = 0.5,
			},

			Features = {-- !CheckForFeature!
			},-- !CheckForFeature!
			-- !CheckForFeature!
			BasePart = {
				Property = {
					Size = Vector3.new(1.2970445156097412, 0.04987366497516632, 0.6478757858276367),
					CFrame = Main_CFrame * CFrame.new(-0.0406494141, -3.17667937, -0.517852783, -0.499959469, 0, -0.866048813, 0, 1, 0, 0.866048813, 0, -0.499959469),
					Color = Color3.new(0.639216, 0.635294, 0.647059),
					Transparency = 1,
				},
				Tween = {
					Easing_Direction = Enum.EasingDirection.Out,
					Easing_Style = Enum.EasingStyle.Cubic,
				},
			},

			Mesh = {
				Property = {
					Offset = Vector3.new(0, 0, 0),
					Scale = Vector3.new(-0.03243115916848183, -0.01505399402230978, -0.032431166619062424),
					VertexColor = Vector3.new(1, 1, 1),
				},
				Tween = {
					Easing_Direction = Enum.EasingDirection.InOut,
					Easing_Style = Enum.EasingStyle.Linear,
				},
			},

			Decal = {
				Property = {
					Color3 = Color3.new(3.92157, 3.92157, 3.92157),
					Transparency = 1,
				},
				Tween = {
					Easing_Direction = Enum.EasingDirection.InOut,
					Easing_Style = Enum.EasingStyle.Linear,
				},
			},
		},

		[Visual_Directory["Shockwave2"]] = {
			General = {
				Offset = CFrame.new(0, -3.49129868, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Tween_Duration = 2,
				Transparency = 0.43,
			},

			Features = {-- !CheckForFeature!
			},-- !CheckForFeature!
			-- !CheckForFeature!
			BasePart = {
				Property = {
					Size = Vector3.new(0.8497866988182068, 0.8497866988182068, 0.8497866988182068),
					CFrame = Main_CFrame * CFrame.new(0, -3.68990231, -0.00396728516, 0.829036474, 0, 0.559194624, 0, 1, 0, -0.559194624, 0, 0.829036474),
					Color = Color3.new(0.639216, 0.635294, 0.647059),
					Transparency = 1,
				},
				Tween = {
					Easing_Direction = Enum.EasingDirection. Out,
					Easing_Style = Enum.EasingStyle.Quad,
				},
			},

			Mesh = {
				Property = {
					Offset = Vector3.new(0, 0, 0),
					Scale = Vector3.new(0.3697408139705658, 2.6614818572998047, 0.3697408139705658),
					VertexColor = Vector3.new(1, 1, 1),
				},
				Tween = {
					Easing_Direction = Enum.EasingDirection.InOut,
					Easing_Style = Enum.EasingStyle.Linear,
				},
			},

			Decal = {
				Property = {
					Color3 = Color3.new(5.88235, 5.88235, 5.88235),
					Transparency = 1,
				},
				Tween = {
					Easing_Direction = Enum.EasingDirection.InOut,
					Easing_Style = Enum.EasingStyle.Linear,
				},
			},
		},

		[Visual_Directory["WindCoolSwirlenable"]] = {
			General = {
				Offset = CFrame.new(0, -3.93539953, 0.118011475, -0.949317455, 1.63912773e-06, 0.314318866, 1.63912773e-06, -1, 1.02519989e-05, 0.314318866, 1.01923943e-05, 0.949317515),
				Tween_Duration = 3,
				Transparency = 0.9,
			},

			Features = {-- !CheckForFeature!
			},-- !CheckForFeature!
			-- !CheckForFeature!
			BasePart = {
				Property = {
					Size = Vector3.new(1.296696662902832, 0.4656711220741272, 1.4228843450546265),
					CFrame = Main_CFrame * CFrame.new(0, -2.72896767, 0, 1, 0, 0, 0, -1, 0, 0, 0, -1),
					Color = Color3.new(0.639216, 0.635294, 0.647059),
					Transparency = 1,
				},
				Tween = {
					Easing_Direction = Enum.EasingDirection.Out,
					Easing_Style = Enum.EasingStyle.Cubic,
				},
			},

			Mesh = {
				Property = {
					Offset = Vector3.new(0, 0, 0),
					Scale = Vector3.new(1.977808952331543, 0.2949250340461731, 1.977808952331543),
					VertexColor = Vector3.new(1, 1, 1),
				},
				Tween = {
					Easing_Direction = Enum.EasingDirection.InOut,
					Easing_Style = Enum.EasingStyle.Linear,
				},
			},

			Decal = {
				Property = {
					Color3 = Color3.new(2.17647, 2.17647, 2.17647),
					Transparency = 1,
				},
				Tween = {
					Easing_Direction = Enum.EasingDirection.InOut,
					Easing_Style = Enum.EasingStyle.Linear,
				},
			},
		},

		[Visual_Directory["WindShockwave"]] = {
			General = {
				Offset = CFrame.new(0, -1.01517296, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Tween_Duration = 2,
				Transparency = 0.5,
			},

			BasePart = {
				Property = {
					Size = Vector3.new(5.486605644226074, 2.274979591369629, 5.486605644226074),
					CFrame = Main_CFrame * CFrame.new(0, -2.99309158, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0),
					Color = Color3.new(0.639216, 0.635294, 0.647059),
					Transparency = 1,
				},
				Tween = {
					Easing_Direction = Enum.EasingDirection. Out,
					Easing_Style = Enum.EasingStyle.Cubic,
				},
			},

			Mesh = {
				Property = {
					Offset = Vector3.new(0, 0, 0),
					Scale = Vector3.new(0.01226193830370903, 0.00235806405544281, 0.01226193830370903),
					VertexColor = Vector3.new(1, 1, 1),
				},
				Tween = {
					Easing_Direction = Enum.EasingDirection.InOut,
					Easing_Style = Enum.EasingStyle.Linear,
				},
			},

			Decal = {
				Property = {
					Color3 = Color3.new(1.30588, 1.30588, 1.30588),
					Transparency = 1,
				},
				Tween = {
					Easing_Direction = Enum.EasingDirection.InOut,
					Easing_Style = Enum.EasingStyle.Linear,
				},
			},
		},

		[Visual_Directory["WindShockwaveenable"]] = {
			General = {
				Offset = CFrame.new(0, -4.08930111, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Tween_Duration = 1,
				Transparency = 0.5,
			},

			BasePart = {
				Property = {
					Size = Vector3.new(5.486605644226074, 2.274979591369629, 5.486605644226074),
					CFrame = Main_CFrame * CFrame.new(0, -2.99309158, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0),
					Color = Color3.new(0.639216, 0.635294, 0.647059),
					Transparency = 1,
				},
				Tween = {
					Easing_Direction = Enum.EasingDirection. Out,
					Easing_Style = Enum.EasingStyle.Cubic,
				},
			},

			Mesh = {
				Property = {
					Offset = Vector3.new(0, 0, 0),
					Scale = Vector3.new(0.01226193830370903, 0.00235806405544281, 0.01226193830370903),
					VertexColor = Vector3.new(1, 1, 1),
				},
				Tween = {
					Easing_Direction = Enum.EasingDirection.Out,
					Easing_Style = Enum.EasingStyle.Cubic,
				},
			},

			Decal = {
				Property = {
					Color3 = Color3.new(1.30588, 1.30588, 1.30588),
					Transparency = 1,
				},
				Tween = {
					Easing_Direction = Enum.EasingDirection.Out,
					Easing_Style = Enum.EasingStyle.Cubic,
				},
			},
		},

		[Visual_Directory["WindWave2"]] = {
			General = {
				Offset = CFrame.new(0, -3.49129868, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Tween_Duration = 0.5,
				Transparency = 0.7,
			},

			BasePart = {
				Property = {
					Size = Vector3.new(0.8497866988182068, 0.8497866988182068, 0.8497866988182068),
					CFrame = Main_CFrame * CFrame.new(0, -3.52160978, -0.00396728516, -0.999848366, 0, 0.017436387, 0, 1, 0, -0.017436387, 0, -0.999848366),
					Color = Color3.new(0.639216, 0.635294, 0.647059),
					Transparency = 1,
				},
				Tween = {
					Easing_Direction = Enum.EasingDirection. Out,
					Easing_Style = Enum.EasingStyle.Cubic,
				},
			},

			Mesh = {
				Property = {
					Offset = Vector3.new(0, 0, 0),
					Scale = Vector3.new(0.2682434022426605, 0.4132399260997772, 0.2682434022426605),
					VertexColor = Vector3.new(1, 1, 1),
				},
				Tween = {
					Easing_Direction = Enum.EasingDirection.Out,
					Easing_Style = Enum.EasingStyle.Cubic,
				},
			},

			Decal = {
				Property = {
					Color3 = Color3.new(5.88235, 5.88235, 5.88235),
					Transparency = 1,
				},
				Tween = {
					Easing_Direction = Enum.EasingDirection.Out,
					Easing_Style = Enum.EasingStyle.Cubic,
				},
			},
		},

		[Visual_Directory["uhenable"]] = {
			General = {
				Offset = CFrame.new(0, -3.75195026, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Tween_Duration = 0.4,
				Transparency = 0.98,
			},

			BasePart = {
				Property = {
					Size = Vector3.new(1.1273804903030396, 0.1283242106437683, 0.5636902451515198),
					CFrame = Main_CFrame * CFrame.new(0, -3.52206087, 0, -1, 0, 0, 0, 1, 0, 0, 0, -1),
					Color = Color3.new(0.639216, 0.635294, 0.647059),
					Transparency = 1,
				},
				Tween = {
					Easing_Direction = Enum.EasingDirection.Out,
					Easing_Style = Enum.EasingStyle.Cubic,
				},
			},

			Mesh = {
				Property = {
					Offset = Vector3.new(0, 0, 0),
					Scale = Vector3.new(0.41322728991508484, 0.04971948638558388, 0.41322728991508484),
					VertexColor = Vector3.new(10, 10, 10),
				},
				Tween = {
					Easing_Direction = Enum.EasingDirection.Out,
					Easing_Style = Enum.EasingStyle.Cubic,
				},
			},

			Decal = {
				Property = {
					Color3 = Color3.new(3.92157, 3.92157, 3.92157),
					Transparency = 1,
				},
				Tween = {
					Easing_Direction = Enum.EasingDirection.Out,
					Easing_Style = Enum.EasingStyle.Cubic,
				},
			},
		},

	}

	for Origin : any, Data in pairs(Visual_Data) do
		if not Origin or not Origin:IsDescendantOf(game) or not Origin:FindFirstChild("Start") then continue end

		-- Build

		local function Emit()
			local Visual = Origin.Start:Clone()
			Visual.Name = Origin.Name
			Visual.Transparency = Data.General.Transparency
			if Visual:FindFirstChildOfClass("Decal") then Visual:FindFirstChildOfClass("Decal").Transparency = Data.General.Transparency Visual.Transparency = 1 end
			Visual.Anchored = true
			Visual.CanCollide = false
			Visual.CanQuery = false
			Visual.CanTouch = false
			Visual.Locked = true
			Visual.CFrame = Main_CFrame * Data.General.Offset
			Visual.Parent = Parent

			-- Initialize

			game:GetService("TweenService"):Create(Visual, TweenInfo.new(Data.General.Tween_Duration, Data.BasePart.Tween.Easing_Style, Data.BasePart.Tween.Easing_Direction), Data.BasePart.Property):Play()
			if Data.Decal then game:GetService("TweenService"):Create(Visual:FindFirstChildOfClass("Decal"), TweenInfo.new(Data.General.Tween_Duration, Data.Decal.Tween.Easing_Style, Data.Decal.Tween.Easing_Direction), Data.Decal.Property):Play() end
			if Data.Mesh then game:GetService("TweenService"):Create(Visual:FindFirstChildOfClass("SpecialMesh"), TweenInfo.new(Data.General.Tween_Duration, Data.Mesh.Tween.Easing_Style, Data.Mesh.Tween.Easing_Direction), Data.Mesh.Property):Play() end

			-- Clean Up

			task.delay(Data.General.Tween_Duration,Visual.Destroy,Visual)
		end

		task.spawn(Emit)
	end

end

local function jumpdkmesh(CF: CFrame, Parent: Instance)
 
	-- Base Setup 

	if CF then
		if typeof(CF) == "Vector3" then
			CF = CFrame.new(CF)
		elseif typeof(CF) ~= "CFrame" then
			CF = nil
		end
	end

	if not Parent then
		local cache = workspace:FindFirstChild("MeshCache")
		if not cache then
			cache = Instance.new("Folder")
			cache.Name = "MeshCache"
			cache.Parent = workspace
		end
		Parent = cache
	end

	local Main_CFrame = CF or CFrame.new(0,0,0)

	-- Settings

	local Visual_Directory = {
		["dramatic"] = Replicated.Assets.VFX.DropKick.Jump.out.dramatic,
		["Hmm3"] = Replicated.Assets.VFX.DropKick.Jump.out.Hmm3,
		["Wind"] = Replicated.Assets.VFX.DropKick.Jump.out.Wind,
		["ShootMesh"] = Replicated.Assets.VFX.DropKick.Jump.out.ShootMesh
	} :: {[string] : Instance}

	local Visual_Data = {
		[Visual_Directory["Hmm3"]] = {
			General = {
				Offset = CFrame.new(-0.151153564, -4.32416344, -1.7925415, 0, 1.33629948e-21, -1, 0, 1, -1.33629948e-21, 1, 0, 0),
				Tween_Duration = 0.25,
				Transparency = 0.95,
			},

			BasePart = {
				Property = {
					Size = Vector3.new(12.603195190429688, 15, 12.603195190429688),
					CFrame = Main_CFrame * CFrame.new(-0.151153564, -1.68119717, -1.79257202, 0, 1.33629948e-21, 1, 0, 1, 1.33629948e-21, -1, 0, 0),
					Color = Color3.new(0.639216, 0.635294, 0.647059),
					Transparency = 1,
				},
				Tween = {
					Easing_Direction = Enum.EasingDirection.Out,
					Easing_Style = Enum.EasingStyle.Cubic,
				},
			},

		},

		[Visual_Directory["ShootMesh"]] = {
			General = {
				Offset = CFrame.new(-0.310913086, -0.587655067, -0.251373291, -1, 1.33629948e-21, 0, -1.33629948e-21, 1, 0, 0, 0, -1),
				Tween_Duration = 0.15,
				Transparency = 0.6,
			},

			BasePart = {
				Property = {
					Size = Vector3.new(1.585519790649414, 29.075138092041016, 1.493143081665039),
					CFrame = Main_CFrame * CFrame.new(-0.310913086, 1.87844801, -0.195892334, -0.138841867, 3.29315662e-05, -0.990314484, 0.0143373907, 0.999895215, -0.00197684765, 0.990210772, -0.0144729614, -0.138827771),
					Color = Color3.new(0.972549, 0.972549, 0.972549),
					Transparency = 1,
				},
				Tween = {
					Easing_Direction = Enum.EasingDirection.Out,
					Easing_Style = Enum.EasingStyle.Cubic,
				},
			},

		},

		[Visual_Directory["Wind"]] = {
			General = {
				Offset = CFrame.new(-3.25473276e-21, -4.87126255, 0, 1, -2.00444926e-21, 0, 2.00444926e-21, -1, 0, 0, 0, -1),
				Tween_Duration = 1.2,
				Transparency = 0.98,
			},

			BasePart = {
				Property = {
					Size = Vector3.new(29.16249656677246, 4.267792224884033, 28.24770736694336),
					CFrame = Main_CFrame * CFrame.new(-3.3484875e-21, -5.01158237, 0, 0, -2.00444926e-21, 1, 0, -1, 2.00444926e-21, 1, 0, 0),
					Color = Color3.new(0.972549, 0.972549, 0.972549),
					Transparency = 1,
				},
				Tween = {
					Easing_Direction = Enum.EasingDirection.Out,
					Easing_Style = Enum.EasingStyle.Cubic,
				},
			},

		},

		[Visual_Directory["dramatic"]] = {
			General = {
				Offset = CFrame.new(-0.151153564, -5.32312918, -1.14996338, 0, -1.33629948e-21, 1, 0, -1, 1.33629948e-21, 1, 0, 0),
				Tween_Duration = 0.1,
				Transparency = 0.9,
			},

			BasePart = {
				Property = {
					Size = Vector3.new(2.551072120666504, 19.071107864379883, 2.551072120666504),
					CFrame = Main_CFrame * CFrame.new(-0.151153564, -6.89178228, -1.14996338, 0, -1.33629948e-21, 1, 0, -1, 1.33629948e-21, 1, 0, 0),
					Color = Color3.new(1, 1, 1),
					Transparency = 1,
				},
				Tween = {
					Easing_Direction = Enum.EasingDirection.Out,
					Easing_Style = Enum.EasingStyle.Cubic,
				},
			},

		},

	}

	for Origin : any, Data in pairs(Visual_Data) do
		if not Origin or not Origin:IsDescendantOf(game) or not Origin:FindFirstChild("Start") then continue end

		-- Build

		local function Emit()
			local Visual = Origin.Start:Clone()
			Visual.Name = Origin.Name
			Visual.Transparency = Data.General.Transparency
			if Visual:FindFirstChildOfClass("Decal") then Visual:FindFirstChildOfClass("Decal").Transparency = Data.General.Transparency Visual.Transparency = 1 end
			Visual.Anchored = true
			Visual.CanCollide = false
			Visual.CanQuery = false
			Visual.CanTouch = false
			Visual.Locked = true
			Visual.CFrame = Main_CFrame * Data.General.Offset
			Visual.Parent = Parent

			-- Initialize

			game:GetService("TweenService"):Create(Visual, TweenInfo.new(Data.General.Tween_Duration, Data.BasePart.Tween.Easing_Style, Data.BasePart.Tween.Easing_Direction), Data.BasePart.Property):Play()

			-- Clean Up

			task.delay(Data.General.Tween_Duration,Visual.Destroy,Visual)
		end

		task.spawn(Emit)
	end

end
function Weapons.DropKick(Character: Model, Frame: string)
    if Frame == "StepL" then
        local eff = VFX.DropKick.step:Clone()
        eff.Parent = workspace.World.Visuals
        eff.CFrame = Character.HumanoidRootPart.CFrame * CFrame.new(0, 1, -2)
        for _, v in eff:GetDescendants() do
            if v:IsA("ParticleEmitter") then
                v:Emit(v:GetAttribute("EmitCount"))
            end
        end
        task.delay(3, function()
            eff:Destroy()
        end)
    end
    if Frame == "StepR" then
        local eff = VFX.DropKick.step2:Clone()
        eff.Parent = workspace.World.Visuals
        eff.CFrame = Character.HumanoidRootPart.CFrame * CFrame.new(0, -1, -2)
        for _, v in eff:GetDescendants() do
            if v:IsA("ParticleEmitter") then
                v:Emit(v:GetAttribute("EmitCount"))
            end
        end
        task.delay(.15, function()
            jumpdkmesh(Character.HumanoidRootPart.CFrame, workspace.World.Visuals)
        end)
        task.delay(3, function()
            eff:Destroy()
        end)
    end
    if Frame == "Start" then
        local eff = VFX.DropKick.grndemit:Clone()
        eff.Parent = workspace.World.Visuals
        eff.CFrame = Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, -3)
        for _, v in eff:GetDescendants() do
            if v:IsA("ParticleEmitter") then
                v:Emit(v:GetAttribute("EmitCount"))
            end
        end
        startdkmesh(Character.HumanoidRootPart.CFrame, workspace.World.Visuals)
        task.delay(3, function()
            eff:Destroy()
        end)
    end
end

local function dkimpactmesh(CF: CFrame, Parent: Instance)
 
	-- Base Setup 

	if CF then
		if typeof(CF) == "Vector3" then
			CF = CFrame.new(CF)
		elseif typeof(CF) ~= "CFrame" then
			CF = nil
		end
	end

	if not Parent then
		local cache = workspace:FindFirstChild("MeshCache")
		if not cache then
			cache = Instance.new("Folder")
			cache.Name = "MeshCache"
			cache.Parent = workspace
		end
		Parent = cache
	end

	local Main_CFrame = CF or CFrame.new(0,0,0)

	-- Settings

	local Visual_Directory = {
		["Hit"] = Replicated.Assets.VFX.DropKick.Expo.Hit,
		["Wind2Impact"] = Replicated.Assets.VFX.DropKick.Expo.Wind2Impact,
		["Hmm"] = Replicated.Assets.VFX.DropKick.Expo.Hmm,
		["Wabius"] = Replicated.Assets.VFX.DropKick.Expo.Wabius,
		["Impact"] = Replicated.Assets.VFX.DropKick.Expo.Impact
	} :: {[string] : Instance}

	local Visual_Data = {
		[Visual_Directory["Hit"]] = {
			General = {
				Offset = CFrame.new(2.17189991e-05, -4.03909416e-06, -8.70697021, -2.1130063e-08, -1.00000012, -2.98023224e-08, -1.3202083e-08, -2.98023224e-08, -1, 1, 2.1130063e-08, 1.3202083e-08),
				Tween_Duration = 0.2,
				Transparency = 0.83,
			},

			BasePart = {
				Property = {
					Size = Vector3.new(4.946621417999268, 9.642217636108398, 9.755118370056152),
					CFrame = Main_CFrame * CFrame.new(2.08466317e-05, -2.61158402e-06, -10.0375061, 2.50724243e-05, 0.819323659, -0.573331594, -1.30964208e-05, 0.573331594, 0.81932354, 1, -1.31081006e-05, 2.50948542e-05),
					Color = Color3.new(0.639216, 0.635294, 0.647059),
					Transparency = 1,
				},
				Tween = {
					Easing_Direction = Enum.EasingDirection.Out,
					Easing_Style = Enum.EasingStyle.Cubic,
				},
			},

			Mesh = {
				Property = {
					Offset = Vector3.new(0, 0, 0),
					Scale = Vector3.new(0.342010498046875, 0.5067828297615051, 0.49523887038230896),
					VertexColor = Vector3.new(1, 1, 1),
				},
				Tween = {
					Easing_Direction = Enum.EasingDirection.Out,
					Easing_Style = Enum.EasingStyle.Cubic,
				},
			},

			Decal = {
				Property = {
					Color3 = Color3.new(1, 1, 1),
					Transparency = 1,
				},
				Tween = {
					Easing_Direction = Enum.EasingDirection.Out,
					Easing_Style = Enum.EasingStyle.Cubic,
				},
			},
		},

		[Visual_Directory["Hmm"]] = {
			General = {
				Offset = CFrame.new(1.9835823e-05, -9.57533302e-07, -11.5791931, 1.00000012, -2.1130063e-08, 0, 2.98023224e-08, -1.32411373e-07, -1.00000024, -2.1130063e-08, 1.00000012, -1.06007263e-07),
				Tween_Duration = 0.3,
				Transparency = 0.93,
			},

			BasePart = {
				Property = {
					Size = Vector3.new(14.12632942199707, 25.388097763061523, 14.642675399780273),
					CFrame = Main_CFrame * CFrame.new(-7.87615209e-05, -8.10472375e-06, -5.84924316, -0.438457578, 6.34521029e-07, -0.898751974, -0.898752093, -1.08608572e-06, 0.438457429, -6.34521029e-07, 1, 1.08608572e-06),
					Color = Color3.new(0.639216, 0.635294, 0.647059),
					Transparency = 1,
				},
				Tween = {
					Easing_Direction = Enum.EasingDirection.Out,
					Easing_Style = Enum.EasingStyle.Cubic,
				},
			},

		},

		[Visual_Directory["Impact"]] = {
			General = {
				Offset = CFrame.new(0.940451801, -2.95042992e-06, -10.5965281, -0.861130595, 2.17288488e-07, -0.508384168, -0.508384228, -8.47667081e-07, 0.861130357, -2.135111e-07, 1, 7.74233797e-07),
				Tween_Duration = 0.3,
				Transparency = 0.5,
			},

			BasePart = {
				Property = {
					Size = Vector3.new(15.719278335571289, 2.602825403213501, 7.8596391677856445),
					CFrame = Main_CFrame * CFrame.new(1.54823301e-05, -6.16447596e-06, -13.1170959, 0.929220438, -1.16738374e-05, 0.369526118, 0.369526148, 6.08431437e-05, -0.929220438, -1.16772217e-05, 1, 6.08608025e-05),
					Color = Color3.new(0.639216, 0.635294, 0.647059),
					Transparency = 1,
				},
				Tween = {
					Easing_Direction = Enum.EasingDirection.Out,
					Easing_Style = Enum.EasingStyle.Cubic,
				},
			},

			Mesh = {
				Property = {
					Offset = Vector3.new(0, 1.746412992477417, 0),
					Scale = Vector3.new(-0.0982455164194107, -0.07808476686477661, -0.0982455164194107),
					VertexColor = Vector3.new(1, 1, 1),
				},
				Tween = {
					Easing_Direction = Enum.EasingDirection.Out,
					Easing_Style = Enum.EasingStyle.Cubic,
				},
			},

			Decal = {
				Property = {
					Color3 = Color3.new(1, 1, 1),
					Transparency = 1,
				},
				Tween = {
					Easing_Direction = Enum.EasingDirection.Out,
					Easing_Style = Enum.EasingStyle.Cubic,
				},
			},
		},

		[Visual_Directory["Wabius"]] = {
			General = {
				Offset = CFrame.new(2.20491256e-05, -4.57930128e-06, -8.20346069, -2.1130063e-08, 1.00000012, 2.98023224e-08, -1.3202083e-08, 2.98023224e-08, 1, 1, -2.1130063e-08, -1.3202083e-08),
				Tween_Duration = 0.3,
				Transparency = 0.5,
			},

			BasePart = {
				Property = {
					Size = Vector3.new(10.199556350708008, 12.77884292602539, 12.792318344116211),
					CFrame = Main_CFrame * CFrame.new(2.20491256e-05, -4.57930128e-06, -8.20346069, -4.69895931e-05, -0.442492217, 0.896772504, 1.09391485e-05, -0.896772504, -0.442492157, 1.00000012, -1.0931165e-05, 4.68957478e-05),
					Color = Color3.new(0.639216, 0.635294, 0.647059),
					Transparency = 1,
				},
				Tween = {
					Easing_Direction = Enum.EasingDirection.Out,
					Easing_Style = Enum.EasingStyle.Cubic,
				},
			},

			Mesh = {
				Property = {
					Offset = Vector3.new(0, 0, 0),
					Scale = Vector3.new(0.44617053866386414, 0.4249914884567261, 0.4109579026699066),
					VertexColor = Vector3.new(1, 1, 1),
				},
				Tween = {
					Easing_Direction = Enum.EasingDirection.Out,
					Easing_Style = Enum.EasingStyle.Cubic,
				},
			},

			Decal = {
				Property = {
					Color3 = Color3.new(1, 1, 1),
					Transparency = 1,
				},
				Tween = {
					Easing_Direction = Enum.EasingDirection.Out,
					Easing_Style = Enum.EasingStyle.Cubic,
				},
			},
		},

		[Visual_Directory["Wind2Impact"]] = {
			General = {
				Offset = CFrame.new(5.25439282e-06, 3.7327427e-06, 2.91195679, -2.1130063e-08, 2.98023224e-08, -1.00000012, -1.3202083e-08, 1, -2.98023224e-08, 1, -1.3202083e-08, 2.1130063e-08),
				Tween_Duration = 0.3,
				Transparency = 0.5,
			},

			BasePart = {
				Property = {
					Size = Vector3.new(14.776262283325195, 30.17328643798828, 30.17328643798828),
					CFrame = Main_CFrame * CFrame.new(2.25563508e-05, -5.40930614e-06, -7.42984009, -2.1130063e-08, 2.98023224e-08, -1.00000012, -1.3202083e-08, 1, -2.98023224e-08, 1, -1.3202083e-08, 2.1130063e-08),
					Color = Color3.new(0.639216, 0.635294, 0.647059),
					Transparency = 1,
				},
				Tween = {
					Easing_Direction = Enum.EasingDirection.Out,
					Easing_Style = Enum.EasingStyle.Cubic,
				},
			},

			Mesh = {
				Property = {
					Offset = Vector3.new(0, 0, 0),
					Scale = Vector3.new(0.40285396575927734, 0.5804046392440796, 0.5804046392440796),
					VertexColor = Vector3.new(1, 1, 1),
				},
				Tween = {
					Easing_Direction = Enum.EasingDirection.Out,
					Easing_Style = Enum.EasingStyle.Cubic,
				},
			},

			Decal = {
				Property = {
					Color3 = Color3.new(1, 1, 1),
					Transparency = 1,
				},
				Tween = {
					Easing_Direction = Enum.EasingDirection.Out,
					Easing_Style = Enum.EasingStyle.Cubic,
				},
			},
		},

	}

	for Origin : any, Data in pairs(Visual_Data) do
		if not Origin or not Origin:IsDescendantOf(game) or not Origin:FindFirstChild("Start") then continue end

		-- Build

		local function Emit()
			local Visual = Origin.Start:Clone()
			Visual.Name = Origin.Name
			Visual.Transparency = Data.General.Transparency
			if Visual:FindFirstChildOfClass("Decal") then Visual:FindFirstChildOfClass("Decal").Transparency = Data.General.Transparency Visual.Transparency = 1 end
			Visual.Anchored = true
			Visual.CanCollide = false
			Visual.CanQuery = false
			Visual.CanTouch = false
			Visual.Locked = true
			Visual.CFrame = Main_CFrame * Data.General.Offset
			Visual.Parent = Parent

			-- Initialize

			game:GetService("TweenService"):Create(Visual, TweenInfo.new(Data.General.Tween_Duration, Data.BasePart.Tween.Easing_Style, Data.BasePart.Tween.Easing_Direction), Data.BasePart.Property):Play()
			if Data.Decal then game:GetService("TweenService"):Create(Visual:FindFirstChildOfClass("Decal"), TweenInfo.new(Data.General.Tween_Duration, Data.Decal.Tween.Easing_Style, Data.Decal.Tween.Easing_Direction), Data.Decal.Property):Play() end
			if Data.Mesh then game:GetService("TweenService"):Create(Visual:FindFirstChildOfClass("SpecialMesh"), TweenInfo.new(Data.General.Tween_Duration, Data.Mesh.Tween.Easing_Style, Data.Mesh.Tween.Easing_Direction), Data.Mesh.Property):Play() end

			-- Clean Up

			task.delay(Data.General.Tween_Duration,Visual.Destroy,Visual)
		end

		task.spawn(Emit)
	end

end

local function slamfunction(CF: Model, Parent: Instance)
    
	-- Base Setup 

	if CF then
		if typeof(CF) == "Vector3" then
			CF = CFrame.new(CF)
		elseif typeof(CF) ~= "CFrame" then
			CF = nil
		end
	end

	if not Parent then
		local cache = workspace:FindFirstChild("MeshCache")
		if not cache then
			cache = Instance.new("Folder")
			cache.Name = "MeshCache"
			cache.Parent = workspace
		end
		Parent = cache
	end

	local Main_CFrame = CF or CFrame.new(0,0,0)

	-- Settings

	local Visual_Directory = {
		["Mesh3"] = Replicated.Assets.VFX.DropKick.Slam.Mesh3,
		["Mesh2"] = Replicated.Assets.VFX.DropKick.Slam.Mesh2,
		["Mesh1"] = Replicated.Assets.VFX.DropKick.Slam.Mesh1
	} :: {[string] : Instance}

	local Visual_Data = {
		[Visual_Directory["Mesh1"]] = {
			General = {
				Offset = CFrame.new(-0.50005126, 1.30590403, 5.06259155, -1.00000048, -1.25807901e-07, -3.57627869e-07, 3.87430191e-07, -7.61742669e-09, 0.999999821, 1.55610195e-07, 1, -5.75477976e-09),
				Tween_Duration = 0.2,
				Transparency = 0.9,
			},

			BasePart = {
				Property = {
					Size = Vector3.new(2.576066017150879, 0.18496616184711456, 1.2872881889343262),
					CFrame = Main_CFrame * CFrame.new(-0.223380089, 0.0401297025, 0.0192566067, -0.342042476, -1.25807901e-07, -0.939685106, -0.939683914, -7.61742669e-09, 0.342042983, 6.9798304e-08, 1, 1.47214109e-07),
					Color = Color3.new(0.639216, 0.635294, 0.647059),
					Transparency = 1,
				},
				Tween = {
					Easing_Direction = Enum.EasingDirection.Out,
					Easing_Style = Enum.EasingStyle.Cubic,
				},
			},

			Mesh = {
				Property = {
					Offset = Vector3.new(0, 0, 0),
					Scale = Vector3.new(-0.06441166996955872, -0.05582752823829651, -0.06441166996955872),
					VertexColor = Vector3.new(1, 1, 1),
				},
				Tween = {
					Easing_Direction = Enum.EasingDirection.Out,
					Easing_Style = Enum.EasingStyle.Cubic,
				},
			},

			Decal = {
				Property = {
					Color3 = Color3.new(3.92157, 3.92157, 3.92157),
					Transparency = 1,
				},
				Tween = {
					Easing_Direction = Enum.EasingDirection.Out,
					Easing_Style = Enum.EasingStyle.Cubic,
				},
			},
		},

		[Visual_Directory["Mesh2"]] = {
			General = {
				Offset = CFrame.new(0.0965180695, 0.397031188, 2.94351196, -1.00000036, -9.60055573e-08, -2.68220901e-07, 2.68220901e-07, -7.61743379e-09, 0.999999762, 9.60055573e-08, 1, -7.61743379e-09),
				Tween_Duration = 0.15,
				Transparency = 0.9,
			},

			BasePart = {
				Property = {
					Size = Vector3.new(2.05979061126709, 0.07920259237289429, 1.0288686752319336),
					CFrame = Main_CFrame * CFrame.new(0.11617212, 0.0453350432, -5.08432007, -0.499959409, -9.60055573e-08, -0.86604923, -0.866048455, -7.61743379e-09, 0.499959588, 5.4595958e-08, 1, 7.93370845e-08),
					Color = Color3.new(0.639216, 0.635294, 0.647059),
					Transparency = 1,
				},
				Tween = {
					Easing_Direction = Enum.EasingDirection.Out,
					Easing_Style = Enum.EasingStyle.Cubic,
				},
			},

			Mesh = {
				Property = {
					Offset = Vector3.new(0, 0, 0),
					Scale = Vector3.new(-0.0515027791261673, -0.02390671707689762, -0.05150279402732849),
					VertexColor = Vector3.new(1, 1, 1),
				},
				Tween = {
					Easing_Direction = Enum.EasingDirection.Out,
					Easing_Style = Enum.EasingStyle.Cubic,
				},
			},

			Decal = {
				Property = {
					Color3 = Color3.new(3.92157, 3.92157, 3.92157),
					Transparency = 1,
				},
				Tween = {
					Easing_Direction = Enum.EasingDirection.Out,
					Easing_Style = Enum.EasingStyle.Cubic,
				},
			},
		},

		[Visual_Directory["Mesh3"]] = {
			General = {
				Offset = CFrame.new(0.477027118, 0.349785596, 0.986083984, -1.00000036, -9.60055573e-08, -2.68220901e-07, 2.68220901e-07, -7.61743379e-09, 0.999999762, 9.60055573e-08, 1, -7.61743379e-09),
				Tween_Duration = 0.2,
				Transparency = 0.9,
			},

			BasePart = {
				Property = {
					Size = Vector3.new(2.7944533824920654, 0.07262186706066132, 1.3958337306976318),
					CFrame = Main_CFrame * CFrame.new(-0.0669433251, -0.183822751, -5.25750732, -1.00000036, -9.60055573e-08, -2.68220901e-07, 2.68220901e-07, -7.61743379e-09, 0.999999762, 9.60055573e-08, 1, -7.61743379e-09),
					Color = Color3.new(0.639216, 0.635294, 0.647059),
					Transparency = 1,
				},
				Tween = {
					Easing_Direction = Enum.EasingDirection.Out,
					Easing_Style = Enum.EasingStyle.Cubic,
				},
			},

			Mesh = {
				Property = {
					Offset = Vector3.new(0, 0, 0),
					Scale = Vector3.new(-0.06987220793962479, -0.021920373663306236, -0.06987222284078598),
					VertexColor = Vector3.new(1, 1, 1),
				},
				Tween = {
					Easing_Direction = Enum.EasingDirection.Out,
					Easing_Style = Enum.EasingStyle.Cubic,
				},
			},

			Decal = {
				Property = {
					Color3 = Color3.new(3.92157, 3.92157, 3.92157),
					Transparency = 1,
				},
				Tween = {
					Easing_Direction = Enum.EasingDirection.Out,
					Easing_Style = Enum.EasingStyle.Cubic,
				},
			},
		},

	}

	for Origin : any, Data in pairs(Visual_Data) do
		if not Origin or not Origin:IsDescendantOf(game) or not Origin:FindFirstChild("Start") then continue end

		-- Build

		local function Emit()
			local Visual = Origin.Start:Clone()
			Visual.Name = Origin.Name
			Visual.Transparency = Data.General.Transparency
			if Visual:FindFirstChildOfClass("Decal") then Visual:FindFirstChildOfClass("Decal").Transparency = Data.General.Transparency Visual.Transparency = 1 end
			Visual.Anchored = true
			Visual.CanCollide = false
			Visual.CanQuery = false
			Visual.CanTouch = false
			Visual.Locked = true
			Visual.CFrame = Main_CFrame * Data.General.Offset
			Visual.Parent = Parent

			-- Initialize

			game:GetService("TweenService"):Create(Visual, TweenInfo.new(Data.General.Tween_Duration, Data.BasePart.Tween.Easing_Style, Data.BasePart.Tween.Easing_Direction), Data.BasePart.Property):Play()
			if Data.Decal then game:GetService("TweenService"):Create(Visual:FindFirstChildOfClass("Decal"), TweenInfo.new(Data.General.Tween_Duration, Data.Decal.Tween.Easing_Style, Data.Decal.Tween.Easing_Direction), Data.Decal.Property):Play() end
			if Data.Mesh then game:GetService("TweenService"):Create(Visual:FindFirstChildOfClass("SpecialMesh"), TweenInfo.new(Data.General.Tween_Duration, Data.Mesh.Tween.Easing_Style, Data.Mesh.Tween.Easing_Direction), Data.Mesh.Property):Play() end

			-- Clean Up

			task.delay(Data.General.Tween_Duration,Visual.Destroy,Visual)
		end

		task.spawn(Emit)
	end

end

-- Store active particle effects for freezing
local ActiveDKImpactParticles = {}
local ActiveCameraEffects = {}

function Weapons.DKImpact(Character: Model, Variant: string, FreezeParticles: boolean)
	local color = Variant == "BF" and Color3.fromRGB(255, 0, 0) or Color3.fromRGB(97, 174, 239)

	-- Use Blackflash effect for BF variant, otherwise use lasthit
	local eff = Variant == "BF" and VFX.DropKick.Blackflash:Clone() or VFX.DropKick.lasthit:Clone()
	eff.Parent = workspace.World.Visuals
	eff.CFrame = Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, -3)

	-- Collect all particle emitters
	local particles = {}
	for _, v in eff:GetDescendants() do
		if v:IsA("ParticleEmitter") then
			if v:GetAttribute("Color") then
				v.Color = ColorSequence.new(color)
				if Variant == "BF" then
					v.LightEmission = -6
				end
			end
			v:Emit(v:GetAttribute("EmitCount"))
			table.insert(particles, v)
		end
	end

	dkimpactmesh(Character.HumanoidRootPart.CFrame, workspace.World.Visuals)
    slamfunction(Character.HumanoidRootPart.CFrame, workspace.World.Visuals)

	-- If we should freeze particles, store them and tween timescale to very slow
	if FreezeParticles then
		ActiveDKImpactParticles[Character] = particles

		-- Tween all particles to slower timescale (0.3 = 30% speed) over 0.5 seconds
		for _, particle in ipairs(particles) do
			local tween = TweenService:Create(particle, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				TimeScale = 0.3  -- Slowed down but still visible motion
			})
			tween:Play()
		end

		-- Only apply camera effect to local player's character
		if Character == Player.Character then
			-- Store original camera values
			local originalCameraType = Camera.CameraType
			local originalFOV = Camera.FieldOfView

			-- Lock camera
			Camera.CameraType = Enum.CameraType.Scriptable

			-- Disable character rotation from camera (prevent shift-lock movement)
			local humanoid = Character:FindFirstChild("Humanoid")
			local originalAutoRotate = humanoid and humanoid.AutoRotate or true
			if humanoid then
				humanoid.AutoRotate = false
			end

			-- Get character root part
			local rootPart = Character.HumanoidRootPart

			-- Create color correction for flash effect with inversion
			local colorCorrection = Instance.new("ColorCorrectionEffect")
			colorCorrection.Parent = game:GetService("Lighting")
			colorCorrection.Saturation = 0
			colorCorrection.TintColor = Color3.fromRGB(255, 255, 255)
			colorCorrection.Brightness = 0

			-- Fast snappy flash effect - JJK Black Flash style
			-- Flash 1: Instant bright white flash
			local flash1 = TweenService:Create(colorCorrection, TweenInfo.new(0.03, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Brightness = 0, -- Bright white flash
				Saturation = -1,
				Contrast = -30,
				TintColor = Color3.fromRGB(255,255,255)
			})

			-- Flash 2: Quick invert with red
			local flash2 = TweenService:Create(colorCorrection, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Brightness = -0.3, -- Inversion
				Saturation = -1, -- High saturation
				Contrast = -1,
				TintColor = Color3.fromRGB(255,255,255) -- Red tint
			})

			-- Flash 3: Quick fade out
			local flash3 = TweenService:Create(colorCorrection, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Saturation = -1,
				Brightness = -0.3,
				Contrast = -2,
				TintColor = Color3.fromRGB(255, 255, 255)
			})

			-- Store shake offset that will be applied in pan loop
			local shakeOffset = CFrame.new()

			-- Chain the flashes (fast JJK-style)
			flash1:Play()
			flash1.Completed:Connect(function()
				flash2:Play()
				flash2.Completed:Connect(function()
					flash3:Play()
					flash3.Completed:Connect(function()
						-- Start camera shake immediately after flash
						-- Impactful camera shake for ultimate move
						CamShake({
							Magnitude = 12, -- Very high magnitude for ultimate
							Frequency = 32,
							Damp = 0.003,
							Influence = Vector3.new(1.8, 2.2, 1.2),
							Location = Character.HumanoidRootPart.Position,
							Falloff = 150
						})

						colorCorrection:Destroy()
					end)
				end)
			end)

			-- Pan camera around character
			local panDuration = 1 -- Total duration of the freeze
			local startTime = os.clock()
			local panConnection
			local fovConnection

			-- Smoothly tween FOV out as camera pans (entire duration)
			local startFOV = originalFOV
			local targetFOV = originalFOV + 70  -- Increased for much more dramatic wide-angle effect
			local fovStartTime = os.clock()

			fovConnection = game:GetService("RunService").RenderStepped:Connect(function()
				local fovElapsed = os.clock() - fovStartTime
				local fovProgress = math.min(fovElapsed / panDuration, 1)

				-- Ease out the FOV zoom (starts fast, slows down)
				local easedFOVProgress = 1 - math.pow(1 - fovProgress, 3) -- Cubic ease out

				Camera.FieldOfView = startFOV + (targetFOV - startFOV) * easedFOVProgress
			end)

			panConnection = game:GetService("RunService").RenderStepped:Connect(function()
				local elapsed = os.clock() - startTime
				local progress = math.min(elapsed / panDuration, 1)

				-- Apply easing to camera pan (starts fast, slows down dramatically)
				local easedProgress = 1 - math.pow(1 - progress, 4) -- Quartic ease out for slower end

				-- Calculate rotation angle (180 degrees over the duration with easing)
				local horizontalAngle = math.rad(180) * easedProgress
				local verticalAngle = math.rad(15) * math.sin(easedProgress * math.pi) -- Slight up/down arc

				-- Get current character position (updates as they move)
				local currentCharPos = rootPart.Position

				-- Calculate camera offset from character (maintain distance)
				local distance = 12 -- Fixed distance for consistency
				local baseHeight = 3 -- Height above character

				-- Rotate around character at an angle
				local offset = CFrame.new(currentCharPos)
					* CFrame.Angles(verticalAngle, horizontalAngle, 0) -- Added vertical angle
					* CFrame.new(0, baseHeight, distance)

				-- Look at character's upper body, then apply shake offset if active
				local baseCFrame = CFrame.lookAt(offset.Position, currentCharPos + Vector3.new(0, 2, 0))
				Camera.CFrame = baseCFrame * shakeOffset
			end)

			-- Store cleanup data
			ActiveCameraEffects[Character] = {
				connection = panConnection,
				fovConnection = fovConnection,
				originalType = originalCameraType,
				originalFOV = originalFOV,
				originalAutoRotate = originalAutoRotate,
				humanoid = humanoid
			}
		end
	end

	task.delay(5, function()
		eff:Destroy()
	end)
end

function Weapons.DKImpactResume(Character: Model)
	-- Resume particles by tweening timescale back to 1
	local particles = ActiveDKImpactParticles[Character]
	if particles then
		for _, particle in ipairs(particles) do
			if particle and particle.Parent then
				local tween = TweenService:Create(particle, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
					TimeScale = 1
				})
				tween:Play()
			end
		end
		ActiveDKImpactParticles[Character] = nil
	end

	-- Resume camera if this is the local player's character
	if Character == Player.Character then
		local cameraData = ActiveCameraEffects[Character]
		if cameraData then
			-- Disconnect pan connection
			if cameraData.connection then
				cameraData.connection:Disconnect()
			end

			-- Disconnect FOV connection
			if cameraData.fovConnection then
				cameraData.fovConnection:Disconnect()
			end

			-- Restore AutoRotate
			if cameraData.humanoid then
				cameraData.humanoid.AutoRotate = cameraData.originalAutoRotate
			end

			-- Tween FOV back to original
			local fovTween = TweenService:Create(Camera, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				FieldOfView = cameraData.originalFOV
			})
			fovTween:Play()

			-- Restore camera type after FOV tween completes
			fovTween.Completed:Connect(function()
				Camera.CameraType = cameraData.originalType
			end)

			ActiveCameraEffects[Character] = nil
		end
	end
end

function Weapons.InputWindowHighlight(Character: Model, Action: string)
	-- Only apply to local player's character
	if Character ~= Player.Character then
		return
	end

	if Action == "Start" then
		-- Create highlight effect
		local highlight = Instance.new("Highlight")
		highlight.Name = "InputWindowHighlight"
		highlight.FillColor = Color3.fromRGB(255, 255, 0) -- Yellow
		highlight.OutlineColor = Color3.fromRGB(255, 200, 0)
		highlight.FillTransparency = 0.5
		highlight.OutlineTransparency = 0
		highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		highlight.Parent = Character

		-- Pulse effect
		local tweenInfo = TweenInfo.new(
			0.3, -- Duration
			Enum.EasingStyle.Sine,
			Enum.EasingDirection.InOut,
			-1, -- Repeat infinitely
			true -- Reverse
		)

		local tween = TweenService:Create(highlight, tweenInfo, {
			FillTransparency = 0.8
		})
		tween:Play()

	elseif Action == "Stop" then
		-- Remove highlight
		local highlight = Character:FindFirstChild("InputWindowHighlight")
		if highlight then
			highlight:Destroy()
		end
	end
end

-- Apply ragdoll and knockback effect (client-side visual)
function Weapons.BFKnockback(Target: Model, AttackerPosition: Vector3)
	-- This is the client-side visual effect
	-- The actual ragdoll state is managed by the server via CollectionService tags

	local humanoid = Target:FindFirstChild("Humanoid")
	local rootPart = Target:FindFirstChild("HumanoidRootPart")

	if not humanoid or not rootPart then
		return
	end

	-- Calculate knockback direction (opposite of hit direction)
	local direction = (rootPart.Position - AttackerPosition).Unit
	-- Create arc motion: horizontal knockback + upward velocity
	local horizontalPower = 50 -- Horizontal knockback strength
	local upwardPower = 30 -- Upward arc strength

	-- Create attachment for LinearVelocity if it doesn't exist
	local attachment = rootPart:FindFirstChild("RootAttachment")
	if not attachment then
		attachment = Instance.new("Attachment")
		attachment.Name = "RootAttachment"
		attachment.Parent = rootPart
	end

	-- Apply LinearVelocity for smooth arc motion
	local linearVelocity = Instance.new("LinearVelocity")
	linearVelocity.VectorVelocity = Vector3.new(
		direction.X * horizontalPower,
		upwardPower, -- Upward component for arc
		direction.Z * horizontalPower
	)
	linearVelocity.MaxForce = math.huge
	linearVelocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	linearVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
	linearVelocity.Attachment0 = attachment
	linearVelocity.Parent = rootPart

	-- Clean up LinearVelocity after arc completes
	game:GetService("Debris"):AddItem(linearVelocity, 0.8)
end

return Weapons