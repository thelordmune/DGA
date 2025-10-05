local ServerStorage = game:GetService("ServerStorage")
local Replicated = game:GetService("ReplicatedStorage")
local Server
local Utilities = require(Replicated.Modules.Utilities)
local Library = require(Replicated.Modules.Library)
local Packets = require(Replicated.Modules.Packets)
local Visuals = require(Replicated.Modules.Visuals)
local WeaponStats = require(ServerStorage.Stats._Weapons)
local MoveStats = require(ServerStorage.Stats._Moves)
local LooseRagdoll = require(Replicated.Modules.Utils.LooseRagdoll)

local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

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

local function getFloorMaterial(character)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil, nil
	end

	local rayOrigin = root.Position
	local rayDirection = Vector3.new(0, -10, 0)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = { character }
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude

	local raycastResult = workspace:Raycast(rayOrigin, rayDirection, raycastParams)
	if raycastResult then
		return raycastResult.Instance.Material, raycastResult.Instance.Color
	end

	return nil, nil
end

NetworkModule.EndPoint = function(Player, Data)
	local Character = Player.Character

	if not Character then
		return
	end

	-- Check if this is an NPC (no Player instance) or a real player
	local isNPC = typeof(Player) ~= "Instance" or not Player:IsA("Player")

	-- For players, check equipped status
	if not isNPC and not Character:GetAttribute("Equipped") then
		return
	end

	local PlayerObject = Server.Modules["Players"].Get(Player)
	local Animation = Replicated.Assets.Animations.Misc.Alchemy

	if Server.Library.StateCount(Character.Actions) or Server.Library.StateCount(Character.Stuns) then
		return
	end

	-- For NPCs, skip the PlayerObject.Keys check
	local canUseSkill = isNPC or (PlayerObject and PlayerObject.Keys)

	if canUseSkill and not Server.Library.CheckCooldown(Character, script.Name) then
		cleanUp()
		Server.Library.SetCooldown(Character, script.Name, 5)
		Server.Library.StopAllAnims(Character)

		local Alchemy = Library.PlayAnimation(Character, Animation)
		if not Alchemy then
			print("Failed to load Stone Lance animation")
			return
		end

		Alchemy.Looped = false
		print("Stone Lance animation loaded, Length:", Alchemy.Length)

		Server.Library.TimedState(Character.Actions, script.Name, Alchemy.Length)
		Server.Library.TimedState(Character.Speeds, "AlcSpeed-0", Alchemy.Length)

		local hittimes = {}
		local moveData = MoveStats[script.Name]
		if moveData and moveData.DamageTable and moveData.DamageTable.Hittimes then
			for i, fraction in ipairs(moveData.DamageTable.Hittimes) do
				hittimes[i] = fraction * Alchemy.Length
			end
		else
			hittimes = {(17/72) * Alchemy.Length, (46/72) * Alchemy.Length}
		end

        task.delay(hittimes[1], function()
           local s = Replicated.Assets.SFX.FMAB.Clap:Clone()
					s.Parent = Character.HumanoidRootPart
					s:Play()
					Debris:AddItem(s, s.TimeLength)

					Server.Visuals.Ranged(Character.HumanoidRootPart.Position, 300, {
						Module = "Base",
						Function = "Clap",
						Arguments = { Character},
					})
        end)

		task.delay(hittimes[2], function()
			local root = Character.HumanoidRootPart
			if not root then return end

			local detectionRange = 30
			local hasValidTarget = false
			local nearestTarget = nil
			local nearestDistance = math.huge

			for _, entity in pairs(workspace.World.Live:GetDescendants()) do
				if entity:IsA("Model") and entity ~= Character and entity:FindFirstChild("Humanoid") and entity:FindFirstChild("HumanoidRootPart") then
					local targetRoot = entity.HumanoidRootPart
					local distance = (targetRoot.Position - root.Position).Magnitude

					if distance <= detectionRange and distance < nearestDistance then
						hasValidTarget = true
						nearestTarget = entity
						nearestDistance = distance
					end
				end
			end

			if not hasValidTarget or not nearestTarget then
				return
			end

			local targetRoot = nearestTarget.HumanoidRootPart
			local spawnPos = Vector3.new(targetRoot.Position.X, root.Position.Y, targetRoot.Position.Z)

			Server.Visuals.Ranged(Character.HumanoidRootPart.Position, 300, {
				Module = "Base",
				Function = "TransmutationCircle",
				Arguments = { Character, CFrame.new(spawnPos) * CFrame.new(0, -2, 0)},
			})

			task.delay(0.3, function()
				local sl = Replicated.Assets.VFX.SL:Clone()

				local wedgeHeight = sl.Size.Y
				local startPos = CFrame.new(spawnPos) * CFrame.new(0, -wedgeHeight - 2, 0)
				local endPos = CFrame.new(spawnPos) * CFrame.new(0, 4, 0)

				sl.CFrame = startPos
				sl.Anchored = true
				sl.CanCollide = false
				sl.Parent = workspace.World.Visuals

				local tweenInfo = TweenInfo.new(
					0.5,
					Enum.EasingStyle.Circular,
					Enum.EasingDirection.InOut
				)

				local tween = TweenService:Create(sl, tweenInfo, {
					CFrame = endPos
				})
				table.insert(activeTweens, tween)
				tween:Play()

				task.delay(0.15, function()
					local vfx = Replicated.Assets.VFX.WallVFX:Clone()
					for _, v in vfx:GetChildren() do
						if v:IsA("ParticleEmitter") then
							v.Parent = sl
						end
					end

					task.delay(.15, function()
						for _, v in sl:GetChildren() do
							if v:IsA("ParticleEmitter") then
								v:Emit(v:GetAttribute("EmitCount"))
							end
						end
					end)
				end)

				task.delay(0.25, function()
					local Hitbox = Server.Modules.Hitbox
					local hitboxSize = sl.Size
					local hitboxCFrame = sl.CFrame * CFrame.new(0, wedgeHeight/2, 0)

					local HitTargets = Hitbox.SpatialQuery(
						Character,
						hitboxSize,
						hitboxCFrame,
						false
					)

					for _, Target in pairs(HitTargets) do
						if Target ~= Character and Target:IsA("Model") and Target:FindFirstChild("Humanoid") then
							print("Stone Lance hit:", Target.Name)

							if moveData and moveData.DamageTable then
								Server.Modules.Damage.Tag(Character, Target, moveData.DamageTable)
							end

							local hitTargetRoot = Target:FindFirstChild("HumanoidRootPart")
							if hitTargetRoot then
								local attachment = hitTargetRoot:FindFirstChild("StoneLanceAttachment")
								if not attachment then
									attachment = Instance.new("Attachment")
									attachment.Name = "StoneLanceAttachment"
									attachment.Parent = hitTargetRoot
								end

								local oldLV = hitTargetRoot:FindFirstChild("StoneLaunchVelocity")
								if oldLV then
									oldLV:Destroy()
								end

								local direction = (hitTargetRoot.Position - root.Position).Unit
								local horizontalPower = 10
								local upwardPower = 30

								local velocity = Vector3.new(
									direction.X * horizontalPower,
									upwardPower,
									direction.Z * horizontalPower
								)

								local targetHumanoid = Target:FindFirstChild("Humanoid")
								if targetHumanoid then
									targetHumanoid.PlatformStand = true
								end

								local lv = Instance.new("LinearVelocity")
								lv.Name = "StoneLaunchVelocity"
								lv.MaxForce = math.huge
								lv.VectorVelocity = velocity
								lv.Attachment0 = attachment
								lv.RelativeTo = Enum.ActuatorRelativeTo.World
								lv.Parent = hitTargetRoot

								LooseRagdoll.Ragdoll(Target, 1.5)

								task.delay(0.8, function()
									if lv and lv.Parent then
										lv:Destroy()
									end
									if targetHumanoid then
										targetHumanoid.PlatformStand = false
									end
								end)
							end
						end
					end
				end)

				task.delay(2.5, function()
					if sl and sl.Parent then
						local wedgeSize = sl.Size
						local wedgeColor = sl.Color
						local wedgeMaterial = sl.Material
						local wedgeCFrame = sl.CFrame

						local numShards = math.random(12, 18)

						for _ = 1, numShards do
							local shard = Instance.new("WedgePart")
							shard.Size = Vector3.new(
								math.random(wedgeSize.X * 0.1, wedgeSize.X * 0.3),
								math.random(wedgeSize.Y * 0.2, wedgeSize.Y * 0.5),
								math.random(wedgeSize.Z * 0.1, wedgeSize.Z * 0.3)
							)
							shard.Color = wedgeColor
							shard.Material = wedgeMaterial
							shard.Anchored = false
							shard.CanCollide = true

							local randomOffset = Vector3.new(
								(math.random() - 0.5) * wedgeSize.X * 0.8,
								(math.random() - 0.5) * wedgeSize.Y * 0.5,
								(math.random() - 0.5) * wedgeSize.Z * 0.8
							)

							shard.CFrame = wedgeCFrame * CFrame.new(randomOffset) * CFrame.Angles(
								math.rad(math.random(0, 360)),
								math.rad(math.random(0, 360)),
								math.rad(math.random(0, 360))
							)

							shard.Parent = workspace.World.Visuals

							local randomDir = Vector3.new(
								(math.random() - 0.5) * 2,
								math.random() * 0.8 + 0.2,
								(math.random() - 0.5) * 2
							).Unit

							local velocityVector = randomDir * math.random(12, 20)

							shard.AssemblyLinearVelocity = velocityVector

							local velocity = Instance.new("BodyVelocity")
							velocity.Velocity = velocityVector
							velocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
							velocity.Parent = shard

							local fadeInfo = TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
							local fadeTween = TweenService:Create(shard, fadeInfo, {Transparency = 1})
							fadeTween:Play()

							Debris:AddItem(velocity, 0.4)
							Debris:AddItem(shard, 2.5)
						end

						sl:Destroy()
					end
				end)
			end)
		end)
	end
end

return NetworkModule