local ServerStorage = game:GetService("ServerStorage")
local Replicated = game:GetService("ReplicatedStorage")
local Server
local Utilities = require(Replicated.Modules.Utilities)
local Library = require(Replicated.Modules.Library)
local Packets = require(Replicated.Modules.Packets)
local Visuals = require(Replicated.Modules.Visuals)
local WeaponStats = require(ServerStorage.Stats._Weapons)
local MoveStats = require(ServerStorage.Stats._Moves)
local Ragdoll = require(Replicated.Modules.Utils.Ragdoll)

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
		Server.Library.SetCooldown(Character, script.Name, 10) -- 10 second cooldown
		Server.Library.StopAllAnims(Character)

		local Alchemy = Library.PlayAnimation(Character, Animation)
		if not Alchemy then
			return
		end

		Alchemy.Looped = false

		Server.Library.TimedState(Character.Actions, script.Name, Alchemy.Length)
		Server.Library.TimedState(Character.Speeds, "AlcSpeed-0", Alchemy.Length)
		Server.Library.TimedState(Character.Speeds, "Jump-50", Alchemy.Length) -- Prevent jumping during move

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
			local s = Replicated.Assets.SFX.FMAB.Transmute:Clone()
			s.Parent = Character.HumanoidRootPart
			s:Play()
			Debris:AddItem(s, s.TimeLength)

			local root = Character.HumanoidRootPart
			if not root then return end

			-- Get character's forward direction
			local forwardDirection = root.CFrame.LookVector

			-- Number of lances to spawn
			local numLances = 6

			-- Spawn lances in a path in front of the player
			for i = 1, numLances do
				task.delay((i - 1) * 0.12, function() -- 0.12 second delay between each lance
					-- Calculate position for this lance
					local baseDistance = 8 + (i * 5) -- Start at 8 studs, add 5 studs per lance

					-- Add random offset perpendicular to forward direction
					local rightDirection = Vector3.new(forwardDirection.Z, 0, -forwardDirection.X).Unit
					local randomOffset = rightDirection * math.random(-4, 4) -- Random offset left/right

					local spawnPos = root.Position + (forwardDirection * baseDistance) + randomOffset
					spawnPos = Vector3.new(spawnPos.X, root.Position.Y, spawnPos.Z) -- Keep Y at ground level

					-- Transmutation circle for each lance
					Server.Visuals.Ranged(spawnPos, 300, {
						Module = "Base",
						Function = "TransmutationCircle",
						Arguments = { Character, CFrame.new(spawnPos) * CFrame.new(0, -2, 0), 1.5 }, -- Cleanup at 1.5s (lance destroyed at 2s)
					})

					task.delay(0.2, function()
						local sl = Replicated.Assets.VFX.SL:Clone()
						sl.Size = sl.Size * 1.5 -- Slightly smaller than single Stone Lance

						local wedgeHeight = sl.Size.Y
						local startPos = CFrame.new(spawnPos) * CFrame.new(0, -wedgeHeight - 2, 0)
						-- Spring bounce: overshoot the target position
						local targetHeight = 3
						local overshootHeight = targetHeight + 1.2 -- Bounce up extra
						local endPos = CFrame.new(spawnPos) * CFrame.new(0, targetHeight, 0)
						local overshootPos = CFrame.new(spawnPos) * CFrame.new(0, overshootHeight, 0)

						sl.CFrame = startPos
						sl.Anchored = true
						sl.CanCollide = false
						sl.Parent = workspace.World.Visuals

						-- Create crater when lance emerges
						local craterPosition = spawnPos + Vector3.new(0, 1, 0)
						Server.Visuals.Ranged(spawnPos, 300, {
							Module = "Base",
							Function = "StoneLanceCrater",
							Arguments = { craterPosition },
						})

						-- Spring animation: bounce up then settle
						-- Phase 1: Rise up with overshoot (0.15s)
						local tweenInfo1 = TweenInfo.new(
							0.15,
							Enum.EasingStyle.Quad,
							Enum.EasingDirection.Out
						)

						local tween1 = TweenService:Create(sl, tweenInfo1, {
							CFrame = overshootPos
						})

						-- Phase 2: Settle down to final position (0.12s)
						local tweenInfo2 = TweenInfo.new(
							0.12,
							Enum.EasingStyle.Elastic,
							Enum.EasingDirection.Out
						)

						local tween2 = TweenService:Create(sl, tweenInfo2, {
							CFrame = endPos
						})

						-- Play spring animation sequence
						table.insert(activeTweens, tween1)
						table.insert(activeTweens, tween2)

						tween1:Play()
						tween1.Completed:Connect(function()
							tween2:Play()
						end)

						-- Camera shake and recoil when lance emerges
						Server.Visuals.Ranged(spawnPos, 300, {
							Module = "Base",
							Function = "StoneLancePathShake",
							Arguments = { spawnPos },
						})

						-- Apply recoil to caster (backward push)
						task.delay(0.05, function()
							if Character and Character:FindFirstChild("HumanoidRootPart") then
								local casterRoot = Character.HumanoidRootPart
								local recoilDirection = -forwardDirection -- Backward from lance direction
								local recoilStrength = 2 -- Subtle recoil

								-- Check if caster is a player or NPC
								local casterPlayer = game.Players:GetPlayerFromCharacter(Character)

								if casterPlayer then
									-- For players: Send to their client
									Packets.Bvel.sendTo({
										Character = Character,
										Name = "StoneLancePathRecoil",
										Targ = Character,
										Velocity = Vector3.new(
											recoilDirection.X * recoilStrength,
											0,
											recoilDirection.Z * recoilStrength
										)
									}, casterPlayer)
								else
									-- For NPCs: Create on server
									local attachment = casterRoot:FindFirstChild("StoneLancePathRecoilAttachment")
									if not attachment then
										attachment = Instance.new("Attachment")
										attachment.Name = "StoneLancePathRecoilAttachment"
										attachment.Parent = casterRoot
									end

									local oldRecoil = casterRoot:FindFirstChild("StoneLancePathRecoil")
									if oldRecoil then
										oldRecoil:Destroy()
									end

									local recoilVelocity = Instance.new("LinearVelocity")
									recoilVelocity.Name = "StoneLancePathRecoil"
									recoilVelocity.MaxForce = 5000
									recoilVelocity.VectorVelocity = Vector3.new(
										recoilDirection.X * recoilStrength,
										0,
										recoilDirection.Z * recoilStrength
									)
									recoilVelocity.Attachment0 = attachment
									recoilVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
									recoilVelocity.Parent = casterRoot

									task.delay(0.15, function()
										if recoilVelocity and recoilVelocity.Parent then
											recoilVelocity:Destroy()
										end
									end)
								end
							end
						end)

						-- VFX particles
						task.delay(0.08, function()
							local vfx = Replicated.Assets.VFX.WallVFX:Clone()
							for _, v in vfx:GetChildren() do
								if v:IsA("ParticleEmitter") then
									v.Parent = sl
								end
							end

							task.delay(.1, function()
								for _, v in sl:GetChildren() do
									if v:IsA("ParticleEmitter") then
										v:Emit(v:GetAttribute("EmitCount"))
									end
								end
							end)
						end)

						-- Hitbox detection
						task.delay(0.12, function()
							local Hitbox = Server.Modules.Hitbox
							local hitboxSize = sl.Size * 1.25
							local hitboxCFrame = sl.CFrame * CFrame.new(0, wedgeHeight/2, 0)

							local HitTargets = Hitbox.SpatialQuery(
								Character,
								hitboxSize,
								hitboxCFrame,
								false
							)

							for _, Target in pairs(HitTargets) do
								if Target ~= Character and Target:IsA("Model") and Target:FindFirstChild("Humanoid") then
									if moveData and moveData.DamageTable then
										Server.Modules.Damage.Tag(Character, Target, moveData.DamageTable)
									end

									local hitTargetRoot = Target:FindFirstChild("HumanoidRootPart")
									if hitTargetRoot then
										local direction = (hitTargetRoot.Position - root.Position).Unit
										local horizontalPower = 8
										local upwardPower = 25

										local velocity = Vector3.new(
											direction.X * horizontalPower,
											upwardPower,
											direction.Z * horizontalPower
										)

										local targetHumanoid = Target:FindFirstChild("Humanoid")
										if targetHumanoid then
											targetHumanoid.PlatformStand = true
										end

										-- Check if target is a player or NPC
										local targetPlayer = game.Players:GetPlayerFromCharacter(Target)

										if targetPlayer then
											-- For players: Send to that player's client
											Packets.Bvel.sendTo({
												Character = Target,
												Name = "StoneLaunchVelocity",
												Targ = Target,
												Velocity = velocity
											}, targetPlayer)
										else
											-- For NPCs: Create on server AND send to all clients
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

											local lv = Instance.new("LinearVelocity")
											lv.Name = "StoneLaunchVelocity"
											lv.MaxForce = math.huge
											lv.VectorVelocity = velocity
											lv.Attachment0 = attachment
											lv.RelativeTo = Enum.ActuatorRelativeTo.World
											lv.Parent = hitTargetRoot

											Packets.Bvel.sendToAll({
												Character = Target,
												Name = "StoneLaunchVelocity",
												Targ = Target,
												Velocity = velocity
											})

											task.delay(0.8, function()
												if lv and lv.Parent then
													lv:Destroy()
												end
											end)
										end

										Ragdoll.Ragdoll(Target, 3.5)

										task.delay(0.8, function()
											if targetHumanoid then
												targetHumanoid.PlatformStand = false
											end
										end)
									end
								end
							end
						end)

						-- Shake then shatter after 2 seconds
						task.delay(2, function()
							if sl and sl.Parent then
								local wedgeSize = sl.Size
								local wedgeColor = sl.Color
								local wedgeMaterial = sl.Material
								local wedgeCFrame = sl.CFrame
								local originalCFrame = sl.CFrame

								-- Shake effect before breaking (0.25 seconds of shaking)
								local shakeIntensity = 0.25
								local shakeDuration = 0.25
								local shakeStartTime = tick()

								local shakeConnection
								shakeConnection = game:GetService("RunService").Heartbeat:Connect(function()
									if not sl or not sl.Parent then
										shakeConnection:Disconnect()
										return
									end

									local elapsed = tick() - shakeStartTime
									if elapsed >= shakeDuration then
										shakeConnection:Disconnect()
										sl.CFrame = originalCFrame -- Reset to original position

										-- Break apart after shake
										local numShards = math.random(8, 12)

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
												(math.random() - 0.5) * wedgeSize.Z * 0.8)

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

											local velocityVector = randomDir * math.random(10, 16)

											shard.AssemblyLinearVelocity = velocityVector

											local velocity = Instance.new("BodyVelocity")
											velocity.Velocity = velocityVector
											velocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
											velocity.Parent = shard

											local fadeInfo = TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
											local fadeTween = TweenService:Create(shard, fadeInfo, {Transparency = 1})
											fadeTween:Play()

											Debris:AddItem(velocity, 0.3)
											Debris:AddItem(shard, 2)
										end

										sl:Destroy()
										return
									end

									-- Apply random shake offset
									local shakeOffset = Vector3.new(
										(math.random() - 0.5) * shakeIntensity,
										(math.random() - 0.5) * shakeIntensity,
										(math.random() - 0.5) * shakeIntensity
									)
									sl.CFrame = originalCFrame * CFrame.new(shakeOffset)
								end)
							end
						end)
					end)
				end)
			end
		end)
	end
end

return NetworkModule
