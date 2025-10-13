local ServerStorage = game:GetService("ServerStorage")
local Replicated = game:GetService("ReplicatedStorage")
local Library = require(Replicated.Modules.Library)
local Skills = require(ServerStorage.Stats._Skills)
local RunService = game:GetService("RunService")

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

	-- WEAPON CHECK: This skill requires Fist weapon
	if Weapon ~= "Fist" then
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
		Server.Library.SetCooldown(Character, script.Name, 5) -- Increased from 2.5 to 5 seconds
		Server.Library.StopAllAnims(Character)

		local Move = Library.PlayAnimation(Character, Animation)
		-- Move:Play()
		local animlength = Move.Length

		Server.Library.TimedState(Character.Actions, script.Name, Move.Length)
		Server.Library.TimedState(Character.Speeds, "AlcSpeed-0", Move.Length)

		local hittimes = {}
		for i, fraction in Skills[Weapon][script.Name].HitTime do
			hittimes[i] = fraction * animlength
		end

		print(tostring(hittimes[1]))

		task.delay(hittimes[1], function()
			-- Safety check - make sure character still exists
			if not Character or not Character.PrimaryPart then
				return
			end

			Server.Visuals.Ranged(Character.HumanoidRootPart.Position, 300, {
				Module = "Base",
				Function = "Downslam",
				Arguments = { Character, "Start" },
			})

			-- Create linear velocity for arc motion
			local lv = Instance.new("LinearVelocity")
			local attachment = Instance.new("Attachment")
			attachment.Parent = Character.PrimaryPart

			lv.MaxForce = math.huge
			lv.Attachment0 = attachment
			lv.RelativeTo = Enum.ActuatorRelativeTo.World
			lv.Parent = Character.PrimaryPart

			-- Launch forward and up
			local forwardVector = Character.PrimaryPart.CFrame.LookVector
			local startTime = os.clock()
			local launchDuration = hittimes[2] - hittimes[1]

			-- Safety cleanup function
			local function cleanup()
				if lv and lv.Parent then
					lv.VectorVelocity = Vector3.zero
					task.wait(0.05)
					lv:Destroy()
				end
				if attachment and attachment.Parent then
					attachment:Destroy()
				end
			end

			-- Cleanup if character dies
			local humanoid = Character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.Died:Once(cleanup)
			end

			-- Smooth arc motion using heartbeat - ONLY DURING RISE
			local conn
			conn = RunService.Heartbeat:Connect(function()
				local elapsed = os.clock() - startTime
				local progress = math.min(elapsed / launchDuration, 1)

				-- Smooth arc trajectory - only forward (Z) and up (Y)
				local forwardSpeed = 50 * (1 - progress * 0.45) -- Gradual slowdown
				local verticalSpeed = 120 * (1 - progress) - 150 * progress -- Much higher arc up then down

				lv.VectorVelocity = forwardVector * forwardSpeed + Vector3.new(0, verticalSpeed, 0)

				-- When rise completes, REMOVE velocity and let gravity take over
				if progress >= 1 then
					Move:AdjustSpeed(0)
					conn:Disconnect()

					-- REMOVE the LinearVelocity - let natural gravity handle the fall
					lv:Destroy()
					attachment:Destroy()

					-- Wait for character to hit the ground naturally
					local descentConn
					descentConn = RunService.Heartbeat:Connect(function()
						-- Check if character still exists
						if not Character or not Character.PrimaryPart then
							if descentConn then
								descentConn:Disconnect()
							end
							return
						end

						-- Check distance to ground
						local raycast = workspace:Raycast(Character.PrimaryPart.Position, Vector3.new(0, -20, 0))
						if raycast and raycast.Distance < 8 then
							-- Close to ground - unpause animation and trigger landing
							Move:AdjustSpeed(1)
							descentConn:Disconnect()

							Server.Visuals.Ranged(Character.HumanoidRootPart.Position, 300, {
								Module = "Base",
								Function = "Downslam",
								Arguments = { Character, "Land" },
							})

							-- Add AOE hitbox for Downslam Kick when landing
							local Hitbox = Server.Modules.Hitbox
							local Entity = Server.Modules["Entities"].Get(Character)

							if Entity then
								local HitTargets = Hitbox.SpatialQuery(
									Character,
									Vector3.new(12, 8, 12), -- Large AOE hitbox
									Entity:GetCFrame() * CFrame.new(0, -2, 0), -- Around the landing point
									false -- Don't visualize
								)

								for _, Target in pairs(HitTargets) do
									if Target ~= Character and Target:IsA("Model") then
										Server.Modules.Damage.Tag(Character, Target, Skills[Weapon][script.Name]["DamageTable"])
										print("Downslam Kick hit:", Target.Name)
									end
								end
							end
						end
					end)
				end
			end)
		end)
	end
end
