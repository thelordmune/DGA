local ServerStorage = game:GetService("ServerStorage")
local Replicated = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Library = require(Replicated.Modules.Library)
local Skills = require(ServerStorage.Stats._Skills)

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
		Weapon = Character:GetAttribute("Weapon") or "Spear"
	else
		Weapon = Global.GetData(Player).Weapon
	end

	-- WEAPON CHECK: This skill requires Spear weapon
	if Weapon ~= "Spear" then
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
		Library.PlaySound(Character.HumanoidRootPart, Replicated.Assets.SFX.Skills.RapidThrust, true, 0.1)

		-- Add action-blocking states immediately after playing animation
		Server.Library.TimedState(Character.Stuns, "RapidThrustActive", animlength) -- Prevent all actions (set FIRST)
		Server.Library.TimedState(Character.Actions, script.Name, animlength)
		Server.Library.TimedState(Character.Speeds, "AlcSpeed-0", animlength)
		Server.Library.TimedState(Character.Speeds, "Jump-50", animlength) -- Prevent jumping during move

		-- Initialize hyperarmor (prevents interruption from damage)
		Character:SetAttribute("HyperarmorDamage", 0)
		Character:SetAttribute("HyperarmorMove", script.Name)
		Server.Visuals.Ranged(Character.HumanoidRootPart.Position, 300, {
			Module = "Misc",
			Function = "StartHyperarmor",
			Arguments = { Character }
		})

		-- Calculate hittimes from fractions
		local hittimes = {}
		for i, fraction in Skills[Weapon][script.Name].Hittimes do
			hittimes[i] = fraction * animlength
		end

		-- Frame-based system
		local FPS = 60
		local startTime = os.clock()
		local velocityActive = false
		local velocityMover = nil
		local heartbeatConnection = nil
		local grabbedTarget = nil -- Track if we grabbed someone on frame 3
		local processedFrames = {} -- Track which frames we've already processed
		local multiHitVictim = nil -- Track the first victim hit for multi-hit state

		-- Map hittimes to frame numbers (assuming 60 FPS animation)
		local frameToHittime = {}
		for i, hittime in ipairs(hittimes) do
			local frameNumber = math.floor((hittime / animlength) * (animlength * FPS))
			frameToHittime[frameNumber] = i
		end

		-- Create forward velocity mover for frames 3-12
		local function createVelocityMover()
			local rootPart = Character.HumanoidRootPart
			if not rootPart then return end

			-- Create attachment if it doesn't exist
			local attachment = rootPart:FindFirstChild("RootAttachment")
			if not attachment then
				attachment = Instance.new("Attachment")
				attachment.Name = "RootAttachment"
				attachment.Parent = rootPart
			end

			-- Create LinearVelocity
			local lv = Instance.new("LinearVelocity")
			lv.Name = "RapidThrustVelocity"
			lv.MaxForce = math.huge
			lv.Attachment0 = attachment
			lv.RelativeTo = Enum.ActuatorRelativeTo.World
			lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
			lv.Parent = rootPart

			return lv
		end

		-- Frame update loop
		heartbeatConnection = RunService.Heartbeat:Connect(function()
			-- CHECK IF SKILL WAS CANCELLED (action state removed by CancelAllActions)
			if not Server.Library.StateCheck(Character.Actions, script.Name) then
				-- Skill was cancelled (hit by enemy, etc.) - cleanup immediately
				-- Stop animation using StopAllAnims to ensure it stops
				Server.Library.StopAllAnims(Character)

				-- Remove stun state to allow other actions
				Server.Library.RemoveState(Character.Stuns, "RapidThrustActive")

				-- Clean up hyperarmor
				Character:SetAttribute("HyperarmorDamage", nil)
				Character:SetAttribute("HyperarmorMove", nil)
				Server.Visuals.Ranged(Character.HumanoidRootPart.Position, 300, {
					Module = "Misc",
					Function = "RemoveHyperarmor",
					Arguments = { Character }
				})

				if heartbeatConnection then
					heartbeatConnection:Disconnect()
					heartbeatConnection = nil
				end
				if velocityMover and velocityMover.Parent then
					velocityMover:Destroy()
					velocityMover = nil
				end
				-- Release grab if still active
				if grabbedTarget then
					local grabberEntity = RefManager.entity.find(Character)
					if grabberEntity and world:has(grabberEntity, comps.Grab) then
						world:remove(grabberEntity, comps.Grab)
					end
				end
				return
			end

			local elapsed = os.clock() - startTime
			if elapsed >= animlength then
				-- Animation complete, cleanup
				-- Clean up hyperarmor
				Character:SetAttribute("HyperarmorDamage", nil)
				Character:SetAttribute("HyperarmorMove", nil)
				Server.Visuals.Ranged(Character.HumanoidRootPart.Position, 300, {
					Module = "Misc",
					Function = "RemoveHyperarmor",
					Arguments = { Character }
				})

				if heartbeatConnection then
					heartbeatConnection:Disconnect()
					heartbeatConnection = nil
				end
				if velocityMover and velocityMover.Parent then
					velocityMover:Destroy()
					velocityMover = nil
				end
				-- Release grab if still active
				if grabbedTarget then
					local grabberEntity = RefManager.entity.find(Character)
					if grabberEntity and world:has(grabberEntity, comps.Grab) then
						world:remove(grabberEntity, comps.Grab)
					end
				end
				return
			end

			-- Calculate current frame
			local currentFrame = math.floor((elapsed / animlength) * (animlength * FPS))

			-- Check if this frame has a hittime and hasn't been processed yet
			local hittimeIndex = frameToHittime[currentFrame]
			if hittimeIndex and not processedFrames[currentFrame] then
				processedFrames[currentFrame] = true -- Mark as processed

				-- Execute VFX and hitboxes for this frame
				if hittimeIndex == 1 then
					Server.Visuals.Ranged(Character.HumanoidRootPart.Position, 300, {
						Module = "Weapons",
						Function = "RapidThrust",
						Arguments = { Character, "1"},
					})

					-- Hitbox for first slash
					local Hitbox = Server.Modules.Hitbox
					local Entity = Server.Modules["Entities"].Get(Character)
					if Entity then
						local HitTargets = Hitbox.SpatialQuery(
							Character,
							Vector3.new(10, 6, 10),
							Entity:GetCFrame() * CFrame.new(0, 0, -3),
							false
						)

						for _, Target in pairs(HitTargets) do
							Server.Modules.Damage.Tag(Character, Target, {
								Damage = Skills[Weapon][script.Name].Slash1.Damage,
								PostureDamage = Skills[Weapon][script.Name].Slash1.PostureDamage,
								Stun = Skills[Weapon][script.Name].Slash1.Stun,
								BlockBreak = Skills[Weapon][script.Name].Slash1.BlockBreak,
								M1 = false,
								M2 = false,
								FX = Skills[Weapon][script.Name].Slash1.FX,
							})
						end
					end
				elseif hittimeIndex == 2 then
					Server.Visuals.Ranged(Character.HumanoidRootPart.Position, 300, {
						Module = "Weapons",
						Function = "RapidThrust",
						Arguments = { Character, "2"},
					})

					-- Hitbox for second slash
					local Hitbox = Server.Modules.Hitbox
					local Entity = Server.Modules["Entities"].Get(Character)
					if Entity then
						local HitTargets = Hitbox.SpatialQuery(
							Character,
							Vector3.new(10, 6, 10),
							Entity:GetCFrame() * CFrame.new(0, 0, -3),
							false
						)

						for _, Target in pairs(HitTargets) do
							Server.Modules.Damage.Tag(Character, Target, {
								Damage = Skills[Weapon][script.Name].Slash2.Damage,
								PostureDamage = Skills[Weapon][script.Name].Slash2.PostureDamage,
								Stun = Skills[Weapon][script.Name].Slash2.Stun,
								BlockBreak = Skills[Weapon][script.Name].Slash2.BlockBreak,
								M1 = false,
								M2 = false,
								FX = Skills[Weapon][script.Name].Slash2.FX,
							})
						end
					end
				elseif hittimeIndex == 3 then
					-- Frame 3: Check for grab
					Server.Visuals.Ranged(Character.HumanoidRootPart.Position, 300, {
						Module = "Weapons",
						Function = "RapidThrust",
						Arguments = { Character, "3"},
					})

					-- Hitbox for frame 3 - check if we hit someone to grab
					local Hitbox = Server.Modules.Hitbox
					local Entity = Server.Modules["Entities"].Get(Character)
					if Entity then
						local HitTargets = Hitbox.SpatialQuery(
							Character,
							Vector3.new(8, 6, 8),
							Entity:GetCFrame() * CFrame.new(0, 0, -3),
							false
						)

						-- If we hit someone on frame 3, grab them
						if #HitTargets > 0 then
							local Target = HitTargets[1] -- Grab the first target hit
							grabbedTarget = Target

							-- MULTI-HIT FIX: Mark victim with MultiHitVictim state
							if not multiHitVictim then
								multiHitVictim = Target
								-- Mark victim for multi-hit combo (duration = full animation length)
								Server.Library.TimedState(Target.IFrames, "MultiHitVictim", animlength)
							end

							-- Apply damage
							Server.Modules.Damage.Tag(Character, Target, {
								Damage = Skills[Weapon][script.Name].Repeat.Damage,
								PostureDamage = Skills[Weapon][script.Name].Repeat.PostureDamage,
								Stun = Skills[Weapon][script.Name].Repeat.Stun,
								BlockBreak = Skills[Weapon][script.Name].Repeat.BlockBreak,
								M1 = false,
								M2 = false,
								FX = Skills[Weapon][script.Name].Repeat.FX,
							})

							-- Apply grab using ECS system
							local grabberEntity = RefManager.entity.find(Character)
							if grabberEntity then
								-- Calculate remaining duration (from frame 3 to frame 13)
								local grabDuration = hittimes[13] - hittimes[3]

								world:set(grabberEntity, comps.Grab, {
									target = Target,
									value = true,
									duration = grabDuration,
									startTime = tick(),
									distance = 3 -- Hold at 3 studs distance
								})
							end
						end
					end
				elseif hittimeIndex >= 4 and hittimeIndex <= 12 then
					-- Frames 4-12: Continue rapid pokes (only if we have a grabbed target)
					Server.Visuals.Ranged(Character.HumanoidRootPart.Position, 300, {
						Module = "Weapons",
						Function = "RapidThrust",
						Arguments = { Character, tostring(hittimeIndex)},
					})

					-- Only apply damage to the grabbed target
					if grabbedTarget then
						Server.Modules.Damage.Tag(Character, grabbedTarget, {
							Damage = Skills[Weapon][script.Name].Repeat.Damage,
							PostureDamage = Skills[Weapon][script.Name].Repeat.PostureDamage,
							Stun = Skills[Weapon][script.Name].Repeat.Stun,
							BlockBreak = Skills[Weapon][script.Name].Repeat.BlockBreak,
							M1 = false,
							M2 = false,
							FX = Skills[Weapon][script.Name].Repeat.FX,
						})
					else
						local Hitbox = Server.Modules.Hitbox
					local Entity = Server.Modules["Entities"].Get(Character)
					if Entity then
						local HitTargets = Hitbox.SpatialQuery(
							Character,
							Vector3.new(8, 6, 8),
							Entity:GetCFrame() * CFrame.new(0, 0, -3),
							false
						)

						-- If we hit someone on frame 3, grab them
						if #HitTargets > 0 then
							local Target = HitTargets[1] -- Grab the first target hit
							grabbedTarget = Target

							-- Apply damage
							Server.Modules.Damage.Tag(Character, Target, {
								Damage = Skills[Weapon][script.Name].Repeat.Damage,
								PostureDamage = Skills[Weapon][script.Name].Repeat.PostureDamage,
								Stun = Skills[Weapon][script.Name].Repeat.Stun,
								BlockBreak = Skills[Weapon][script.Name].Repeat.BlockBreak,
								M1 = false,
								M2 = false,
								FX = Skills[Weapon][script.Name].Repeat.FX,
							})

							-- Apply grab using ECS system
							local grabberEntity = RefManager.entity.find(Character)
							if grabberEntity then
								-- Calculate remaining duration (from frame 3 to frame 13)
								local grabDuration = hittimes[13] - hittimes[3]

								world:set(grabberEntity, comps.Grab, {
									target = Target,
									value = true,
									duration = grabDuration,
									startTime = tick(),
									distance = 3 -- Hold at 3 studs distance
								})
							end
						end
					end
					end
				elseif hittimeIndex == 13 then
					Server.Visuals.Ranged(Character.HumanoidRootPart.Position, 300, {
						Module = "Weapons",
						Function = "RapidThrust",
						Arguments = { Character, "13"},
					})

					-- Release grab on frame 13
					if grabbedTarget then
						local grabberEntity = RefManager.entity.find(Character)
						if grabberEntity and world:has(grabberEntity, comps.Grab) then
							world:remove(grabberEntity, comps.Grab)
						end
					end
				elseif hittimeIndex == 14 then
					-- Final frame: Slam
					Server.Visuals.Ranged(Character.HumanoidRootPart.Position, 300, {
						Module = "Weapons",
						Function = "RapidThrust",
						Arguments = { Character, "14"},
					})

					-- Final hitbox - hit the grabbed target or anyone in range
					if grabbedTarget then
						-- Guaranteed hit on grabbed target
						Server.Modules.Damage.Tag(Character, grabbedTarget, {
							Damage = Skills[Weapon][script.Name].Slam.Damage,
							PostureDamage = Skills[Weapon][script.Name].Slam.PostureDamage,
							Stun = Skills[Weapon][script.Name].Slam.Stun,
							BlockBreak = Skills[Weapon][script.Name].Slam.BlockBreak,
							M1 = false,
							M2 = false,
							FX = Skills[Weapon][script.Name].Slam.FX,
						})
					else
						-- No grab, check for targets in range
						local Hitbox = Server.Modules.Hitbox
						local Entity = Server.Modules["Entities"].Get(Character)
						if Entity then
							local HitTargets = Hitbox.SpatialQuery(
								Character,
								Vector3.new(12, 8, 12),
								Entity:GetCFrame() * CFrame.new(0, 0, -3),
								false
							)

							for _, Target in pairs(HitTargets) do
								Server.Modules.Damage.Tag(Character, Target, {
									Damage = Skills[Weapon][script.Name].Slam.Damage,
									PostureDamage = Skills[Weapon][script.Name].Slam.PostureDamage,
									Stun = Skills[Weapon][script.Name].Slam.Stun,
									BlockBreak = Skills[Weapon][script.Name].Slam.BlockBreak,
									M1 = false,
									M2 = false,
									FX = Skills[Weapon][script.Name].Slam.FX,
								})
							end
						end
					end
				end
			end

			-- Handle velocity during hittimes 3-12 (the rapid poke sequence)
			-- Start velocity at hittime 3, stop at hittime 13
			if elapsed >= hittimes[3] and elapsed < hittimes[13] then
				if not velocityActive then
					velocityActive = true
					velocityMover = createVelocityMover()
				end

				-- Update velocity direction every frame to simulate walking forward
				if velocityMover and velocityMover.Parent then
					local rootPart = Character.HumanoidRootPart
					if rootPart then
						local forwardVector = rootPart.CFrame.LookVector
						forwardVector = Vector3.new(forwardVector.X, 0, forwardVector.Z).Unit
						velocityMover.VectorVelocity = forwardVector * 25 -- Forward speed
					end
				end
			elseif elapsed >= hittimes[13] and velocityActive then
				-- Stop velocity at hittime 13
				if velocityMover and velocityMover.Parent then
					velocityMover:Destroy()
					velocityMover = nil
				end
				velocityActive = false
			end
		end)
    end
end