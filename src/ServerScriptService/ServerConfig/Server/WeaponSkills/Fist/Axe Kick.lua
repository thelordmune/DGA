local ServerStorage = game:GetService("ServerStorage")
local Replicated = game:GetService("ReplicatedStorage")
local Library = require(Replicated.Modules.Library)
local Skills = require(ServerStorage.Stats._Skills)
local Ragdoller = require(Replicated.Modules.Utils.Ragdoll)

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
		Server.Library.TimedState(Character.Speeds, "AlcSpeed4", Move.Length)

		local hittimes = {}
		for i, fraction in Skills[Weapon][script.Name].HitTime do
			hittimes[i] = fraction * animlength
		end

		-- print(tostring(hittimes[1]))
			Library.PlaySound(Character.HumanoidRootPart, Replicated.Assets.SFX.Skills.AxeKick.Swing, true)
		task.delay(hittimes[1], function()


			Server.Visuals.Ranged(Character.HumanoidRootPart.Position, 300, {
				Module = "Base",
				Function = "AxeKick",
				Arguments = { Character, "Swing" },
			})
		end)

		task.delay(hittimes[2], function()
			-- Play impact sounds FIRST (outside hitbox check so they always play)
			Library.PlaySound(Character.HumanoidRootPart, Replicated.Assets.SFX.Skills.AxeKick.Rocks, true)
			task.delay(.1, function()
				Library.PlaySound(Character.HumanoidRootPart, Replicated.Assets.SFX.Skills.AxeKick.Impact, true)
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
						Server.Modules.Damage.Tag(Character, Target, Skills[Weapon][script.Name]["DamageTable"])
						-- print("Axe Kick hit:", Target.Name)

						-- Ragdoll the target for 1 second
						Ragdoller.Ragdoll(Target, 3)
					end
				end
			end
		end)
	end
end
