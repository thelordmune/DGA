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
local EmitModule = require(game.ReplicatedStorage.Modules.Utils.EmitModule)
local VFXCleanup = require(Replicated.Modules.Utils.VFXCleanup)
local RunService = game:GetService("RunService")
local Global = require(Replicated.Modules.Shared.Global)

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
local AB = require(Replicated.Modules.Utils.AymanBolt)
local RockMod = require(Replicated.Modules.Utils.RockMod)

local TInfo = TweenInfo.new(0.35, Enum.EasingStyle.Circular, Enum.EasingDirection.Out, 0)

local function safeDelayedDestroy(instance, delay)
	task.delay(delay, function()
		if instance and instance.Parent then
			instance:Destroy()
		end
	end)
end

local Weapons = {}

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
	if model:IsA("Model") and Players:GetPlayerFromCharacter(model) then return model end
	if not model:IsA("Model") then return model end

	if not isInNpcRegistryCamera(model) then
		return model
	end

	local clientCamera = nil
	for _, child in workspace:GetChildren() do
		if child.Name == "NpcRegistryCamera" and child:IsA("Camera") and child:GetAttribute("ClientOwned") then
			clientCamera = child
			break
		end
	end

	local chronoId = model:GetAttribute("ChronoId")
	if chronoId and clientCamera then
		local clientClone = clientCamera:FindFirstChild(tostring(chronoId), true)
		if clientClone and clientClone:IsA("Model") then
			return clientClone
		end
	end

	if clientCamera and model.Name then
		local byName = clientCamera:FindFirstChild(model.Name, true)
		if byName and byName:IsA("Model") then
			return byName
		end
	end

	return model
end

function Weapons.SpecialShake(magnitude: number, frequency: number?, location: Vector3?)
	-- Special camera shake for intense moments (even more impactful)
	CamShake({
		Magnitude = magnitude * 2, -- Double magnitude for special shakes
		Frequency = frequency or 30, -- Even higher frequency
		Damp = 0.004, -- Even slower dampening
		Influence = Vector3.new(1.5, 1.5, 1), -- Maximum influence
		Location = location or workspace.CurrentCamera.CFrame.Position,
		Falloff = 120
	})
end

