local ServerStorage = game:GetService("ServerStorage")
local Replicated = game:GetService("ReplicatedStorage")
local Library = require(Replicated.Modules.Library)
local Skills = require(ServerStorage.Stats._Skills)
local RunService = game:GetService("RunService")
local Sfx = Replicated.Assets.SFX

local Global = require(Replicated.Modules.Shared.Global)
return function(Player, Data, Server)
	print("[Inverse Slide] ========== SKILL CALLED ==========")
	print("[Inverse Slide] Player:", Player.Name)

	local Character = Player.Character

	if not Character then
		print("[Inverse Slide] ❌ No character found")
		return
	end
	print("[Inverse Slide] ✅ Character found:", Character.Name)

	-- Check if this is an NPC (no Player instance) or a real player
	local isNPC = typeof(Player) ~= "Instance" or not Player:IsA("Player")
	print("[Inverse Slide] Is NPC:", isNPC)

	-- For players, check equipped status
	if not isNPC and not Character:GetAttribute("Equipped") then
		print("[Inverse Slide] ❌ Not equipped")
		return
	end
	print("[Inverse Slide] ✅ Equipped check passed")

	-- Get weapon - for NPCs use attribute, for players use Global.GetData
	local Weapon
	if isNPC then
		Weapon = Character:GetAttribute("Weapon") or "Fist"
	else
		Weapon = Global.GetData(Player).Weapon
	end
	print("[Inverse Slide] Weapon:", Weapon)

	-- WEAPON CHECK: This skill requires Fist weapon
	-- if Weapon ~= "Fist" then
	-- 	print("[Inverse Slide] ❌ Wrong weapon - requires Fist, got:", Weapon)
	-- 	return -- Character doesn't have the correct weapon for this skill
	-- end
	-- print("[Inverse Slide] ✅ Weapon check passed")

	local PlayerObject = Server.Modules["Players"].Get(Player)
	local Animation = Replicated.Assets.Animations.Skills.Weapons[Weapon][script.Name]
	print("[Inverse Slide] Animation:", Animation)

	if Server.Library.StateCount(Character.Actions) or Server.Library.StateCount(Character.Stuns) then
		print("[Inverse Slide] ❌ Character is in action or stunned")
		return
	end
	print("[Inverse Slide] ✅ State check passed")

	-- For NPCs, skip the PlayerObject.Keys check
	local canUseSkill = isNPC or (PlayerObject and PlayerObject.Keys)
	print("[Inverse Slide] Can use skill:", canUseSkill)

	if canUseSkill and not Server.Library.CheckCooldown(Character, script.Name) then
		print("[Inverse Slide] ✅ Cooldown check passed - EXECUTING SKILL!")
		Server.Library.SetCooldown(Character, script.Name, 5) -- Increased from 2.5 to 5 seconds
		Server.Library.StopAllAnims(Character)

		local Move = Library.PlayAnimation(Character, Animation)
		print("[Inverse Slide] Animation playing, length:", Move.Length)
		local animlength = Move.Length

		Server.Library.TimedState(Character.Actions, script.Name, Move.Length)
		Server.Library.TimedState(Character.Speeds, "AlcSpeed-0", Move.Length)

		local hittimes = {}
		for i, fraction in Skills[Weapon][script.Name].HitTimes do
			hittimes[i] = fraction * animlength
		end

		-- Get hitbox module and entity
		local Hitbox = Server.Modules.Hitbox
		local Entity = Server.Modules["Entities"].Get(Character)

		-- Create leap effect from hittime[1] to hittime[2]
		local HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart")
		local Humanoid = Character:FindFirstChild("Humanoid")

		if HumanoidRootPart and Humanoid then
			-- First kick - ground effect (no damage)
			task.delay(hittimes[1], function()
				Server.Visuals.Ranged(Character.HumanoidRootPart.Position, 300, {
					Module = "Base",
					Function = "IS",
					Arguments = { Character, "RightDust" },
				})

				local leapSound = Sfx.Skills.IS.Leap:Clone()
				leapSound.Volume = 4
				leapSound.PlaybackSpeed = 2
				leapSound.Parent = Character.HumanoidRootPart
				leapSound:Play()
				game:GetService("Debris"):AddItem(leapSound, leapSound.TimeLength)
			end)
		else
			-- Fallback if no HumanoidRootPart/Humanoid
			task.delay(hittimes[1], function()
				Server.Visuals.Ranged(Character.HumanoidRootPart.Position, 300, {
					Module = "Base",
					Function = "IS",
					Arguments = { Character, "RightDust" },
				})
			end)
		end

		-- Second kick - lift effect + start velocity
        task.delay(hittimes[2], function()
            Server.Visuals.Ranged(Character.HumanoidRootPart.Position, 300, {
				Module = "Base",
				Function = "IS",
				Arguments = { Character, "Lift" },
			})

			local jumpSound = Sfx.Skills.IS.Jump:Clone()
			jumpSound.Parent = Character.HumanoidRootPart
			jumpSound.Volume = 4
			jumpSound.PlaybackSpeed = 2
			jumpSound:Play()
			game:GetService("Debris"):AddItem(jumpSound, jumpSound.TimeLength)

			-- Send velocity to player (they have network ownership)
			local leapDuration = hittimes[4] - hittimes[2]
			Server.Packets.Bvel.sendTo({
				Character = Character,
				Name = "ISVelocity",
				HorizontalPower = 45, -- Rightward speed
				duration = leapDuration
			}, Player)
        end)

		-- Remove velocity at hittimes[4] (end of leap)
		task.delay(hittimes[4], function()
			Server.Packets.Bvel.sendTo({
				Character = Character,
				Name = "RemoveISVelocity"
			}, Player)
		end)

		-- Third kick - damage + knockback to the left
        task.delay(hittimes[3], function()
            Server.Visuals.Ranged(Character.HumanoidRootPart.Position, 300, {
				Module = "Base",
				Function = "IS",
				Arguments = { Character, "Start" },
			})

			local dumpSound = Sfx.Skills.IS.Dump:Clone()
			dumpSound.Parent = Character.HumanoidRootPart
			dumpSound:Play()

			-- Tween out the dump sound before hittimes[4]
			local fadeOutDuration = hittimes[4] - hittimes[3]
			local TweenService = game:GetService("TweenService")
			local fadeInfo = TweenInfo.new(fadeOutDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			TweenService:Create(dumpSound, fadeInfo, { Volume = 0.5 }):Play()
			game:GetService("Debris"):AddItem(dumpSound, fadeOutDuration + 0.5)
			-- Screenshake for third kick (left-right bouncy)
			-- Server.Visuals.Ranged(Character.HumanoidRootPart.Position, 300, {
			-- 	Module = "Base",
			-- 	Function = "Shake",
			-- 	Arguments = {
			-- 		"Once",
			-- 		{
			-- 			4,  -- magnitude
			-- 			12, -- roughness (bouncy)
			-- 			0,  -- fadeInTime
			-- 			0.4, -- fadeOutTime
			-- 			Vector3.new(0.5, 0.2, 0.5), -- posInfluence (less vertical)
			-- 			Vector3.new(0.2, 1.5, 0.2) -- rotInfluence (strong left-right rotation)
			-- 		}
			-- 	}
			-- })

			--Library.PlaySound(Character.HumanoidRootPart, Sfx.Skills.IS["2"], true, 0.1)
			-- Create hitbox for third kick
			if Entity then
				local HitTargets = Hitbox.SpatialQuery(
					Character,
					Vector3.new(6, 6, 6),
					Entity:GetCFrame() * CFrame.new(0, 0, -3),
					false
				)

				for _, Target in pairs(HitTargets) do
					if Target ~= Character and Target:IsA("Model") then
						Server.Modules.Damage.Tag(Character, Target, Skills[Weapon][script.Name].DamageTable)

						-- Apply ground knockback to the left (same as running attack knockback)
						if Target:FindFirstChild("HumanoidRootPart") and Target:FindFirstChild("Humanoid") then
							-- Stop all animations and play knockback animation
							Library.StopAllAnims(Target)
							local KnockbackAnim = Library.PlayAnimation(Target, Replicated.Assets.Animations.Misc.KnockbackStun)
							KnockbackAnim.Priority = Enum.AnimationPriority.Action3

							-- Get animation length for knockback duration
							local duration = KnockbackAnim.Length

							-- Lock rotation and disable controls during knockback
							Library.TimedState(Target.Stuns, "NoRotate", duration)
							Library.TimedState(Target.Stuns, "KnockbackStun", duration)

							-- Enable dash VFX during knockback (it will automatically follow the target)
							Server.Visuals.Ranged(Target.HumanoidRootPart.Position, 300, {
								Module = "Base",
								Function = "DashFX",
								Arguments = { Target, "Left" }
							})

							-- Apply knockback to the left using modified KnockbackBvel
							local eroot = Target.HumanoidRootPart
							local root = Character.HumanoidRootPart

							-- Clean up any existing velocities
							for _, child in ipairs(eroot:GetChildren()) do
								if child:IsA("LinearVelocity") or child:IsA("BodyVelocity") or child:IsA("BodyPosition") or child:IsA("BodyGyro") then
									child:Destroy()
								end
							end

							-- Calculate left direction (negative right vector)
							local leftDirection = root.CFrame.RightVector * -1
							leftDirection = Vector3.new(leftDirection.X, 0, leftDirection.Z).Unit

							-- Make target face the direction they're being knocked (to the right, opposite of knockback)
							local faceDirection = -leftDirection
							local targetCFrame = CFrame.new(eroot.Position, eroot.Position + faceDirection)

							local bodyGyro = Instance.new("BodyGyro")
							bodyGyro.MaxTorque = Vector3.new(0, math.huge, 0)
							bodyGyro.P = 10000
							bodyGyro.D = 500
							bodyGyro.CFrame = targetCFrame
							bodyGyro.Parent = eroot

							-- Create BodyVelocity for knockback with smooth easing
							local maxPower = 60 -- Peak velocity in the middle

							-- Reset velocity
							eroot.AssemblyLinearVelocity = Vector3.zero
							eroot.AssemblyAngularVelocity = Vector3.zero

							local bv = Instance.new("BodyVelocity")
							bv.MaxForce = Vector3.new(50000, 0, 50000)
							bv.Velocity = Vector3.zero
							bv.Parent = eroot

							-- Use Heartbeat to smoothly ease velocity with Sine wave (slow start, fast middle, slow end)
							local startTime = os.clock()
							local connection
							connection = RunService.Heartbeat:Connect(function()
								local elapsed = os.clock() - startTime
								if elapsed >= duration then
									connection:Disconnect()
									return
								end

								-- Calculate progress and use sine wave to create smooth acceleration and deceleration
								local progress = elapsed / duration
								local velocityMultiplier = math.sin(progress * math.pi) -- Creates bell curve: 0 -> 1 -> 0
								local currentPower = maxPower * velocityMultiplier

								if bv and bv.Parent then
									bv.Velocity = leftDirection * currentPower
									eroot.AssemblyLinearVelocity = leftDirection * currentPower
								else
									connection:Disconnect()
								end
							end)

							-- Clean up after knockback duration
							task.delay(duration, function()
								if connection then
									connection:Disconnect()
								end
								if bv and bv.Parent then bv:Destroy() end
								if bodyGyro and bodyGyro.Parent then bodyGyro:Destroy() end

								-- End dash VFX
								Server.Visuals.Ranged(Target.HumanoidRootPart.Position, 300, {
									Module = "Base",
									Function = "EndDashFX",
									Arguments = { Target }
								})
							end)
						end
					end
				end
			end
        end)

		-- Fourth kick - damage (more impactful screenshake)
        task.delay(hittimes[4], function()
            Server.Visuals.Ranged(Character.HumanoidRootPart.Position, 300, {
				Module = "Base",
				Function = "IS",
				Arguments = { Character, "End" },
			})

			local landSound = Sfx.Skills.IS.Land:Clone()
			landSound.Parent = Character.HumanoidRootPart
			landSound.Volume = 10
			landSound:Play()
			game:GetService("Debris"):AddItem(landSound, landSound.TimeLength)

			-- Screenshake for fourth kick (MORE IMPACTFUL - stronger left-right bouncy)

			--Library.PlaySound(Character.HumanoidRootPart, Sfx.Skills.IS["3"], true, 0.1)
			-- Create hitbox for fourth kick
			if Entity then
				local HitTargets = Hitbox.SpatialQuery(
					Character,
					Vector3.new(6, 6, 6),
					Entity:GetCFrame() * CFrame.new(0, 0, -3),
					false
				)

				for _, Target in pairs(HitTargets) do
					if Target ~= Character and Target:IsA("Model") then
						Server.Modules.Damage.Tag(Character, Target, Skills[Weapon][script.Name].DamageTable)
					end
				end
			end
        end)
    end
end