local ServerStorage = game:GetService("ServerStorage")
local Replicated = game:GetService("ReplicatedStorage")
local Library = require(Replicated.Modules.Library)
local Skills = require(ServerStorage.Stats._Skills)
local VoxBreaker = require(Replicated.Modules.Voxel)
local Debris = game:GetService("Debris")

local Global = require(Replicated.Modules.Shared.Global)
return function(Player, Data, Server)
	local Character = Player.Character

	if not Character or not Character:GetAttribute("Equipped") then
		return
	end
	local Weapon = Global.GetData(Player).Weapon
	local PlayerObject = Server.Modules["Players"].Get(Player)
	local Animation = Replicated.Assets.Animations.Skills.Weapons[Weapon][script.Name]

	if Server.Library.StateCount(Character.Actions) or Server.Library.StateCount(Character.Stuns) then
		return
	end

	if PlayerObject and PlayerObject.Keys and not Server.Library.CheckCooldown(Character, script.Name) then
		Server.Library.SetCooldown(Character, script.Name, 2.5)
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
			overlapParams.FilterType = Enum.RaycastFilterType.Exclude
			overlapParams.FilterDescendantsInstances = {Character, workspace.World.Live, workspace.World.Visuals, workspace.World.Map} -- Only check map parts

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

				for _, part in pairs(destroyedParts) do
					if part:IsA("BasePart") then
						-- Make part moveable
						part.Anchored = false
						part.CanCollide = true

						-- Create velocity to fling parts forward
						local bodyVelocity = Instance.new("BodyVelocity")
						bodyVelocity.MaxForce = Vector3.new(4000, 4000, 4000)

						-- Calculate fling direction with some randomness
						local flingDirection = forwardDirection + Vector3.new(
							(math.random() - 0.5) * 0.5, -- Random X spread
							math.random() * 0.3, -- Slight upward bias
							(math.random() - 0.5) * 0.3  -- Random Z spread
						)

						bodyVelocity.Velocity = flingDirection.Unit * (50 + math.random() * 30) -- 50-80 speed
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

						-- print("Shell Piercer: Flung wall part with velocity:", bodyVelocity.Velocity)
					end
				end

				-- print("Shell Piercer: Destroyed", #destroyedParts, "wall parts")
			end
		end)
	end
end
