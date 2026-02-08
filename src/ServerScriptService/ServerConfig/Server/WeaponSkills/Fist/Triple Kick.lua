local ServerStorage = game:GetService("ServerStorage")
local Replicated = game:GetService("ReplicatedStorage")
local Library = require(Replicated.Modules.Library)
local Skills = require(ServerStorage.Stats._Skills)
local RunService = game:GetService("RunService")
local Sfx = Replicated.Assets.SFX
local StateManager = require(Replicated.Modules.ECS.StateManager)

local Global = require(Replicated.Modules.Shared.Global)
return function(Player, Data, Server)
	print("[Triple Kick] ========== SKILL CALLED ==========")
	print("[Triple Kick] Player:", Player.Name)

	local Character = Player.Character

	if not Character then
		print("[Triple Kick] ❌ No character found")
		return
	end
	print("[Triple Kick] ✅ Character found:", Character.Name)

	-- Check if this is an NPC (no Player instance) or a real player
	local isNPC = typeof(Player) ~= "Instance" or not Player:IsA("Player")
	print("[Triple Kick] Is NPC:", isNPC)

	-- For players, check equipped status
	if not isNPC and not Character:GetAttribute("Equipped") then
		print("[Triple Kick] ❌ Not equipped")
		return
	end
	print("[Triple Kick] ✅ Equipped check passed")

	-- Get weapon - for NPCs use attribute, for players use Global.GetData
	local Weapon
	if isNPC then
		Weapon = Character:GetAttribute("Weapon") or "Fist"
	else
		Weapon = Global.GetData(Player).Weapon
	end
	print("[Triple Kick] Weapon:", Weapon)

	-- WEAPON CHECK: This skill requires Fist weapon
	if Weapon ~= "Fist" then
		print("[Triple Kick] ❌ Wrong weapon - requires Fist, got:", Weapon)
		return -- Character doesn't have the correct weapon for this skill
	end
	print("[Triple Kick] ✅ Weapon check passed")

	local PlayerObject = Server.Modules["Players"].Get(Player)
	local Animation = Replicated.Assets.Animations.Skills.Weapons[Weapon][script.Name]
	print("[Triple Kick] Animation:", Animation)

	if StateManager.StateCount(Character, "Actions") or StateManager.StateCount(Character, "Stuns") then
		print("[Triple Kick] ❌ Character is in action or stunned")
		return
	end
	print("[Triple Kick] ✅ State check passed")

	-- For NPCs, skip the PlayerObject.Keys check
	local canUseSkill = isNPC or (PlayerObject and PlayerObject.Keys)
	print("[Triple Kick] Can use skill:", canUseSkill)

	if canUseSkill and not Server.Library.CheckCooldown(Character, script.Name) then
		print("[Triple Kick] ✅ Cooldown check passed - EXECUTING SKILL!")
		Server.Library.SetCooldown(Character, script.Name, 5) -- Increased from 2.5 to 5 seconds
		Server.Library.StopAllAnims(Character)

		local Move = Library.PlayAnimation(Character, Animation)
		print("[Triple Kick] Animation playing, length:", Move.Length)
		local animlength = Move.Length

		StateManager.TimedState(Character, "Actions", script.Name, Move.Length)
		StateManager.TimedState(Character, "Speeds", "AlcSpeed-0", Move.Length)
		StateManager.TimedState(Character, "Speeds", "Jump-50", Move.Length) -- Prevent jumping during move

		local hittimes = {}
		for i, fraction in Skills[Weapon][script.Name].HitTime do
			hittimes[i] = fraction * animlength
		end

		-- MULTI-HIT FIX: Track first victim for multi-hit state
		local multiHitVictim = nil

		-- Get hitbox module and entity
		local Hitbox = Server.Modules.Hitbox
		local Entity = Server.Modules["Entities"].Get(Character)

		-- Create leap effect from hittime[1] to hittime[2]
		local HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart")
		local Humanoid = Character:FindFirstChild("Humanoid")

		if HumanoidRootPart and Humanoid then
			-- First kick - ground effect (no damage) + start leap
			task.delay(hittimes[1], function()
				Server.Visuals.Ranged(Character.HumanoidRootPart.Position, 300, {
					Module = "Weapons",
					Function = "TripleKick",
					Arguments = { Character, "Ground" },
				})

                Library.PlaySound(Character.HumanoidRootPart, Sfx.Skills.TripleKick.Jump, true, 0.1)

				-- Create attachment for LinearVelocity
				local attachment = Instance.new("Attachment")
				attachment.Name = "TripleKickAttachment"
				attachment.Parent = HumanoidRootPart

				-- Get forward direction
				local forwardDirection = (HumanoidRootPart.CFrame * CFrame.new(0, 0, -1)).Position - HumanoidRootPart.Position
				forwardDirection = forwardDirection.Unit

				-- Create LinearVelocity for smooth movement
				local linearVelocity = Instance.new("LinearVelocity")
				linearVelocity.Name = "TripleKickVelocity"
				linearVelocity.Attachment0 = attachment
				linearVelocity.MaxForce = math.huge
				linearVelocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
				linearVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
				linearVelocity.Parent = HumanoidRootPart

				-- Use Heartbeat loop to smoothly update velocity with easing
				local startTime = os.clock()
				local leapDuration = hittimes[2] - hittimes[1]
				local connection

				connection = RunService.Heartbeat:Connect(function()
					local elapsed = os.clock() - startTime

					if elapsed >= leapDuration then
						-- Leap phase complete, disconnect and start fall
						connection:Disconnect()
						linearVelocity:Destroy()

						-- Create slow fall LinearVelocity
						local fallVelocity = Instance.new("LinearVelocity")
						fallVelocity.Name = "TripleKickFall"
						fallVelocity.Attachment0 = attachment
						fallVelocity.MaxForce = math.huge
						fallVelocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
						fallVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
						fallVelocity.VectorVelocity = Vector3.new(0, -3, 0) -- Slower fall (reduced from -8 to -3)
						fallVelocity.Parent = HumanoidRootPart

						-- Remove fall velocity at end of animation
						task.delay(animlength - hittimes[2], function()
							if fallVelocity and fallVelocity.Parent then
								fallVelocity:Destroy()
							end
							if attachment and attachment.Parent then
								attachment:Destroy()
							end
						end)
						return
					end

					-- Calculate progress with Quad EaseOut easing
					local progress = elapsed / leapDuration
					local easedProgress = 1 - (1 - progress) ^ 2 -- Quad EaseOut formula

					-- Interpolate upward velocity (starts high, ends low)
					local upwardVelocity = 15 * (1 - easedProgress) -- Starts at 15, ends at 0

					-- Interpolate forward velocity (starts medium, ends low)
					local forwardVelocity = 6 * (1 - easedProgress) -- Starts at 6, ends at 0 (increased from 3)

					-- Update LinearVelocity
					if linearVelocity and linearVelocity.Parent then
						linearVelocity.VectorVelocity = Vector3.new(
							forwardDirection.X * forwardVelocity,
							upwardVelocity,
							forwardDirection.Z * forwardVelocity
						)
					else
						connection:Disconnect()
					end
				end)
			end)
		else
			-- Fallback if no HumanoidRootPart/Humanoid
			task.delay(hittimes[1], function()
				Server.Visuals.Ranged(Character.HumanoidRootPart.Position, 300, {
					Module = "Weapons",
					Function = "TripleKick",
					Arguments = { Character, "Ground" },
				})
			end)
		end

		-- Second kick - damage
        task.delay(hittimes[2], function()
            Server.Visuals.Ranged(Character.HumanoidRootPart.Position, 300, {
				Module = "Weapons",
				Function = "TripleKick",
				Arguments = { Character, "Hit" },
			})

			-- Screenshake for second kick (left-right bouncy)
			Server.Visuals.Ranged(Character.HumanoidRootPart.Position, 300, {
				Module = "Base",
				Function = "Shake",
				Arguments = {
					"Once",
					{
						4,  -- magnitude
						12, -- roughness (bouncy)
						0,  -- fadeInTime
						0.4, -- fadeOutTime
						Vector3.new(0.5, 0.2, 0.5), -- posInfluence (less vertical)
						Vector3.new(0.2, 1.5, 0.2) -- rotInfluence (strong left-right rotation)
					}
				}
			})

            Library.PlaySound(Character.HumanoidRootPart, Sfx.Skills.TripleKick["1"], true, 0.1)
			-- Create hitbox for second kick
			if Entity then
				local HitTargets = Hitbox.SpatialQuery(
					Character,
					Vector3.new(6, 6, 6),
					Entity:GetCFrame() * CFrame.new(0, 0, -3),
					false
				)

				for _, Target in pairs(HitTargets) do
					if Target ~= Character and Target:IsA("Model") then
						-- MULTI-HIT FIX: Mark first victim with MultiHitVictim state
						if not multiHitVictim then
							multiHitVictim = Target
							-- Mark victim for multi-hit combo (duration = full animation length)
							StateManager.TimedState(Target, "IFrames", "MultiHitVictim", animlength)
						end

						Server.Modules.Damage.Tag(Character, Target, Skills[Weapon][script.Name].DamageTable)
					end
				end
			end
        end)

		-- Third kick - damage + knockback to the left
        task.delay(hittimes[3], function()
            Server.Visuals.Ranged(Character.HumanoidRootPart.Position, 300, {
				Module = "Weapons",
				Function = "TripleKick",
				Arguments = { Character, "Hit" },
			})

			-- Screenshake for third kick (left-right bouncy)
			Server.Visuals.Ranged(Character.HumanoidRootPart.Position, 300, {
				Module = "Base",
				Function = "Shake",
				Arguments = {
					"Once",
					{
						4,  -- magnitude
						12, -- roughness (bouncy)
						0,  -- fadeInTime
						0.4, -- fadeOutTime
						Vector3.new(0.5, 0.2, 0.5), -- posInfluence (less vertical)
						Vector3.new(0.2, 1.5, 0.2) -- rotInfluence (strong left-right rotation)
					}
				}
			})

			Library.PlaySound(Character.HumanoidRootPart, Sfx.Skills.TripleKick["2"], true, 0.1)
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
							StateManager.TimedState(Target, "Stuns", "NoRotate", duration)
							StateManager.TimedState(Target, "Stuns", "KnockbackStun", duration)

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
				Module = "Weapons",
				Function = "TripleKick",
				Arguments = { Character, "Hit" },
			})

			-- Screenshake for fourth kick (MORE IMPACTFUL - stronger left-right bouncy)
			Server.Visuals.Ranged(Character.HumanoidRootPart.Position, 300, {
				Module = "Base",
				Function = "Shake",
				Arguments = {
					"Once",
					{
						6,  -- magnitude (increased from 4)
						15, -- roughness (more bouncy, increased from 12)
						0,  -- fadeInTime
						0.5, -- fadeOutTime (longer duration)
						Vector3.new(0.8, 0.3, 0.8), -- posInfluence (stronger)
						Vector3.new(0.3, 2.0, 0.3) -- rotInfluence (stronger left-right rotation)
					}
				}
			})

			Library.PlaySound(Character.HumanoidRootPart, Sfx.Skills.TripleKick["3"], true, 0.1)
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