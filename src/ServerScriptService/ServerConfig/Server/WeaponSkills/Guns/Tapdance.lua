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
		Server.Library.TimedState(Character.Speeds, "AlcSpeed-0", animlength)
		Server.Library.TimedState(Character.Speeds, "Jump-50", animlength) -- Prevent jumping during move

		-- Initialize hyperarmor tracking for this move
		Character:SetAttribute("HyperarmorDamage", 0)
		Character:SetAttribute("HyperarmorMove", script.Name)

		-- Start hyperarmor visual indicator (white highlight)
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
			lv.Name = "TapdanceVelocity"
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
				-- Server.Library.RemoveState(Character.Stuns, "RapidThrustActive")

				-- Clean up hyperarmor data and visual
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
				return
			end

			local elapsed = os.clock() - startTime
			if elapsed >= animlength then
				-- Animation complete, cleanup
				-- Clean up hyperarmor data and visual
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
					-- First hit: VFX only, no hitbox
					Server.Visuals.Ranged(Character.HumanoidRootPart.Position, 300, {
						Module = "Weapons",
						Function = "Tapdance",
						Arguments = { Character, "1"},
					})
                    Library.PlaySound(Character.HumanoidRootPart, Replicated.Assets.SFX.Skills.Tapdance, true)
				elseif hittimeIndex == 2 then
					Server.Visuals.Ranged(Character.HumanoidRootPart.Position, 300, {
						Module = "Weapons",
						Function = "Tapdance",
						Arguments = { Character, "2"},
					})

					-- Hitbox for second hit
					local Hitbox = Server.Modules.Hitbox
					local Entity = Server.Modules["Entities"].Get(Character)
					if Entity then
						local HitTargets = Hitbox.SpatialQuery(
							Character,
							Vector3.new(10, 6, 10),
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

							local targetHumanoid = Target:FindFirstChildOfClass("Humanoid")
							if targetHumanoid then
								local animator = targetHumanoid:FindFirstChildOfClass("Animator")
								if animator then
									local customStunAnim = Instance.new("Animation")
									customStunAnim.AnimationId = "rbxassetid://71707180683326"
									local animTrack = animator:LoadAnimation(customStunAnim)
									animTrack:Play()
									customStunAnim:Destroy()
								end
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
				elseif hittimeIndex == 3 then
					Server.Visuals.Ranged(Character.HumanoidRootPart.Position, 300, {
						Module = "Weapons",
						Function = "Tapdance",
						Arguments = { Character, "3"},
					})

					-- Hitbox for third hit
					local Hitbox = Server.Modules.Hitbox
					local Entity = Server.Modules["Entities"].Get(Character)
					if Entity then
						local HitTargets = Hitbox.SpatialQuery(
							Character,
							Vector3.new(10, 6, 10),
							Entity:GetCFrame() * CFrame.new(0, 0, -6),
							false
						)

						for _, Target in pairs(HitTargets) do
							-- Play custom stun animation on victim
							-- local targetHumanoid = Target:FindFirstChildOfClass("Humanoid")
							-- if targetHumanoid then
							-- 	local animator = targetHumanoid:FindFirstChildOfClass("Animator")
							-- 	if animator then
							-- 		local customStunAnim = Instance.new("Animation")
							-- 		customStunAnim.AnimationId = "rbxassetid://71707180683326"
							-- 		local animTrack = animator:LoadAnimation(customStunAnim)
							-- 		animTrack:Play()
							-- 		customStunAnim:Destroy()
							-- 	end
							-- end

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
				elseif hittimeIndex == 4 then
					Server.Visuals.Ranged(Character.HumanoidRootPart.Position, 300, {
						Module = "Weapons",
						Function = "Tapdance",
						Arguments = { Character, "4"},
					})

					-- Hitbox for fourth hit
					local Hitbox = Server.Modules.Hitbox
					local Entity = Server.Modules["Entities"].Get(Character)
					if Entity then
						local HitTargets = Hitbox.SpatialQuery(
							Character,
							Vector3.new(10, 6, 10),
							Entity:GetCFrame() * CFrame.new(0, 0, -6),
							false
						)

						for _, Target in pairs(HitTargets) do
							-- Play custom stun animation on victim
							-- local targetHumanoid = Target:FindFirstChildOfClass("Humanoid")
							-- if targetHumanoid then
							-- 	local animator = targetHumanoid:FindFirstChildOfClass("Animator")
							-- 	if animator then
							-- 		local customStunAnim = Instance.new("Animation")
							-- 		customStunAnim.AnimationId = "rbxassetid://71707180683326"
							-- 		local animTrack = animator:LoadAnimation(customStunAnim)
							-- 		animTrack:Play()
							-- 		customStunAnim:Destroy()
							-- 	end
							-- end

							Server.Modules.Damage.Tag(Character, Target, {
								Damage = Skills[Weapon][script.Name].FinalHit.Damage,
								PostureDamage = Skills[Weapon][script.Name].FinalHit.PostureDamage,
								Stun = Skills[Weapon][script.Name].FinalHit.Stun,
								BlockBreak = Skills[Weapon][script.Name].FinalHit.BlockBreak,
								M1 = false,
								M2 = false,
								FX = Skills[Weapon][script.Name].FinalHit.FX,
							})
						end
					end
				end
			end

			-- Handle velocity with easing between hittime 1 and hittime 2
			-- Start velocity at hittime 1, ease out towards hittime 2
			if #hittimes >= 2 then
				if elapsed >= hittimes[1] and elapsed < hittimes[2] then
					if not velocityActive then
						velocityActive = true
						velocityMover = createVelocityMover()
					end

					-- Update velocity direction with easing
					if velocityMover and velocityMover.Parent then
						local rootPart = Character.HumanoidRootPart
						if rootPart then
							-- Calculate progress through the velocity phase (0 to 1)
							local progress = (elapsed - hittimes[1]) / (hittimes[2] - hittimes[1])
							progress = math.clamp(progress, 0, 1)

							-- Ease out using cubic easing (starts fast, ends slow)
							local easedProgress = 1 - math.pow(1 - progress, 3)

							-- Interpolate speed from starting speed to 0
							local startSpeed = 175 -- Starting forward speed
							local currentSpeed = startSpeed * (1 - easedProgress)

							local forwardVector = rootPart.CFrame.LookVector
							forwardVector = Vector3.new(forwardVector.X, 0, forwardVector.Z).Unit
							velocityMover.VectorVelocity = forwardVector * currentSpeed
						end
					end
				elseif elapsed >= hittimes[2] and velocityActive then
					-- Stop velocity at hittime 2
					if velocityMover and velocityMover.Parent then
						velocityMover:Destroy()
						velocityMover = nil
					end
					velocityActive = false
				end
			end
		end)
	end
end