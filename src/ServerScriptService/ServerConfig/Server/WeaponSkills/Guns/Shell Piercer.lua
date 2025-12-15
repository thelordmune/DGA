local ServerStorage = game:GetService("ServerStorage")
local Replicated = game:GetService("ReplicatedStorage")
local Library = require(Replicated.Modules.Library)
local Skills = require(ServerStorage.Stats._Skills)
local VoxBreaker = require(Replicated.Modules.Voxel)
local Debris = game:GetService("Debris")
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
		Weapon = Character:GetAttribute("Weapon") or "Guns"
	else
		Weapon = Global.GetData(Player).Weapon
	end

	-- WEAPON CHECK: This skill requires Guns weapon
	if Weapon ~= "Guns" then
		warn(string.format("[Shell Piercer] BLOCKED: %s has weapon '%s' but needs 'Guns'", Character.Name, Weapon))
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
		Server.Library.SetCooldown(Character, script.Name, 6) -- Increased from 2.5 to 6 seconds
		Server.Library.StopAllAnims(Character)

		local Move = Library.PlayAnimation(Character, Animation)
		-- Move:Play()
		local animlength = Move.Length

		Server.Library.TimedState(Character.Actions, script.Name, Move.Length)
		Server.Library.TimedState(Character.Speeds, "AlcSpeed6", Move.Length)
		Server.Library.TimedState(Character.Speeds, "Jump-50", Move.Length) -- Prevent jumping during move

		local hittimes = {}
		for i, fraction in Skills[Weapon][script.Name].HitTime do
			hittimes[i] = fraction * animlength
		end

		---- print(tostring(hittimes[1]))

		Server.Visuals.Ranged(Character.HumanoidRootPart.Position, 300, {
			Module = "Base",
			Function = "ShellPiercer",
			Arguments = { Character, "Start", hittimes[1] },
		})

		---- print("Sending shake to client for player:", Player.Name)


		task.delay(hittimes[1], function()
			Server.Visuals.Ranged(Character.HumanoidRootPart.Position, 300, {
				Module = "Base",
				Function = "ShellPiercer",
				Arguments = { Character, "Hit" },
			})

			-- Regular hitbox for enemies AND walls
			local Hitbox = Server.Modules.Hitbox
			local Entity = Server.Modules["Entities"].Get(Character)

			local HitTargets = Hitbox.SpatialQuery(
				Character,
				Vector3.new(8, 12, 20), -- Increased hitbox size for better hit detection
				Entity:GetCFrame() * CFrame.new(0, 0, -10), -- In front of player
				false -- Don't visualize
			)

			-- Track targets to prevent duplicate hits
			local targets = {}
			local soundeffects = {}
			local root = Character.HumanoidRootPart

			-- Damage enemies and destroy Construct walls
			for _, Target in pairs(HitTargets) do
				-- Hit enemies
				if Target ~= Character and Target:IsA("Model") and not table.find(targets, Target) then
					table.insert(targets, Target)
					Server.Modules.Damage.Tag(Character, Target, Skills[Weapon][script.Name]["DamageTable"])
				end

				-- Destroy Construct walls (same as Deconstruct)
				if Target:GetAttribute("Id") then
					if not soundeffects[Target] then
						soundeffects[Target] = {
							wallhit = Replicated.Assets.SFX.Hits.RAHit:Clone(),
						}
						soundeffects[Target].wallhit.Parent = root
						soundeffects[Target].wallhit.Volume = 1
						soundeffects[Target].wallhit.TimePosition = 0.35
						soundeffects[Target].wallhit:Play()
						Debris:AddItem(soundeffects[Target].wallhit, soundeffects[Target].wallhit.TimeLength)
					end

					Server.Visuals.FireClient(Player, {
						Module = "Base",
						Function = "Shake",
						Arguments = {
							"Once",
							{ 6, 11, 0, 0.7, Vector3.new(1.1, 2, 1.1), Vector3.new(0.34, 0.25, 0.34) },
						},
					})

					-- Voxelize the wall permanently (negative time = no reset)
					local parts = VoxBreaker:VoxelizePart(Target, 20, -1)
					local playerForward = root.CFrame.LookVector
					playerForward = Vector3.new(playerForward.X, playerForward.Y, playerForward.Z).Unit

					-- Fling the destroyed parts forward
					for _, v in pairs(parts) do
						if v:IsA("BasePart") then
							-- Add trail to the debris part
							local attachment0 = Instance.new("Attachment")
							attachment0.Name = "TrailAttachment0"
							attachment0.Position = Vector3.new(0, v.Size.Y/2, 0)
							attachment0.Parent = v

							local attachment1 = Instance.new("Attachment")
							attachment1.Name = "TrailAttachment1"
							attachment1.Position = Vector3.new(0, -v.Size.Y/2, 0)
							attachment1.Parent = v

							local trail = Instance.new("Trail")
							trail.Attachment0 = attachment0
							trail.Attachment1 = attachment1

							-- White trail color
							trail.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
							trail.Transparency = NumberSequence.new({
								NumberSequenceKeypoint.new(0, 0.4),
								NumberSequenceKeypoint.new(0.7, 0.7),
								NumberSequenceKeypoint.new(1, 1)
							})
							trail.Lifetime = 0.8
							trail.MinLength = 0

							-- Much smaller trail
							trail.WidthScale = NumberSequence.new({
								NumberSequenceKeypoint.new(0, 0.2),
								NumberSequenceKeypoint.new(0.5, 0.1),
								NumberSequenceKeypoint.new(1, 0.05)
							})

							trail.FaceCamera = true
							trail.LightEmission = 0.2
							trail.LightInfluence = 0.8
							trail.Parent = v

							-- Create a connection to update the hitbox as the part moves
							local hitConnection
							hitConnection = RunService.PostSimulation:Connect(function()
								local TargetsFound = Hitbox.SpatialQuery(
									Character,
									v.Size,
									v.CFrame,
									false
								)

								for _, target in TargetsFound do
									if target ~= Character and not table.find(targets, target) and target:IsA("Model") then
										table.insert(targets, target)
										Server.Modules.Damage.Tag(Character, target, {
											Damage = 5,
											PostureDamage = 8,
											Stun = 0.3,
											LightKnockback = true,
											M2 = false,
											FX = Replicated.Assets.VFX.Blood.Attachment,
										})
									end
								end
							end)

							v.CollisionGroup = "Rock"
							v.Anchored = false
							v.CanCollide = true

							local direction = (v.Position - root.Position).Unit
							local randomSpread = Vector3.new(
								(math.random() - 0.5) * 0.5,
								math.random() * 0.5,
								(math.random() - 0.5) * 0.5
							)

							local combinedDirection = (playerForward + randomSpread).Unit
							local velocityVector = combinedDirection * 120

							v.AssemblyLinearVelocity = velocityVector

							local debrisVelocity = Instance.new("BodyVelocity")
							debrisVelocity.Velocity = velocityVector
							debrisVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
							debrisVelocity.Parent = v

							v.Destroying:Connect(function()
								hitConnection:Disconnect()
							end)

							Debris:AddItem(debrisVelocity, 0.5)
							Debris:AddItem(v, 8 + math.random() * 4)
						end
					end
				end
			end
		end)
	end
end
