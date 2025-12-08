local ServerStorage = game:GetService("ServerStorage")
local Replicated = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Library = require(Replicated.Modules.Library)
local Skills = require(ServerStorage.Stats._Skills)

local Global = require(Replicated.Modules.Shared.Global)
local world = require(Replicated.Modules.ECS.jecs_world)
local comps = require(Replicated.Modules.ECS.jecs_components)
local RefManager = require(Replicated.Modules.ECS.jecs_ref_manager)
local Ragdoll = require(Replicated.Modules.Utils.Ragdoll)

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
		-- Stop ALL animations first
		Server.Library.StopAllAnims(Character)

		-- Remove any existing body movers FIRST
		Server.Packets.Bvel.sendTo({Character = Character, Name = "RemoveBvel"},Player)

		Server.Library.SetCooldown(Character, script.Name, 5)

		-- Play animation to get the track and length
		local Move = Library.PlayAnimation(Character, Animation)
		local animlength = Move.Length

		-- Add action-blocking states immediately after playing animation
		Server.Library.TimedState(Character.Stuns, "ChargedThrustActive", animlength) -- Prevent all actions (set FIRST)
		Server.Library.TimedState(Character.Actions, script.Name, animlength)
		Server.Library.TimedState(Character.Speeds, "AlcSpeed-0", animlength)

		-- Calculate hittimes from fractions
		local hittimes = {}
		for i, fraction in Skills[Weapon][script.Name].Hittimes do
			hittimes[i] = fraction * animlength
		end

		-- Frame-based system
		local FPS = 60
		local startTime = os.clock()
		local heartbeatConnection = nil
		local grabbedTarget = nil -- Track if we grabbed someone on frame 1
		local processedFrames = {} -- Track which frames we've already processed

		-- Map hittimes to frame numbers
		local frameToHittime = {}
		for i, hittime in ipairs(hittimes) do
			local frameNumber = math.floor((hittime / animlength) * (animlength * FPS))
			frameToHittime[frameNumber] = i
		end

		-- Frame update loop
		heartbeatConnection = RunService.Heartbeat:Connect(function()
			-- CHECK IF SKILL WAS CANCELLED (action state removed by CancelAllActions)
			if not Server.Library.StateCheck(Character.Actions, script.Name) then
				-- Skill was cancelled (hit by enemy, etc.) - cleanup immediately
				-- Stop animation using StopAllAnims to ensure it stops
				Server.Library.StopAllAnims(Character)

				-- Remove stun state to allow other actions
				Server.Library.RemoveState(Character.Stuns, "ChargedThrustActive")

				if heartbeatConnection then
					heartbeatConnection:Disconnect()
					heartbeatConnection = nil
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
				if heartbeatConnection then
					heartbeatConnection:Disconnect()
					heartbeatConnection = nil
				end
				-- Release grab if still active and apply ragdoll
				if grabbedTarget then
					local grabberEntity = RefManager.entity.find(Character)
					if grabberEntity and world:has(grabberEntity, comps.Grab) then
						world:remove(grabberEntity, comps.Grab)
					end

					-- Apply ragdoll for 2 seconds
					Ragdoll.Ragdoll(grabbedTarget, 2)
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
					-- Frame 1: Initial thrust - check for grab
					Server.Visuals.Ranged(Character.HumanoidRootPart.Position, 300, {
						Module = "Weapons",
						Function = "ChargedThrust",
						Arguments = { Character, "1"},
					})

					-- Hitbox for first thrust - check if we hit someone to grab
					local Hitbox = Server.Modules.Hitbox
					local Entity = Server.Modules["Entities"].Get(Character)
					if Entity then
						local HitTargets = Hitbox.SpatialQuery(
							Character,
							Vector3.new(10, 6, 10),
							Entity:GetCFrame() * CFrame.new(0, 0, -3),
							false
						)

						-- If we hit someone on frame 1, grab them
						if #HitTargets > 0 then
							local Target = HitTargets[1] -- Grab the first target hit
							grabbedTarget = Target

							-- Apply damage
							Server.Modules.Damage.Tag(Character, Target, {
								Damage = Skills[Weapon][script.Name].Init.Damage,
								PostureDamage = Skills[Weapon][script.Name].Init.PostureDamage,
								Stun = Skills[Weapon][script.Name].Init.Stun,
								BlockBreak = Skills[Weapon][script.Name].Init.BlockBreak,
								M1 = false,
								M2 = false,
								FX = Skills[Weapon][script.Name].Init.FX,
							})

							-- Calculate remaining duration (from frame 1 to frame 2)
							local grabDuration = hittimes[2] - hittimes[1]

							-- Apply stun states to prevent victim from using moves
							Server.Library.TimedState(Target.Stuns, "ChargedThrustGrab", grabDuration)
							Server.Library.TimedState(Target.Stuns, "NoRotate", grabDuration)

							-- Apply velocity towards attacker (pull effect)
							local targetRoot = Target:FindFirstChild("HumanoidRootPart")
							local attackerRoot = Character:FindFirstChild("HumanoidRootPart")
							if targetRoot and attackerRoot then
								-- Calculate direction from target to attacker
								local pullDirection = (attackerRoot.Position - targetRoot.Position).Unit
								local pullPower = 50 -- Increased pull strength

								-- Apply pull velocity using ServerBvel
								task.spawn(function()
									Server.Modules.ServerBvel.PullVelocity(Target, pullDirection, pullPower, grabDuration)
								end)
							end

							-- Apply grab using ECS system
							local grabberEntity = RefManager.entity.find(Character)
							if grabberEntity then
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
				elseif hittimeIndex == 2 then
					-- Frame 2: Pull/finish - only if we have a grabbed target
					if grabbedTarget then
						Server.Visuals.Ranged(Character.HumanoidRootPart.Position, 300, {
							Module = "Weapons",
							Function = "ChargedThrust",
							Arguments = { Character, "2"},
						})

						-- Apply final damage to the grabbed target
						Server.Modules.Damage.Tag(Character, grabbedTarget, {
							Damage = Skills[Weapon][script.Name].Pull.Damage,
							PostureDamage = Skills[Weapon][script.Name].Pull.PostureDamage,
							Stun = Skills[Weapon][script.Name].Pull.Stun,
							BlockBreak = Skills[Weapon][script.Name].Pull.BlockBreak,
							M1 = false,
							M2 = false,
							FX = Skills[Weapon][script.Name].Pull.FX,
						})

						-- Ragdoll the target for 2 seconds (instant ragdoll like Axe Kick)
						task.spawn(function()
							Ragdoll.Ragdoll(grabbedTarget, 2)
						end)

						-- Release grab immediately after frame 2
						local grabberEntity = RefManager.entity.find(Character)
						if grabberEntity and world:has(grabberEntity, comps.Grab) then
							world:remove(grabberEntity, comps.Grab)
						end
					end
					-- If no grabbed target, don't play VFX for frame 2
				end
			end
		end)
	end
end
