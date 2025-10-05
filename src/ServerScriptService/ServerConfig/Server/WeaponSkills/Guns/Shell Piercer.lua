local ServerStorage = game:GetService("ServerStorage")
local Replicated = game:GetService("ReplicatedStorage")
local Library = require(Replicated.Modules.Library)
local Skills = require(ServerStorage.Stats._Skills)
local VoxBreaker = require(Replicated.Modules.Voxel)
local Debris = game:GetService("Debris")

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

		local hittimes = {}
		for i, fraction in Skills[Weapon][script.Name].HitTime do
			hittimes[i] = fraction * animlength
		end

		print(tostring(hittimes[1]))

		Server.Visuals.Ranged(Character.HumanoidRootPart.Position, 300, {
			Module = "Base",
			Function = "ShellPiercer",
			Arguments = { Character, "Start", hittimes[1] },
		})

		print("Sending shake to client for player:", Player.Name)


		task.delay(hittimes[1], function()
			Server.Visuals.Ranged(Character.HumanoidRootPart.Position, 300, {
				Module = "Base",
				Function = "ShellPiercer",
				Arguments = { Character, "Hit" },
			})

			-- Regular hitbox for enemies
			local Hitbox = Server.Modules.Hitbox
			local Entity = Server.Modules["Entities"].Get(Character)

			local HitTargets = Hitbox.SpatialQuery(
				Character,
				Vector3.new(4, 8, 14), -- Same size as wall hitbox
				Entity:GetCFrame() * CFrame.new(0, 0, -10), -- In front of player
				false -- Don't visualize
			)

			-- Damage enemies
			for _, Target in pairs(HitTargets) do
				if Target ~= Character and Target:IsA("Model") then
					Server.Modules.Damage.Tag(Character, Target, Skills[Weapon][script.Name]["DamageTable"])
					print("Shell Piercer hit enemy:", Target.Name)
				end
			end

			-- Create hitbox for wall detection and destruction
			local hitboxSize = Vector3.new(4, 5, 14) -- Wide and deep hitbox for shell piercing
			local hitboxCFrame = Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, -10) -- In front of player

			print("Shell Piercer: Creating wall destruction hitbox at position:", hitboxCFrame.Position)
			print("Shell Piercer: Hitbox size:", hitboxSize)
			print("Shell Piercer: Checking for transmutable parts in workspace.Transmutables")

			-- Check if workspace.Transmutables exists
			if not workspace:FindFirstChild("Transmutables") then
				print("Shell Piercer: WARNING - workspace.Transmutables folder not found!")
				return
			end

			-- First, let's manually check what parts are in the area
			local testPart = Instance.new("Part")
			testPart.Size = hitboxSize
			testPart.CFrame = hitboxCFrame
			testPart.Anchored = true
			testPart.CanCollide = false
			testPart.Transparency = 1
			testPart.Color = Color3.fromRGB(255, 0, 0)
			testPart.Parent = workspace

			local partsInArea = workspace:GetPartsInPart(testPart)
			print("Shell Piercer: Found", #partsInArea, "total parts in hitbox area")

			for i, part in pairs(partsInArea) do
				print("Shell Piercer: Part", i, ":", part.Name, "Parent:", part.Parent and part.Parent.Name or "nil")
				print("  - Has Destroyable attribute:", part:GetAttribute("Destroyable"))
				print("  - Is in Transmutables:", workspace.Transmutables and part:IsDescendantOf(workspace.Transmutables) or false)
				print("  - Part size:", part.Size)
				print("  - Part material:", part.Material)
			end

			-- If no parts found, let's try a different approach - set Destroyable on nearby parts
			if #partsInArea == 0 then
				print("Shell Piercer: No parts found in area, trying larger search...")
				-- testPart.Size = Vector3.new(20, 20, 40) -- Much larger
				-- partsInArea = workspace:GetPartsInPart(testPart)
				-- print("Shell Piercer: Found", #partsInArea, "parts in larger area")
			else
				-- Try to make the parts destroyable if they aren't already
				for _, part in pairs(partsInArea) do
					if not part:GetAttribute("Destroyable") then
						print("Shell Piercer: Setting Destroyable=true on part:", part.Name)
						part:SetAttribute("Destroyable", true)
					end
				end
			end

			-- Clean up test part
			Debris:AddItem(testPart, 5) -- Keep it longer for debugging

			-- Create overlap params to detect walls (parts with Destroyable attribute)
			local overlapParams = OverlapParams.new()
			overlapParams.FilterType = Enum.RaycastFilterType.Include

			-- Only include workspace.Transmutables - this ensures we ONLY hit transmutable walls
			-- and never hit characters, accessories, or any other objects
			local filterList = {}
			if workspace:FindFirstChild("Transmutables") then
				table.insert(filterList, workspace.Transmutables)
			end

			overlapParams.FilterDescendantsInstances = filterList

			print("Shell Piercer: Calling VoxBreaker:CreateHitbox...")

			-- Use VoxBreaker to create hitbox and destroy walls
			local destroyedParts = VoxBreaker:CreateHitbox(
				hitboxSize,
				hitboxCFrame,
				Enum.PartType.Block,
				3, -- Minimum voxel size
				15, -- Time to reset (15 seconds)
				overlapParams
			)

			print("Shell Piercer: VoxBreaker returned", #destroyedParts, "destroyed parts")

			-- Fling the destroyed parts forward
			if #destroyedParts > 0 then
				local forwardDirection = Character.HumanoidRootPart.CFrame.LookVector
				local RunService = game:GetService("RunService")

				for _, part in pairs(destroyedParts) do
					if part:IsA("BasePart") then
						-- Make part moveable
						part.Anchored = false
						part.CanCollide = true

						-- Add trail to the part
						local attachment0 = Instance.new("Attachment")
						attachment0.Name = "TrailAttachment0"
						attachment0.Position = Vector3.new(0, part.Size.Y/2, 0)
						attachment0.Parent = part

						local attachment1 = Instance.new("Attachment")
						attachment1.Name = "TrailAttachment1"
						attachment1.Position = Vector3.new(0, -part.Size.Y/2, 0)
						attachment1.Parent = part

						local trail = Instance.new("Trail")
						trail.Attachment0 = attachment0
						trail.Attachment1 = attachment1

						-- Match the part color exactly
						trail.Color = ColorSequence.new(part.Color)
						trail.Transparency = NumberSequence.new({
							NumberSequenceKeypoint.new(0, 0.3),   -- More transparent at start
							NumberSequenceKeypoint.new(0.7, 0.6), -- Fade more
							NumberSequenceKeypoint.new(1, 1)      -- Fully transparent at end
						})
						trail.Lifetime = 2.0  -- Long trail
						trail.MinLength = 0   -- Show trail even for small movements

						-- Make trail wider and more visible
						trail.WidthScale = NumberSequence.new({
							NumberSequenceKeypoint.new(0, 1.5),   -- Wider at start
							NumberSequenceKeypoint.new(0.5, 1.2), -- Stay wide in middle
							NumberSequenceKeypoint.new(1, 0.4)    -- Taper at end
						})

						trail.FaceCamera = true
						trail.LightEmission = 0  -- No glow - use actual part color
						trail.LightInfluence = 1 -- Fully affected by lighting to match part
						trail.Parent = part

						-- Create velocity to fling parts forward
						local bodyVelocity = Instance.new("BodyVelocity")
						bodyVelocity.MaxForce = Vector3.new(4000, 4000, 4000)

						-- Calculate fling direction with some randomness
						local flingDirection = forwardDirection + Vector3.new(
							(math.random() - 0.5) * 0.5, -- Random X spread
							math.random() * 0.3, -- Slight upward bias
							(math.random() - 0.5) * 0.3  -- Random Z spread
						)

						local flingSpeed = 50 + math.random() * 30 -- 50-80 speed
						bodyVelocity.Velocity = flingDirection.Unit * flingSpeed
						bodyVelocity.Parent = part

						-- Remove velocity after a short time
						Debris:AddItem(bodyVelocity, 0.8)

						-- Add some rotation for realism
						local bodyAngularVelocity = Instance.new("BodyAngularVelocity")
						bodyAngularVelocity.MaxTorque = Vector3.new(4000, 4000, 4000)
						bodyAngularVelocity.AngularVelocity = Vector3.new(
							(math.random() - 0.5) * 20,
							(math.random() - 0.5) * 20,
							(math.random() - 0.5) * 20
						)
						bodyAngularVelocity.Parent = part
						Debris:AddItem(bodyAngularVelocity, 0.8)

						-- Add hitbox to the flying part
						local hitTargets = {} -- Track what we've already hit
						local hitConnection
						hitConnection = RunService.Heartbeat:Connect(function()
							if not part or not part.Parent then
								hitConnection:Disconnect()
								return
							end

							-- Check for nearby characters
							local partsInRadius = workspace:GetPartBoundsInRadius(part.Position, part.Size.Magnitude)

							for _, hitPart in pairs(partsInRadius) do
								local hitCharacter = hitPart.Parent
								if hitCharacter and hitCharacter:IsA("Model") and hitCharacter:FindFirstChild("Humanoid") then
									-- Don't hit the caster or already-hit targets
									if hitCharacter ~= Character and not hitTargets[hitCharacter] then
										hitTargets[hitCharacter] = true

										-- Apply damage
										local damageTable = {
											Damage = 5, -- Reduced damage for debris
											PostureDamage = 8,
											Stun = 0.3,
											LightKnockback = true,
											M2 = false,
											FX = Replicated.Assets.VFX.Blood.Attachment,
										}

										Server.Modules.Damage.Tag(Character, hitCharacter, damageTable)
										print("Shell Piercer debris hit:", hitCharacter.Name)
									end
								end
							end
						end)

						-- Clean up hitbox connection after 2 seconds
						task.delay(2, function()
							if hitConnection then
								hitConnection:Disconnect()
							end
						end)

						-- print("Shell Piercer: Flung wall part with velocity:", bodyVelocity.Velocity)
					end
				end

				-- print("Shell Piercer: Destroyed", #destroyedParts, "wall parts")
			end
		end)
	end
end
