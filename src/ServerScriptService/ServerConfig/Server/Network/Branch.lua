local NetworkModule = {}
local Server = require(script.Parent.Parent)
local Replicated = game:GetService("ReplicatedStorage")
local Library = require(Replicated.Modules.Library)
local Moves = require(game:GetService("ServerStorage").Stats._Moves)
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local RockMod = require(Replicated.Modules.Utils.RockMod)

-- Bezier curve function for quadratic bezier
local function Bezier(t, start, control, endPos)
	return (1 - t)^2 * start + 2 * (1 - t) * t * control + t^2 * endPos
end

-- Active connections for cleanup
local activeConnections = {}

local function cleanUp()
	for _, connection in activeConnections do
		if connection and connection.Connected then
			connection:Disconnect()
		end
	end
	activeConnections = {}
end

NetworkModule.EndPoint = function(Player, Data)
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

	local PlayerObject = Server.Modules["Players"].Get(Player)
	local Animation = Replicated.Assets.Animations.Misc.Alchemy

	if Server.Library.StateCount(Character.Actions) or Server.Library.StateCount(Character.Stuns) then
		return
	end

	-- For NPCs, skip the PlayerObject.Keys check
	local canUseSkill = isNPC or (PlayerObject and PlayerObject.Keys)

	if canUseSkill and not Server.Library.CheckCooldown(Character, script.Name) then
		cleanUp()
		Server.Library.SetCooldown(Character, script.Name, 10) -- 10 second cooldown
		Server.Library.StopAllAnims(Character)

		local Alchemy = Library.PlayAnimation(Character, Animation)
		if not Alchemy then
			return
		end

		Alchemy.Looped = false

		Server.Library.TimedState(Character.Actions, script.Name, Alchemy.Length)
		Server.Library.TimedState(Character.Speeds, "AlcSpeed-0", Alchemy.Length)
		Server.Library.TimedState(Character.Stuns, "NoRotate", Alchemy.Length)

		local root = Character:FindFirstChild("HumanoidRootPart")
		if not root then
			return
		end

		-- Clean up when animation ends
		Alchemy.Ended:Once(function()
			cleanUp()
		end)

		-- Wait for animation keyframe
		local kfConn
		kfConn = Alchemy.KeyframeReached:Connect(function(key)
			if key == "Clap" then
				-- Play clap sound
				local s = Replicated.Assets.SFX.FMAB.Clap:Clone()
				s.Parent = root
				s:Play()
				Debris:AddItem(s, s.TimeLength)

				-- Visual effects
				Server.Visuals.Ranged(root.Position, 300, {
					Module = "Base",
					Function = "Clap",
					Arguments = { Character },
				})
			end

			if key == "Touch" then
				-- Find target (closest enemy) RIGHT BEFORE spawning rocks
				local target = nil
				local closestDistance = math.huge

				for _, potentialTarget in workspace.World.Live:GetDescendants() do
					if potentialTarget:IsA("Model") and potentialTarget ~= Character then
						local targetRoot = potentialTarget:FindFirstChild("HumanoidRootPart")
						local targetHumanoid = potentialTarget:FindFirstChild("Humanoid")

						if targetRoot and targetHumanoid and targetHumanoid.Health > 0 then
							local distance = (root.Position - targetRoot.Position).Magnitude
							if distance < closestDistance and distance <= 50 then -- Max range 50 studs
								closestDistance = distance
								target = potentialTarget
							end
						end
					end
				end

				-- Get target position (opponent's current position or default)
				local targetPos
				local distance = 30 -- Default distance
				if target and target:FindFirstChild("HumanoidRootPart") then
					targetPos = target.HumanoidRootPart.Position
					distance = (root.Position - targetPos).Magnitude
					print("[BRANCH] Target found:", target.Name, "at position:", targetPos, "distance:", distance)
				else
					targetPos = (root.CFrame * CFrame.new(0, 0, -30)).Position
					print("[BRANCH] No target found, using default position:", targetPos)
				end

				-- Calculate dynamic speed based on distance
				-- Closer targets = faster rocks (0.02-0.04 spawn speed)
				-- Further targets = slower rocks (0.05-0.08 spawn speed)
				local baseSpeed = math.clamp(distance / 1000, 0.02, 0.08) -- Increased general speed
				local spawnSpeed = {
					Left = baseSpeed * 0.8, -- Left is faster
					Right = baseSpeed * 1.2 -- Right is slower
				}

				-- Calculate hit delay based on distance (faster for closer targets)
				local hitDelay = math.clamp(distance / 50, 0.3, 0.8) -- 0.3s for close, 0.8s for far

				-- Play transmutation sound
				local s = Replicated.Assets.SFX.FMAB.Transmute:Clone()
				s.Volume = 2
				s.Parent = root
				s:Play()
				Debris:AddItem(s, s.TimeLength)

				Server.Visuals.Ranged(root.Position, 300, {
					Module = "Base",
					Function = "Transmute",
					Arguments = { Character },
				})

				-- Send visual packet to all clients with dynamic speed
				Server.Visuals.Ranged(root.Position, 300, {
					Module = "Base",
					Function = "Branch",
					Arguments = { Character, targetPos, "Left", spawnSpeed.Left },
				})

				Server.Visuals.Ranged(root.Position, 300, {
					Module = "Base",
					Function = "Branch",
					Arguments = { Character, targetPos, "Right", spawnSpeed.Right },
				})

				-- Damage detection at target position with dynamic delay
				if target then
					task.delay(hitDelay, function() -- Dynamic delay based on distance
						local Hitbox = Server.Modules.Hitbox
						local hitTargets = Hitbox.SpatialQuery(Character, Vector3.new(12, 8, 12), CFrame.new(targetPos))

						for _, hitTarget in hitTargets do
							if hitTarget ~= Character then
								Server.Modules.Damage.Tag(Character, hitTarget, {
									Damage = 15,
									PostureDamage = 20,
									Stun = 0.8,
									BlockBreak = true, -- FIXED: Branch should guard break
									M1 = false,
									M2 = false,
									FX = Replicated.Assets.VFX.Blood.Attachment,
								})
							end
						end

						-- Create crater at impact point
						Server.Visuals.Ranged(targetPos, 300, {
							Module = "Base",
							Function = "BranchCrater",
							Arguments = { targetPos },
						})
					end)
				end
			end
		end)
		table.insert(activeConnections, kfConn)
	end
end

return NetworkModule