function Weapons.GrandCleave(Character: Model, Frame: string, duration: number?)
	Character = resolveChronoModel(Character) :: Model
	if not Character or not Character:FindFirstChild("HumanoidRootPart") then return end
	if Frame == "Slash1" then
		local eff = VFX.Cleave.slash:Clone()
		eff.Parent = workspace.World.Visuals
		eff.CFrame = Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, -2) * CFrame.Angles(0, 0, math.rad(-15))
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
		eff.CFrame = Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, -1) * CFrame.Angles(0, 0, math.rad(-15))
		for _, v in eff:GetDescendants() do
			if v:IsA("ParticleEmitter") then
				v:Emit(v:GetAttribute("EmitCount"))
			end
		end
		local geff = VFX.Cleave.swingwooo:Clone()
		geff.Parent = workspace.World.Visuals
		geff.CFrame = Character.HumanoidRootPart.CFrame * CFrame.new(0, -2.5, 0)
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
		eff.CFrame = Character.HumanoidRootPart.CFrame * CFrame.new(0, 0.3, -2) * CFrame.Angles(0, 0, math.rad(15))
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

	local Main_CFrame = CF or CFrame.new(0, 0, 0)

	-- Settings

	local Visual_Directory = {
		["uhenable"] = Replicated.Assets.VFX.DropKick.Firstmeshwoosh.uhenable,
		["WindShockwaveenable"] = Replicated.Assets.VFX.DropKick.Firstmeshwoosh.WindShockwaveenable,
		["Shockwave2"] = Replicated.Assets.VFX.DropKick.Firstmeshwoosh.Shockwave2,
		["Mesh1"] = Replicated.Assets.VFX.DropKick.Firstmeshwoosh.Mesh1,
		["WindWave2"] = Replicated.Assets.VFX.DropKick.Firstmeshwoosh.WindWave2,
		["Mesh2"] = Replicated.Assets.VFX.DropKick.Firstmeshwoosh.Mesh2,
		["WindShockwave"] = Replicated.Assets.VFX.DropKick.Firstmeshwoosh.WindShockwave,
		["WindCoolSwirlenable"] = Replicated.Assets.VFX.DropKick.Firstmeshwoosh.WindCoolSwirlenable,
	} :: { [string]: Instance }

	local Visual_Data = {
		[Visual_Directory["Mesh1"]] = {
			General = {
				Offset = CFrame.new(0.906616211, -1.53215492, -0.56427002, -1, 0, 0, 0, 1, 0, 0, 0, -1),
				Tween_Duration = 0.6,
				Transparency = 0.45,
			},

			Features = { -- !CheckForFeature!
			}, -- !CheckForFeature!
			-- !CheckForFeature!
			BasePart = {
				Property = {
					Size = Vector3.new(1.2913484573364258, 0.04084079712629318, 0.6449999809265137),
					CFrame = Main_CFrame
						* CFrame.new(0.68460083, -3.26126003, -0.406341553, -1, 0, 0, 0, 1, 0, 0, 0, -1),
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

			Features = { -- !CheckForFeature!
			}, -- !CheckForFeature!
			-- !CheckForFeature!
			BasePart = {
				Property = {
					Size = Vector3.new(1.2970445156097412, 0.04987366497516632, 0.6478757858276367),
					CFrame = Main_CFrame * CFrame.new(
						-0.0406494141,
						-3.17667937,
						-0.517852783,
						-0.499959469,
						0,
						-0.866048813,
						0,
						1,
						0,
						0.866048813,
						0,
						-0.499959469
					),
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

			Features = { -- !CheckForFeature!
			}, -- !CheckForFeature!
			-- !CheckForFeature!
			BasePart = {
				Property = {
					Size = Vector3.new(0.8497866988182068, 0.8497866988182068, 0.8497866988182068),
					CFrame = Main_CFrame * CFrame.new(
						0,
						-3.68990231,
						-0.00396728516,
						0.829036474,
						0,
						0.559194624,
						0,
						1,
						0,
						-0.559194624,
						0,
						0.829036474
					),
					Color = Color3.new(0.639216, 0.635294, 0.647059),
					Transparency = 1,
				},
				Tween = {
					Easing_Direction = Enum.EasingDirection.Out,
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
				Offset = CFrame.new(
					0,
					-3.93539953,
					0.118011475,
					-0.949317455,
					1.63912773e-06,
					0.314318866,
					1.63912773e-06,
					-1,
					1.02519989e-05,
					0.314318866,
					1.01923943e-05,
					0.949317515
				),
				Tween_Duration = 3,
				Transparency = 0.9,
			},

			Features = { -- !CheckForFeature!
			}, -- !CheckForFeature!
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
					Easing_Direction = Enum.EasingDirection.Out,
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
					Easing_Direction = Enum.EasingDirection.Out,
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
					CFrame = Main_CFrame * CFrame.new(
						0,
						-3.52160978,
						-0.00396728516,
						-0.999848366,
						0,
						0.017436387,
						0,
						1,
						0,
						-0.017436387,
						0,
						-0.999848366
					),
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

	for Origin: any, Data in pairs(Visual_Data) do
		if not Origin or not Origin:IsDescendantOf(game) or not Origin:FindFirstChild("Start") then
			continue
		end

		-- Build

		local function Emit()
			local Visual = Origin.Start:Clone()
			Visual.Name = Origin.Name
			Visual.Transparency = Data.General.Transparency
			if Visual:FindFirstChildOfClass("Decal") then
				Visual:FindFirstChildOfClass("Decal").Transparency = Data.General.Transparency
				Visual.Transparency = 1
			end
			Visual.Anchored = true
			Visual.CanCollide = false
			Visual.CanQuery = false
			Visual.CanTouch = false
			Visual.Locked = true
			Visual.CFrame = Main_CFrame * Data.General.Offset
			Visual.Parent = Parent

			-- Initialize

			game:GetService("TweenService")
				:Create(
					Visual,
					TweenInfo.new(
						Data.General.Tween_Duration,
						Data.BasePart.Tween.Easing_Style,
						Data.BasePart.Tween.Easing_Direction
					),
					Data.BasePart.Property
				)
				:Play()
			if Data.Decal then
				game:GetService("TweenService")
					:Create(
						Visual:FindFirstChildOfClass("Decal"),
						TweenInfo.new(
							Data.General.Tween_Duration,
							Data.Decal.Tween.Easing_Style,
							Data.Decal.Tween.Easing_Direction
						),
						Data.Decal.Property
					)
					:Play()
			end
			if Data.Mesh then
				game:GetService("TweenService")
					:Create(
						Visual:FindFirstChildOfClass("SpecialMesh"),
						TweenInfo.new(
							Data.General.Tween_Duration,
							Data.Mesh.Tween.Easing_Style,
							Data.Mesh.Tween.Easing_Direction
						),
						Data.Mesh.Property
					)
					:Play()
			end

			-- Clean Up

			task.delay(Data.General.Tween_Duration, Visual.Destroy, Visual)
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

	local Main_CFrame = CF or CFrame.new(0, 0, 0)

	-- Settings

	local Visual_Directory = {
		["dramatic"] = Replicated.Assets.VFX.DropKick.Jump.out.dramatic,
		["Hmm3"] = Replicated.Assets.VFX.DropKick.Jump.out.Hmm3,
		["Wind"] = Replicated.Assets.VFX.DropKick.Jump.out.Wind,
		["ShootMesh"] = Replicated.Assets.VFX.DropKick.Jump.out.ShootMesh,
	} :: { [string]: Instance }

	local Visual_Data = {
		[Visual_Directory["Hmm3"]] = {
			General = {
				Offset = CFrame.new(
					-0.151153564,
					-4.32416344,
					-1.7925415,
					0,
					1.33629948e-21,
					-1,
					0,
					1,
					-1.33629948e-21,
					1,
					0,
					0
				),
				Tween_Duration = 0.25,
				Transparency = 0.95,
			},

			BasePart = {
				Property = {
					Size = Vector3.new(12.603195190429688, 15, 12.603195190429688),
					CFrame = Main_CFrame * CFrame.new(
						-0.151153564,
						-1.68119717,
						-1.79257202,
						0,
						1.33629948e-21,
						1,
						0,
						1,
						1.33629948e-21,
						-1,
						0,
						0
					),
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
				Offset = CFrame.new(
					-0.310913086,
					-0.587655067,
					-0.251373291,
					-1,
					1.33629948e-21,
					0,
					-1.33629948e-21,
					1,
					0,
					0,
					0,
					-1
				),
				Tween_Duration = 0.15,
				Transparency = 0.6,
			},

			BasePart = {
				Property = {
					Size = Vector3.new(1.585519790649414, 29.075138092041016, 1.493143081665039),
					CFrame = Main_CFrame * CFrame.new(
						-0.310913086,
						1.87844801,
						-0.195892334,
						-0.138841867,
						3.29315662e-05,
						-0.990314484,
						0.0143373907,
						0.999895215,
						-0.00197684765,
						0.990210772,
						-0.0144729614,
						-0.138827771
					),
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
				Offset = CFrame.new(
					-3.25473276e-21,
					-4.87126255,
					0,
					1,
					-2.00444926e-21,
					0,
					2.00444926e-21,
					-1,
					0,
					0,
					0,
					-1
				),
				Tween_Duration = 1.2,
				Transparency = 0.98,
			},

			BasePart = {
				Property = {
					Size = Vector3.new(29.16249656677246, 4.267792224884033, 28.24770736694336),
					CFrame = Main_CFrame * CFrame.new(
						-3.3484875e-21,
						-5.01158237,
						0,
						0,
						-2.00444926e-21,
						1,
						0,
						-1,
						2.00444926e-21,
						1,
						0,
						0
					),
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
				Offset = CFrame.new(
					-0.151153564,
					-5.32312918,
					-1.14996338,
					0,
					-1.33629948e-21,
					1,
					0,
					-1,
					1.33629948e-21,
					1,
					0,
					0
				),
				Tween_Duration = 0.1,
				Transparency = 0.9,
			},

			BasePart = {
				Property = {
					Size = Vector3.new(2.551072120666504, 19.071107864379883, 2.551072120666504),
					CFrame = Main_CFrame * CFrame.new(
						-0.151153564,
						-6.89178228,
						-1.14996338,
						0,
						-1.33629948e-21,
						1,
						0,
						-1,
						1.33629948e-21,
						1,
						0,
						0
					),
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

	for Origin: any, Data in pairs(Visual_Data) do
		if not Origin or not Origin:IsDescendantOf(game) or not Origin:FindFirstChild("Start") then
			continue
		end

		-- Build

		local function Emit()
			local Visual = Origin.Start:Clone()
			Visual.Name = Origin.Name
			Visual.Transparency = Data.General.Transparency
			if Visual:FindFirstChildOfClass("Decal") then
				Visual:FindFirstChildOfClass("Decal").Transparency = Data.General.Transparency
				Visual.Transparency = 1
			end
			Visual.Anchored = true
			Visual.CanCollide = false
			Visual.CanQuery = false
			Visual.CanTouch = false
			Visual.Locked = true
			Visual.CFrame = Main_CFrame * Data.General.Offset
			Visual.Parent = Parent

			-- Initialize

			game:GetService("TweenService")
				:Create(
					Visual,
					TweenInfo.new(
						Data.General.Tween_Duration,
						Data.BasePart.Tween.Easing_Style,
						Data.BasePart.Tween.Easing_Direction
					),
					Data.BasePart.Property
				)
				:Play()

			-- Clean Up

			task.delay(Data.General.Tween_Duration, Visual.Destroy, Visual)
		end

		task.spawn(Emit)
	end
end
function Weapons.DropKick(Character: Model, Frame: string)
	Character = resolveChronoModel(Character) :: Model
	if not Character or not Character:FindFirstChild("HumanoidRootPart") then return end
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
		task.delay(0.15, function()
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

	local Main_CFrame = CF or CFrame.new(0, 0, 0)

	-- Settings

	local Visual_Directory = {
		["Hit"] = Replicated.Assets.VFX.DropKick.Expo.Hit,
		["Wind2Impact"] = Replicated.Assets.VFX.DropKick.Expo.Wind2Impact,
		["Hmm"] = Replicated.Assets.VFX.DropKick.Expo.Hmm,
		["Wabius"] = Replicated.Assets.VFX.DropKick.Expo.Wabius,
		["Impact"] = Replicated.Assets.VFX.DropKick.Expo.Impact,
	} :: { [string]: Instance }

	local Visual_Data = {
		[Visual_Directory["Hit"]] = {
			General = {
				Offset = CFrame.new(
					2.17189991e-05,
					-4.03909416e-06,
					-8.70697021,
					-2.1130063e-08,
					-1.00000012,
					-2.98023224e-08,
					-1.3202083e-08,
					-2.98023224e-08,
					-1,
					1,
					2.1130063e-08,
					1.3202083e-08
				),
				Tween_Duration = 0.2,
				Transparency = 0.83,
			},

			BasePart = {
				Property = {
					Size = Vector3.new(4.946621417999268, 9.642217636108398, 9.755118370056152),
					CFrame = Main_CFrame * CFrame.new(
						2.08466317e-05,
						-2.61158402e-06,
						-10.0375061,
						2.50724243e-05,
						0.819323659,
						-0.573331594,
						-1.30964208e-05,
						0.573331594,
						0.81932354,
						1,
						-1.31081006e-05,
						2.50948542e-05
					),
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
				Offset = CFrame.new(
					1.9835823e-05,
					-9.57533302e-07,
					-11.5791931,
					1.00000012,
					-2.1130063e-08,
					0,
					2.98023224e-08,
					-1.32411373e-07,
					-1.00000024,
					-2.1130063e-08,
					1.00000012,
					-1.06007263e-07
				),
				Tween_Duration = 0.3,
				Transparency = 0.93,
			},

			BasePart = {
				Property = {
					Size = Vector3.new(14.12632942199707, 25.388097763061523, 14.642675399780273),
					CFrame = Main_CFrame * CFrame.new(
						-7.87615209e-05,
						-8.10472375e-06,
						-5.84924316,
						-0.438457578,
						6.34521029e-07,
						-0.898751974,
						-0.898752093,
						-1.08608572e-06,
						0.438457429,
						-6.34521029e-07,
						1,
						1.08608572e-06
					),
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
				Offset = CFrame.new(
					0.940451801,
					-2.95042992e-06,
					-10.5965281,
					-0.861130595,
					2.17288488e-07,
					-0.508384168,
					-0.508384228,
					-8.47667081e-07,
					0.861130357,
					-2.135111e-07,
					1,
					7.74233797e-07
				),
				Tween_Duration = 0.3,
				Transparency = 0.5,
			},

			BasePart = {
				Property = {
					Size = Vector3.new(15.719278335571289, 2.602825403213501, 7.8596391677856445),
					CFrame = Main_CFrame * CFrame.new(
						1.54823301e-05,
						-6.16447596e-06,
						-13.1170959,
						0.929220438,
						-1.16738374e-05,
						0.369526118,
						0.369526148,
						6.08431437e-05,
						-0.929220438,
						-1.16772217e-05,
						1,
						6.08608025e-05
					),
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
				Offset = CFrame.new(
					2.20491256e-05,
					-4.57930128e-06,
					-8.20346069,
					-2.1130063e-08,
					1.00000012,
					2.98023224e-08,
					-1.3202083e-08,
					2.98023224e-08,
					1,
					1,
					-2.1130063e-08,
					-1.3202083e-08
				),
				Tween_Duration = 0.3,
				Transparency = 0.5,
			},

			BasePart = {
				Property = {
					Size = Vector3.new(10.199556350708008, 12.77884292602539, 12.792318344116211),
					CFrame = Main_CFrame * CFrame.new(
						2.20491256e-05,
						-4.57930128e-06,
						-8.20346069,
						-4.69895931e-05,
						-0.442492217,
						0.896772504,
						1.09391485e-05,
						-0.896772504,
						-0.442492157,
						1.00000012,
						-1.0931165e-05,
						4.68957478e-05
					),
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
				Offset = CFrame.new(
					5.25439282e-06,
					3.7327427e-06,
					2.91195679,
					-2.1130063e-08,
					2.98023224e-08,
					-1.00000012,
					-1.3202083e-08,
					1,
					-2.98023224e-08,
					1,
					-1.3202083e-08,
					2.1130063e-08
				),
				Tween_Duration = 0.3,
				Transparency = 0.5,
			},

			BasePart = {
				Property = {
					Size = Vector3.new(14.776262283325195, 30.17328643798828, 30.17328643798828),
					CFrame = Main_CFrame * CFrame.new(
						2.25563508e-05,
						-5.40930614e-06,
						-7.42984009,
						-2.1130063e-08,
						2.98023224e-08,
						-1.00000012,
						-1.3202083e-08,
						1,
						-2.98023224e-08,
						1,
						-1.3202083e-08,
						2.1130063e-08
					),
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

	for Origin: any, Data in pairs(Visual_Data) do
		if not Origin or not Origin:IsDescendantOf(game) or not Origin:FindFirstChild("Start") then
			continue
		end

		-- Build

		local function Emit()
			local Visual = Origin.Start:Clone()
			Visual.Name = Origin.Name
			Visual.Transparency = Data.General.Transparency
			if Visual:FindFirstChildOfClass("Decal") then
				Visual:FindFirstChildOfClass("Decal").Transparency = Data.General.Transparency
				Visual.Transparency = 1
			end
			Visual.Anchored = true
			Visual.CanCollide = false
			Visual.CanQuery = false
			Visual.CanTouch = false
			Visual.Locked = true
			Visual.CFrame = Main_CFrame * Data.General.Offset
			Visual.Parent = Parent

			-- Initialize

			game:GetService("TweenService")
				:Create(
					Visual,
					TweenInfo.new(
						Data.General.Tween_Duration,
						Data.BasePart.Tween.Easing_Style,
						Data.BasePart.Tween.Easing_Direction
					),
					Data.BasePart.Property
				)
				:Play()
			if Data.Decal then
				game:GetService("TweenService")
					:Create(
						Visual:FindFirstChildOfClass("Decal"),
						TweenInfo.new(
							Data.General.Tween_Duration,
							Data.Decal.Tween.Easing_Style,
							Data.Decal.Tween.Easing_Direction
						),
						Data.Decal.Property
					)
					:Play()
			end
			if Data.Mesh then
				game:GetService("TweenService")
					:Create(
						Visual:FindFirstChildOfClass("SpecialMesh"),
						TweenInfo.new(
							Data.General.Tween_Duration,
							Data.Mesh.Tween.Easing_Style,
							Data.Mesh.Tween.Easing_Direction
						),
						Data.Mesh.Property
					)
					:Play()
			end

			-- Clean Up

			task.delay(Data.General.Tween_Duration, Visual.Destroy, Visual)
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

	local Main_CFrame = CF or CFrame.new(0, 0, 0)

	-- Settings

	local Visual_Directory = {
		["Mesh3"] = Replicated.Assets.VFX.DropKick.Slam.Mesh3,
		["Mesh2"] = Replicated.Assets.VFX.DropKick.Slam.Mesh2,
		["Mesh1"] = Replicated.Assets.VFX.DropKick.Slam.Mesh1,
	} :: { [string]: Instance }

	local Visual_Data = {
		[Visual_Directory["Mesh1"]] = {
			General = {
				Offset = CFrame.new(
					-0.50005126,
					1.30590403,
					5.06259155,
					-1.00000048,
					-1.25807901e-07,
					-3.57627869e-07,
					3.87430191e-07,
					-7.61742669e-09,
					0.999999821,
					1.55610195e-07,
					1,
					-5.75477976e-09
				),
				Tween_Duration = 0.2,
				Transparency = 0.9,
			},

			BasePart = {
				Property = {
					Size = Vector3.new(2.576066017150879, 0.18496616184711456, 1.2872881889343262),
					CFrame = Main_CFrame * CFrame.new(
						-0.223380089,
						0.0401297025,
						0.0192566067,
						-0.342042476,
						-1.25807901e-07,
						-0.939685106,
						-0.939683914,
						-7.61742669e-09,
						0.342042983,
						6.9798304e-08,
						1,
						1.47214109e-07
					),
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
				Offset = CFrame.new(
					0.0965180695,
					0.397031188,
					2.94351196,
					-1.00000036,
					-9.60055573e-08,
					-2.68220901e-07,
					2.68220901e-07,
					-7.61743379e-09,
					0.999999762,
					9.60055573e-08,
					1,
					-7.61743379e-09
				),
				Tween_Duration = 0.15,
				Transparency = 0.9,
			},

			BasePart = {
				Property = {
					Size = Vector3.new(2.05979061126709, 0.07920259237289429, 1.0288686752319336),
					CFrame = Main_CFrame * CFrame.new(
						0.11617212,
						0.0453350432,
						-5.08432007,
						-0.499959409,
						-9.60055573e-08,
						-0.86604923,
						-0.866048455,
						-7.61743379e-09,
						0.499959588,
						5.4595958e-08,
						1,
						7.93370845e-08
					),
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
				Offset = CFrame.new(
					0.477027118,
					0.349785596,
					0.986083984,
					-1.00000036,
					-9.60055573e-08,
					-2.68220901e-07,
					2.68220901e-07,
					-7.61743379e-09,
					0.999999762,
					9.60055573e-08,
					1,
					-7.61743379e-09
				),
				Tween_Duration = 0.2,
				Transparency = 0.9,
			},

			BasePart = {
				Property = {
					Size = Vector3.new(2.7944533824920654, 0.07262186706066132, 1.3958337306976318),
					CFrame = Main_CFrame * CFrame.new(
						-0.0669433251,
						-0.183822751,
						-5.25750732,
						-1.00000036,
						-9.60055573e-08,
						-2.68220901e-07,
						2.68220901e-07,
						-7.61743379e-09,
						0.999999762,
						9.60055573e-08,
						1,
						-7.61743379e-09
					),
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

	for Origin: any, Data in pairs(Visual_Data) do
		if not Origin or not Origin:IsDescendantOf(game) or not Origin:FindFirstChild("Start") then
			continue
		end

		-- Build

		local function Emit()
			local Visual = Origin.Start:Clone()
			Visual.Name = Origin.Name
			Visual.Transparency = Data.General.Transparency
			if Visual:FindFirstChildOfClass("Decal") then
				Visual:FindFirstChildOfClass("Decal").Transparency = Data.General.Transparency
				Visual.Transparency = 1
			end
			Visual.Anchored = true
			Visual.CanCollide = false
			Visual.CanQuery = false
			Visual.CanTouch = false
			Visual.Locked = true
			Visual.CFrame = Main_CFrame * Data.General.Offset
			Visual.Parent = Parent

			-- Initialize

			game:GetService("TweenService")
				:Create(
					Visual,
					TweenInfo.new(
						Data.General.Tween_Duration,
						Data.BasePart.Tween.Easing_Style,
						Data.BasePart.Tween.Easing_Direction
					),
					Data.BasePart.Property
				)
				:Play()
			if Data.Decal then
				game:GetService("TweenService")
					:Create(
						Visual:FindFirstChildOfClass("Decal"),
						TweenInfo.new(
							Data.General.Tween_Duration,
							Data.Decal.Tween.Easing_Style,
							Data.Decal.Tween.Easing_Direction
						),
						Data.Decal.Property
					)
					:Play()
			end
			if Data.Mesh then
				game:GetService("TweenService")
					:Create(
						Visual:FindFirstChildOfClass("SpecialMesh"),
						TweenInfo.new(
							Data.General.Tween_Duration,
							Data.Mesh.Tween.Easing_Style,
							Data.Mesh.Tween.Easing_Direction
						),
						Data.Mesh.Property
					)
					:Play()
			end

			-- Clean Up

			task.delay(Data.General.Tween_Duration, Visual.Destroy, Visual)
		end

		task.spawn(Emit)
	end
end

-- Store active particle effects for freezing
local ActiveDKImpactParticles = {}
local ActiveCameraEffects = {}

function Weapons.DKImpact(Character: Model, Variant: string, FreezeParticles: boolean)
	Character = resolveChronoModel(Character) :: Model
	if not Character or not Character:FindFirstChild("HumanoidRootPart") then return end
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

	-- Register VFX with cleanup system
	VFXCleanup.RegisterVFX(Character, eff)

	-- If we should freeze particles, store them and tween timescale to very slow
	if FreezeParticles then
		ActiveDKImpactParticles[Character] = particles

		-- Tween all particles to slower timescale (0.3 = 30% speed) over 0.5 seconds
		for _, particle in ipairs(particles) do
			local tween =
				TweenService:Create(particle, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					TimeScale = 0.3, -- Slowed down but still visible motion
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
			local flash1 = TweenService:Create(
				colorCorrection,
				TweenInfo.new(0.03, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{
					Brightness = 0, -- Bright white flash
					Saturation = -1,
					Contrast = -30,
					TintColor = Color3.fromRGB(255, 255, 255),
				}
			)

			-- Flash 2: Quick invert with red
			local flash2 = TweenService:Create(
				colorCorrection,
				TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{
					Brightness = -0.3, -- Inversion
					Saturation = -1, -- High saturation
					Contrast = -1,
					TintColor = Color3.fromRGB(255, 255, 255), -- Red tint
				}
			)

			-- Flash 3: Quick fade out
			local flash3 = TweenService:Create(
				colorCorrection,
				TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{
					Saturation = -1,
					Brightness = -0.3,
					Contrast = -2,
					TintColor = Color3.fromRGB(255, 255, 255),
				}
			)

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
							Falloff = 150,
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
			local targetFOV = originalFOV + 70 -- Increased for much more dramatic wide-angle effect
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
				humanoid = humanoid,
			}
		end
	end

	task.delay(5, function()
		eff:Destroy()
	end)
end

function Weapons.DKImpactResume(Character: Model)
	Character = resolveChronoModel(Character) :: Model
	if not Character then return end
	-- Resume particles by tweening timescale back to 1
	local particles = ActiveDKImpactParticles[Character]
	if particles then
		for _, particle in ipairs(particles) do
			if particle and particle.Parent then
				local tween =
					TweenService:Create(particle, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
						TimeScale = 1,
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
			local fovTween =
				TweenService:Create(Camera, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
					FieldOfView = cameraData.originalFOV,
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
	Character = resolveChronoModel(Character) :: Model
	-- Only apply to local player's character
	if not Character or Character ~= Player.Character then
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
			FillTransparency = 0.8,
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
	Target = resolveChronoModel(Target) :: Model
	-- This is the client-side visual effect
	-- The actual ragdoll state is managed by the server via CollectionService tags

	if not Target then return end
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

function Weapons.WhirlWind(Character: Model, Frame: string)
	Character = resolveChronoModel(Character) :: Model
	if not Character or not Character:FindFirstChild("HumanoidRootPart") then return end
	local Weapon: BasePart = Character:FindFirstChild("Handle")
	print("fired" .. Frame)
	if Frame == "Start" then
		EmitModule.emit(Weapon.Blade.az)
		EmitModule.emit(Weapon.Blade.Dustdrag)
	end
	if Frame == "Jump" then
		local jump = Replicated.Assets.VFX.WhirlWind.jump:Clone()
		jump.CFrame = Character.HumanoidRootPart.CFrame * CFrame.new(0, -2, 0)
		jump.Parent = workspace.World.Visuals
		EmitModule.emit(jump)
	end
	if Frame == "TT" then
		local function toggleTrails(enabled)
			for _, descendant in Weapon:GetDescendants() do
				if descendant:IsA("Trail") then
					descendant.Enabled = enabled
				end
			end
		end

		toggleTrails(true)

		wait(0.112)

		toggleTrails(false)
	end
	if Frame == "SS" then
		local spin = Replicated.Assets.VFX.WhirlWind.spinnn:Clone()
		local slashslam = Replicated.Assets.VFX.WhirlWind.slashslam:Clone()
		spin:PivotTo(Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, -2) * CFrame.Angles(0, 0, math.rad(90)))
		slashslam.CFrame = Character.HumanoidRootPart.CFrame * CFrame.new(1, 0, 0) * CFrame.Angles(0,0, math.rad(90))
		spin.Parent = workspace.World.Visuals
		slashslam.Parent = workspace.World.Visuals
		EmitModule.emit(spin)
		EmitModule.emit(slashslam)
	end
	if Frame == "TTR" then
		EmitModule.emit(Weapon.Blade.Move2Startup)

		local function toggleTrails(enabled)
			for _, descendant in Weapon:GetDescendants() do
				if descendant:IsA("Trail") then
					descendant.Enabled = enabled
				end
			end
		end

		toggleTrails(true)

		wait(0.8)

		toggleTrails(false)
	end

	if Frame == "SS2" then
		local slashslam = Replicated.Assets.VFX.WhirlWind.slashslam:Clone()
		slashslam.CFrame = Character.HumanoidRootPart.CFrame * CFrame.new(1, 0, 0) * CFrame.Angles(0,0,math.rad(90))
		slashslam.Parent = workspace.World.Visuals
		EmitModule.emit(slashslam)
	end
	if Frame == "End" then
		local slammesh = Replicated.Assets.VFX.WhirlWind.slammeshh:Clone()
		local slam = Replicated.Assets.VFX.WhirlWind.Slam:Clone()
		slammesh:PivotTo(Character.HumanoidRootPart.CFrame * CFrame.new(0, -2, -2))
		slam.CFrame = Character.HumanoidRootPart.CFrame * CFrame.new(0, -2, 0)
		slammesh.Parent = workspace.World.Visuals
		slam.Parent = workspace.World.Visuals
		EmitModule.emit(slammesh)
		EmitModule.emit(slam)
	end
end

function Weapons.RapidThrust(Character: Model, Frame: string)
	Character = resolveChronoModel(Character) :: Model
	if not Character or not Character:FindFirstChild("HumanoidRootPart") then return end
	local eff = Replicated.Assets.VFX.RT:Clone()
	eff.Parent = workspace.World.Visuals
	eff:PivotTo(Character.HumanoidRootPart.CFrame * CFrame.new(0, -.5, -2) * CFrame.Angles(math.rad(180),0,math.rad(90)))
	local Weapon: BasePart = Character:FindFirstChild("Handle")
	if Frame == "1" then
		EmitModule.emit(eff.slash, eff.firstslashdragsmoke, Weapon.Blade.az)
	end
	if Frame == "2" then
		EmitModule.emit(eff.slash2, eff["2ndslashsmoke"], Weapon.Blade.az, eff.bloodhit)
	end
	if Frame == "3" or Frame == "4" or Frame == "5" or Frame == "6" or Frame == "7" or Frame == "8" or Frame == "9" or Frame == "10" or Frame == "11" or Frame == "12" then
		eff:PivotTo(Character.HumanoidRootPart.CFrame * CFrame.new(0, -.5, -2) * CFrame.Angles(math.rad(180),0,math.rad(90)))
		EmitModule.emit(eff.spearpoke, eff.bloodhitFASTPOKES)
		CamShake({
			Location = Character.PrimaryPart.Position,
			Magnitude = 4.5,
			Damp = 0.00005,
			Frequency = 20,
			Influence = Vector3.new(.55, 1, .55),
			Falloff = 65,
		})
	end
	if Frame == "14" then
		eff:PivotTo(Character.HumanoidRootPart.CFrame * CFrame.new(0, -.5, -2) * CFrame.Angles(math.rad(180),0,math.rad(90)))
		EmitModule.emit(eff.Slam, eff.slash3, eff.slashwoww, eff.Slammeshs)
CamShake({
			Location = Character.PrimaryPart.Position,
			Magnitude = 6.5,
			Damp = 0.00005,
			Frequency = 13,
			Influence = Vector3.new(.35, 1, .35),
			Falloff = 65,
		})
	end
end
local Effects = Replicated.Assets.VFX.CT
function Weapons.ChargedThrust(Character: Model, Frame: string)
	Character = resolveChronoModel(Character) :: Model
	if not Character or not Character:FindFirstChild("HumanoidRootPart") then return end
	local Weapon: BasePart = Character:FindFirstChild("Handle")
	

	if Frame == "1" then --.3 in moon --CAST
	for _, Beam in Weapon.Blade:GetDescendants() do
		if Beam:IsA("Trail") then
				Beam.Enabled = true
				task.delay(.5, function()
					Beam.Enabled = false
				end)
			end
	end
		local Smoke = Effects.Smoke:Clone()
		task.delay(4, Smoke.Destroy, Smoke)
		Smoke.CFrame = Character.PrimaryPart.CFrame
			* CFrame.new(-0.348693848, -2.5, -0.0576248169, 0, 0, -1, 0, 1, 0, 1, 0, 0)
		Smoke.Parent = workspace.World.Visuals
		EmitModule.emit(Smoke)
		EmitModule.emit(Weapon)

		task.wait(0.23)

		local Highlight = Effects.HighLight:Clone()
		task.delay(1, Highlight.Destroy, Highlight)
		Highlight.Parent = Character
		TweenService:Create(
			Highlight,
			TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{
				OutlineTransparency = 1,
				FillTransparency = 1,
				FillColor = Color3.new(0.266667, 0.266667, 0.266667),
				OutlineColor = Color3.new(1, 1, 1),
			}
		):Play()

		local Cast = Effects.Cast:Clone()
		task.delay(3, Cast.Destroy, Cast)
		Cast:PivotTo(
			Character.PrimaryPart.CFrame * CFrame.new(-0.205993652, -2.61796093, -1.27952766, 1, 0, 0, 0, 1, 0, 0, 0, 1)
		)
		Cast.Parent = workspace.World.Visuals
		EmitModule.emit(Cast)
		
		CamShake({
			Location = Character.PrimaryPart.Position,
			Magnitude = 4.5,
			Damp = 0.00005,
			Frequency = 20,
			Influence = Vector3.new(.55, 1, .55),
			Falloff = 65,
		})
	end

	if Frame == "2" then --.5 in moon -- FOLLOWUP IF THEY GET HIT
		local InitialHit = Effects.InitialHit:Clone()
		task.delay(4, InitialHit.Destroy, InitialHit)
		InitialHit.CFrame = Character.PrimaryPart.CFrame
			* CFrame.new(-0.615753174, -0.5, -6.82315445, 1, 0, 0, 0, 1, 0, 0, 0, 1)
		InitialHit.Parent = workspace.World.Visuals
		EmitModule.emit(InitialHit)
		
		CamShake({
			Location = Character.PrimaryPart.Position,
			Magnitude = 3.5,
			Damp = 0.00005,
			Frequency = 25,
			Influence = Vector3.new(.35, 1, .35),
			Falloff = 65,
		})
		
		task.wait(.4)

		local FinalHit = Effects.FinalHit:Clone()
		task.delay(4, FinalHit.Destroy, FinalHit)
		FinalHit.CFrame = Character.PrimaryPart.CFrame
			* CFrame.new(-0.785003662, 1.23792648, -9.0717926, 1, 0, 0, 0, 1, 0, 0, 0, 1)
		FinalHit.Parent = workspace.World.Visuals
		EmitModule.emit(FinalHit)
		
		CamShake({
			Location = Character.PrimaryPart.Position,
			Magnitude = 5.5,
			Damp = 0.00005,
			Frequency = 28,
			Influence = Vector3.new(.55, 1, .55),
			Falloff = 65,
		})
	end
end

function Weapons.Tapdance(Character: Model, Frame: string)
	Character = resolveChronoModel(Character) :: Model
	if not Character or not Character:FindFirstChild("HumanoidRootPart") then return end
	local eff = Replicated.Assets.VFX.Tapdance:Clone()
	eff.Parent = workspace.World.Visuals
	eff:PivotTo(Character.HumanoidRootPart.CFrame * CFrame.new(0, 0,-3.5))
	local conn
	conn = RunService.Heartbeat:Connect(function()
		if not eff or not eff.Parent or not Character or not Character.Parent then
			conn:Disconnect()
			return
		end
		eff:PivotTo(Character.HumanoidRootPart.CFrame * CFrame.new(0, 0,-3.5))
	end)

	-- Register VFX with cleanup system (will be cleaned up on death/cancellation)
	VFXCleanup.RegisterVFX(Character, eff, conn)

	local Weapon = Character:FindFirstChild("RightGun")
	if Frame == "1" then
		EmitModule.emit(eff.Start, eff.dashmesh)
	end
	if Frame == "2" then
		EmitModule.emit(eff.Start)
		-- for _, v in Weapon:GetDescendants() do if v:IsA("ParticleEmitter") then v:Emit(v:GetAttribute("EmitCount")) end end
		-- -- Make shootmesh transparent
		-- if eff.shootmesh then
		-- 	eff.shootmesh.Transparency = 1
		-- end
		EmitModule.emit(eff.Combined)
	end
	if Frame == "3" then

		-- for _, v in Weapon:GetDescendants() do if v:IsA("ParticleEmitter") then v:Emit(v:GetAttribute("EmitCount")) end end
		-- -- Make shootmesh transparent
		-- if eff.shootmesh then
		-- 	eff.shootmesh.Transparency = 1
		-- end
		EmitModule.emit(eff.Combined)
	end
	if Frame == "4" then
		-- for _, v in Weapon:GetDescendants() do if v:IsA("ParticleEmitter") then v:Emit(v:GetAttribute("EmitCount")) end end
		-- -- Make shootmesh transparent
		-- if eff.shootmesh then
		-- 	eff.shootmesh.Transparency = 1
		-- end
		EmitModule.emit(eff.Combined)
		CamShake({
			Location = Character.PrimaryPart.Position,
			Magnitude = 4.5,
			Damp = 0.00005,
			Frequency = 20,
			Influence = Vector3.new(.55, 1, .55),
			Falloff = 89,
		})
	end
	task.delay(4, function()
			conn:Disconnect()
			eff:Destroy()
		end)
end

function Weapons.Hellraiser(Character: Model, Frame: string)
	Character = resolveChronoModel(Character) :: Model
	if not Character or not Character:FindFirstChild("HumanoidRootPart") then return end
	local eff = Replicated.Assets.VFX.Hellraiser:Clone()
	eff.Parent = workspace.World.Visuals
	eff:PivotTo(Character.HumanoidRootPart.CFrame * CFrame.new(0, 0,-3.5))

	-- Register VFX with cleanup system (will be cleaned up on death/cancellation)
	VFXCleanup.RegisterVFX(Character, eff)

	local Weapon = Character:FindFirstChild("LeftGun")
	if Frame  == "1" then
		if Weapon then
			for _, v in Weapon:GetDescendants() do
				if v:IsA("ParticleEmitter") then
					v.Enabled = true
				end
			end
		end
	end
	if Frame  == "2" then
		if Weapon then
			for _, v in Weapon:GetDescendants() do
				if v:IsA("ParticleEmitter") then
					v.Enabled = false
				end
			end
		end
	end
	if Frame  == "3" then
		EmitModule.emit(eff.PullSmoke, eff.gunskill2)
		CamShake({
			Location = Character.PrimaryPart.Position,
			Magnitude = 6.5,
			Damp = 0.00005,
			Frequency = 35,
			Influence = Vector3.new(.55, .15, .55),
			Falloff = 89,
		})
	end
end

-- Scythe Critical Flash VFX
-- Creates a rapid color correction flash effect at frame 25 of scythe crit
-- Nen color helper functions for Scythe crit effects
local WHITE_THRESHOLD = 0.9

local function isWhiteColor(color: Color3): boolean
	return color.R >= WHITE_THRESHOLD and color.G >= WHITE_THRESHOLD and color.B >= WHITE_THRESHOLD
end

local function getColorVariation(baseColor: Color3): Color3
	local variationAmount = math.random() * 0.3 - 0.15 -- -0.15 to +0.15
	local h, s, v = baseColor:ToHSV()
	local newV = math.clamp(v + variationAmount, 0.2, 1.0)
	local newS = math.clamp(s + (variationAmount * 0.5), 0.1, 1.0)
	return Color3.fromHSV(h, newS, newV)
end

local function getPlayerNenColor(character: Model): Color3?
	local player = game.Players:GetPlayerFromCharacter(character)
	if not player then return nil end

	-- Get Nen data from player's replicated data
	local nenData = Global.GetData(player, "Nen")
	if not nenData then return nil end

	-- Check if player has Nen unlocked
	if not nenData.Unlocked then return nil end

	-- Get custom color (stored as {R, G, B} table)
	local colorData = nenData.Color
	if colorData and colorData.R and colorData.G and colorData.B then
		return Color3.fromRGB(colorData.R, colorData.G, colorData.B)
	end

	return nil
end

-- Apply Nen color to white particles/beams/trails on a character's weapon
function Weapons.ApplyNenColorToWeaponEffects(Character: Model)
	Character = resolveChronoModel(Character) :: Model
	if not Character then return end
	local nenColor = getPlayerNenColor(Character)
	if not nenColor then return end

	for _, descendant in Character:GetDescendants() do
		if descendant:GetAttribute("Weapon") then
			for _, effect in descendant:GetDescendants() do
				if effect:IsA("ParticleEmitter") then
					local colorSeq = effect.Color
					local keypoints = colorSeq.Keypoints
					local hasWhite = false
					for _, kp in keypoints do
						if isWhiteColor(kp.Value) then
							hasWhite = true
							break
						end
					end
					if hasWhite then
						local targetColor = getColorVariation(nenColor)
						local newKeypoints = {}
						for _, kp in keypoints do
							if isWhiteColor(kp.Value) then
								table.insert(newKeypoints, ColorSequenceKeypoint.new(kp.Time, targetColor))
							else
								table.insert(newKeypoints, kp)
							end
						end
						effect.Color = ColorSequence.new(newKeypoints)
					end
				elseif effect:IsA("Beam") or effect:IsA("Trail") then
					local colorSeq = effect.Color
					local keypoints = colorSeq.Keypoints
					local hasWhite = false
					for _, kp in keypoints do
						if isWhiteColor(kp.Value) then
							hasWhite = true
							break
						end
					end
					if hasWhite then
						local targetColor = getColorVariation(nenColor)
						local newKeypoints = {}
						for _, kp in keypoints do
							if isWhiteColor(kp.Value) then
								table.insert(newKeypoints, ColorSequenceKeypoint.new(kp.Time, targetColor))
							else
								table.insert(newKeypoints, kp)
							end
						end
						effect.Color = ColorSequence.new(newKeypoints)
					end
				end
			end
		end
	end
end

function Weapons.ScytheCritFlash(Character: Model)
	Character = resolveChronoModel(Character) :: Model
	if not Character then return end
	-- Apply Nen color to weapon effects if player has Nen unlocked
	Weapons.ApplyNenColorToWeaponEffects(Character)

	-- Camera shake on impact
	CamShake({
		Location = Character.PrimaryPart and Character.PrimaryPart.Position or Character:GetPivot().Position,
		Magnitude = 8,
		Damp = 0.003,
		Frequency = 25,
		Influence = Vector3.new(1, 1.2, 1),
		Falloff = 100,
	})
end

function Weapons.Deconstruct(Character: Model)
	local root = Character.HumanoidRootPart

	local eff = Replicated.Assets.VFX.Deconstruct:Clone()
	eff.CFrame = root.CFrame * CFrame.new(0, 0, -2) * CFrame.Angles(0, math.rad(-180), 0)
	eff.Anchored = true
	eff.CanCollide = false
	eff.Parent = workspace.World.Visuals
	for _, v in (eff:GetDescendants()) do
		if v:IsA("ParticleEmitter") then
			v:Emit(v:GetAttribute("EmitCount"))
		end
	end

	-- Camera shake like Rapid Thrust
	CamShake({
		Location = root.Position,
		Magnitude = 5.5,
		Damp = 0.00005,
		Frequency = 18,
		Influence = Vector3.new(0.45, 1, 0.45),
		Falloff = 65,
	})

	safeDelayedDestroy(eff, 3)
end
function Weapons.AlchemicAssault(Character: Model, Type: string)
	if Type == "Jump" then
		local root = Character.HumanoidRootPart
		local p = Replicated.Assets.VFX.Jump:Clone()
		p.CFrame = root.CFrame * CFrame.new(0, -2, 0)
		p.Anchored = true
		p.Parent = workspace.World.Visuals
		Debris:AddItem(p, 1)

		for _, v in (p:GetDescendants()) do
			if v:IsA("ParticleEmitter") then
				v:Emit(v:GetAttribute("EmitCount"))
			end
		end
	end
end

function Weapons.HandEffect(Character: Instance, Weapon: string, Combo: number)
	-- Resolve Chrono NPC models to client clones
	Character = resolveChronoModel(Character :: Model)
	if not Character then return end

	local effect = Replicated.Assets.VFX.HandEffect:Clone()
	local effect2 = Replicated.Assets.VFX.HandEffect:Clone()
	if Combo == 1 then
		for _, v in effect:GetDescendants() do
			if v:IsA("ParticleEmitter") then
				v.Parent = Character["Left Arm"].LeftGripAttachment
				v:Emit(v:GetAttribute("EmitCount"))
			end
		end
	end
	if Combo == 2 then
		for _, v in effect:GetDescendants() do
			if v:IsA("ParticleEmitter") then
				v.Parent = Character["Right Arm"].RightGripAttachment
				v:Emit(v:GetAttribute("EmitCount"))
			end
		end
	end
	if Combo == 3 then
		for _, v in effect:GetDescendants() do
			if v:IsA("ParticleEmitter") then
				v.Parent = Character["Left Arm"].LeftGripAttachment
				v:Emit(v:GetAttribute("EmitCount"))
			end
		end
		for _, v in effect2:GetDescendants() do
			if v:IsA("ParticleEmitter") then
				v.Parent = Character["Right Arm"].RightGripAttachment
				v:Emit(v:GetAttribute("EmitCount"))
			end
		end
	end
	if Combo == 4 then
		for _, v in effect:GetDescendants() do
			if v:IsA("ParticleEmitter") then
				v.Parent = Character["Left Arm"].LeftGripAttachment
				v:Emit(v:GetAttribute("EmitCount"))
			end
		end
		for _, v in effect2:GetDescendants() do
			if v:IsA("ParticleEmitter") then
				v.Parent = Character["Right Arm"].RightGripAttachment
				v:Emit(v:GetAttribute("EmitCount"))
			end
		end
	end
end

function Weapons.FlameProjExplosion(Frame: CFrame)
	local eff = Replicated.Assets.VFX.Explosion:Clone()
	eff.CFrame = Frame
	eff.Parent = workspace.World.Visuals

	for _, v in eff:GetDescendants() do
		if v:IsA("ParticleEmitter") then
			v:Emit(v:GetAttribute("EmitCount") or 10)
		end
	end

	Weapons.Shake(3, 20, Character.HumanoidRootPart.Position) -- Increased magnitude for more impact

	Debris:AddItem(eff, 5)
end

function Weapons.Lightning(params: {})
	local Lightning = require(game:GetService("ReplicatedStorage").Lightning)
	---- print(params)
	local lightning = Lightning.new(table.unpack(params))
end

local function meshfunction(CF: CFrame?, Parent: Instance?)
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

	local Main_CFrame = CF or CFrame.new(0, 0, 0)

	-- Settings

	local Visual_Directory = {
		["Bam"] = Replicated.Assets.VFX.GlockWind.WindHit.Bam,
		["Wind1"] = Replicated.Assets.VFX.GlockWind.WindHit.Wind1,
		["WindTime"] = Replicated.Assets.VFX.GlockWind.WindHit.WindTime,
	} :: { [string]: Instance }

	local Visual_Data = {
		[Visual_Directory["WindTime"]] = {
			General = {
				Offset = CFrame.new(
					0.142611697,
					-0.0974341929,
					0.223849222,
					0.82567358,
					3.2189073e-05,
					-0.564148188,
					-0.564148188,
					1.69824652e-05,
					-0.82567358,
					-1.69824652e-05,
					1,
					3.2189073e-05
				),
				Tween_Duration = 0.9,
				Transparency = 0.95,
			},

			BasePart = {
				Property = {
					Size = Vector3.new(11.642829895019531, 3.650705575942993, 11.277613639831543),
					CFrame = Main_CFrame * CFrame.new(
						0.142566457,
						-0.0974551663,
						-1.16666901,
						0.564148188,
						3.2189073e-05,
						0.82567358,
						0.82567358,
						1.69824652e-05,
						-0.564148188,
						-3.2189073e-05,
						1,
						-1.69824652e-05
					),
					Color = Color3.new(0.972549, 0.972549, 0.972549),
					Transparency = 1,
				},
				Tween = {
					Easing_Direction = Enum.EasingDirection.Out,
					Easing_Style = Enum.EasingStyle.Cubic,
				},
			},
		},

		[Visual_Directory["Wind1"]] = {
			General = {
				Offset = CFrame.new(
					-0.593957543,
					0.0688220412,
					0.827984631,
					-0.564148188,
					-3.2189073e-05,
					0.82567358,
					-0.82567358,
					-1.69824652e-05,
					-0.564148188,
					3.2189073e-05,
					-1,
					-1.69824652e-05
				),
				Tween_Duration = 0.9,
				Transparency = 0.95,
			},

			BasePart = {
				Property = {
					Size = Vector3.new(5.941439628601074, 2.281934976577759, 6.157501220703125),
					CFrame = Main_CFrame * CFrame.new(
						-0.594238997,
						0.0691366941,
						1.0633285,
						0,
						-5.12773113e-09,
						-1,
						1,
						9.7161319e-09,
						0,
						-9.71704139e-09,
						-1,
						-5.12864062e-09
					),
					Color = Color3.new(0.623529, 0.631373, 0.67451),
					Transparency = 1,
				},
				Tween = {
					Easing_Direction = Enum.EasingDirection.Out,
					Easing_Style = Enum.EasingStyle.Cubic,
				},
			},
		},

		[Visual_Directory["Bam"]] = {
			General = {
				Offset = CFrame.new(
					-0.786581635,
					0.379521042,
					1.66430068,
					-0.82567358,
					-3.2189073e-05,
					-0.564148188,
					0.564148188,
					-1.69824652e-05,
					-0.82567358,
					1.69824652e-05,
					-1,
					3.2189073e-05
				),
				Tween_Duration = 1,
				Transparency = 0.95,
			},

			BasePart = {
				Property = {
					Size = Vector3.new(9.895853996276855, 2.655467987060547, 9.895853996276855),
					CFrame = Main_CFrame * CFrame.new(
						-0.786581635,
						0.379521042,
						1.66430068,
						0.82567358,
						-3.2189073e-05,
						0.564148188,
						-0.564148188,
						-1.69824652e-05,
						0.82567358,
						-1.69824652e-05,
						-1,
						-3.2189073e-05
					),
					Color = Color3.new(0.670588, 0.670588, 0.670588),
					Transparency = 1,
				},
				Tween = {
					Easing_Direction = Enum.EasingDirection.Out,
					Easing_Style = Enum.EasingStyle.Quart,
				},
			},
		},
	}

	for Origin: any, Data in pairs(Visual_Data) do
		if not Origin or not Origin:IsDescendantOf(game) or not Origin:FindFirstChild("Start") then
			continue
		end

		-- Build

		local function Emit()
			local Visual = Origin.Start:Clone()
			Visual.Name = Origin.Name
			Visual.Transparency = Data.General.Transparency
			if Visual:FindFirstChildOfClass("Decal") then
				Visual:FindFirstChildOfClass("Decal").Transparency = Data.General.Transparency
				Visual.Transparency = 1
			end
			Visual.Anchored = true
			Visual.CanCollide = false
			Visual.CanQuery = false
			Visual.CanTouch = false
			Visual.Locked = true
			Visual.CFrame = Main_CFrame * Data.General.Offset
			Visual.Parent = Parent

			-- Initialize

			game:GetService("TweenService")
				:Create(
					Visual,
					TweenInfo.new(
						Data.General.Tween_Duration,
						Data.BasePart.Tween.Easing_Style,
						Data.BasePart.Tween.Easing_Direction
					),
					Data.BasePart.Property
				)
				:Play()

			-- Clean Up

			task.delay(Data.General.Tween_Duration, Visual.Destroy, Visual)
		end

		task.spawn(Emit)
	end
end

function Weapons.Shot(Character: Model, Combo: number, LeftGun: MeshPart, RightGun: MeshPart)
	-- ---- print("Weapons.Shot called - Character:", Character.Name, "Combo:", Combo, "LeftGun:", LeftGun and LeftGun.Name or "nil", "RightGun:", RightGun and RightGun.Name or "nil")
	if Combo == 1 then
		local eff = Replicated.Assets.VFX.Shot:Clone()
		eff.Parent = workspace.World.Visuals
		-- Use RightGun position and face forward in character's direction
		local effectPosition
		if LeftGun and LeftGun:FindFirstChild("EndPart") then
			local endPart = LeftGun:FindFirstChild("EndPart")
			effectPosition = endPart.Position
			-- ---- print("Combo 1: Using LeftGun", endPart.Name, "position")
		elseif LeftGun then
			-- Use gun position even without End part
			effectPosition = LeftGun.Position
			-- ---- print("Combo 1: Using LeftGun base position")
		else
			-- Fallback to hand position
			effectPosition = Character:FindFirstChild("RightHand").Position
			-- ---- print("Combo 1: Using RightHand fallback")
		end
		-- Always face forward in character's direction
		eff.CFrame = CFrame.lookAt(effectPosition, effectPosition + Character.HumanoidRootPart.CFrame.LookVector)
			* CFrame.Angles(0, math.rad(90), 0)
		for _, v in eff:GetDescendants() do
			if v:IsA("ParticleEmitter") then
				v:Emit(v:GetAttribute("EmitCount"))
			end
		end
		safeDelayedDestroy(eff, 3)
	end
	if Combo == 2 then
		local eff = Replicated.Assets.VFX.Shot:Clone()
		eff.Parent = workspace.World.Visuals
		-- Use LeftGun position and face forward in character's direction
		local effectPosition
		if RightGun and RightGun:FindFirstChild("EndPart") then
			local endPart = RightGun:FindFirstChild("EndPart")
			effectPosition = endPart.Position
			-- ---- print("Combo 2: Using RightGun", endPart.Name, "position")
		elseif RightGun then
			-- Use gun position even without End part
			effectPosition = RightGun.Position
			-- ---- print("Combo 2: Using RightGun base position")
		else
			-- Fallback to hand position
			effectPosition = Character:FindFirstChild("LeftHand").Position
			-- ---- print("Combo 2: Using LeftHand fallback")
		end
		-- Always face forward in character's direction
		eff.CFrame = CFrame.lookAt(effectPosition, effectPosition + Character.HumanoidRootPart.CFrame.LookVector)
			* CFrame.Angles(0, math.rad(90), 0)
		for _, v in eff:GetDescendants() do
			if v:IsA("ParticleEmitter") then
				v:Emit(v:GetAttribute("EmitCount"))
			end
		end
		safeDelayedDestroy(eff, 3)
	end
	if Combo == 3 then
		local eff = Replicated.Assets.VFX.Combined:Clone()
		eff.Parent = workspace.World.Visuals
		-- Position in front of character and face forward (no rotation)
		eff.CFrame = Character.HumanoidRootPart.CFrame * CFrame.new(0, 1.5, -2) * CFrame.Angles(0, math.rad(180), 0)
		-- ---- print("Combo 3: Using Combined effect in front of character")

		for _, v in eff:GetDescendants() do
			if v:IsA("ParticleEmitter") then
				v:Emit(v:GetAttribute("EmitCount"))
			end
		end
		safeDelayedDestroy(eff, 3)

		meshfunction(eff.CFrame, workspace.World.Visuals)
	end
end

function Weapons.RockSkewer(Character: Model, Frame: string, Wedge: WedgePart)
	if Frame == "Stomp" then
		local stompeffect = Replicated.Assets.VFX.Stone.uptiltrock:Clone()
		stompeffect.CFrame = Character.HumanoidRootPart.CFrame * CFrame.new(0, -2, -5)
		stompeffect.Parent = workspace.World.Visuals
		for _, v in stompeffect:GetDescendants() do
			if v:IsA("ParticleEmitter") then
				v:Emit(v:GetAttribute("EmitCount"))
			end
		end
		local meshfunction2 = require(Replicated.Assets.VFX.Stone.StoneMesh.wowmesh)

		require(Replicated.Assets.VFX.Stone.StoneMesh.wowmesh)(
			Character.HumanoidRootPart.CFrame * CFrame.new(0, -1, -5)
		)
		Debris:AddItem(stompeffect, 3)
	end

	if Frame == "Launch" then
		-- for _, v in Wedge:GetDescendants() do
		-- 	if v:IsA("Beam") then
		-- 		TweenService:Create(v, TInfo, { Width0 = 1.035, Width1 = 2.766 }):Play()
		-- 	end
		-- end
		local vfx1 = Replicated.Assets.VFX.Stone.lightninghit:Clone()
		local vfx2 = Replicated.Assets.VFX.Stone.rockfly:Clone()
		vfx2.boom.CFrame = Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, -5)
		vfx1.CFrame = Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, -5)
		vfx2.CFrame = Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, -5)
		vfx1.Parent = workspace.World.Visuals
		vfx2.Parent = workspace.World.Visuals
		for _, v in vfx1:GetDescendants() do
			if v:IsA("ParticleEmitter") then
				v:Emit(v:GetAttribute("EmitCount"))
			end
		end
		task.delay(0.1, function()
			for _, v in vfx2:GetDescendants() do
				if v:IsA("ParticleEmitter") then
					v:Emit(v:GetAttribute("EmitCount"))
				end
			end
		end)

		local armeffects = Replicated.Assets.VFX.Stone.Arm:Clone()
		for _, v in armeffects:GetDescendants() do
			if v:IsA("ParticleEmitter") then
				v.Parent = Character["Left Arm"].LeftGripAttachment
				v:Emit(v:GetAttribute("EmitCount"))
				v.Enabled = true
			end
		end
		task.delay(1, function()
			for _, v in Character["Left Arm"].LeftGripAttachment:GetDescendants() do
				if v:IsA("ParticleEmitter") then
					v.Enabled = false
					Debris:AddItem(v, 3)
				end
			end
		end)
		local pl = Replicated.Assets.VFX.Stone.PointLight:Clone()
		pl.Parent = Character.HumanoidRootPart
		local TInfo4 = TweenInfo.new(0.15, Enum.EasingStyle.Circular, Enum.EasingDirection.InOut, 0)
		local TInfo5 = TweenInfo.new(0.1, Enum.EasingStyle.Circular, Enum.EasingDirection.InOut, 0)
		local activeTweens = {}
		local t1 = TweenService:Create(pl, TInfo4, { Range = 5 })
		table.insert(activeTweens, t1)
		t1:Play()

		local t2 = TweenService:Create(pl, TInfo5, { Brightness = 0 })
		table.insert(activeTweens, t2)
		t1.Completed:Connect(function()
			t2:Play()
		end)
		t2.Completed:Connect(function()
			pl:Destroy()
		end)
		Debris:AddItem(vfx1, 2)
		Debris:AddItem(vfx2, 2)
		Debris:AddItem(Wedge, 2)
		require(Replicated.Assets.VFX.Stone.StoneMesh.woahMesh)(
			Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, -8.5)
		)
		require(Replicated.Assets.VFX.Stone.StoneMesh.wwMesh)(Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, -11))
		require(Replicated.Assets.VFX.Stone.StoneMesh.twoM)(Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, -3))
	end
end

function Weapons.Firestorm(Character: Model, Frame: string)
	if Frame == "Start" then
		local eff = Replicated.Assets.VFX.Firestorm:Clone()
		for _, v in eff:GetDescendants() do
			if v:IsA("Attachment") then
				v.Parent = Character.HumanoidRootPart
				for _, m in v:GetDescendants() do
					if m:IsA("ParticleEmitter") then
						task.delay(m:GetAttribute("EmitDelay"), function()
							m:Emit(m:GetAttribute("EmitCount"))
						end)
						-- m:Emit(m:GetAttribute("EmitCount"))
					end
				end
			end
		end
		task.delay(3, function()
			eff:Destroy()
		end)
	end
end

function Weapons.SpecialCritStone(Character)
	local eff = Replicated.Assets.VFX.Stone.Crit:Clone()
	eff.CFrame = Character.HumanoidRootPart.CFrame * CFrame.new(0, -2.5, -3)
	eff.Parent = workspace.World.Visuals
	for _, v in eff:GetDescendants() do
		if v:IsA("ParticleEmitter") then
			v:Emit(v:GetAttribute("EmitCount"))
		end
	end

	require(Replicated.Assets.VFX.Stone.StoneCrit.windM)(Character.HumanoidRootPart.CFrame * CFrame.new(0, -3, 0))
	require(Replicated.Assets.VFX.Stone.StoneCrit.circleW)(Character.HumanoidRootPart.CFrame * CFrame.new(0, -1, 0))
	require(Replicated.Assets.VFX.Stone.StoneCrit.rotateM)(Character.HumanoidRootPart.CFrame * CFrame.new(0, -1, 0))

	local pl = Replicated.Assets.VFX.Stone.PointLight:Clone()
	pl.Parent = Character.HumanoidRootPart
	local TInfo4 = TweenInfo.new(0.15, Enum.EasingStyle.Circular, Enum.EasingDirection.InOut, 0)
	local TInfo5 = TweenInfo.new(0.1, Enum.EasingStyle.Circular, Enum.EasingDirection.InOut, 0)
	local activeTweens = {}
	local t1 = TweenService:Create(pl, TInfo4, { Range = 5 })
	table.insert(activeTweens, t1)
	t1:Play()

	local t2 = TweenService:Create(pl, TInfo5, { Brightness = 0 })
	table.insert(activeTweens, t2)
	t1.Completed:Connect(function()
		t2:Play()
	end)
	task.delay(3, function()
		eff:Destroy()
	end)
end

function Weapons.Cinder(Character: Model, Frame: string)
	if Frame == "Start" then
		local startup = Replicated.Assets.VFX.Cinder["RightArm"]["Move2Startup"]:Clone()
		startup.Parent = Character["Right Arm"]
		for _, v in pairs(startup:GetDescendants()) do
			if v:IsA("ParticleEmitter") then
				local emitCount = v:GetAttribute("EmitCount") or 1
				local emitDelay = v:GetAttribute("EmitDelay") or 0.1

				-- Start a coroutine to emit once after delay
				coroutine.wrap(function()
					task.wait(emitDelay)
					v:Emit(emitCount)
				end)()
			end
		end

		local fx2 = Replicated.Assets.VFX.Cinder.Move2BeamPart2:Clone()
		fx2.Parent = workspace.World.Visuals
		-- Use fresh CFrame to avoid dash position desync
		local currentCFrame = Character.HumanoidRootPart.CFrame
		fx2.CFrame = currentCFrame * CFrame.new(0, 0, -15)
		for _, v in pairs(fx2:GetDescendants()) do
			if v:IsA("ParticleEmitter") or v:IsA("Beam") then
				local emitDelay = v:GetAttribute("EmitDelay") or 0.1
				local emitDuration = v:GetAttribute("EmitDuration") or 1

				coroutine.wrap(function()
					task.wait(emitDelay) -- wait before enabling
					v.Enabled = true -- enable particle emission
					task.wait(emitDuration) -- wait for duration
					v.Enabled = false -- disable particle emission
				end)()
			end
		end

		local start = Replicated.Assets.VFX.Cinder.Move2BeamPart:Clone()
		start.Parent = workspace.World.Visuals
		start.CFrame = Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, -10)
		for _, v in pairs(start:GetDescendants()) do
			if v:IsA("ParticleEmitter") or v:IsA("Beam") then
				local emitDelay = v:GetAttribute("EmitDelay") or 0.1
				local emitDuration = v:GetAttribute("EmitDuration") or 1

				coroutine.wrap(function()
					task.wait(emitDelay)
					if v:IsA("ParticleEmitter") then
						v:Emit(v:GetAttribute("EmitCount"))
					end
					v.Enabled = true -- enable particle emission
					task.wait(emitDuration) -- wait for duration
					v.Enabled = false -- disable particle emission
				end)()
			end
		end

		local fx3 = Replicated.Assets.VFX.Cinder.Move2BeamPart3:Clone()
		fx3.Parent = workspace.World.Visuals
		fx3.CFrame = Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, -3)
		for _, v in pairs(fx3:GetDescendants()) do
			if v:IsA("ParticleEmitter") or v:IsA("Beam") then
				local emitDelay = v:GetAttribute("EmitDelay") or 0.1
				local emitDuration = v:GetAttribute("EmitDuration") or 1

				coroutine.wrap(function()
					task.wait(emitDelay) -- wait before enabling
					v.Enabled = true -- enable particle emission
					task.wait(emitDuration) -- wait for duration
					v.Enabled = false -- disable particle emission
				end)()
			end
		end
		task.delay(3, function()
			startup:Destroy()
			fx2:Destroy()
			fx3:Destroy()
		end)
	end
end

function Weapons.Cascade(Character: Model, Frame: string)
	if Frame == "Start" then
		local eff = Replicated.Assets.VFX.Cascade.Arms
		for _, v in eff:GetChildren() do
			local h = v:Clone()
			h.Parent = Character["Right Arm"].RightGripAttachment
			h:Emit(h:GetAttribute("EmitCount"))
		end
		for _, v in eff:GetChildren() do
			local h = v:Clone()
			h.Parent = Character["Left Arm"].LeftGripAttachment
			h:Emit(h:GetAttribute("EmitCount"))
		end
		task.delay(3, function()
			for _, v in Character["Right Arm"].RightGripAttachment:GetDescendants() do
				if v:IsA("ParticleEmitter") then
					v:Destroy()
				end
			end
			for _, v in Character["Left Arm"].LeftGripAttachment:GetDescendants() do
				if v:IsA("ParticleEmitter") then
					v:Destroy()
				end
			end
		end)
	end

	if Frame == "Summon" then
		local eff = Replicated.Assets.VFX.Cascade.Summon:Clone()
		eff.Parent = workspace.World.Visuals
		eff.CFrame = Character.HumanoidRootPart.CFrame * CFrame.new(0, -2.5, -4)
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

function Weapons.NeedleThrust(Character: Model, Frame: string)
	local eff = Replicated.Assets.VFX.NewNT:Clone()
	if Frame == "Start" then
		eff.Parent = workspace.World.Visuals
		eff:PivotTo(Character.HumanoidRootPart.CFrame * CFrame.new(0, -2.5, 0))
		EmitModule.emit(eff.jump, eff.spearpushwoahhh)
	end

	if Frame == "Hit" then
		eff:PivotTo(Character.HumanoidRootPart.CFrame * CFrame.new(0, -2.5, 0))
		EmitModule.emit(eff.Pierce, eff.bloodhit)
			end
end

function Weapons.ShellPiercer(Character: Model, Frame: string, tim: number)
	if Frame == "Start" then
		local eff = Replicated.Assets.VFX.ShellPiercer.Charge:Clone()
		local rGun = Character:FindFirstChild("RightGun")
		eff.Charge.Parent = rGun.EndPart
		for _, v in rGun.EndPart:GetDescendants() do
			if v:IsA("ParticleEmitter") then
				v:Emit(v:GetAttribute("EmitCount"))
				v.Enabled = true
			end
		end
		task.delay(tim, function()
			for _, v in rGun.EndPart:GetDescendants() do
				if v:IsA("ParticleEmitter") then
					v.Enabled = false
				end
			end
			rGun.EndPart.Charge:Destroy()
		end)
	end
	if Frame == "Hit" then
		local eff = Replicated.Assets.VFX.ShellPiercer.Hit:Clone()
		eff.Parent = workspace.World.Visuals
		eff.CFrame = Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, -4) * CFrame.Angles(0, math.rad(90), 0)
		for _, v in eff:GetDescendants() do
			if v:IsA("ParticleEmitter") then
				v:Emit(v:GetAttribute("EmitCount"))
			end
		end
		task.delay(3, function()
			eff:Destroy()
		end)

		-- Impactful camera shake for ultimate move
		-- Weapons.SpecialShake(8, 28, Character.HumanoidRootPart.Position)
		CamShake({
			Location = Character.PrimaryPart.Position,
			Magnitude = 14.5,
			Damp = 0.00005,
			Frequency = 45,
			Influence = Vector3.new(0.35, 1, 0.35),
			Falloff = 45,
		})
		local lighting = game:GetService("Lighting")

		-- Get or create bloom and blur effects
		local bloom = lighting:FindFirstChild("Bloom")
		local blur = lighting:FindFirstChild("Blur")

		-- Create if they don't exist
		if not bloom then
			bloom = Instance.new("BloomEffect")
			bloom.Name = "Bloom"
			bloom.Intensity = 0
			bloom.Size = 0
			bloom.Threshold = 0
			bloom.Parent = lighting
		end

		if not blur then
			blur = Instance.new("BlurEffect")
			blur.Name = "Blur"
			blur.Size = 0
			blur.Parent = lighting
		end

		-- Store original values (should be 0 if properly cleaned up)
		local originalBloomIntensity = 0
		local originalBloomSize = 0
		local originalBloomThreshold = 0
		local originalBlurSize = 0

		-- Target values for the effect
		local targetBloomIntensity = 2
		local targetBloomSize = 56
		local targetBloomThreshold = 0.8
		local targetBlurSize = 24

		-- Use RenderStepped for smooth real-time blur effect
		local startTime = tick()
		local duration = 0.2 -- Total duration (in + out)

		local connection
		connection = RunService.RenderStepped:Connect(function()
			local elapsed = tick() - startTime
			local progress = math.min(elapsed / duration, 1)

			-- Circular in-out easing
			local alpha
			if progress < 0.5 then
				-- First half: ease in
				local t = progress * 2
				alpha = 1 - math.sqrt(1 - t * t)
			else
				-- Second half: ease out
				local t = (progress - 0.5) * 2
				alpha = 1 - (1 - math.sqrt(1 - (1 - t) * (1 - t)))
			end

			-- Apply values
			bloom.Intensity = originalBloomIntensity + (targetBloomIntensity - originalBloomIntensity) * alpha
			bloom.Size = originalBloomSize + (targetBloomSize - originalBloomSize) * alpha
			bloom.Threshold = originalBloomThreshold + (targetBloomThreshold - originalBloomThreshold) * alpha
			blur.Size = originalBlurSize + (targetBlurSize - originalBlurSize) * alpha

			-- Clean up when complete
			if progress >= 1 then
				connection:Disconnect()
				-- Reset to 0 (clean state)
				bloom.Intensity = 0
				bloom.Size = 0
				bloom.Threshold = 0
				blur.Size = 0
			end
		end)
	end
end

function Weapons.SC(Character: Model, Frame: string)
	if Frame == "Sweep" then
		local eff = Replicated.Assets.VFX.SC.Sweep:Clone()
		eff:SetPrimaryPartCFrame(Character.HumanoidRootPart.CFrame * CFrame.new(1.5, -2.5, -3.5))
		eff.Parent = workspace.World.Visuals
		for _, v in eff:GetDescendants() do
			if v:IsA("ParticleEmitter") then
				v:Emit(v:GetAttribute("EmitCount"))
			end
		end
		task.delay(3, function()
			eff:Destroy()
		end)
	end
	if Frame == "Up" then
		local eff = Replicated.Assets.VFX.SC.up:Clone()
		eff.CFrame = Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, -5) * CFrame.Angles(math.rad(90), 0, 0)
		eff.Parent = workspace.World.Visuals
		for _, v in eff:GetDescendants() do
			if v:IsA("ParticleEmitter") then
				v:Emit(v:GetAttribute("EmitCount"))
			end
		end
		task.delay(3, function()
			eff:Destroy()
		end)
	end
	if Frame == "Down" then
		local eff = Replicated.Assets.VFX.SC.down:Clone()
		eff.CFrame = Character.HumanoidRootPart.CFrame * CFrame.new(0, 3, -3) * CFrame.Angles(math.rad(-90), 0, 0)
		eff.Parent = workspace.World.Visuals
		for _, v in eff:GetDescendants() do
			if v:IsA("ParticleEmitter") then
				v:Emit(v:GetAttribute("EmitCount"))
			end
		end
		task.delay(3, function()
			eff:Destroy()
		end)
	end
	if Frame == "groundye" then
		local eff = Replicated.Assets.VFX.SC.groundye:Clone()
		eff.CFrame = Character.HumanoidRootPart.CFrame * CFrame.new(0, -2.5, -3)
		eff.Parent = workspace.World.Visuals
		for _, v in eff:GetDescendants() do
			if v:IsA("ParticleEmitter") then
				v:Emit(v:GetAttribute("EmitCount"))
			end
		end
		task.delay(3, function()
			eff:Destroy()
		end)
	end
	if Frame == "LFire" then
		local lGun = Character:FindFirstChild("LeftGun")
		for _, v in lGun:GetDescendants() do
			if v:IsA("ParticleEmitter") then
				v:Emit(v:GetAttribute("EmitCount"))
			end
		end
		-- task.delay(3, function()

		-- end)
	end
	if Frame == "RFire" then
		local rGun = Character:FindFirstChild("RightGun")
		for _, v in rGun:GetDescendants() do
			if v:IsA("ParticleEmitter") then
				v:Emit(v:GetAttribute("EmitCount"))
			end
		end
		-- task.delay(3, function()
		-- 	eff:Destroy()
		-- end)
	end
end

function Weapons.AxeKick(Character: Model, Frame: string)
	if Frame == "Swing" then
		local meshes = require(Replicated.Assets.VFX.axekickmeshes.AllMeshes)
		meshes(Character.HumanoidRootPart.CFrame, workspace.World.Visuals)
		local axekickVFX = Replicated.Assets.VFX:FindFirstChild("Axekick")
		if axekickVFX and axekickVFX:FindFirstChild("Downslam") then
			local eff = axekickVFX.Downslam:Clone()
			eff.CFrame = Character.HumanoidRootPart.CFrame
			eff.Parent = Character.HumanoidRootPart
			for _, v in eff:GetDescendants() do
				if v:IsA("ParticleEmitter") then
					task.delay(v:GetAttribute("EmitDelay") or 0, function()
						v:Emit(v:GetAttribute("EmitCount") or 10)
					end)
				end
			end
			task.delay(3, function()
				eff:Destroy()
			end)
			task.delay(0.1, function()
				local ak = Replicated.Assets.VFX:FindFirstChild("Axekick")
				if ak and ak:FindFirstChild("SlamFx") then
					local eff2 = ak.SlamFx:Clone()
					eff2.CFrame = Character.HumanoidRootPart.CFrame * CFrame.new(0, -2.5, -3)
					eff2.Parent = workspace.World.Visuals
					for _, v in eff2:GetDescendants() do
						if v:IsA("ParticleEmitter") then
							task.delay(v:GetAttribute("EmitDelay") or 0, function()
								v:Emit(v:GetAttribute("EmitCount") or 10)
							end)
						end
					end
					task.delay(3, function()
						eff2:Destroy()
					end)

					local impactPosition = Character.HumanoidRootPart.CFrame * CFrame.new(0, -2.5, -3)
					local craterPosition = impactPosition.Position + Vector3.new(0, 1, 0) -- Raise 1 stud above ground

					local success, err = pcall(function()
						local craterCFrame = CFrame.new(craterPosition)

						local effect = RockMod.New("Crater", craterCFrame, {
							Distance = { 5.5, 15 },
							SizeMultiplier = 0.3,
							PartCount = 12,
							Layers = { 3, 3 },
							ExitIterationDelay = { 0, 0 },
							LifeCycle = {
								Entrance = {
									Type = "Elevate",
									Speed = 0.25,
									Division = 3,
									EasingStyle = Enum.EasingStyle.Quad,
									EasingDirection = Enum.EasingDirection.Out,
								},

								Exit = {
									Type = "SizeDown",
									Speed = 0.3,
									Division = 2,
									EasingStyle = Enum.EasingStyle.Sine,
									EasingDirection = Enum.EasingDirection.In,
								},
							}, -- Instant, no delay
						})

						if effect then
							effect:Debris("Normal", {
								Size = { 0.75, 2.5 },
								UpForce = { 0.55, 0.95 },
								RotationalForce = { 15, 35 },
								Spread = { 8, 8 },
								PartCount = 10,
								Radius = 8,
								LifeTime = 5,
								LifeCycle = {
									Entrance = {
										Type = "SizeUp",
										Speed = 0.25,
										Division = 3,
										EasingStyle = Enum.EasingStyle.Quad,
										EasingDirection = Enum.EasingDirection.Out,
									},
									Exit = {
										Type = "SizeDown",
										Speed = 0.3,
										Division = 2,
										EasingStyle = Enum.EasingStyle.Sine,
										EasingDirection = Enum.EasingDirection.In,
									},
								},
							})
						end
					end)

					if not success then
						warn(`[AxeKick] Failed to create crater effect: {err}`)
					end

					-- Vicious but brief screenshake on impact
					Weapons.SpecialShake(10, 35, impactPosition.Position) -- Very impactful shake for axe kick

					-- Brief bloom effect on impact
					local lighting = game:GetService("Lighting")
					local bloom = lighting:FindFirstChild("Bloom")

					if not bloom then
						bloom = Instance.new("BloomEffect")
						bloom.Name = "Bloom"
						bloom.Enabled = true
						bloom.Intensity = 0
						bloom.Size = 24
						bloom.Threshold = 2
						bloom.Parent = lighting
					end

					-- Store original values
					local originalIntensity = bloom.Intensity
					local originalSize = bloom.Size
					local originalThreshold = bloom.Threshold

					-- Create brief bloom tween (in and out)
					local tweenInfo = TweenInfo.new(
						0.15, -- Duration for in (0.15 seconds)
						Enum.EasingStyle.Circular,
						Enum.EasingDirection.InOut,
						0,
						true, -- Reverses automatically
						0
					)

					local bloomTween = TweenService:Create(bloom, tweenInfo, {
						Intensity = 30,
						Size = 5,
						Threshold = 0.5,
					})

					bloomTween:Play()

					-- Reset to original values after completion
					bloomTween.Completed:Connect(function()
						bloom.Intensity = originalIntensity
						bloom.Size = originalSize
						bloom.Threshold = originalThreshold
					end)
				end
			end)
		end
	end
end

local function dsmesh(CF: CFrame, Parent: Instance)
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

	local Main_CFrame = CF or CFrame.new(0, 0, 0)

	-- Settings

	local Visual_Directory = {
		["WindRing"] = Replicated.Assets.VFX.DownslamVFX.Jump.Jump.WindRing,
		["Wind"] = Replicated.Assets.VFX.DownslamVFX.Jump.Slam.Wind,
		["WindBig"] = Replicated.Assets.VFX.DownslamVFX.Jump.Slam.WindBig,
		["Kick"] = Replicated.Assets.VFX.DownslamVFX.Jump.Slam.Kick,
		["Wind1"] = Replicated.Assets.VFX.DownslamVFX.Jump.Slam.Wind1,
		["Wind2"] = Replicated.Assets.VFX.DownslamVFX.Jump.Jump.Wind2,
	} :: { [string]: Instance }

	local Visual_Data = {
		[Visual_Directory["WindBig"]] = {
			General = {
				Offset = CFrame.new(
					0.14389044,
					-6.14201164,
					0.147280157,
					-0.0871312022,
					0,
					0.996197224,
					0,
					-1,
					0,
					0.996197283,
					0,
					0.0871317983
				),
				Tween_Duration = 0.3,
				Transparency = 0.7,
			},

			Random_Angles = {
				X = { 0, 0 },
				Y = { 0, 0 },
				Z = { 0, 0 },
			},
			BasePart = {
				Property = {
					Size = Vector3.new(22.354114532470703, 0.42486676573753357, 22.354108810424805),
					CFrame = Main_CFrame * CFrame.new(
						0.14389044,
						-8.68135548,
						0.147280157,
						-0.996199965,
						0,
						-0.0871019065,
						0,
						-1.00000048,
						0,
						-0.08710289,
						0,
						0.996199727
					),
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
					Scale = Vector3.new(-2.9735352993011475, -0.10105361044406891, -2.9735360145568848),
					VertexColor = Vector3.new(1, 1, 1),
				},
				Tween = {
					Easing_Direction = Enum.EasingDirection.Out,
					Easing_Style = Enum.EasingStyle.Cubic,
				},
			},

			Decal = {
				Property = {
					Color3 = Color3.new(10.0196, 10.0196, 10.0196),
					Transparency = 1,
				},
				Tween = {
					Easing_Direction = Enum.EasingDirection.Out,
					Easing_Style = Enum.EasingStyle.Cubic,
				},
			},
		},

		[Visual_Directory["Wind1"]] = {
			General = {
				Offset = CFrame.new(-0.113482013, -7.26768684, 4.91738319e-07, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Tween_Duration = 0.4,
				Transparency = 0.9,
			},

			Features = {
				Random_Angles = {
					X = { 0, 0 },
					Y = { -360, 360 },
					Z = { 0, 0 },
				},
			},

			BasePart = {
				Property = {
					Size = Vector3.new(25.763809204101562, 2.8394811153411865, 25.763809204101562),
					CFrame = Main_CFrame * CFrame.new(
						-0.113482013,
						-7.35580206,
						4.91738319e-07,
						-0.783837199,
						0,
						0.620966434,
						0,
						1,
						0,
						-0.620966434,
						0,
						-0.783837199
					),
					Color = Color3.new(1, 1, 1),
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
				Offset = CFrame.new(
					0.1087787,
					-6.41260242,
					0.0389252082,
					-2.38418579e-07,
					0,
					-1.00000012,
					0,
					1,
					0,
					1.00000012,
					0,
					-2.38418579e-07
				),
				Tween_Duration = 0.5,
				Transparency = 0.95,
			},

			Random_Angles = {
				X = { 0, 0 },
				Y = { 0, 0 },
				Z = { 0, 0 },
			},
			BasePart = {
				Property = {
					Size = Vector3.new(25.052053451538086, 4.060371398925781, 25.052053451538086),
					CFrame = Main_CFrame * CFrame.new(
						0,
						-7.56635475,
						0,
						0.336982906,
						0,
						0.941510856,
						0,
						1,
						0,
						-0.941510856,
						0,
						0.336982906
					),
					Color = Color3.new(0.972549, 0.972549, 0.972549),
					Transparency = 1,
				},
				Tween = {
					Easing_Direction = Enum.EasingDirection.Out,
					Easing_Style = Enum.EasingStyle.Cubic,
				},
			},
		},

		[Visual_Directory["Kick"]] = {
			General = {
				Offset = CFrame.new(-0.113484487, -4.35610867, 0.625125647, 0, 0, 1, 1, 0, 0, 0, 1, 0),
				Tween_Duration = 0.15,
				Transparency = 0.9,
			},

			Features = {
				Random_Angles = {
					X = { 0, 0 },
					Y = { -360, 360 },
					Z = { 0, 0 },
				},
			},

			BasePart = {
				Property = {
					Size = Vector3.new(0.4741426110267639, 5.183227062225342, 5.183227062225342),
					CFrame = Main_CFrame
						* CFrame.new(-0.113484487, -7.55821896, 0.625125647, 0, 0, 1, 1, 0, 0, 0, 1, 0),
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
					Scale = Vector3.new(0.09007208794355392, 0.5183614492416382, 0.5183614492416382),
					VertexColor = Vector3.new(1, 1, 1),
				},
				Tween = {
					Easing_Direction = Enum.EasingDirection.Out,
					Easing_Style = Enum.EasingStyle.Cubic,
				},
			},

			Decal = {
				Property = {
					Color3 = Color3.new(100.216, 100.216, 100.216),
					Transparency = 1,
				},
				Tween = {
					Easing_Direction = Enum.EasingDirection.Out,
					Easing_Style = Enum.EasingStyle.Cubic,
				},
			},
		},

		[Visual_Directory["WindRing"]] = {
			General = {
				Offset = CFrame.new(0.152786076, -5.18276215, 0.375100195, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Tween_Duration = 0.3,
				Transparency = 0.7,
			},

			Random_Angles = {
				X = { 0, 0 },
				Y = { 0, 0 },
				Z = { 0, 0 },
			},
			BasePart = {
				Property = {
					Size = Vector3.new(15.603704452514648, 3.2936112880706787, 15.603704452514648),
					CFrame = Main_CFrame * CFrame.new(
						0.152969867,
						-8.23160553,
						0.375163078,
						-0.965929806,
						0,
						0.258804828,
						0,
						1,
						0,
						-0.258804828,
						0,
						-0.965929806
					),
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
					Scale = Vector3.new(7.092589378356934, 3.2938053607940674, 7.092589378356934),
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

		[Visual_Directory["Wind2"]] = {
			General = {
				Offset = CFrame.new(0.678757071, 2.8957653, 0.832559586, 0, 0, 1, 0, -1, 0, 1, 0, 0),
				Tween_Duration = 0.3,
				Transparency = 0.8,
			},

			Random_Angles = {
				X = { 0, 0 },
				Y = { 0, 0 },
				Z = { 0, 0 },
			},
			BasePart = {
				Property = {
					Size = Vector3.new(18.56374740600586, 0.9379472136497498, 18.790721893310547),
					CFrame = Main_CFrame * CFrame.new(
						0.750563145,
						-7.59732962,
						0.9011935,
						-0.422593057,
						0,
						-0.906319737,
						0,
						-1,
						0,
						-0.906319737,
						0,
						0.422593057
					),
					Color = Color3.new(0.639216, 0.635294, 0.647059),
					Transparency = 1,
				},
				Tween = {
					Easing_Direction = Enum.EasingDirection.Out,
					Easing_Style = Enum.EasingStyle.Quint,
				},
			},
		},
	}

	for Origin: any, Data in pairs(Visual_Data) do
		if not Origin or not Origin:IsDescendantOf(game) or not Origin:FindFirstChild("Start") then
			continue
		end

		-- Build

		local function Emit()
			local Visual = Origin.Start:Clone()
			Visual.Name = Origin.Name
			Visual.Transparency = Data.General.Transparency
			if Visual:FindFirstChildOfClass("Decal") then
				Visual:FindFirstChildOfClass("Decal").Transparency = Data.General.Transparency
				Visual.Transparency = 1
			end
			Visual.Anchored = true
			Visual.CanCollide = false
			Visual.CanQuery = false
			Visual.CanTouch = false
			Visual.Locked = true
			Visual.CFrame = Main_CFrame * Data.General.Offset
			Visual.Parent = Parent

			-- Random Angles

			if Data.Features and Data.Features.Random_Angles then
				Data.BasePart.Property.CFrame *= CFrame.Angles(
					math.random(unpack(Data.Features.Random_Angles.X)),
					math.random(unpack(Data.Features.Random_Angles.Y)),
					math.random(unpack(Data.Features.Random_Angles.Z))
				)
			end

			-- Initialize

			game:GetService("TweenService")
				:Create(
					Visual,
					TweenInfo.new(
						Data.General.Tween_Duration,
						Data.BasePart.Tween.Easing_Style,
						Data.BasePart.Tween.Easing_Direction
					),
					Data.BasePart.Property
				)
				:Play()
			if Data.Decal then
				game:GetService("TweenService")
					:Create(
						Visual:FindFirstChildOfClass("Decal"),
						TweenInfo.new(
							Data.General.Tween_Duration,
							Data.Decal.Tween.Easing_Style,
							Data.Decal.Tween.Easing_Direction
						),
						Data.Decal.Property
					)
					:Play()
			end
			if Data.Mesh then
				game:GetService("TweenService")
					:Create(
						Visual:FindFirstChildOfClass("SpecialMesh"),
						TweenInfo.new(
							Data.General.Tween_Duration,
							Data.Mesh.Tween.Easing_Style,
							Data.Mesh.Tween.Easing_Direction
						),
						Data.Mesh.Property
					)
					:Play()
			end

			-- Clean Up

			task.delay(Data.General.Tween_Duration, Visual.Destroy, Visual)
		end

		task.spawn(Emit)
	end
end

function Weapons.Downslam(Character: Model, Frame: string)
	if Frame == "Start" then
		local eff = Replicated.Assets.VFX.DownslamVFX.jumpvfx:Clone()
		eff.CFrame = Character.HumanoidRootPart.CFrame * CFrame.new(0, -2.5, 0)
		eff.Parent = workspace.World.Visuals
		for _, v in eff:GetDescendants() do
			if v:IsA("ParticleEmitter") then
				v:Emit(v:GetAttribute("EmitCount"))
			end
		end

		dsmesh(Character.HumanoidRootPart.CFrame, workspace.World.Visuals)

		task.delay(3, function()
			eff:Destroy()
		end)
	end
	if Frame == "Land" then
		local eff = Replicated.Assets.VFX.DownslamVFX.slam:Clone()
		eff.CFrame = Character.HumanoidRootPart.CFrame * CFrame.new(0, -2.5, 0)
		eff.Parent = workspace.World.Visuals
		for _, v in eff:GetDescendants() do
			if v:IsA("ParticleEmitter") then
				v:Emit(v:GetAttribute("EmitCount"))
			end
		end
		task.delay(3, function()
			eff:Destroy()
		end)

		-- Create crater impact effect
		local impactPosition = Character.HumanoidRootPart.CFrame * CFrame.new(0, -2.5, 0)
		local craterPosition = impactPosition.Position + Vector3.new(0, 1, 0) -- Raise 1 stud above ground

		local success, err = pcall(function()
			local craterCFrame = CFrame.new(craterPosition)

			local effect = RockMod.New("Crater", craterCFrame, {
				Distance = { 5.5, 15 },
				SizeMultiplier = 0.4,
				PartCount = 14,
				Layers = { 3, 4 },
				ExitIterationDelay = { 0, 0 },
				LifeCycle = {
					Entrance = {
						Type = "Elevate",
						Speed = 0.25,
						Division = 3,
						EasingStyle = Enum.EasingStyle.Quad,
						EasingDirection = Enum.EasingDirection.Out,
					},

					Exit = {
						Type = "SizeDown",
						Speed = 0.3,
						Division = 2,
						EasingStyle = Enum.EasingStyle.Sine,
						EasingDirection = Enum.EasingDirection.In,
					},
				}, -- Instant, no delay
			})

			if effect then
				effect:Debris("Normal", {
					Size = { 0.75, 2.5 },
					UpForce = { 0.6, 1.0 },
					RotationalForce = { 20, 40 },
					Spread = { 10, 10 },
					PartCount = 12,
					Radius = 10,
					LifeTime = 5,
					LifeCycle = {
						Entrance = {
							Type = "SizeUp",
							Speed = 0.25,
							Division = 3,
							EasingStyle = Enum.EasingStyle.Quad,
							EasingDirection = Enum.EasingDirection.Out,
						},
						Exit = {
							Type = "SizeDown",
							Speed = 0.3,
							Division = 2,
							EasingStyle = Enum.EasingStyle.Sine,
							EasingDirection = Enum.EasingDirection.In,
						},
					},
				})
			end
		end)

		if not success then
			warn(`[Downslam] Failed to create crater effect: {err}`)
		end
	end
end

function Weapons.TripleKick(Character: Model, Frame: string)
	if Frame == "Ground" then
		local tk = Replicated.Assets.VFX.TripleKick
		local eff = Replicated.Assets.VFX.TripleKick.Ground:Clone()
		eff.CFrame = Character.HumanoidRootPart.CFrame * CFrame.new(0, -2.5, 0)
		eff.Parent = workspace.World.Visuals
		for _, v in eff:GetDescendants() do
			if v:IsA("ParticleEmitter") then
				v:Emit(v:GetAttribute("EmitCount"))
			end
		end

		-- Add trail effects to right leg
		local rightLeg = Character:FindFirstChild("Right Leg")
		if rightLeg then
			for _, v in tk:GetChildren() do
				if v:IsA("Attachment") and v.Name == "L" or v.Name == "R" then
					local clone = v:Clone()
					clone.Parent = rightLeg
				elseif v:IsA("Trail") then
					local clone = v:Clone()
					clone.Parent = rightLeg
				end
			end
			task.delay(3, function()
				for _, v in rightLeg:GetDescendants() do
					if v:IsA("Attachment") or v:IsA("Trail") then
						v:Destroy()
					end
				end
			end)
		end

		task.delay(3, function()
			eff:Destroy()
		end)
	elseif Frame == "Hit" then
		local rightLeg = Character:FindFirstChild("Right Leg")
		if not rightLeg then
			return
		end

		local eff = Replicated.Assets.VFX.TripleKick.Shoot:Clone()
		eff.CanCollide = false
		eff.Anchored = false
		eff.Massless = true
		eff.Parent = workspace.World.Visuals
		local eff2 = Replicated.Assets.VFX.TripleKick.Part:Clone()
		eff2.CanCollide = false
		eff2.Anchored = false
		eff2.Massless = true
		eff2.Parent = workspace.World.Visuals

		-- Use RenderStepped to continuously update VFX position to follow the leg
		local connection
		connection = RunService.RenderStepped:Connect(function()
			if rightLeg and rightLeg.Parent and eff and eff.Parent then
				eff.CFrame = rightLeg.CFrame * CFrame.new(0, -1, 0) * CFrame.Angles(0, 0, math.rad(-90))
				eff2.CFrame = rightLeg.CFrame * CFrame.new(0, -1, 0) * CFrame.Angles(0, 0, math.rad(-90))
			else
				if connection then
					connection:Disconnect()
				end
			end
		end)

		for _, v in eff:GetDescendants() do
			if v:IsA("ParticleEmitter") then
				v:Emit(v:GetAttribute("EmitCount"))
			end
		end

		for _, v in eff2:GetDescendants() do
			if v:IsA("ParticleEmitter") then
				v:Emit(v:GetAttribute("EmitCount"))
			end
		end

		task.delay(3, function()
			if connection then
				connection:Disconnect()
			end
			eff:Destroy()
		end)
	end
end

-- Store active IS effects per character
local activeISEffects = {}
local activeISConnections = {}

function Weapons.IS(Character: Model, Frame: string)
	local eff

	-- Get or create the effect for this character
	if Frame == "RightDust" then
		-- First frame - spawn the effect
		eff = Replicated.Assets.VFX.IS:Clone()
		eff:PivotTo(Character.HumanoidRootPart.CFrame * CFrame.new(0, -2.5, 0))
		eff.Parent = workspace.World.Visuals

		-- Store it for reuse
		activeISEffects[Character] = eff

		-- Store parts that should follow the character and their offset from HumanoidRootPart
		local followParts = {}
		local excludedNames = { "Lift", "Model" } -- Parts that should NOT follow

		for _, part in eff:GetDescendants() do
			if part:IsA("BasePart") then
				local shouldExclude = false
				for _, excludedName in excludedNames do
					if part.Name == excludedName or part:IsDescendantOf(eff:FindFirstChild(excludedName) or game) then
						shouldExclude = true
						break
					end
				end

				if not shouldExclude then
					-- Store the offset from the character's HumanoidRootPart
					local offset = Character.HumanoidRootPart.CFrame:ToObjectSpace(part.CFrame)
					followParts[part] = offset
				end
			end
		end

		-- Create a connection to update the effect's position every frame
		local connection = RunService.Heartbeat:Connect(function()
			if
				Character
				and Character.Parent
				and Character:FindFirstChild("HumanoidRootPart")
				and eff
				and eff.Parent
			then
				-- Update all parts that should follow
				for part, offset in followParts do
					if part and part.Parent then
						part.CFrame = Character.HumanoidRootPart.CFrame * CFrame.new(0, -5, 0)
					end
				end
			else
				-- Character or effect was destroyed, disconnect
				if activeISConnections[Character] then
					activeISConnections[Character]:Disconnect()
					activeISConnections[Character] = nil
				end
			end
		end)
		activeISConnections[Character] = connection

		-- Register VFX with cleanup system
		VFXCleanup.RegisterVFX(Character, eff, connection)

		local rd = eff.Model
		for _, v in rd:GetDescendants() do
			if v:IsA("ParticleEmitter") then
				v:Emit(v:GetAttribute("EmitCount"))
			end
		end
		task.delay(3, function()
			rd:Destroy()
		end)
	else
		-- Subsequent frames - reuse the existing effect
		eff = activeISEffects[Character]
		if not eff then
			warn("[Weapons.IS] Effect not found for character. RightDust must be called first!")
			return
		end
	end

	if Frame == "Lift" then
		local lift = eff.Lift
		for _, v in lift:GetDescendants() do
			if v:IsA("ParticleEmitter") then
				v:Emit(v:GetAttribute("EmitCount"))
			end
		end
		task.delay(3, function()
			lift:Destroy()
		end)
	elseif Frame == "Start" then
		-- Enable existing particle emitters on character
		for _, v in Character:GetDescendants() do
			if v:IsA("ParticleEmitter") then
				v.Enabled = true
			end
		end

		for _, v in eff.HeadMove:GetDescendants() do
			if v:IsA("ParticleEmitter") then
				v.Enabled = true
			end
		end

		for _, v in eff.smoke:GetDescendants() do
			if v:IsA("ParticleEmitter") then
				v.Enabled = true
			end
		end

		local TweenService = game:GetService("TweenService")
		local TInfo = TweenInfo.new(0.05, Enum.EasingStyle.Circular, Enum.EasingDirection.InOut, 3, true)

		-- Get ISBody particle emitters
		local ISBodyFolder = Replicated.Assets.VFX.ISBody
		local bodyEmitters = {}
		for _, emitter in ISBodyFolder:GetChildren() do
			if emitter:IsA("ParticleEmitter") then
				table.insert(bodyEmitters, emitter)
			end
		end

		-- Apply transparency toggle and add ISBody particles to all body parts
		for _, part in Character:GetDescendants() do
			if
				(part:IsA("BasePart") or part:IsA("MeshPart"))
				and part ~= Character:FindFirstChild("HumanoidRootPart")
			then
				-- Apply transparency tween
				local itween = TweenService:Create(part, TInfo, { Transparency = 1 })
				itween:Play()

				-- Clone and attach ISBody particle emitters to this part
				for _, emitter in bodyEmitters do
					local clonedEmitter = emitter:Clone()
					clonedEmitter.Parent = part
					clonedEmitter.Enabled = true
					-- Don't destroy here - will be destroyed in "End" frame
				end
			end
		end
	elseif Frame == "End" then
		-- Disable particle emitters in effect parts
		for _, v in eff.HeadMove:GetDescendants() do
			if v:IsA("ParticleEmitter") then
				v.Enabled = false
			end
		end

		for _, v in eff.smoke:GetDescendants() do
			if v:IsA("ParticleEmitter") then
				v.Enabled = false
			end
		end

		for _, v in eff.Land:GetDescendants() do
			if v:IsA("ParticleEmitter") then
				v:Emit(v:GetAttribute("EmitCount"))
			end
		end

		-- Get ISBody emitter names to identify which particles to disable/destroy
		local ISBodyFolder = Replicated.Assets.VFX.ISBody
		local emitterNames = {}
		for _, emitter in ISBodyFolder:GetChildren() do
			if emitter:IsA("ParticleEmitter") then
				emitterNames[emitter.Name] = true
			end
		end

		-- Disable ALL particle emitters on character (including ISBody ones)
		for _, part in Character:GetDescendants() do
			if part:IsA("ParticleEmitter") then
				part.Enabled = false
			end
		end

		-- Destroy everything after 3 seconds
		task.delay(3, function()
			-- Only destroy ISBody particle emitters on character (the ones we added)
			for _, part in Character:GetDescendants() do
				if part:IsA("ParticleEmitter") and emitterNames[part.Name] then
					part:Destroy()
				end
			end

			-- Disconnect the position update connection
			if activeISConnections[Character] then
				activeISConnections[Character]:Disconnect()
				activeISConnections[Character] = nil
			end

			-- Destroy the effect
			if eff and eff.Parent then
				eff:Destroy()
			end

			-- Remove from active effects table
			activeISEffects[Character] = nil
		end)
	end
end

-- Bezier curve function for quadratic bezier
local function Bezier(t, start, control, endPos)
	return (1 - t) ^ 2 * start + 2 * (1 - t) * t * control + t ^ 2 * endPos
end

-- Branch alchemy skill visual effect
function Weapons.Branch(Character: Model, targetPos: Vector3, side: string, customSpawnSpeed: number?)
	local root = Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end

	local TweenService = game:GetService("TweenService")
	local Debris = game:GetService("Debris")
	local HttpService = game:GetService("HttpService")

	-- Get ground material and material variant from character OR target position
	local groundMaterial = Enum.Material.Slate
	local groundMaterialVariant = ""
	local groundColor = Color3.fromRGB(100, 100, 100)

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { workspace.World.Live, workspace.World.Visuals }

	-- Try to get material from target position first (where rocks will spawn)
	local rayResult = workspace:Raycast(targetPos + Vector3.new(0, 5, 0), Vector3.new(0, -10, 0), rayParams)
	if not rayResult or not rayResult.Instance then
		-- Fallback to character position
		rayResult = workspace:Raycast(root.Position, Vector3.new(0, -10, 0), rayParams)
	end

	if rayResult and rayResult.Instance then
		groundMaterial = rayResult.Instance.Material
		groundMaterialVariant = rayResult.Instance.MaterialVariant
		groundColor = rayResult.Instance.Color
	end

	-- Determine start position based on side
	local startPos
	if side == "Left" then
		startPos = root.Position + (root.CFrame.RightVector * -15)
	else
		startPos = root.Position + (root.CFrame.RightVector * 15)
	end

	-- Control point for bezier curve with both horizontal and vertical arc
	-- The curve should arc AWAY from the straight line path (horizontally) AND upward (vertically)
	local midPoint = (startPos + targetPos) * 0.5

	-- Calculate perpendicular direction for horizontal arc
	local pathDirection = (targetPos - startPos).Unit
	local perpendicular = Vector3.new(pathDirection.Z, 0, -pathDirection.X).Unit

	-- Left side arcs +25 studs, right side arcs -25 studs
	local horizontalOffset
	if side == "Left" then
		horizontalOffset = perpendicular * 25
	else
		horizontalOffset = perpendicular * -25
	end

	-- Combine horizontal and vertical offset for extreme curve
	local controlPos = midPoint + Vector3.new(0, 15, 0) + horizontalOffset

	-- Calculate bezier points (fewer segments for better spacing with meshes)
	local numSegments = 10
	local bezierPoints = {}
	for i = 0, numSegments do
		local t = i / numSegments
		local pos = Bezier(t, startPos, controlPos, targetPos)
		table.insert(bezierPoints, pos)
	end

	-- Track previous plank position for spawning effect
	local previousPlankPos = startPos
	local plankCount = 0

	-- SPAWN ALL AT THE SAME TIME - no delay between left and right
	local baseDelay = 0
	-- Much faster spawn speed
	local spawnSpeed = customSpawnSpeed or 0.02

	-- Create connected planks along the bezier path
	for i = 1, #bezierPoints - 1 do
		local currentPoint = bezierPoints[i]
		local nextPoint = bezierPoints[i + 1]

		-- Calculate direction and distance between points
		local direction = (nextPoint - currentPoint)
		local distance = direction.Magnitude
		direction = direction.Unit

		-- Progress along the path (0 to 1)
		local t = i / #bezierPoints

		-- Size progression: start as long skinny rectangles, end as bigger squares
		-- INCREASED SIZE to ensure meshes touch each other
		local plankWidth = (2 + (t * 6)) -- 2 to 8 (bigger to ensure overlap)
		local plankHeight = (2 + (t * 6)) -- 2 to 8 (bigger to ensure overlap)
		local plankLength = distance * 1.5 -- INCREASED length to ensure rocks touch

		plankCount = plankCount + 1

		-- Capture the previous position for this plank
		local spawnFromPos = previousPlankPos

		task.delay(baseDelay + (plankCount - 1) * spawnSpeed, function()
			-- Create plank
			local plank = Replicated.Assets.VFX.WALL:Clone()
			plank.Name = "BranchRock_" .. HttpService:GenerateGUID(false)
			plank.Anchored = true
			plank.CanCollide = false
			plank.Material = groundMaterial
			plank.MaterialVariant = groundMaterialVariant
			plank.Color = groundColor
			plank.Transparency = 1 -- Start fully transparent
			plank.Size = Vector3.new(plankWidth, plankHeight, plankLength)

			plank.Parent = workspace.World.Visuals

			-- Add Highlight (white) - must be added AFTER parenting
			local highlight = Instance.new("Highlight")
			highlight.FillColor = Color3.fromRGB(255, 255, 255)
			highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
			highlight.FillTransparency = 0
			highlight.OutlineTransparency = 0
			highlight.Adornee = plank
			highlight.Parent = plank

			-- Add WallVFX particles
			local wallVFX = Replicated.Assets.VFX.WallVFX:Clone()
			for _, v in wallVFX:GetChildren() do
				if v:IsA("ParticleEmitter") then
					v.Parent = plank
				end
			end

			-- Add Jump VFX particles
			local jumpVFX = Replicated.Assets.VFX.Jump:Clone()
			for _, v in jumpVFX:GetChildren() do
				if v:IsA("ParticleEmitter") then
					v.Parent = plank
				end
			end

			-- Position plank using CFrame.lookAt (like zipline example)
			-- Position the plank so its center is exactly at currentPoint
			local finalCFrame = CFrame.lookAt(currentPoint, nextPoint)
			plank.Position = currentPoint -- Set position explicitly to ensure center is at currentPoint

			task.spawn(function()
				for _ = 1, 3 do
					AB.new(plank.CFrame, finalCFrame, {
						PartCount = 10, -- self explanatory
						CurveSize0 = 5, -- self explanatory
						CurveSize1 = 5, -- self explanatory
						PulseSpeed = 11, -- how fast the bolts will be
						PulseLength = 1, -- how long each bolt is
						FadeLength = 0.25, -- self explanatory
						MaxRadius = math.random(10,18), -- the zone of the bolts
						Thickness = 0.2, -- self explanatory
						Frequency = 0.55, -- how much it will zap around the less frequency (jitter amp)
						Color = Color3.fromRGB(46, 176, 231),
					})
					task.wait(0.065)
				end
			end)

			-- Add slight random rotation
			local randomRotation = CFrame.Angles(
				math.rad((math.random() - 0.5) * 5),
				math.rad((math.random() - 0.5) * 5),
				math.rad((math.random() - 0.5) * 5)
			)
			finalCFrame = finalCFrame * randomRotation

			-- Start CFrame: at previous position, facing the same direction
			local startCFrame = CFrame.lookAt(spawnFromPos, spawnFromPos + direction) * randomRotation
			plank.CFrame = startCFrame

			-- Tween from previous position to final position AND fade in
			local tweenDuration = 0.15 + (math.random() * 0.1)
			local tweenInfo = TweenInfo.new(tweenDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			local tween = TweenService:Create(plank, tweenInfo, {
				CFrame = finalCFrame,
				Transparency = 0,
			})
			tween:Play()

			-- Fade out highlight
			TweenService
				:Create(
					highlight,
					TweenInfo.new(tweenDuration * 1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
					{
						FillTransparency = 1,
						OutlineTransparency = 1,
					}
				)
				:Play()

			-- Emit particles once spawned
			tween.Completed:Connect(function()
				for _, v in plank:GetChildren() do
					if v:IsA("ParticleEmitter") then
						local emitCount = v:GetAttribute("EmitCount")
						if emitCount then
							v:Emit(emitCount)
						end
					end
				end
			end)

			-- Crumble and fade out when despawning
			task.delay(2.5, function()
				-- Break into smaller pieces (crumble effect)
				for _ = 1, 3 do
					local crumble = Instance.new("Part")
					crumble.Name = "BranchCrumble"
					crumble.Anchored = false
					crumble.CanCollide = false
					crumble.Material = groundMaterial
					crumble.MaterialVariant = groundMaterialVariant
					crumble.Color = groundColor
					crumble.Size = plank.Size / 3
					crumble.CFrame = plank.CFrame
						* CFrame.new(
							(math.random() - 0.5) * plank.Size.X,
							(math.random() - 0.5) * plank.Size.Y,
							(math.random() - 0.5) * plank.Size.Z
						)
					crumble.Parent = workspace.World.Visuals

					-- Add velocity to crumbles
					local velocity = Instance.new("BodyVelocity")
					velocity.MaxForce = Vector3.new(4000, 4000, 4000)
					velocity.Velocity = Vector3.new((math.random() - 0.5) * 10, -5, (math.random() - 0.5) * 10)
					velocity.Parent = crumble

					-- Fade out crumbles
					TweenService:Create(crumble, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {
						Transparency = 1,
					}):Play()

					game:GetService("Debris"):AddItem(crumble, 0.6)
				end

				-- Fade out main plank
				local fadeTween =
					TweenService:Create(plank, TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {
						Transparency = 1,
					})
				fadeTween:Play()
				game:GetService("Debris"):AddItem(plank, 0.4)
			end)
		end)

		-- Update previous position for next plank (use nextPoint as the new starting position)
		previousPlankPos = nextPoint
	end
end

-- Branch Crater Effect
Weapons.BranchCrater = function(targetPos)
	local craterPosition = targetPos + Vector3.new(0, 1, 0) -- Raise 1 stud above ground

	local success, err = pcall(function()
		local craterCFrame = CFrame.new(craterPosition)

		local effect = RockMod.New("Crater", craterCFrame, {
			Distance = { 5, 12 },
			SizeMultiplier = 0.5,
			PartCount = 10,
			Layers = { 2, 3 },
			ExitIterationDelay = { 0.5, 1 },
			LifeCycle = {
				Entrance = {
					Type = "Elevate",
					Speed = 0.25,
					Division = 3,
					EasingStyle = Enum.EasingStyle.Quad,
					EasingDirection = Enum.EasingDirection.Out,
				},
				Exit = {
					Type = "SizeDown",
					Speed = 0.3,
					Division = 2,
					EasingStyle = Enum.EasingStyle.Sine,
					EasingDirection = Enum.EasingDirection.In,
				},
			},
		})

		if effect then
			effect:Debris("Normal", {
				Size = { 0.5, 1.5 },
				UpForce = { 0.4, 0.8 },
				RotationalForce = { 10, 25 },
				Spread = { 6, 6 },
				PartCount = 8,
				Radius = 6,
				LifeTime = 4,
				LifeCycle = {
					Entrance = {
						Type = "SizeUp",
						Speed = 0.25,
						Division = 3,
						EasingStyle = Enum.EasingStyle.Quad,
						EasingDirection = Enum.EasingDirection.Out,
					},
					Exit = {
						Type = "SizeDown",
						Speed = 0.3,
						Division = 2,
						EasingStyle = Enum.EasingStyle.Sine,
						EasingDirection = Enum.EasingDirection.In,
					},
				},
			})
		end
	end)

	if not success then
		warn("[BranchCrater] Error creating crater:", err)
	end
end

-- WhirlWind Crater Effect
Weapons.WhirlWindCrater = function(targetPos)
	local craterPosition = targetPos + Vector3.new(0, 1, 0) -- Raise 1 stud above ground

	local success, err = pcall(function()
		local craterCFrame = CFrame.new(craterPosition)

		local effect = RockMod.New("Crater", craterCFrame, {
			Distance = { 4, 10 },
			SizeMultiplier = 0.4,
			PartCount = 8,
			Layers = { 2, 2 },
			ExitIterationDelay = { 0.5, 1 },
			LifeCycle = {
				Entrance = {
					Type = "Elevate",
					Speed = 0.3,
					Division = 3,
					EasingStyle = Enum.EasingStyle.Quad,
					EasingDirection = Enum.EasingDirection.Out,
				},
				Exit = {
					Type = "SizeDown",
					Speed = 0.35,
					Division = 2,
					EasingStyle = Enum.EasingStyle.Sine,
					EasingDirection = Enum.EasingDirection.In,
				},
			},
		})

		if effect then
			effect:Debris("Normal", {
				Size = { 0.4, 1.2 },
				UpForce = { 0.3, 0.6 },
				RotationalForce = { 8, 20 },
				Spread = { 5, 5 },
				PartCount = 6,
				Radius = 5,
				LifeTime = 3.5,
				LifeCycle = {
					Entrance = {
						Type = "SizeUp",
						Speed = 0.25,
						Division = 3,
						EasingStyle = Enum.EasingStyle.Quad,
						EasingDirection = Enum.EasingDirection.Out,
					},
					Exit = {
						Type = "SizeDown",
						Speed = 0.3,
						Division = 2,
						EasingStyle = Enum.EasingStyle.Sine,
						EasingDirection = Enum.EasingDirection.In,
					},
				},
			})
		end
	end)

	if not success then
		warn("[WhirlWindCrater] Error creating crater:", err)
	end
end

-- Stone Lance Crater Effect
Weapons.StoneLanceCrater = function(targetPos)
	local craterPosition = targetPos + Vector3.new(0, 1, 0) -- Raise 1 stud above ground

	local success, err = pcall(function()
		local craterCFrame = CFrame.new(craterPosition)

		local effect = RockMod.New("Crater", craterCFrame, {
			Distance = { 5, 12 },
			SizeMultiplier = 0.5,
			PartCount = 10,
			Layers = { 2, 3 },
			ExitIterationDelay = { 0.5, 1 },
			LifeCycle = {
				Entrance = {
					Type = "Elevate",
					Speed = 0.25,
					Division = 3,
					EasingStyle = Enum.EasingStyle.Quad,
					EasingDirection = Enum.EasingDirection.Out,
				},
				Exit = {
					Type = "SizeDown",
					Speed = 0.4,
					Division = 2,
					EasingStyle = Enum.EasingStyle.Sine,
					EasingDirection = Enum.EasingDirection.In,
				},
			},
		})

		if effect then
			effect:Debris("Normal", {
				Size = { 0.5, 1.5 },
				UpForce = { 0.4, 0.7 },
				RotationalForce = { 10, 25 },
				Spread = { 6, 6 },
				PartCount = 8,
				Radius = 6,
				LifeTime = 4,
				LifeCycle = {
					Entrance = {
						Type = "SizeUp",
						Speed = 0.25,
						Division = 3,
						EasingStyle = Enum.EasingStyle.Quad,
						EasingDirection = Enum.EasingDirection.Out,
					},
					Exit = {
						Type = "SizeDown",
						Speed = 0.3,
						Division = 2,
						EasingStyle = Enum.EasingStyle.Sine,
						EasingDirection = Enum.EasingDirection.In,
					},
				},
			})
		end
	end)

	if not success then
		warn("[StoneLanceCrater] Error creating crater:", err)
	end
end

-- Aerial Attack Landing Crater (Scythe slam)
-- Creates a circular crater on ground impact from an aerial dive
Weapons.AerialCrater = function(Character)
	if not Character or not Character.Parent then return end
	if typeof(Character) ~= "Instance" then return end

	local hrp = Character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	-- Camera shake (single hit, like Rapid Thrust)
	CamShake({
		Location = hrp.Position,
		Magnitude = 5.5,
		Damp = 0.00005,
		Frequency = 18,
		Influence = Vector3.new(0.45, 1, 0.45),
		Falloff = 65,
	})

	local success, err = pcall(function()
		-- Custom raycast params that exclude characters so crater rocks don't spawn on players/NPCs
		local rayParams = RaycastParams.new()
		rayParams.FilterType = Enum.RaycastFilterType.Exclude
		local filterList = {Character, workspace.World.Live, workspace.World.Visuals}
		if workspace:FindFirstChild("Entities") then
			table.insert(filterList, workspace.Entities)
		end
		if workspace:FindFirstChild("NpcRegistryCamera") then
			table.insert(filterList, workspace.NpcRegistryCamera)
		end
		rayParams.FilterDescendantsInstances = filterList

		local groundRay = workspace:Raycast(hrp.Position, Vector3.new(0, -15, 0), rayParams)
		if not groundRay then return end

		local craterCFrame = CFrame.new(groundRay.Position)

		-- Main crater ring
		local effect = RockMod.New("Crater", craterCFrame, {
			Normal = groundRay.Normal,
			RaycastParams = rayParams,
			Distance = { 4, 12 },
			SizeMultiplier = 0.7,
			PartCount = 18,
			Layers = { 3, 4 },
			ExitIterationDelay = { 0.5, 1 },
			LifeCycle = {
				Entrance = {
					Type = "Elevate",
					Speed = 0.2,
					Division = 3,
					EasingStyle = Enum.EasingStyle.Back,
					EasingDirection = Enum.EasingDirection.Out,
				},
				Exit = {
					Type = "SizeDown",
					Speed = 0.4,
					Division = 2,
					EasingStyle = Enum.EasingStyle.Sine,
					EasingDirection = Enum.EasingDirection.In,
				},
			},
		})

		if effect then
			effect:Debris("Normal", {
				Size = { 0.4, 1.2 },
				UpForce = { 0.5, 1.0 },
				RotationalForce = { 10, 30 },
				Spread = { 5, 5 },
				PartCount = 14,
				Radius = 10,
				LifeTime = 3,
				LifeCycle = {
					Entrance = {
						Type = "SizeUp",
						Speed = 0.2,
						Division = 3,
						EasingStyle = Enum.EasingStyle.Quad,
						EasingDirection = Enum.EasingDirection.Out,
					},
				},
			})
		end
	end)

	if not success then
		warn("[AerialCrater] Error creating crater:", err)
	end
end

-- Ground Decay Effect (CXZ combination)
-- Creates 3 delayed craters centered on the player
-- First crater: big rocks, small diameter
-- Second crater: medium rocks, medium diameter
-- Third crater: small rocks, big diameter
Weapons.GroundDecay = function(Character)
	local root = Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end

	local centerPos = root.Position

	-- Get ground material and material variant from character position
	local groundMaterial = Enum.Material.Slate
	local groundMaterialVariant = ""

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { workspace.World.Live, workspace.World.Visuals }

	local rayResult = workspace:Raycast(root.Position, Vector3.new(0, -10, 0), rayParams)
	if rayResult and rayResult.Instance then
		groundMaterial = rayResult.Instance.Material
		groundMaterialVariant = rayResult.Instance.MaterialVariant
	end

	-- First crater: Big rocks, small diameter
	task.delay(0, function()
		CamShake({
			Location = Character.PrimaryPart.Position,
			Magnitude = 3.5,
			Damp = 0.00005,
			Frequency = 35,
			Influence = Vector3.new(0.55, 0.15, 0.55),
			Falloff = 89,
		})
		local craterCFrame = CFrame.new(centerPos + Vector3.new(0, 1, 0))

		local effect = RockMod.New("Crater", craterCFrame, {
			Distance = { 3, 6 }, -- Small diameter
			SizeMultiplier = 1.2, -- Big rocks
			PartCount = 8,
			Layers = { 2, 2 },
			Material = groundMaterial,
			MaterialVariant = groundMaterialVariant,
			ExitIterationDelay = { 0.5, 1 },
			LifeCycle = {
				Entrance = {
					Type = "Elevate",
					Speed = 0.3,
					Division = 3,
					EasingStyle = Enum.EasingStyle.Quad,
					EasingDirection = Enum.EasingDirection.Out,
				},
				Exit = {
					Type = "SizeDown",
					Speed = 0.4,
					Division = 2,
					EasingStyle = Enum.EasingStyle.Sine,
					EasingDirection = Enum.EasingDirection.In,
				},
			},
		})

		if effect then
			effect:Debris("Normal", {
				Size = { 1, 2 }, -- Big debris
				UpForce = { 0.5, 0.9 },
				RotationalForce = { 15, 30 },
				Spread = { 5, 5 },
				PartCount = 6,
				Radius = 5,
				LifeTime = 5,
				LifeCycle = {
					Entrance = {
						Type = "SizeUp",
						Speed = 0.25,
						Division = 3,
						EasingStyle = Enum.EasingStyle.Quad,
						EasingDirection = Enum.EasingDirection.Out,
					},
					Exit = {
						Type = "SizeDown",
						Speed = 0.3,
						Division = 2,
						EasingStyle = Enum.EasingStyle.Sine,
						EasingDirection = Enum.EasingDirection.In,
					},
				},
			})
		end

		-- Brief bouncy stark screenshake for first crater
		-- Weapons.Shake(6, 30, centerPos) -- Impactful shake for first crater
	end)

	-- Second crater: Medium rocks, medium diameter
	task.delay(0.4, function()
		CamShake({
			Location = Character.PrimaryPart.Position,
			Magnitude = 4.5,
			Damp = 0.00005,
			Frequency = 35,
			Influence = Vector3.new(0.55, 0.5, 0.55),
			Falloff = 89,
		})
		local craterCFrame = CFrame.new(centerPos + Vector3.new(0, 1, 0))

		local effect = RockMod.New("Crater", craterCFrame, {
			Distance = { 6, 12 }, -- Medium diameter
			SizeMultiplier = 0.8, -- Medium rocks
			PartCount = 12,
			Layers = { 2, 3 },
			Material = groundMaterial,
			MaterialVariant = groundMaterialVariant,
			ExitIterationDelay = { 0.5, 1 },
			LifeCycle = {
				Entrance = {
					Type = "Elevate",
					Speed = 0.3,
					Division = 3,
					EasingStyle = Enum.EasingStyle.Quad,
					EasingDirection = Enum.EasingDirection.Out,
				},
				Exit = {
					Type = "SizeDown",
					Speed = 0.4,
					Division = 2,
					EasingStyle = Enum.EasingStyle.Sine,
					EasingDirection = Enum.EasingDirection.In,
				},
			},
		})
		if effect then
			effect:Debris("Normal", {
				Size = { 0.6, 1.2 }, -- Medium debris
				UpForce = { 0.5, 0.9 },
				RotationalForce = { 15, 30 },
				Spread = { 7, 7 },
				PartCount = 10,
				Radius = 8,
				LifeTime = 5,
				LifeCycle = {
					Entrance = {
						Type = "SizeUp",
						Speed = 0.25,
						Division = 3,
						EasingStyle = Enum.EasingStyle.Quad,
						EasingDirection = Enum.EasingDirection.Out,
					},
					Exit = {
						Type = "SizeDown",
						Speed = 0.3,
						Division = 2,
						EasingStyle = Enum.EasingStyle.Sine,
						EasingDirection = Enum.EasingDirection.In,
					},
				},
			})
		end

		-- Brief bouncy stark screenshake for second crater
		-- Weapons.Shake(7, 32, centerPos) -- Stronger shake for second crater
	end)

	-- Third crater: Small rocks, big diameter
	task.delay(0.8, function()
		CamShake({
			Location = Character.PrimaryPart.Position,
			Magnitude = 7.5,
			Damp = 0.00005,
			Frequency = 41,
			Influence = Vector3.new(0.55, 1, 0.55),
			Falloff = 89,
		})
		local craterCFrame = CFrame.new(centerPos + Vector3.new(0, 1, 0))

		local effect = RockMod.New("Crater", craterCFrame, {
			Distance = { 12, 20 }, -- Big diameter
			SizeMultiplier = 0.4, -- Small rocks
			PartCount = 16,
			Layers = { 3, 4 },
			Material = groundMaterial,
			MaterialVariant = groundMaterialVariant,
			ExitIterationDelay = { 0.5, 1 },
			LifeCycle = {
				Entrance = {
					Type = "Elevate",
					Speed = 0.3,
					Division = 3,
					EasingStyle = Enum.EasingStyle.Quad,
					EasingDirection = Enum.EasingDirection.Out,
				},
				Exit = {
					Type = "SizeDown",
					Speed = 0.4,
					Division = 2,
					EasingStyle = Enum.EasingStyle.Sine,
					EasingDirection = Enum.EasingDirection.In,
				},
			},
		})

		if effect then
			effect:Debris("Normal", {
				Size = { 0.3, 0.8 }, -- Small debris
				UpForce = { 0.5, 0.9 },
				RotationalForce = { 15, 30 },
				Spread = { 10, 10 },
				PartCount = 14,
				Radius = 12,
				LifeTime = 5,
				LifeCycle = {
					Entrance = {
						Type = "SizeUp",
						Speed = 0.25,
						Division = 3,
						EasingStyle = Enum.EasingStyle.Quad,
						EasingDirection = Enum.EasingDirection.Out,
					},
					Exit = {
						Type = "SizeDown",
						Speed = 0.3,
						Division = 2,
						EasingStyle = Enum.EasingStyle.Sine,
						EasingDirection = Enum.EasingDirection.In,
					},
				},
			})
		end

		-- Brief bouncy stark screenshake for third crater (biggest)
		-- Weapons.SpecialShake(9, 35, centerPos) -- Most impactful shake for biggest crater
	end)
end

--- Stone Lance Path Camera Shake
--- Subtle shake when each lance emerges from the ground
Weapons.StoneLancePathShake = function(lancePosition)
	CamShake({
		Location = lancePosition,
		Magnitude = 2.5,
		Damp = 0.00008,
		Frequency = 30,
		Influence = Vector3.new(0.4, 0.1, 0.4),
		Falloff = 65,
	})
end

--- Stone Lance Camera Shake
--- More pronounced shake for the single large lance
Weapons.StoneLanceShake = function(lancePosition)
	CamShake({
		Location = lancePosition,
		Magnitude = 4.0,
		Damp = 0.00005,
		Frequency = 35,
		Influence = Vector3.new(0.5, 0.15, 0.5),
		Falloff = 80,
	})
end

function Weapons.SpecialCritScythe(Character: Model)
	local Lighting = game:GetService("Lighting")
	local TextPlus = require(Replicated.Modules.Utils.Text)
	local Global = require(Replicated.Modules.Shared.Global)

	-- Constants for white color detection
	local WHITE_THRESHOLD = 0.95 -- How close to white a color must be (0-1)

	-- Check if a color is white or nearly white
	local function isWhiteColor(color: Color3): boolean
		local r, g, b = color.R, color.G, color.B
		return r >= WHITE_THRESHOLD and g >= WHITE_THRESHOLD and b >= WHITE_THRESHOLD
	end

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

	-- Generate a color variation (lighter or darker) of the base color
	-- Keeps colors bright - only varies within the bright range
	local function getColorVariation(baseColor: Color3): Color3
		local variationAmount = (math.random() * 0.2 - 0.1) -- -0.1 to +0.1 (smaller range)
		local h, s, v = baseColor:ToHSV()
		-- Keep brightness high (0.7 to 1.0) and saturation strong (0.4 to 1.0)
		local newV = math.clamp(v + variationAmount, 0.7, 1.0)
		local newS = math.clamp(s + (variationAmount * 0.3), 0.4, 1.0)
		return Color3.fromHSV(h, newS, newV)
	end

	-- Apply Nen color to a ParticleEmitter if it has white color
	local function applyNenColorToParticle(particle: ParticleEmitter, nenColor: Color3)
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
			local targetColor = getColorVariation(nenColor)
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
	local function applyNenColorToBeam(beam: Beam, nenColor: Color3)
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
			local targetColor = getColorVariation(nenColor)
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
	local function applyNenColorToTrail(trail: Trail, nenColor: Color3)
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
			local targetColor = getColorVariation(nenColor)
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
	local function applyNenColorToEffects(instance: Instance, nenColor: Color3)
		for _, descendant in instance:GetDescendants() do
			if descendant:IsA("ParticleEmitter") then
				applyNenColorToParticle(descendant, nenColor)
			elseif descendant:IsA("Beam") then
				applyNenColorToBeam(descendant, nenColor)
			elseif descendant:IsA("Trail") then
				applyNenColorToTrail(descendant, nenColor)
			end
		end

		-- Also check the instance itself
		if instance:IsA("ParticleEmitter") then
			applyNenColorToParticle(instance, nenColor)
		elseif instance:IsA("Beam") then
			applyNenColorToBeam(instance, nenColor)
		elseif instance:IsA("Trail") then
			applyNenColorToTrail(instance, nenColor)
		end
	end

	-- Get Scythe VFX folder
	local scytheVFX = VFX:FindFirstChild("Scythe")
	if not scytheVFX then return end

	-- Get root part for sound parenting
	local rootPart = Character:FindFirstChild("HumanoidRootPart") or Character.PrimaryPart

	-- Get player from character early - try multiple methods for reliability
	local playerFromChar = Players:GetPlayerFromCharacter(Character)
	if not playerFromChar then
		-- Fallback: check if this is local player's character
		local localPlayer = Players.LocalPlayer
		if localPlayer and localPlayer.Character == Character then
			playerFromChar = localPlayer
		end
	end

	-- Get player's Nen data early (for VFX colors and text)
	local nenType = "Enhance"
	local nenColor = Color3.fromRGB(100, 200, 255) -- Default light blue for Nen effects
	local hasCustomNenColor = true -- Always apply color to Nen effects
	if playerFromChar then
		local nenData = Global.GetData(playerFromChar, "Nen")
		if nenData then
			if nenData.Type then
				nenType = nenData.Type
			end
			if nenData.Color then
				local r, g, b = nenData.Color.R, nenData.Color.G, nenData.Color.B
				-- Only use custom color if it's NOT white (255, 255, 255)
				-- Otherwise use the default light blue
				if not (r >= 250 and g >= 250 and b >= 250) then
					-- Get color and ensure it's bright/vibrant (no dark colors allowed)
					local rawColor = Color3.fromRGB(r, g, b)
					nenColor = ensureBrightColor(rawColor)
				end
			end
		end
	end

	-- Play ScytheCrit sounds (1, 2, 3) immediately at animation start
	-- ScytheCrit folder is under SFX > Nen > ScytheCrit
	local nenSfxFolder = SFX:FindFirstChild("Nen")
	local scytheCritFolder = nenSfxFolder and nenSfxFolder:FindFirstChild("ScytheCrit")
	if scytheCritFolder and rootPart then
		-- Play all 3 sounds in a separate thread so they don't block VFX
		task.spawn(function()
			for i = 1, 2 do
				local sound = scytheCritFolder:FindFirstChild(tostring(i))
				if sound and sound:IsA("Sound") then
					local soundClone = sound:Clone()
					soundClone.Parent = rootPart
					soundClone:Play()
					soundClone.Ended:Once(function()
						soundClone:Destroy()
					end)
				end
				if i < 2 then
					task.wait(0.05)
				end
			end
		end)
	end

	-- Clone Crit model to character's root part
	local critModel = scytheVFX:FindFirstChild("Crit")
	local critClone = nil
	local warnPart = nil
	local wwwwModel = nil

	if critModel then
		critClone = critModel:Clone()
		local humanoidRootPart = Character:FindFirstChild("HumanoidRootPart")
		if humanoidRootPart then
			critClone:PivotTo(humanoidRootPart.CFrame)
			critClone.Parent = humanoidRootPart
		end
		-- Find warn part and wwww model for later emission
		warnPart = critClone:FindFirstChild("warn", true)
		wwwwModel = critClone:FindFirstChild("wwww", true)

		-- Apply custom Nen color to ALL crit VFX (white effects get tinted)
		-- This includes warn, wwww, and any other effects in the crit model
		if hasCustomNenColor then
			applyNenColorToEffects(critClone, nenColor)
			-- Also specifically apply to warn and wwww if found
			if warnPart then
				applyNenColorToEffects(warnPart, nenColor)
			end
			if wwwwModel then
				applyNenColorToEffects(wwwwModel, nenColor)
			end
		end
	end

	-- Emit warn part immediately (color already applied above)
	if warnPart then
		EmitModule.emit(warnPart)
	end

	-- Emit Bling attachment first
	for _, descendant in Character:GetDescendants() do
		if descendant.Name == "Bling" and descendant:IsA("Attachment") then
			for _, particle in descendant:GetChildren() do
				if particle:IsA("ParticleEmitter") then
					particle:Emit(particle:GetAttribute("EmitCount") or 1)
				end
			end
			break
		end
	end

	-- Emit ALL effects on weapon parts (parts with "Weapon" attribute) and enable them for 10 seconds
	-- Weapon parts are direct children of Character with "Weapon" attribute set
	-- Skip effects under "Bling" attachment - those should only emit, not stay enabled
	-- Apply custom Nen color to white effects (with slight variations)
	local weaponEffects = {}
	for _, weaponPart in Character:GetChildren() do
		if weaponPart:GetAttribute("Weapon") then
			for _, effect in weaponPart:GetDescendants() do
				-- Check if this effect is under a Bling attachment
				local isUnderBling = false
				local parent = effect.Parent
				while parent and parent ~= weaponPart do
					if parent.Name == "Bling" then
						isUnderBling = true
						break
					end
					parent = parent.Parent
				end

				if effect:IsA("ParticleEmitter") then
					-- Apply custom Nen color to white particles
					if hasCustomNenColor then
						applyNenColorToParticle(effect, nenColor)
					end
					effect:Emit(effect:GetAttribute("EmitCount") or 1)
					-- Only enable if not under Bling
					if not isUnderBling then
						effect.Enabled = true
						table.insert(weaponEffects, effect)
					end
				elseif effect:IsA("Trail") then
					-- Apply custom Nen color to white trails
					if hasCustomNenColor then
						applyNenColorToTrail(effect, nenColor)
					end
					-- Only enable if not under Bling
					if not isUnderBling then
						effect.Enabled = true
						table.insert(weaponEffects, effect)
					end
				elseif effect:IsA("Beam") then
					-- Apply custom Nen color to white beams
					if hasCustomNenColor then
						applyNenColorToBeam(effect, nenColor)
					end
					-- Only enable if not under Bling
					if not isUnderBling then
						effect.Enabled = true
						table.insert(weaponEffects, effect)
					end
				end
			end
		end
	end

	-- Emit wwww model immediately (no delay)
	if wwwwModel then
		EmitModule.emit(wwwwModel)
	end

	-- local effect = RockMod.New("Path", Character.HumanoidRootPart.CFrame, {})

	-- 	if effect then
	-- 		effect:Debris("Normal", {
	-- 			Size = { 0.4, 1.2 },
	-- 			UpForce = { 0.3, 0.6 },
	-- 			RotationalForce = { 8, 20 },
	-- 			Spread = { 5, 5 },
	-- 			PartCount = 6,
	-- 			Radius = 5,
	-- 			LifeTime = 3.5,
	-- 			LifeCycle = {
	-- 				Entrance = {
	-- 					Type = "SizeUp",
	-- 					Speed = 0.25,
	-- 					Division = 3,
	-- 					EasingStyle = Enum.EasingStyle.Quad,
	-- 					EasingDirection = Enum.EasingDirection.Out,
	-- 				},
	-- 				Exit = {
	-- 					Type = "SizeDown",
	-- 					Speed = 0.3,
	-- 					Division = 2,
	-- 					EasingStyle = Enum.EasingStyle.Sine,
	-- 					EasingDirection = Enum.EasingDirection.In,
	-- 				},
	-- 			},
	-- 		})
	-- 	end


	-- Play Nen type sound
	if nenSfxFolder and rootPart then
		local soundName = nenType
		local nenTypeSound = nenSfxFolder:FindFirstChild(soundName)
		if nenTypeSound and nenTypeSound:IsA("Sound") then
			local typeSoundClone = nenTypeSound:Clone()
			typeSoundClone.Parent = rootPart
			typeSoundClone:Play()
			typeSoundClone.Ended:Once(function()
				typeSoundClone:Destroy()
			end)
		end
	end

	-- Color correction flash effect with sound timing
	local impactScythe = scytheVFX:FindFirstChild("ImpactScythe")
	if impactScythe then
		local colorCorrections = {}
		for _, child in pairs(impactScythe:GetChildren()) do
			if child:IsA("ColorCorrectionEffect") then
				local clone = child:Clone()
				clone.Parent = Lighting
				table.insert(colorCorrections, clone)
			end
		end

		-- Sort by name to ensure numbered order (cc, cc2, cc3, cc4)
		table.sort(colorCorrections, function(a, b)
			return a.Name < b.Name
		end)

		-- Loop through 2 complete playthroughs
		task.spawn(function()
			for i = 1, 2 do
				for _, cc in ipairs(colorCorrections) do
					cc.Enabled = true
					task.wait(0.002)
					cc.Enabled = false
				end
			end
			-- Delete all clones
			for _, cc in ipairs(colorCorrections) do
				cc:Destroy()
			end
		end)
	end

	-- Camera shake - FIRM like Rapid Thrust (increased magnitude)
	CamShake({
		Location = Character.PrimaryPart and Character.PrimaryPart.Position or Character:GetPivot().Position,
		Magnitude = 10,
		Damp = 0.00005,
		Frequency = 13,
		Influence = Vector3.new(0.5, 1, 0.5),
		Falloff = 65,
	})

	-- Create aggressive Nen type text using TextPlus (positioned at character's feet/Load VFX area)
	local hrp = Character:FindFirstChild("HumanoidRootPart")
	-- if hrp then
	-- 	-- Create a part at the feet to anchor the billboard
	-- 	local footAnchor = Instance.new("Part")
	-- 	footAnchor.Name = "NenTextAnchor"
	-- 	footAnchor.Anchored = true
	-- 	footAnchor.CanCollide = false
	-- 	footAnchor.Transparency = 1
	-- 	footAnchor.Size = Vector3.new(1, 1, 1)
	-- 	footAnchor.CFrame = hrp.CFrame * CFrame.new(0, -hrp.Size.Y / 2 - 1, 0)
	-- 	footAnchor.Parent = workspace.World.Visuals

	-- 	-- Create BillboardGui at feet (Load VFX position)
	-- 	local billboardGui = Instance.new("BillboardGui")
	-- 	billboardGui.Name = "NenCritText"
	-- 	billboardGui.Adornee = footAnchor
	-- 	billboardGui.Size = UDim2.fromOffset(800, 200) -- Larger size to prevent cropping
	-- 	billboardGui.StudsOffset = Vector3.new(0, 1, 0) -- Slightly above ground
	-- 	billboardGui.AlwaysOnTop = true
	-- 	billboardGui.MaxDistance = 100
	-- 	billboardGui.Parent = Players.LocalPlayer and Players.LocalPlayer:FindFirstChild("PlayerGui")

	-- 	-- Create text container frame for TextPlus
	-- 	local textFrame = Instance.new("Frame")
	-- 	textFrame.Name = "TextFrame"
	-- 	textFrame.BackgroundTransparency = 1
	-- 	textFrame.Size = UDim2.fromScale(1, 1)
	-- 	textFrame.Position = UDim2.fromScale(0.5, 0.5)
	-- 	textFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	-- 	textFrame.Parent = billboardGui

	-- 	-- Create text using TextPlus with Jura font, black stroke
	-- 	TextPlus.Create(textFrame, nenType:upper(), {
	-- 		Size = 52,
	-- 		Color = nenColor,
	-- 		Font = Font.new("rbxasset://fonts/families/Jura.json", Enum.FontWeight.Bold, Enum.FontStyle.Italic),
	-- 		StrokeSize = 3,
	-- 		StrokeColor = Color3.new(0, 0, 0),
	-- 		StrokeTransparency = 0,
	-- 		XAlignment = "Center",
	-- 		YAlignment = "Center",
	-- 		CharacterSpacing = 1.2, -- Slightly wider spacing
	-- 	})

	-- 	-- Animate: start transparent, fade in, then enlarge and fade out
	-- 	task.spawn(function()
	-- 		-- Set initial transparency (fade in effect)
	-- 		for _, child in textFrame:GetDescendants() do
	-- 			if child:IsA("TextLabel") then
	-- 				child.TextTransparency = 1
	-- 				local stroke = child:FindFirstChildOfClass("UIStroke")
	-- 				if stroke then
	-- 					stroke.Transparency = 1
	-- 				end
	-- 			end
	-- 		end

	-- 		-- Fade in
	-- 		local fadeInTime = 0.2
	-- 		local startTime = tick()
	-- 		while tick() - startTime < fadeInTime do
	-- 			local alpha = (tick() - startTime) / fadeInTime
	-- 			for _, child in textFrame:GetDescendants() do
	-- 				if child:IsA("TextLabel") then
	-- 					child.TextTransparency = 1 - alpha
	-- 					local stroke = child:FindFirstChildOfClass("UIStroke")
	-- 					if stroke then
	-- 						stroke.Transparency = 1 - alpha
	-- 					end
	-- 				end
	-- 			end
	-- 			task.wait()
	-- 		end

	-- 		-- Ensure fully visible
	-- 		for _, child in textFrame:GetDescendants() do
	-- 			if child:IsA("TextLabel") then
	-- 				child.TextTransparency = 0
	-- 				local stroke = child:FindFirstChildOfClass("UIStroke")
	-- 				if stroke then
	-- 					stroke.Transparency = 0
	-- 				end
	-- 			end
	-- 		end

	-- 		-- Hold briefly
	-- 		task.wait(0.3)

	-- 		-- Enlarge and fade out
	-- 		local fadeOutTime = 0.25
	-- 		startTime = tick()
	-- 		while tick() - startTime < fadeOutTime do
	-- 			local alpha = (tick() - startTime) / fadeOutTime
	-- 			for _, child in textFrame:GetDescendants() do
	-- 				if child:IsA("TextLabel") then
	-- 					child.TextTransparency = alpha
	-- 					child.TextSize = 52 * (1 + alpha * 0.8) -- Enlarge to 1.8x
	-- 					local stroke = child:FindFirstChildOfClass("UIStroke")
	-- 					if stroke then
	-- 						stroke.Transparency = alpha
	-- 					end
	-- 				end
	-- 			end
	-- 			task.wait()
	-- 		end

	-- 		-- Cleanup
	-- 		if billboardGui.Parent then
	-- 			billboardGui:Destroy()
	-- 		end
	-- 		if footAnchor.Parent then
	-- 			footAnchor:Destroy()
	-- 		end
	-- 	end)
	-- end

	-- RockMod Forward effect - straight forward debris path with lots of rocks
	print("[ScytheCrit] Starting RockMod Forward effect, hrp:", hrp)
	if hrp then
		-- Raycast down to get ground normal
		local rayParams = RaycastParams.new()
		rayParams.FilterType = Enum.RaycastFilterType.Exclude
		rayParams.FilterDescendantsInstances = {Character, workspace.World.Live}

		local groundRay = workspace:Raycast(hrp.Position, Vector3.new(0, -10, 0), rayParams)
		print("[ScytheCrit] Ground raycast result:", groundRay and "HIT" or "MISS", groundRay and groundRay.Instance or "nil")
		if groundRay then
			-- Get character's facing direction (flatten to XZ plane)
			local lookVector = -hrp.CFrame.LookVector
			local flatLookVector = Vector3.new(lookVector.X, 0, lookVector.Z).Unit

			-- Position at character's feet
			local startCFrame = CFrame.new(groundRay.Position)

			print("[ScytheCrit] Creating RockMod.New Forward at", groundRay.Position, "direction:", flatLookVector)
			local _forwardEffect = RockMod.New("Forward", startCFrame, {
				Normal = groundRay.Normal,
				Direction = flatLookVector, -- Use character's actual facing direction (forward)
				Length = 30, -- Long path going straight forward
				StepSize = 1.2, -- More debris (smaller step = more rocks)
				BaseSize = 1.8, -- Size of debris
				ScaleFactor = 1.065, -- Rocks grow slightly larger as they go
				Distance = {2, 5}, -- Spread from center line
				Rotation = {-25, 25},
				PartLifeTime = 1.8,
				LifeCycle = {
					Entrance = {
						Type = "SizeUp",
						Speed = 0.15,
						EasingStyle = Enum.EasingStyle.Circular,
						EasingDirection = Enum.EasingDirection.Out,
					},
					Exit = {
						Type = "SizeDown",
						Speed = 0.25,
						EasingStyle = Enum.EasingStyle.Quad,
						EasingDirection = Enum.EasingDirection.In,
					},
				},
			})
			print("[ScytheCrit] RockMod.New returned:", _forwardEffect)
		else
			print("[ScytheCrit] Ground raycast MISSED - no RockMod effect created")
		end
	else
		print("[ScytheCrit] No HumanoidRootPart found!")
	end

	-- Cleanup: disable weapon effects after 10 seconds
	task.delay(10, function()
		for _, effect in weaponEffects do
			if effect and effect.Parent then
				effect.Enabled = false
			end
		end
	end)

	-- Cleanup crit model after effect
	task.delay(2, function()
		if critClone and critClone.Parent then
			critClone:Destroy()
		end
	end)
end

--[[
	ScytheCritLoad - Ground charging VFX for Scythe critical attack
	Called when crit animation STARTS (not at frame 46)

	Timeline (at 60fps):
	- Frame 0: Position at character's feet, enable particles (normal TimeScale = 1)
	- Frame 40: TimeScale set to 0 (freeze effect)
	- Frame 46: TimeScale set back to 1, then Enabled = false
]]
function Weapons.ScytheCritLoad(Character: Model)
	print("[ScytheCritLoad] Function called for:", Character and Character.Name or "nil")

	local Global = require(Replicated.Modules.Shared.Global)

	-- Get Scythe VFX folder
	local scytheVFX = VFX:FindFirstChild("Scythe")
	if not scytheVFX then
		warn("[ScytheCritLoad] Scythe VFX folder not found!")
		return
	end

	-- Get the Load model
	local loadModel = scytheVFX:FindFirstChild("Load")
	if not loadModel then
		warn("[ScytheCritLoad] Load model not found in Scythe VFX folder!")
		return
	end

	-- Get character's root part for positioning
	local humanoidRootPart = Character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then
		warn("[ScytheCritLoad] HumanoidRootPart not found!")
		return
	end

	print("[ScytheCritLoad] All checks passed, creating VFX")

	-- Constants for white color detection
	local WHITE_THRESHOLD = 0.95

	local function isWhiteColor(color: Color3): boolean
		return color.R >= WHITE_THRESHOLD and color.G >= WHITE_THRESHOLD and color.B >= WHITE_THRESHOLD
	end

	local function ensureBrightColor(color: Color3): Color3
		local h, s, v = color:ToHSV()
		local newS = math.max(s, 0.5)
		local newV = math.max(v, 0.7)
		return Color3.fromHSV(h, newS, newV)
	end

	local function getColorVariation(baseColor: Color3): Color3
		local variationAmount = (math.random() * 0.2 - 0.1)
		local h, s, v = baseColor:ToHSV()
		local newV = math.clamp(v + variationAmount, 0.7, 1.0)
		local newS = math.clamp(s + (variationAmount * 0.3), 0.4, 1.0)
		return Color3.fromHSV(h, newS, newV)
	end

	-- Apply Nen color to a ParticleEmitter
	local function applyNenColorToParticle(particle: ParticleEmitter, nenColor: Color3)
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
			local targetColor = getColorVariation(nenColor)
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

	-- Get player's Nen color
	local nenColor = Color3.fromRGB(100, 200, 255) -- Default light blue
	local playerFromChar = Players:GetPlayerFromCharacter(Character)
	if not playerFromChar then
		local localPlayer = Players.LocalPlayer
		if localPlayer and localPlayer.Character == Character then
			playerFromChar = localPlayer
		end
	end

	if playerFromChar then
		local nenData = Global.GetData(playerFromChar, "Nen")
		if nenData and nenData.Color then
			local r, g, b = nenData.Color.R, nenData.Color.G, nenData.Color.B
			if not (r >= 250 and g >= 250 and b >= 250) then
				nenColor = ensureBrightColor(Color3.fromRGB(r, g, b))
			end
		end
	end

	-- Clone the Load model
	local loadClone = loadModel:Clone()

	-- Position at character's feet (ground level)
	local footOffset = Vector3.new(0, -humanoidRootPart.Size.Y / 2 - 1.5, 0)
	local footCFrame = humanoidRootPart.CFrame * CFrame.new(footOffset)
	loadClone:PivotTo(footCFrame)
	loadClone.Parent = workspace.World.Visuals

	print("[ScytheCritLoad] VFX cloned and parented to workspace.World.Visuals")

	-- Collect all particle emitters and apply Nen color
	local particles = {}

	-- Check all descendants
	for _, descendant in loadClone:GetDescendants() do
		if descendant:IsA("ParticleEmitter") then
			-- Apply Nen color
			applyNenColorToParticle(descendant, nenColor)
			-- Enable the particle
			descendant.Enabled = true
			-- Also emit in case Rate is 0
			local emitCount = descendant:GetAttribute("EmitCount") or 50
			descendant:Emit(emitCount)
			table.insert(particles, descendant)
		end
	end

	-- Also check direct children if loadClone is a BasePart
	if loadClone:IsA("BasePart") then
		for _, child in loadClone:GetChildren() do
			if child:IsA("ParticleEmitter") then
				applyNenColorToParticle(child, nenColor)
				child.Enabled = true
				local emitCount = child:GetAttribute("EmitCount") or 50
				child:Emit(emitCount)
				table.insert(particles, child)
			end
		end
	end

	print("[ScytheCritLoad] Found and enabled", #particles, "particle emitters")

	local hrp = Character:FindFirstChild("HumanoidRootPart")
	local nenType = "Enhance"
	if hrp then
		-- Create a part at the feet to anchor the billboard
		local footAnchor = Instance.new("Part")
		footAnchor.Name = "NenTextAnchor"
		footAnchor.Anchored = true
		footAnchor.CanCollide = false
		footAnchor.Transparency = 1
		footAnchor.Size = Vector3.new(1, 1, 1)
		footAnchor.CFrame = hrp.CFrame * CFrame.new(0, -hrp.Size.Y / 2 - 1, 0)
		footAnchor.Parent = workspace.World.Visuals

		-- Create BillboardGui at feet (Load VFX position)
		local billboardGui = Instance.new("BillboardGui")
		billboardGui.Name = "NenCritText"
		billboardGui.Adornee = footAnchor
		billboardGui.Size = UDim2.fromOffset(800, 200) -- Larger size to prevent cropping
		billboardGui.StudsOffset = Vector3.new(0, 1, 0) -- Slightly above ground
		billboardGui.AlwaysOnTop = true
		billboardGui.MaxDistance = 100
		billboardGui.Parent = Players.LocalPlayer and Players.LocalPlayer:FindFirstChild("PlayerGui")

		-- Create text container frame
		local textFrame = Instance.new("Frame")
		textFrame.Name = "TextFrame"
		textFrame.BackgroundTransparency = 1
		textFrame.Size = UDim2.fromScale(.5, .5)
		textFrame.Position = UDim2.fromScale(1, 0.5)
		textFrame.AnchorPoint = Vector2.new(0.5, 0.5)
		textFrame.ClipsDescendants = false
		textFrame.Parent = billboardGui

		-- Create text using TextPlus with Jura font, black stroke
		local TextPlus = require(Replicated.Modules.Utils.Text)
		TextPlus.Create(textFrame, nenType:upper(), {
			Size = 52,
			Color = nenColor,
			Font = Font.new("rbxasset://fonts/families/Jura.json", Enum.FontWeight.Bold, Enum.FontStyle.Italic),
			StrokeSize = 3,
			StrokeColor = Color3.new(0, 0, 0),
			StrokeTransparency = 0,
			XAlignment = "Center",
			YAlignment = "Center",
			CharacterSpacing = 1.2, -- Slightly wider spacing
		})

		-- Animate: start transparent, fade in, then enlarge and fade out
		task.spawn(function()
			-- Set initial transparency (fade in effect)
			for _, child in textFrame:GetDescendants() do
				if child:IsA("TextLabel") then
					child.TextTransparency = 1
					local stroke = child:FindFirstChildOfClass("UIStroke")
					if stroke then
						stroke.Transparency = 1
					end
				end
			end

			-- Fade in
			local fadeInTime = 0.2
			local startTime = tick()
			while tick() - startTime < fadeInTime do
				local alpha = (tick() - startTime) / fadeInTime
				for _, child in textFrame:GetDescendants() do
					if child:IsA("TextLabel") then
						child.TextTransparency = 1 - alpha
						local stroke = child:FindFirstChildOfClass("UIStroke")
						if stroke then
							stroke.Transparency = 1 - alpha
						end
					end
				end
				task.wait()
			end

			-- Ensure fully visible
			for _, child in textFrame:GetDescendants() do
				if child:IsA("TextLabel") then
					child.TextTransparency = 0
					local stroke = child:FindFirstChildOfClass("UIStroke")
					if stroke then
						stroke.Transparency = 0
					end
				end
			end

			-- Hold briefly
			task.wait(0.3)

			-- Enlarge and fade out
			local fadeOutTime = 0.25
			startTime = tick()
			while tick() - startTime < fadeOutTime do
				local alpha = (tick() - startTime) / fadeOutTime
				for _, child in textFrame:GetDescendants() do
					if child:IsA("TextLabel") then
						child.TextTransparency = alpha
						child.TextSize = 52 * (1 + alpha * 0.8) -- Enlarge to 1.8x
						local stroke = child:FindFirstChildOfClass("UIStroke")
						if stroke then
							stroke.Transparency = alpha
						end
					end
				end
				task.wait()
			end

			-- Cleanup
			if billboardGui.Parent then
				billboardGui:Destroy()
			end
			if footAnchor.Parent then
				footAnchor:Destroy()
			end
		end)
	end

	-- Timeline (at 60fps):
	-- Frame 0-39: Normal TimeScale (1), particles enabled
	-- Frame 40: TimeScale instantly set to 0 (freeze)
	-- Frame 46: TimeScale set back to 1, then disable particles

	local frame40Time = 40 / 60  -- 0.667 seconds
	local frame46Time = 46 / 60  -- 0.767 seconds

	-- At frame 40: Set TimeScale to 0 (instant freeze)
	task.delay(frame40Time, function()
		if not loadClone or not loadClone.Parent then return end

		for _, particle in particles do
			if particle and particle.Parent then
				particle.TimeScale = 0
			end
		end
	end)

	-- At frame 46: Set TimeScale back to 1, then disable
	task.delay(frame46Time, function()
		if not loadClone or not loadClone.Parent then return end

		for _, particle in particles do
			if particle and particle.Parent then
				particle.TimeScale = 1
				particle.Enabled = false
			end
		end
	end)

	-- Cleanup after effect completes
	task.delay(3, function()
		if loadClone and loadClone.Parent then
			loadClone:Destroy()
		end
	end)
end

return Weapons
