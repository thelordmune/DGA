local ServerStorage = game:GetService("ServerStorage")
local Replicated = game:GetService("ReplicatedStorage")
local Library = require(Replicated.Modules.Library)
local Skills = require(ServerStorage.Stats._Skills)
local RunService = game:GetService("RunService")
local Sfx = Replicated.Assets.SFX

local Global = require(Replicated.Modules.Shared.Global)
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
		Weapon = Character:GetAttribute("Weapon") or "Fist"
	else
		Weapon = Global.GetData(Player).Weapon
	end

	local PlayerObject = Server.Modules["Players"].Get(Player)
	local Animation = Replicated.Assets.Animations.Skills.Weapons[Weapon][script.Name]

	if Server.Library.StateCount(Character.Actions) or Server.Library.StateCount(Character.Stuns) then
		return
	end

	-- For NPCs, skip the PlayerObject.Keys check
	local canUseSkill = isNPC or (PlayerObject and PlayerObject.Keys)

	if canUseSkill and not Server.Library.CheckCooldown(Character, script.Name) then
		Server.Library.SetCooldown(Character, script.Name, 5)
		Server.Library.StopAllAnims(Character)

		local Move = Library.PlayAnimation(Character, Animation)
		local animlength = Move.Length

		Server.Library.TimedState(Character.Actions, script.Name, Move.Length)
		Server.Library.TimedState(Character.Speeds, "AlcSpeed-0", Move.Length)
		Server.Library.TimedState(Character.Speeds, "Jump-50", Move.Length) -- Prevent jumping during move

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

		-- Store sounds for cleanup on cancellation
		local leapSound
		local jumpSound

		if HumanoidRootPart and Humanoid then
			-- First kick - ground effect (no damage)
			task.delay(hittimes[1], function()
				-- CHECK IF SKILL WAS CANCELLED
				if not Server.Library.StateCheck(Character.Actions, script.Name) then
					return
				end

				Server.Visuals.Ranged(Character.HumanoidRootPart.Position, 300, {
					Module = "Base",
					Function = "IS",
					Arguments = { Character, "RightDust" },
				})

				leapSound = Sfx.Skills.IS.Leap:Clone()
				leapSound.Volume = 4
				leapSound.PlaybackSpeed = 2
				leapSound.Parent = Character.HumanoidRootPart
				leapSound:Play()
				game:GetService("Debris"):AddItem(leapSound, leapSound.TimeLength)
			end)
		else
			-- Fallback if no HumanoidRootPart/Humanoid
			task.delay(hittimes[1], function()
				-- CHECK IF SKILL WAS CANCELLED
				if not Server.Library.StateCheck(Character.Actions, script.Name) then
					return
				end

				Server.Visuals.Ranged(Character.HumanoidRootPart.Position, 300, {
					Module = "Base",
					Function = "IS",
					Arguments = { Character, "RightDust" },
				})
			end)
		end

		-- Second kick - lift effect + start velocity
        task.delay(hittimes[2], function()
			-- CHECK IF SKILL WAS CANCELLED
			if not Server.Library.StateCheck(Character.Actions, script.Name) then
				return
			end

            Server.Visuals.Ranged(Character.HumanoidRootPart.Position, 300, {
				Module = "Base",
				Function = "IS",
				Arguments = { Character, "Lift" },
			})

			jumpSound = Sfx.Skills.IS.Jump:Clone()
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
			-- CHECK IF SKILL WAS CANCELLED
			if not Server.Library.StateCheck(Character.Actions, script.Name) then
				-- Clean up velocity if cancelled
				Server.Packets.Bvel.sendTo({
					Character = Character,
					Name = "RemoveISVelocity"
				}, Player)
				return
			end

			Server.Packets.Bvel.sendTo({
				Character = Character,
				Name = "RemoveISVelocity"
			}, Player)
		end)

		-- Third kick - START MULTI-HIT (no knockback yet, just damage)
        task.delay(hittimes[3], function()
			-- CHECK IF SKILL WAS CANCELLED
			if not Server.Library.StateCheck(Character.Actions, script.Name) then
				return
			end

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

			-- Multi-hit loop from hittime 3 to hittime 4
			local multiHitDuration = hittimes[4] - hittimes[3]
			local hitInterval = 0.025 -- Hit every 0.1 seconds
			local startTime = os.clock()
			local hitConnection

			hitConnection = RunService.Heartbeat:Connect(function()
				-- CHECK IF SKILL WAS CANCELLED
				if not Server.Library.StateCheck(Character.Actions, script.Name) then
					if hitConnection then
						hitConnection:Disconnect()
					end
					-- Stop sound if cancelled
					if dumpSound and dumpSound.Parent then
						dumpSound:Stop()
						dumpSound:Destroy()
					end
					return
				end

				local elapsed = os.clock() - startTime
				if elapsed >= multiHitDuration then
					if hitConnection then
						hitConnection:Disconnect()
					end
					return
				end

				-- Check if enough time has passed for next hit
				local hitCount = math.floor(elapsed / hitInterval)
				local lastHitTime = hitCount * hitInterval
				local timeSinceLastHit = elapsed - lastHitTime

				if timeSinceLastHit < 0.016 then -- Within one frame of hit time
					-- Create hitbox for multi-hit (NO KNOCKBACK)
					if Entity then
						local HitTargets = Hitbox.SpatialQuery(
							Character,
							Vector3.new(6, 6, 6),
							Entity:GetCFrame() * CFrame.new(0, 0, -3),
							false
						)

						for _, Target in pairs(HitTargets) do
							if Target ~= Character and Target:IsA("Model") then
								-- Apply damage WITHOUT knockback
								Server.Modules.Damage.Tag(Character, Target, Skills[Weapon][script.Name].DamageTable)
							end
						end
					end
				end
			end)
        end)

		-- Fourth kick - FINAL HIT with knockback
        task.delay(hittimes[4], function()
			-- CHECK IF SKILL WAS CANCELLED
			if not Server.Library.StateCheck(Character.Actions, script.Name) then
				return
			end

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

			-- Create hitbox for fourth kick WITH KNOCKBACK
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
    end
end