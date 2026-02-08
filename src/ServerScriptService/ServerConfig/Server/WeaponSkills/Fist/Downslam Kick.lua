local ServerStorage = game:GetService("ServerStorage")
local Replicated = game:GetService("ReplicatedStorage")
local Library = require(Replicated.Modules.Library)
local Skills = require(ServerStorage.Stats._Skills)
local RunService = game:GetService("RunService")
local StateManager = require(Replicated.Modules.ECS.StateManager)

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

	if StateManager.StateCount(Character, "Actions") or StateManager.StateCount(Character, "Stuns") then
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

		StateManager.TimedState(Character, "Actions", script.Name, Move.Length)
		StateManager.TimedState(Character, "Speeds", "AlcSpeed-0", Move.Length)
		StateManager.TimedState(Character, "Speeds", "Jump-50", Move.Length) -- Prevent jumping during move

		local hittimes = {}
		for i, fraction in Skills[Weapon][script.Name].HitTime do
			hittimes[i] = fraction * animlength
		end

		---- print(tostring(hittimes[1]))

		task.delay(hittimes[1], function()
			-- Safety check - make sure character still exists
			if not Character or not Character.PrimaryPart then
				return
			end

			Server.Visuals.Ranged(Character.HumanoidRootPart.Position, 300, {
				Module = "Weapons",
				Function = "Downslam",
				Arguments = { Character, "Start" },
			})

			-- Create linear velocity for smooth upward launch
			local lv = Instance.new("LinearVelocity")
			local attachment = Instance.new("Attachment")
			attachment.Parent = Character.PrimaryPart

			lv.MaxForce = 200000  -- Reduced from math.huge to prevent excessive force
			lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
			lv.ForceLimitMode = Enum.ForceLimitMode.PerAxis
			lv.ForceLimitsEnabled = true
			lv.MaxAxesForce = Vector3.new(40000, 40000, 40000)  -- Allow Y-axis during rise
			lv.Attachment0 = attachment
			lv.RelativeTo = Enum.ActuatorRelativeTo.World
			lv.Parent = Character.PrimaryPart

			-- Get initial forward direction
			local forwardVector = Character.PrimaryPart.CFrame.LookVector
			forwardVector = Vector3.new(forwardVector.X, 0, forwardVector.Z).Unit  -- Flatten to horizontal

			-- Smooth upward launch parameters
			local startTime = os.clock()
			local riseDuration = 0.4  -- Duration of upward movement
			local initialUpwardSpeed = 70
			local initialForwardSpeed = 35

			-- Cleanup if character dies
			local humanoid = Character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.Died:Once(function()
					if lv and lv.Parent then
						lv:Destroy()
					end
					if attachment and attachment.Parent then
						attachment:Destroy()
					end
				end)
			end

			-- Smooth rise with player control
			local riseConn
			riseConn = RunService.Heartbeat:Connect(function()
				if not Character or not Character.PrimaryPart then
					riseConn:Disconnect()
					return
				end

				local elapsed = os.clock() - startTime
				local progress = math.min(elapsed / riseDuration, 1)

				-- Smooth deceleration curve for upward movement
				local upwardSpeed = initialUpwardSpeed * (1 - progress)

				-- Get current player input direction for air control
				local currentForward = Character.PrimaryPart.CFrame.LookVector
				currentForward = Vector3.new(currentForward.X, 0, currentForward.Z).Unit

				-- Allow player to control horizontal direction during jump
				local horizontalSpeed = initialForwardSpeed * (1 - progress * 0.3)

				-- Apply velocity (player can steer horizontally)
				lv.VectorVelocity = currentForward * horizontalSpeed + Vector3.new(0, upwardSpeed, 0)

				-- When rise completes, restrict to horizontal movement only
				if progress >= 1 then
					riseConn:Disconnect()

					-- Restrict LinearVelocity to horizontal movement only (no Y-axis)
					lv.MaxAxesForce = Vector3.new(40000, 0, 40000)  -- No Y-axis force
					lv.VectorVelocity = Vector3.new(lv.VectorVelocity.X, 0, lv.VectorVelocity.Z)  -- Zero out Y velocity

					-- Pause animation during fall (will be resumed faster when close to ground)
					if Move then
						Move:AdjustSpeed(0)
					end

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
						local rayParams = RaycastParams.new()
						rayParams.FilterType = Enum.RaycastFilterType.Exclude
						rayParams.FilterDescendantsInstances = {Character}

						local raycast = workspace:Raycast(
							Character.PrimaryPart.Position,
							Vector3.new(0, -20, 0),
							rayParams
						)

						if raycast and raycast.Distance < 8 then
							-- Close to ground - unpause animation at 2x speed for faster landing
							if Move then
								Move:AdjustSpeed(2)  -- 2x speed for faster descent animation
							end
							descentConn:Disconnect()

							-- Clean up LinearVelocity after landing
							if lv and lv.Parent then
								lv:Destroy()
							end
							if attachment and attachment.Parent then
								attachment:Destroy()
							end

							Server.Visuals.Ranged(Character.HumanoidRootPart.Position, 300, {
								Module = "Weapons",
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
										---- print("Downslam Kick hit:", Target.Name)
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
