local ServerStorage = game:GetService("ServerStorage")
local Replicated = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Library = require(Replicated.Modules.Library)
local Skills = require(ServerStorage.Stats._Skills)
local VoxBreaker = require(Replicated.Modules.Voxel)
local Debris = game:GetService("Debris")

local Global = require(Replicated.Modules.Shared.Global)
local world = require(Replicated.Modules.ECS.jecs_world)
local comps = require(Replicated.Modules.ECS.jecs_components)
local RefManager = require(Replicated.Modules.ECS.jecs_ref_manager)
return function(Player, Data, Server)
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

	-- Get weapon - for NPCs use attribute, for players use Global.GetData
	local Weapon
	if isNPC then
		Weapon = Character:GetAttribute("Weapon") or "Guns"
	else
		Weapon = Global.GetData(Player).Weapon
	end

	-- WEAPON CHECK: This skill requires Guns weapon
	if Weapon ~= "Guns" then
		return -- Character doesn't have the correct weapon for this skill
	end

	local PlayerObject = Server.Modules["Players"].Get(Player)
	local Animation = Replicated.Assets.Animations.Skills.Weapons[Weapon][script.Name]

	if Server.Library.StateCount(Character.Actions) or Server.Library.StateCount(Character.Stuns) then
		return
	end

	-- For NPCs, skip the PlayerObject.Keys check
	local canUseSkill = isNPC or (PlayerObject and PlayerObject.Keys)

	if canUseSkill and not Server.Library.CheckCooldown(Character, script.Name) then
		-- Stop ALL animations first (including dash) to prevent animation root motion from interfering
		Server.Library.StopAllAnims(Character)

		-- Remove any existing body movers FIRST
		Server.Packets.Bvel.sendTo({Character = Character, Name = "RemoveBvel"},Player)

		Server.Library.SetCooldown(Character, script.Name, 5)

		-- Play animation to get the track and length
		local Move = Library.PlayAnimation(Character, Animation)
		local animlength = Move.Length

		-- Add action-blocking states immediately after playing animation
		-- Server.Library.TimedState(Character.Stuns, "RapidThrustActive", animlength) -- Prevent all actions (set FIRST)
		Server.Library.TimedState(Character.Actions, script.Name, animlength)
		Server.Library.TimedState(Character.Speeds, "AlcSpeed5", animlength)
		Server.Library.TimedState(Character.Speeds, "Jump-50", animlength) -- Prevent jumping during move

	    local hittimes = {}
		for i, fraction in Skills[Weapon][script.Name].Hittimes do
			hittimes[i] = fraction * animlength
		end

		-- Store sound for cleanup
		local hellraiserSound

		-- MULTI-HIT FIX: Track first victim for multi-hit state
		local multiHitVictim = nil

        task.delay(hittimes[1], function()
			-- CHECK IF SKILL WAS CANCELLED
			if not Server.Library.StateCheck(Character.Actions, script.Name) then
				return
			end

            Server.Visuals.Ranged(Character.HumanoidRootPart.Position, 300, {
				Module = "Weapons",
				Function = "Hellraiser",
				Arguments = { Character, "1"},
			})
            hellraiserSound = Library.PlaySound(Character.HumanoidRootPart, Replicated.Assets.SFX.Skills.Hellraiser, true)

            for _ = 1, 10 do
				-- CHECK IF SKILL WAS CANCELLED
				if not Server.Library.StateCheck(Character.Actions, script.Name) then
					if hellraiserSound and hellraiserSound.Parent then
						hellraiserSound:Stop()
						hellraiserSound:Destroy()
					end
					return
				end

                task.wait(0.005)
            local Hitbox = Server.Modules.Hitbox
					local Entity = Server.Modules["Entities"].Get(Character)
					if Entity then
						local HitTargets = Hitbox.SpatialQuery(
							Character,
							Vector3.new(6,4,8),
							Entity:GetCFrame() * CFrame.new(0, 0, -6),
							false
						)

						for _, Target in pairs(HitTargets) do
							-- MULTI-HIT FIX: Mark first victim with MultiHitVictim state
							if not multiHitVictim then
								multiHitVictim = Target
								-- Mark victim for multi-hit combo (duration = full animation length)
								Server.Library.TimedState(Target.IFrames, "MultiHitVictim", animlength)
							end

							Server.Modules.Damage.Tag(Character, Target, {
								Damage = Skills[Weapon][script.Name].Hit.Damage,
								PostureDamage = Skills[Weapon][script.Name].Hit.PostureDamage,
								Stun = Skills[Weapon][script.Name].Hit.Stun,
								BlockBreak = Skills[Weapon][script.Name].Hit.BlockBreak,
								M1 = false,
								M2 = false,
								FX = Skills[Weapon][script.Name].Hit.FX,
							})
						end
					end
                end
        end)
        task.delay(hittimes[2], function()
			-- CHECK IF SKILL WAS CANCELLED
			if not Server.Library.StateCheck(Character.Actions, script.Name) then
				if hellraiserSound and hellraiserSound.Parent then
					hellraiserSound:Stop()
					hellraiserSound:Destroy()
				end
				return
			end

            Server.Visuals.Ranged(Character.HumanoidRootPart.Position, 300, {
				Module = "Weapons",
				Function = "Hellraiser",
				Arguments = { Character, "2"},
			})
            local Hitbox = Server.Modules.Hitbox
					local Entity = Server.Modules["Entities"].Get(Character)
					if Entity then
						local HitTargets = Hitbox.SpatialQuery(
							Character,
							Vector3.new(4,4,8),
							Entity:GetCFrame() * CFrame.new(0, 0, -6),
							false
						)

						for _, Target in pairs(HitTargets) do
							Server.Modules.Damage.Tag(Character, Target, {
								Damage = Skills[Weapon][script.Name].Hit.Damage,
								PostureDamage = Skills[Weapon][script.Name].Hit.PostureDamage,
								Stun = Skills[Weapon][script.Name].Hit.Stun,
								BlockBreak = Skills[Weapon][script.Name].Hit.BlockBreak,
								M1 = false,
								M2 = false,
								FX = Skills[Weapon][script.Name].Hit.FX,
							})
						end
					end
        end)
        task.delay(hittimes[3], function()
			-- CHECK IF SKILL WAS CANCELLED
			if not Server.Library.StateCheck(Character.Actions, script.Name) then
				if hellraiserSound and hellraiserSound.Parent then
					hellraiserSound:Stop()
					hellraiserSound:Destroy()
				end
				return
			end

            Server.Visuals.Ranged(Character.HumanoidRootPart.Position, 300, {
				Module = "Weapons",
				Function = "Hellraiser",
				Arguments = { Character, "3"},
			})
            local Hitbox = Server.Modules.Hitbox
					local Entity = Server.Modules["Entities"].Get(Character)
					if Entity then
						local HitTargets = Hitbox.SpatialQuery(
							Character,
							Vector3.new(4,6,18),
							Entity:GetCFrame() * CFrame.new(0, 0, -10),
							false
						)

						local targets = {}
						local soundeffects = {}
						local root = Character.HumanoidRootPart

						for _, Target in pairs(HitTargets) do
							-- Hit enemies
							if Target ~= Character and Target:IsA("Model") and not table.find(targets, Target) then
								table.insert(targets, Target)
								Server.Modules.Damage.Tag(Character, Target, {
									Damage = Skills[Weapon][script.Name].FinalHit.Damage,
									PostureDamage = Skills[Weapon][script.Name].FinalHit.PostureDamage,
									Stun = Skills[Weapon][script.Name].FinalHit.Stun,
									BlockBreak = Skills[Weapon][script.Name].FinalHit.BlockBreak,
									M1 = false,
									M2 = false,
									Knockback = true,
									Status = Skills[Weapon][script.Name].FinalHit.Status,
									FX = Skills[Weapon][script.Name].FinalHit.FX,
								})
							end

							-- Destroy Construct walls (same as Deconstruct and Shell Piercer)
							if Target:GetAttribute("Id") then
								if not soundeffects[Target] then
									soundeffects[Target] = {
										wallhit = Replicated.Assets.SFX.Hits.RAHit:Clone(),
									}
									soundeffects[Target].wallhit.Parent = root
									soundeffects[Target].wallhit.Volume = 1
									soundeffects[Target].wallhit.TimePosition = 0.35
									soundeffects[Target].wallhit:Play()
									Debris:AddItem(soundeffects[Target].wallhit, soundeffects[Target].wallhit.TimeLength)
								end

								Server.Visuals.FireClient(Player, {
									Module = "Base",
									Function = "Shake",
									Arguments = {
										"Once",
										{ 6, 11, 0, 0.7, Vector3.new(1.1, 2, 1.1), Vector3.new(0.34, 0.25, 0.34) },
									},
								})

								-- Voxelize the wall permanently (negative time = no reset)
								local parts = VoxBreaker:VoxelizePart(Target, 20, -1)
								local playerForward = root.CFrame.LookVector
								playerForward = Vector3.new(playerForward.X, playerForward.Y, playerForward.Z).Unit

								-- Fling the destroyed parts forward
								for _, v in pairs(parts) do
									if v:IsA("BasePart") then
										-- Add trail to the debris part
										local attachment0 = Instance.new("Attachment")
										attachment0.Name = "TrailAttachment0"
										attachment0.Position = Vector3.new(0, v.Size.Y/2, 0)
										attachment0.Parent = v

										local attachment1 = Instance.new("Attachment")
										attachment1.Name = "TrailAttachment1"
										attachment1.Position = Vector3.new(0, -v.Size.Y/2, 0)
										attachment1.Parent = v

										local trail = Instance.new("Trail")
										trail.Attachment0 = attachment0
										trail.Attachment1 = attachment1

										-- White trail color
										trail.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
										trail.Transparency = NumberSequence.new({
											NumberSequenceKeypoint.new(0, 0.4),
											NumberSequenceKeypoint.new(0.7, 0.7),
											NumberSequenceKeypoint.new(1, 1)
										})
										trail.Lifetime = 0.8
										trail.MinLength = 0

										-- Much smaller trail
										trail.WidthScale = NumberSequence.new({
											NumberSequenceKeypoint.new(0, 0.2),
											NumberSequenceKeypoint.new(0.5, 0.1),
											NumberSequenceKeypoint.new(1, 0.05)
										})

										trail.FaceCamera = true
										trail.LightEmission = 0.2
										trail.LightInfluence = 0.8
										trail.Parent = v

										-- Create a connection to update the hitbox as the part moves
										local hitConnection
										hitConnection = RunService.PostSimulation:Connect(function()
											local TargetsFound = Hitbox.SpatialQuery(
												Character,
												v.Size,
												v.CFrame,
												false
											)

											for _, target in TargetsFound do
												if target ~= Character and not table.find(targets, target) and target:IsA("Model") then
													table.insert(targets, target)
													Server.Modules.Damage.Tag(Character, target, {
														Damage = 5,
														PostureDamage = 8,
														Stun = 0.3,
														LightKnockback = true,
														M2 = false,
														FX = Replicated.Assets.VFX.Blood.Attachment,
													})
												end
											end
										end)

										v.CollisionGroup = "Rock"
										v.Anchored = false
										v.CanCollide = true

										local randomSpread = Vector3.new(
											(math.random() - 0.5) * 0.5,
											math.random() * 0.5,
											(math.random() - 0.5) * 0.5
										)

										local combinedDirection = (playerForward + randomSpread).Unit
										local velocityVector = combinedDirection * 120

										v.AssemblyLinearVelocity = velocityVector

										local debrisVelocity = Instance.new("BodyVelocity")
										debrisVelocity.Velocity = velocityVector
										debrisVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
										debrisVelocity.Parent = v

										v.Destroying:Connect(function()
											hitConnection:Disconnect()
										end)

										Debris:AddItem(debrisVelocity, 0.5)
										Debris:AddItem(v, 8 + math.random() * 4)
									end
								end
							end
						end
					end
        end)
    end
end