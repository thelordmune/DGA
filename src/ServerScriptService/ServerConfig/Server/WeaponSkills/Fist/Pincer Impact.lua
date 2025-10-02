local ServerStorage = game:GetService("ServerStorage")
local Replicated = game:GetService("ReplicatedStorage")
local Library = require(Replicated.Modules.Library)
local Skills = require(ServerStorage.Stats._Skills)
local RunService = game:GetService("RunService")

local Global = require(Replicated.Modules.Shared.Global)
return function(Player, Data, Server)
    local Char = Player.Character

	if not Char or not Char:GetAttribute("Equipped") then
		return
	end
	local Weapon = Global.GetData(Player).Weapon
	local PlayerObject = Server.Modules["Players"].Get(Player)
	local Animation = Replicated.Assets.Animations.Skills.Weapons[Weapon][script.Name]

	if Server.Library.StateCount(Char.Actions) or Server.Library.StateCount(Char.Stuns) then
		return
	end

	if PlayerObject and PlayerObject.Keys and not Server.Library.CheckCooldown(Char, script.Name) then
		Server.Library.SetCooldown(Char, script.Name, 2.5)
		Server.Library.StopAllAnims(Char)

		local Move = Library.PlayAnimation(Char, Animation)
		-- Move:Play()
		local animlength = Move.Length

		Server.Library.TimedState(Char.Actions, script.Name, Move.Length)
		Server.Library.TimedState(Char.Speeds, "AlcSpeed-0", Move.Length)

		local hittimes = {}
		for i, fraction in Skills[Weapon][script.Name].HitTime do
			hittimes[i] = fraction * animlength
		end

		-- Track if player pressed M1 during the input window
		local pressedM1 = false
		local inputWindowActive = false

		-- Calculate keyframe times (assuming 60 FPS animation)
		local fps = 60
		-- TESTING: Expanded window from keyframes 98-107 to 90-115 (25 frames instead of 9)
		local keyframe98Time = (90 / fps)  -- Was 98
		local keyframe107Time = (115 / fps)  -- Was 107

		print(`[PINCER IMPACT] Input window: {keyframe98Time}s to {keyframe107Time}s (duration: {keyframe107Time - keyframe98Time}s)`)
		print(`[PINCER IMPACT] PlayerObject exists: {PlayerObject ~= nil}`)
		print(`[PINCER IMPACT] PlayerObject.Keys exists: {PlayerObject and PlayerObject.Keys ~= nil}`)
		if PlayerObject and PlayerObject.Keys then
			print("[PINCER IMPACT] 📋 All available keys in PlayerObject.Keys:")
			for key, value in pairs(PlayerObject.Keys) do
				print(`  - {key} = {value}`)
			end
		end

		print(tostring(hittimes[1]))
        task.delay(hittimes[1], function()
            Server.Visuals.Ranged(Char.HumanoidRootPart.Position, 300, {
					Module = "Base",
					Function = "AlchemicAssault",
					Arguments = { Char, "Jump" },
				})
                Server.Visuals.Ranged(Char.HumanoidRootPart.Position, 300, {
					Module = "Weapons",
					Function = "DropKick",
					Arguments = { Char, "Start" },
				})
            Server.Library.RemoveState(Char.Speeds, "AlcSpeed-0")
            Server.Library.TimedState(Char.Speeds, "AlcSpeed-6", Move.Length - hittimes[1])
        end)

        print(tostring(hittimes[3]-hittimes[2]) .. "this is the ptbvel 1 duration")

        task.delay(hittimes[2], function()
            Server.Packets.Bvel.sendTo({Character = Char, Name = "PIBvel"}, Player)
        end)

        print(tostring(hittimes[4]-hittimes[3]) .. "this is the ptbvel 2 duration")

        task.delay(hittimes[3], function()
            Server.Library.TimedState(Char.Stuns, "NoRotate", hittimes[4])
            Server.Packets.Bvel.sendTo({Character = Char, Name = "PIBvel2"}, Player)
        end)

		-- Start input window at keyframe 90 (TESTING - was 98)
		task.delay(keyframe98Time, function()
			inputWindowActive = true
			print("[PINCER IMPACT] ✅ Input window OPENED at keyframe 90 (TESTING)")

			-- Show highlight to indicate input window
			Server.Visuals.Ranged(Char.HumanoidRootPart.Position, 300, {
				Module = "Weapons",
				Function = "InputWindowHighlight",
				Arguments = { Char, "Start" },
			})
		end)

		-- End input window at keyframe 115 (TESTING - was 107)
		task.delay(keyframe107Time, function()
			inputWindowActive = false
			print("[PINCER IMPACT] ❌ Input window CLOSED at keyframe 115 (TESTING)")

			-- Remove highlight
			Server.Visuals.Ranged(Char.HumanoidRootPart.Position, 300, {
				Module = "Weapons",
				Function = "InputWindowHighlight",
				Arguments = { Char, "Stop" },
			})
		end)

		-- Listen for M1 input during the window
		local m1Connection
		local frameCount = 0
		local printedKeys = false
		m1Connection = RunService.Heartbeat:Connect(function()
			if not Char or not Char.Parent then
				print("[PINCER IMPACT] ⚠️ Character missing, disconnecting M1 listener")
				m1Connection:Disconnect()
				return
			end

			-- Debug: Print all keys once when window opens
			if inputWindowActive and not printedKeys then
				printedKeys = true
				print("[PINCER IMPACT] 📋 Keys during window:")
				if PlayerObject.Keys then
					for key, value in pairs(PlayerObject.Keys) do
						print(`  - {key} = {value}`)
					end
				end
			end

			-- Debug: Print status every 10 frames during window
			if inputWindowActive then
				frameCount = frameCount + 1
				if frameCount % 10 == 0 then
					-- Check the Attack key (M1 is called "Attack" in PlayerObject.Keys)
					local attackState = PlayerObject.Keys and PlayerObject.Keys.Attack
					print(`[PINCER IMPACT] 🔍 Checking... Window Active: {inputWindowActive}, Attack key: {attackState}`)
				end
			end

			-- Check if player is pressing Attack (M1) during the input window
			if inputWindowActive and PlayerObject.Keys and PlayerObject.Keys.Attack then
				pressedM1 = true
				print("[PINCER IMPACT] 🎯 SUCCESS! Attack key pressed during input window! Will use BF variant.")
				m1Connection:Disconnect()
			end
		end)

		-- Clean up connection when animation ends
		task.delay(Move.Length, function()
			if m1Connection then
				m1Connection:Disconnect()
			end
		end)

        task.delay(hittimes[4], function()
			-- Send "BF" variant if M1 was pressed, otherwise "None"
			local variant = pressedM1 and "BF" or "None"

			if pressedM1 then
				print(`[PINCER IMPACT] 💥 Sending DKImpact with variant: {variant} (RED - Player hit the timing!)`)
			else
				print(`[PINCER IMPACT] 💨 Sending DKImpact with variant: {variant} (BLUE - Player missed the timing)`)
			end

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
				for _, Target in pairs(HitTargets) do
					if Target ~= Char and Target:IsA("Model") then
						Server.Modules.Damage.Tag(Char, Target, Skills[Weapon][script.Name]["DamageTable"])
						print("Pincer Impact hit:", Target.Name)
						hitSomeone = true
						table.insert(hitTargets, Target)
					end
				end

				-- If hit someone, pause animation and slow particles
				if hitSomeone then
					print("[PINCER IMPACT] 🎯 Hit detected! Pausing animation and particles...")

					-- Pause attacker's animation by setting speed to 0
					Move:AdjustSpeed(0)

					-- Pause all hit targets' animations
					local targetAnimTracks = {}
					for _, Target in ipairs(hitTargets) do
						if Target:FindFirstChild("Humanoid") and Target.Humanoid:FindFirstChild("Animator") then
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

					-- Resume attacker's animation
					Move:AdjustSpeed(1)

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
            Server.Visuals.Ranged(Char.HumanoidRootPart.Position, 300, {
					Module = "Weapons",
					Function = "DropKick",
					Arguments = { Char, "StepL" },
				})
        end)
        task.delay(hittimes[6], function()
            Server.Visuals.Ranged(Char.HumanoidRootPart.Position, 300, {
					Module = "Weapons",
					Function = "DropKick",
					Arguments = { Char, "StepR" },
				})
        end)
    end
end