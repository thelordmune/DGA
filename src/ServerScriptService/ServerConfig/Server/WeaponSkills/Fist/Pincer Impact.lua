local ServerStorage = game:GetService("ServerStorage")
local Replicated = game:GetService("ReplicatedStorage")
local Library = require(Replicated.Modules.Library)
local Skills = require(ServerStorage.Stats._Skills)
local RunService = game:GetService("RunService")
local SFX = Replicated:WaitForChild("Assets").SFX
local StateManager = require(Replicated.Modules.ECS.StateManager)

local Global = require(Replicated.Modules.Shared.Global)
local Ragdoll = require(Replicated.Modules.Utils.Ragdoll)

-- BvelRemove Effect enum for optimized packet (matches client-side decoder)
local BvelRemoveEffect = {
	All = 0,        -- Remove all body movers
	Pincer = 5,     -- Remove Pincer velocity specifically
}
return function(Player, Data, Server)
    local Char = Player.Character

	if not Char then
		return
	end

	-- Check if this is an NPC (no Player instance) or a real player
	local isNPC = typeof(Player) ~= "Instance" or not Player:IsA("Player")

	-- For players, check equipped status
	if not isNPC and not Char:GetAttribute("Equipped") then
		return
	end

	-- Get weapon - for NPCs use attribute, for players use Global.GetData
	local Weapon
	if isNPC then
		Weapon = Char:GetAttribute("Weapon") or "Fist"
	else
		Weapon = Global.GetData(Player).Weapon
	end

	-- WEAPON CHECK: This skill requires Fist weapon
	if Weapon ~= "Fist" then
		return -- Character doesn't have the correct weapon for this skill
	end

	local PlayerObject = Server.Modules["Players"].Get(Player)
	local Animation = Replicated.Assets.Animations.Skills.Weapons[Weapon][script.Name]

	-- Use ActionPriority to check if HyperArmorSkill can start
	-- PincerImpact is a hyper armor skill (priority 5), can cancel almost everything
	if not Server.Library.CanStartAction(Char, "PincerImpact") then
		return
	end
	if StateManager.StateCount(Char, "Stuns") then
		return
	end

	-- For NPCs, skip the PlayerObject.Keys check
	local canUseSkill = isNPC or (PlayerObject and PlayerObject.Keys)

	if canUseSkill and not Server.Library.CheckCooldown(Char, script.Name) then
		-- Start HyperArmorSkill action with priority system (priority 5, hard to cancel)
		Server.Library.StartAction(Char, "PincerImpact")

		-- Stop ALL animations first (including dash) to prevent animation root motion from interfering
		Server.Library.StopAllAnims(Char)

		-- Remove any existing body movers FIRST and wait for it to complete
		if not isNPC then
			-- Optimized: Use BvelRemove packet (2 bytes vs ~20+ bytes)
			Server.Packets.BvelRemove.sendTo({Character = Char, Effect = BvelRemoveEffect.All}, Player)
			task.wait(0.1) -- Increased delay to ensure animations stop and RemoveBvel completes
		end

		Server.Library.SetCooldown(Char, script.Name, 5) -- Increased from 2.5 to 5 seconds

		local Move = Library.PlayAnimation(Char, Animation)
		-- Move:Play()
		local animlength = Move.Length

		StateManager.TimedState(Char, "Actions", script.Name, Move.Length)
		StateManager.TimedState(Char, "Speeds", "AlcSpeed-0", Move.Length)
		StateManager.TimedState(Char, "Speeds", "Jump-50", Move.Length) -- Prevent jumping during move

		-- Initialize hyperarmor tracking for this move
		Char:SetAttribute("HyperarmorDamage", 0)
		Char:SetAttribute("HyperarmorMove", script.Name)

		-- Start hyperarmor visual indicator (white highlight)
		Server.Visuals.Ranged(Char.HumanoidRootPart.Position, 300, {
			Module = "Misc",
			Function = "StartHyperarmor",
			Arguments = { Char }
		})

		-- Add forward movement for NPCs (players have animation root motion)
		local forwardVelocity = nil
		if isNPC then
			local rootPart = Char:FindFirstChild("HumanoidRootPart")
			if rootPart then
				local attachment = rootPart:FindFirstChild("RootAttachment")
				if not attachment then
					attachment = Instance.new("Attachment")
					attachment.Name = "RootAttachment"
					attachment.Parent = rootPart
				end

				-- Create LinearVelocity on server for physics
				forwardVelocity = Instance.new("LinearVelocity")
				forwardVelocity.Name = "PincerImpactVelocity"
				forwardVelocity.MaxForce = math.huge
				forwardVelocity.VectorVelocity = rootPart.CFrame.LookVector * 30
				forwardVelocity.Attachment0 = attachment
				forwardVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
				forwardVelocity.Parent = rootPart

				-- Also replicate to all clients for visual sync
				Server.Packets.Bvel.sendToAll({
					Character = Char,
					Name = "PincerForwardVelocity",
					Targ = Char
				})
			end
		end

		-- Cleanup function for when skill ends or is cancelled
		local function cleanup()
			if Char and Char.Parent then
				Char:SetAttribute("HyperarmorDamage", nil)
				Char:SetAttribute("HyperarmorMove", nil)

				-- Remove hyperarmor visual
				Server.Visuals.Ranged(Char.HumanoidRootPart.Position, 300, {
					Module = "Misc",
					Function = "RemoveHyperarmor",
					Arguments = { Char }
				})

				-- Clean up forward velocity for NPCs
				if forwardVelocity and forwardVelocity.Parent then
					forwardVelocity:Destroy()
				end

				-- Also remove on clients
				if isNPC then
					-- Optimized: Use BvelRemove packet with Pincer effect (2 bytes vs ~30+ bytes)
					Server.Packets.BvelRemove.sendToAll({
						Character = Char,
						Effect = BvelRemoveEffect.Pincer
					})
				end
			end
		end

		-- Call cleanup when move ends, then add recovery endlag
		task.delay(Move.Length, function()
			cleanup()
			-- Add recovery endlag after skill completes (0.25s for heavy skill)
			if Char then
				StateManager.TimedState(Char, "Actions", "PincerRecovery", 0.25)
			end
		end)

		local hittimes = {}
		for i, fraction in Skills[Weapon][script.Name].HitTime do
			hittimes[i] = fraction * animlength
		end

		-- Track if player pressed M1 during the input window (only for players, not NPCs)
		local pressedM1 = false
		local inputWindowActive = false

		-- Calculate keyframe times (assuming 60 FPS animation)
		local fps = 60
		-- Input window from keyframes 98-107 (9 frames)
		local keyframe98Time = (98 / fps)
		local keyframe107Time = (107 / fps)
        task.delay(hittimes[1], function()

            Server.Library.PlaySound(Char, SFX.PI.Start)
            Server.Visuals.Ranged(Char.HumanoidRootPart.Position, 300, {
					Module = "Weapons",
					Function = "AlchemicAssault",
					Arguments = { Char, "Jump" },
				})
                Server.Visuals.Ranged(Char.HumanoidRootPart.Position, 300, {
					Module = "Weapons",
					Function = "DropKick",
					Arguments = { Char, "Start" },
				})
            StateManager.RemoveState(Char, "Speeds", "AlcSpeed-0")
            StateManager.TimedState(Char, "Speeds", "AlcSpeed-6", Move.Length - hittimes[1])
        end)

        -- ---- print(tostring(hittimes[3]-hittimes[2]) .. "this is the ptbvel 1 duration")

        task.delay(hittimes[2], function()
			-- Send to player (they have network ownership)
            Server.Packets.Bvel.sendTo({Character = Char, Name = "PIBvel", Targ = Char}, Player)
        end)


        task.delay(hittimes[3], function()
            Server.Library.PlaySound(Char, SFX.PI.Leap)
            Server.Visuals.Ranged(Char.HumanoidRootPart.Position, 300, {
					Module = "Weapons",
					Function = "AlchemicAssault",
					Arguments = { Char, "Jump" },
				})
                Server.Visuals.Ranged(Char.HumanoidRootPart.Position, 300, {
					Module = "Weapons",
					Function = "DropKick",
					Arguments = { Char, "Start" },
				})
			-- Send to player (they have network ownership)
            Server.Packets.Bvel.sendTo({Character = Char, Name = "PIBvel2", Targ = Char}, Player)
        end)

		-- Only set up M1 input detection for players (not NPCs)
		if not isNPC and PlayerObject and PlayerObject.Keys then
			-- Start input window at keyframe 98
			task.delay(keyframe98Time, function()
				inputWindowActive = true
			end)

			-- End input window at keyframe 107
			task.delay(keyframe107Time, function()
				inputWindowActive = false
			end)

			-- Listen for M1 input during the window
			local m1Connection
			local frameCount = 0
			local hasAttempted = false -- Track if player has already pressed M1 (prevents spam)
			local lastAttackState = false -- Track previous Attack key state for edge detection

			m1Connection = RunService.Heartbeat:Connect(function()
				if not Char or not Char.Parent then
					m1Connection:Disconnect()
					return
				end

				-- Get current Attack key state
				local currentAttackState = PlayerObject.Keys and PlayerObject.Keys.Attack or false

				-- Detect rising edge (key was just pressed, not held)
				local justPressed = currentAttackState and not lastAttackState

				-- Only register ONE attempt during the input window
				if inputWindowActive and justPressed and not hasAttempted then
					hasAttempted = true -- Mark that player has used their one chance
					pressedM1 = true
					m1Connection:Disconnect()
				elseif justPressed and not inputWindowActive and not hasAttempted then
					-- Player pressed too early or too late - mark as attempted (failed)
					hasAttempted = true
				end

				-- Update last state for next frame
				lastAttackState = currentAttackState
			end)

			-- Clean up connection when animation ends
			task.delay(Move.Length, function()
				if m1Connection then
					m1Connection:Disconnect()
				end
			end)
		end

        task.delay(hittimes[4], function()
			-- BF variant is now available if player hits M1 timing (no adrenaline requirement)
			local canUseBF = pressedM1

			-- Send "BF" variant if M1 was pressed, otherwise "None"
			local variant = canUseBF and "BF" or "None"

			-- Create hitbox at impact
			local Hitbox = Server.Modules.Hitbox
			local Entity = Server.Modules["Entities"].Get(Char)

			if Entity then
				local HitTargets = Hitbox.SpatialQuery(
					Char,
					Vector3.new(10, 8, 10), -- Impact AOE hitbox
					Entity:GetCFrame() * CFrame.new(0, 0, -5), -- In front of player
					false -- Don't visualize
				)

				local hitSomeone = false
				local hitTargets = {}

				-- Choose damage table based on variant (canUseBF instead of pressedM1)
				local damageTable = canUseBF and Skills[Weapon][script.Name]["BFDamageTable"] or Skills[Weapon][script.Name]["DamageTable"]

				for _, Target in pairs(HitTargets) do
					if Target ~= Char and Target:IsA("Model") then
						Server.Modules.Damage.Tag(Char, Target, damageTable)
						-- ---- print(`Pincer Impact hit: {Target.Name} with variant: {variant}`)
						hitSomeone = true
						table.insert(hitTargets, Target)

						-- Only apply additional stun for BF variant (non-BF uses damage table stun which is 0)
						if canUseBF then
							StateManager.TimedState(Target, "Actions", "PincerImpactStun", damageTable.Stun)
							StateManager.TimedState(Target, "Stuns", "NoAttack", damageTable.Stun)
						end
					end
				end

				-- If hit someone with BF variant, do cinematic cutscene
				if hitSomeone and canUseBF then
					Server.Library.PlaySound(Char, SFX.PI.Zoom, true)	
                    task.delay(.2, function()
                    Server.Library.PlaySound(Char, SFX.PI.Impact4, true)
					Server.Library.PlaySound(Char, SFX.PI.Hit, true)
                    Server.Library.PlaySound(Char, SFX.PI.Impact, true)
                    Server.Library.PlaySound(Char, SFX.PI.Impact2, true)
                    Server.Library.PlaySound(Char, SFX.PI.Impact3, true)
					Server.Library.PlaySound(Char, SFX.PI.Impact5, true)
                end)
					-- ---- print("[PINCER IMPACT] 🎯 BF Hit detected! Starting cinematic cutscene...")

					-- Lock attacker's rotation and position
					local attackerCFrame = Char.HumanoidRootPart.CFrame
					local attackerAnchor = Instance.new("BodyPosition")
					attackerAnchor.Position = attackerCFrame.Position
					attackerAnchor.MaxForce = Vector3.new(100000, 100000, 100000)  -- Reduced from math.huge
					attackerAnchor.P = 10000
					attackerAnchor.D = 500
					attackerAnchor.Parent = Char.HumanoidRootPart

					local attackerGyro = Instance.new("BodyGyro")
					attackerGyro.CFrame = attackerCFrame
					attackerGyro.MaxTorque = Vector3.new(100000, 100000, 100000)  -- Reduced from math.huge
					attackerGyro.P = 10000
					attackerGyro.D = 500
					attackerGyro.Parent = Char.HumanoidRootPart

					-- Add NoRotate stun during freeze
					StateManager.TimedState(Char, "Stuns", "NoRotate", 1)

					-- Pause attacker's animation by setting speed to 0
					Move:AdjustSpeed(0)

					-- Pause all hit targets' animations and lock them in place
					local targetAnimTracks = {}
					local targetLocks = {}
					for _, Target in ipairs(hitTargets) do
						if Target:FindFirstChild("Humanoid") and Target.Humanoid:FindFirstChild("Animator") then
							-- Lock target position and rotation
							local targetCFrame = Target.HumanoidRootPart.CFrame
							local targetAnchor = Instance.new("BodyPosition")
							targetAnchor.Position = targetCFrame.Position
							targetAnchor.MaxForce = Vector3.new(100000, 100000, 100000)  -- Reduced from math.huge
							targetAnchor.P = 10000
							targetAnchor.D = 500
							targetAnchor.Parent = Target.HumanoidRootPart

							local targetGyro = Instance.new("BodyGyro")
							targetGyro.CFrame = targetCFrame
							targetGyro.MaxTorque = Vector3.new(100000, 100000, 100000)  -- Reduced from math.huge
							targetGyro.P = 10000
							targetGyro.D = 500
							targetGyro.Parent = Target.HumanoidRootPart

							targetLocks[Target] = {anchor = targetAnchor, gyro = targetGyro}

							-- Pause animations
							local tracks = Target.Humanoid.Animator:GetPlayingAnimationTracks()
							targetAnimTracks[Target] = {}
							for _, track in ipairs(tracks) do
								-- Store original speed
								table.insert(targetAnimTracks[Target], {track = track, speed = track.Speed})
								-- Pause the animation
								track:AdjustSpeed(0)
							end
						end
					end

					-- Send particle freeze AND camera effect to client
					Server.Visuals.Ranged(Char.HumanoidRootPart.Position, 300, {
						Module = "Weapons",
						Function = "DKImpact",
						Arguments = { Char, variant, true}, -- true = freeze particles + camera
					})

					-- Wait 1 second (increased from 0.5)
					task.wait(1)

					-- Remove attacker's position/rotation locks
					attackerAnchor:Destroy()
					attackerGyro:Destroy()

					-- Resume attacker's animation
					Move:AdjustSpeed(1)

					-- Remove target locks and resume animations
					for _, locks in pairs(targetLocks) do
						if locks.anchor then
							locks.anchor:Destroy()
						end
						if locks.gyro then
							locks.gyro:Destroy()
						end
					end

					-- Resume all hit targets' animations
					for _, tracks in pairs(targetAnimTracks) do
						for _, trackData in ipairs(tracks) do
							if trackData.track and trackData.track.IsPlaying then
								trackData.track:AdjustSpeed(trackData.speed)
							end
						end
					end

					-- Send particle resume to client
					Server.Visuals.Ranged(Char.HumanoidRootPart.Position, 300, {
						Module = "Weapons",
						Function = "DKImpactResume",
						Arguments = { Char },
					})

					-- NOW apply ragdoll + knockback AFTER freeze ends (BodyPosition/BodyGyro are destroyed)
					for _, Target in ipairs(hitTargets) do
						local targetHumanoid = Target:FindFirstChild("Humanoid")
						local targetRoot = Target:FindFirstChild("HumanoidRootPart")

						-- Check if target is still alive and valid
						if targetHumanoid and targetRoot and targetHumanoid.Health > 0 and Target.Parent then
							---- print(`[PINCER IMPACT BF] Applying ragdoll + knockback to {Target.Name} (Health: {targetHumanoid.Health})`)

							-- Apply ragdoll effect
							local ragdollDuration = 5 -- Ragdoll lasts 2 seconds
							Ragdoll.Ragdoll(Target, ragdollDuration)

							-- Calculate knockback direction (away from attacker)
							local direction = (targetRoot.Position - Char.HumanoidRootPart.Position).Unit
							local horizontalPower = 50 -- Horizontal knockback strength
							local upwardPower = 30 -- Upward arc strength

							-- Always apply on server (works for all character types)
							-- Players can't apply physics to other players on client due to network ownership
							Server.Modules.ServerBvel.BFKnockback(Target, direction, horizontalPower, upwardPower)

							---- print(`[PINCER IMPACT BF] ✅ Ragdoll + Knockback applied to {Target.Name}`)
						end
					end
				elseif hitSomeone and not pressedM1 then
					-- Hit with None variant - just play VFX, no cutscene
					-- ---- print("[PINCER IMPACT] 💨 None variant hit - no cutscene")
					Server.Visuals.Ranged(Char.HumanoidRootPart.Position, 300, {
						Module = "Weapons",
						Function = "DKImpact",
						Arguments = { Char, variant, false}, -- false = don't freeze
					})
				else
					-- No hit, just play normal VFX
					Server.Visuals.Ranged(Char.HumanoidRootPart.Position, 300, {
						Module = "Weapons",
						Function = "DKImpact",
						Arguments = { Char, variant, false}, -- false = don't freeze
					})
				end
			end
        end)

        task.delay(hittimes[5], function()
            Server.Library.PlaySound(Char, SFX.PI.Left)
            Server.Visuals.Ranged(Char.HumanoidRootPart.Position, 300, {
					Module = "Weapons",
					Function = "DropKick",
					Arguments = { Char, "StepL" },
				})
        end)
        task.delay(hittimes[6], function()
            Server.Library.PlaySound(Char, SFX.PI.Right)
            Server.Visuals.Ranged(Char.HumanoidRootPart.Position, 300, {
					Module = "Weapons",
					Function = "DropKick",
					Arguments = { Char, "StepR" },
				})
        end)
    end
end