local ServerStorage = game:GetService("ServerStorage")
local Replicated = game:GetService("ReplicatedStorage")
local Library = require(Replicated.Modules.Library)
local Skills = require(ServerStorage.Stats._Skills)
local Ragdoller = require(Replicated.Modules.Utils.Ragdoll)
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
		StateManager.TimedState(Character, "Speeds", "AlcSpeed4", Move.Length)
		StateManager.TimedState(Character, "Speeds", "Jump-50", Move.Length) -- Prevent jumping during move

		local hittimes = {}
		for i, fraction in Skills[Weapon][script.Name].HitTime do
			hittimes[i] = fraction * animlength
		end

		-- Store sounds for cleanup
		local swingSound = Library.PlaySound(Character.HumanoidRootPart, Replicated.Assets.SFX.Skills.AxeKick.Swing, true)
		local rocksSound
		local impactSound

		task.delay(hittimes[1], function()
			-- CHECK IF SKILL WAS CANCELLED
			if not StateManager.StateCheck(Character, "Actions", script.Name) then
				if swingSound and swingSound.Parent then
					swingSound:Stop()
					swingSound:Destroy()
				end
				return
			end

			Server.Visuals.Ranged(Character.HumanoidRootPart.Position, 300, {
				Module = "Weapons",
				Function = "AxeKick",
				Arguments = { Character, "Swing" },
			})
		end)

		task.delay(hittimes[2], function()
			-- CHECK IF SKILL WAS CANCELLED
			if not StateManager.StateCheck(Character, "Actions", script.Name) then
				if swingSound and swingSound.Parent then
					swingSound:Stop()
					swingSound:Destroy()
				end
				return
			end

			-- Play impact sounds FIRST (outside hitbox check so they always play)
			rocksSound = Library.PlaySound(Character.HumanoidRootPart, Replicated.Assets.SFX.Skills.AxeKick.Rocks, true)
			task.delay(.1, function()
				-- CHECK IF SKILL WAS CANCELLED
				if not StateManager.StateCheck(Character, "Actions", script.Name) then
					if rocksSound and rocksSound.Parent then
						rocksSound:Stop()
						rocksSound:Destroy()
					end
					return
				end

				impactSound = Library.PlaySound(Character.HumanoidRootPart, Replicated.Assets.SFX.Skills.AxeKick.Impact, true)
			end)

			-- Add short hitbox for Axe Kick
			local Hitbox = Server.Modules.Hitbox
			local Entity = Server.Modules["Entities"].Get(Character)

			if Entity then
				local HitTargets = Hitbox.SpatialQuery(
					Character,
					Vector3.new(6, 8, 6), -- Short, focused hitbox
					Entity:GetCFrame() * CFrame.new(0, 0, -3), -- Close in front of player
					false -- Don't visualize
				)

				for _, Target in pairs(HitTargets) do
					if Target ~= Character and Target:IsA("Model") then
						-- Check if target is blocking or parrying before applying damage
						local isBlocking = StateManager.StateCheck(Target, "Frames", "Blocking")
						local isParrying = StateManager.StateCheck(Target, "Frames", "Parry")

						-- Only ragdoll on direct hits, not when blocked or parried
						if not isBlocking and not isParrying then
							Server.Modules.Damage.Tag(Character, Target, Skills[Weapon][script.Name]["DamageTable"])
							---- print("Axe Kick hit:", Target.Name)

							-- Apply upward velocity to the target
							local targetRoot = Target:FindFirstChild("HumanoidRootPart")
							if targetRoot then
								-- Apply upward knockback (reduced from 40 to 25)
								local upwardPower = 25
								Server.Modules.ServerBvel.UpwardKnockback(Target, upwardPower)
							end

							-- Ragdoll the target for 3 seconds (instant ragdoll)
							task.spawn(function()
								Ragdoller.Ragdoll(Target, 1.5)
							end)
						else
							-- Still apply damage but without ragdoll
							Server.Modules.Damage.Tag(Character, Target, Skills[Weapon][script.Name]["DamageTable"])
						end
					end
				end
			end
		end)
	end
end
