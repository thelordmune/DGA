local ServerStorage = game:GetService("ServerStorage")
local Replicated = game:GetService("ReplicatedStorage")
local Server
local Utilities = require(Replicated.Modules.Utilities)
local Library = require(Replicated.Modules.Library)
local Packets = require(Replicated.Modules.Packets)
local Visuals = require(Replicated.Modules.Visuals)
local Voxbreaker = require(Replicated.Modules.Voxel)
local SFX = Replicated.Assets.SFX
local WeaponStats = require(ServerStorage.Stats._Weapons)
local Moves = require(ServerStorage.Stats._Moves)
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local RunService = game:GetService("RunService")

local NetworkModule = {}
local Server = require(script.Parent.Parent)
NetworkModule.__index = NetworkModule
local self = setmetatable({}, NetworkModule)

local activeConnections = {}
local activeTweens = {}

local function cleanUp()
	for _, conn in pairs(activeConnections) do
		conn:Disconnect()
	end
	activeConnections = {}

	for _, t in pairs(activeTweens) do
		t:Cancel()
	end
	activeTweens = {}
end

NetworkModule.EndPoint = function(Player, Data)
	local Character = Player.Character

	if not Character or not Character:GetAttribute("Equipped") then
		return
	end

	local PlayerObject = Server.Modules["Players"].Get(Player)
	local Animation = Replicated.Assets.Animations.Abilities.Stone[script.Name]

	local root = Character:FindFirstChild("HumanoidRootPart")

	if Server.Library.StateCount(Character.Actions) or Server.Library.StateCount(Character.Stuns) then
		return
	end

	if PlayerObject and PlayerObject.Keys and not Server.Library.CheckCooldown(Character, "RockSkewer") then
		cleanUp()
		Server.Library.SetCooldown(Character, "RockSkewer", 3)
		Server.Library.StopAllAnims(Character)
		print("doing rock skewer")


		local Alchemy = Library.PlayAnimation(Character, Animation)
		Alchemy.Looped = false
		local tim = Alchemy:GetTimeOfKeyframe("Launch")

		Server.Library.TimedState(Character.Actions, "RockSkewer", Alchemy.Length)
		Server.Library.TimedState(Character.Stuns, "NoRotate", Alchemy.Length)
		Server.Library.TimedState(Character.Speeds, "AlcSpeed-0", Alchemy.Length)

		local rock = Instance.new("Part")
		rock.Anchored = true
		rock.CanCollide = false
		rock.Size = Vector3.new(2, 2, 2)
		rock.Transparency = 1
		rock.CFrame = root.CFrame * CFrame.new(0, -3, -5)
		rock.Parent = Character

		local mesh = Instance.new("SpecialMesh", rock)
		mesh.MeshType = Enum.MeshType.FileMesh
		mesh.MeshId = "rbxassetid://1290033"
		mesh.TextureId = "rbxassetid://1290030"
		mesh.Scale = Vector3.new(1, 1, 1)

		local rockSpinSpeed = 50
		local rockSpinConnection


		local poofSpinSpeed = 15
		local poofSpinConnection
		local poofMoveSpeed = 90
		local kfConn
		kfConn = Alchemy.KeyframeReached:Connect(function(key)
			if key == "Stomp" then
				rock.Transparency = 0
				local s = Replicated.Assets.SFX.Skills.RockSkewer.Stomp:Clone()
				s.Volume = 2
				s.Parent = Character.HumanoidRootPart
				s:Play()
				Debris:AddItem(s, s.TimeLength)

				rockSpinConnection = RunService.Heartbeat:Connect(function(dt)
					rock.CFrame = rock.CFrame
						* CFrame.Angles(rockSpinSpeed * dt, rockSpinSpeed * dt, rockSpinSpeed * dt)
				end)
				table.insert(activeConnections, rockSpinConnection)

				local TInfo = TweenInfo.new(tim - 0.2, Enum.EasingStyle.Bounce)
				local tween = TweenService:Create(rock, TInfo, { CFrame = root.CFrame * CFrame.new(0, 0, -5) })
				tween:Play()
				table.insert(activeTweens, tween)
				Server.Visuals.Ranged(
					root.Position,
					300,
					{ Module = "Base", Function = "RockSkewer", Arguments = { Character, "Stomp" } }
				)
			end

			if key == "Launch" then
				local s = Replicated.Assets.SFX.Skills.RockSkewer.Launch:Clone()
				s.Volume = 1
				s.Parent = Character.HumanoidRootPart
				s:Play()
				Debris:AddItem(s, s.TimeLength)
				local sound = Replicated.Assets.SFX.Skills.RockSkewer.Deconstruct:Clone()
				sound.Volume = 3
				sound.Parent = Character.HumanoidRootPart
				sound:Play()
				Debris:AddItem(sound, sound.TimeLength)
				if rockSpinConnection then
					rockSpinConnection:Disconnect()
				end
				rock:Destroy()

				local poof = Replicated.Assets.VFX.Poof:Clone()
				poof.Anchored = true
				poof.CanCollide = false
				poof.CFrame = root.CFrame * CFrame.new(0, 0, -5) * CFrame.Angles(math.rad(-90), 0, 0)
				poof.Parent = workspace.World.Visuals

				local startTime = os.time()
				local hitSomething = false

				poofSpinConnection = RunService.Heartbeat:Connect(function(dt)
					if hitSomething then
						return
					end

					local previousPosition = poof.Position

					poof.CFrame = poof.CFrame * CFrame.Angles(0, poofSpinSpeed * dt, 0)

					local forwardVector = root.CFrame.LookVector
					poof.CFrame = poof.CFrame + forwardVector * poofMoveSpeed * dt

					local raycastParams = RaycastParams.new()
					raycastParams.FilterDescendantsInstances = { Character, poof }
					raycastParams.FilterType = Enum.RaycastFilterType.Blacklist

					local raycastResult =
						workspace:Raycast(previousPosition, (poof.Position - previousPosition), raycastParams)

					if raycastResult then
						local hitPart = raycastResult.Instance
						local hitHumanoid = hitPart:FindFirstAncestorOfClass("Model"):FindFirstChildOfClass("Humanoid")

						if hitHumanoid and hitHumanoid ~= Character.Humanoid then
							hitSomething = true
							local target = hitHumanoid.Parent
							Server.Modules.Damage.Tag(Character, target, Moves.Stone["DamageTable1"])

							Server.Visuals.Ranged(
								root.Position,
								300,
								{ Module = "Base", Function = "Wallbang", Arguments = { hitPart.Position } }
							)
						elseif hitPart then
							hitSomething = true
							Server.Visuals.Ranged(
								root.Position,
								300,
								{ Module = "Base", Function = "Wallbang", Arguments = { hitPart.Position } }
							)
						end

						if hitSomething then
							poofSpinConnection:Disconnect()
							poof:Destroy()
						end
					end
				end)
				table.insert(activeConnections, poofSpinConnection)
				Server.Visuals.Ranged(
					root.Position,
					300,
					{ Module = "Base", Function = "RockSkewer", Arguments = { Character, "Launch", poof } }
				)

				Debris:AddItem(poof, 2)
			end
		end)
		table.insert(activeConnections, kfConn)
	end
end

return NetworkModule
