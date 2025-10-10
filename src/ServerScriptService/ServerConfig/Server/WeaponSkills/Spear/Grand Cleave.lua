local ServerStorage = game:GetService("ServerStorage")
local Replicated = game:GetService("ReplicatedStorage")
local Library = require(Replicated.Modules.Library)
local Skills = require(ServerStorage.Stats._Skills)
local Global = require(Replicated.Modules.Shared.Global)

-- Import the hold system
local SkillFactory = require(Replicated.Modules.Utils.SkillFactory)

-- Create the skill with hold system
local GrandCleave = SkillFactory.CreateWeaponSkill({
	name = "Grand Cleave",
	animation = Replicated.Assets.Animations.Skills.Weapons.Spear["Grand Cleave"],
	hasBodyMovers = false, -- No body movers, can be held
	damage = 50,
	cooldown = 6,

	execute = function(self, Player, Character, holdDuration)
		local Server = require(script.Parent.Parent.Parent)

		print(`[Grand Cleave] Executed after {holdDuration}s hold`)

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
		Weapon = Character:GetAttribute("Weapon") or "Spear"
	else
		Weapon = Global.GetData(Player).Weapon
	end

	-- WEAPON CHECK: This skill requires Spear weapon
	if Weapon ~= "Spear" then
		return -- Character doesn't have the correct weapon for this skill
	end

	local PlayerObject = Server.Modules["Players"].Get(Player)
	local Animation = Replicated.Assets.Animations.Skills.Weapons[Weapon][script.Name]

	-- Check for stuns (Actions check removed because hold system just cleared it)
	if Server.Library.StateCount(Character.Stuns) then
		return
	end

	-- For NPCs, skip the PlayerObject.Keys check
	local canUseSkill = isNPC or (PlayerObject and PlayerObject.Keys)

	if canUseSkill and not Server.Library.CheckCooldown(Character, script.Name) then
		-- Cooldown is handled by WeaponSkillHold system
		-- Server.Library.SetCooldown(Character, script.Name, 6)
		Server.Library.StopAllAnims(Character)

		local Move = Library.PlayAnimation(Character, Animation)
		-- Move:Play()
		local animlength = Move.Length

		Server.Library.TimedState(Character.Actions, script.Name, Move.Length)
		Server.Library.TimedState(Character.Speeds, "AlcSpeed4", Move.Length)

		-- Calculate hold bonuses
		local damageMultiplier = 1.0
		local rangeMultiplier = 1.0

		if holdDuration > 0.5 then
			damageMultiplier = 1 + (holdDuration * 0.2) -- +20% per second
			rangeMultiplier = 1 + (holdDuration * 0.1) -- +10% per second
			print(`⚡ Grand Cleave charged! Damage: {damageMultiplier}x, Range: {rangeMultiplier}x`)
		end

		local hittimes = {}
		for i, fraction in Skills[Weapon][script.Name].HitTimes do
			hittimes[i] = fraction * animlength
		end

        task.delay(hittimes[1], function()
            Server.Visuals.Ranged(Character.HumanoidRootPart.Position, 300, {
				Module = "Weapons",
				Function = "GrandCleave",
				Arguments = { Character, "Slash1"},
			})

			-- Play Swing1 sound effect
			Library.PlaySound(Character.HumanoidRootPart, Replicated.Assets.SFX.Skills.GrandCleave.Swing1, true, 0.1)
			Library.PlaySound(Character.HumanoidRootPart, Replicated.Assets.SFX.Skills.GrandCleave.Woosh1, true, 0.1)

			-- Add hitbox for Slash1
			local Hitbox = Server.Modules.Hitbox
			local Entity = Server.Modules["Entities"].Get(Character)

			if Entity then
				-- Apply range multiplier to hitbox
				local baseSize = Vector3.new(10, 10, 12)
				local hitboxSize = baseSize * rangeMultiplier

				local HitTargets = Hitbox.SpatialQuery(
					Character,
					hitboxSize,
					Entity:GetCFrame() * CFrame.new(0, 0, -5), -- In front of player
					false -- Don't visualize
				)

				local hitSomething = false
				for _, Target in pairs(HitTargets) do
					if Target ~= Character and Target:IsA("Model") then
						-- Apply damage multiplier
						local damageTable = table.clone(Skills[Weapon][script.Name]["Slash1"])
						damageTable.Damage = (damageTable.Damage or 0) * damageMultiplier

						Server.Modules.Damage.Tag(Character, Target, damageTable)
						print("Grand Cleave Slash1 hit:", Target.Name, "Damage:", damageTable.Damage)
						hitSomething = true
					end
				end

				-- Play Hit1 sound if we hit something
				if hitSomething then
					Library.PlaySound(Character.HumanoidRootPart, Replicated.Assets.SFX.Skills.GrandCleave.Hit1, true, 0.1)
				end
			end
        end)
        task.delay(hittimes[2], function()
            Server.Visuals.Ranged(Character.HumanoidRootPart.Position, 300, {
				Module = "Weapons",
				Function = "GrandCleave",
				Arguments = { Character, "Drag", hittimes[3] - hittimes[2]},
			})
        end)
        task.delay(hittimes[4], function()
            Server.Visuals.Ranged(Character.HumanoidRootPart.Position, 300, {
				Module = "Weapons",
				Function = "GrandCleave",
				Arguments = { Character, "Drag", hittimes[6] - hittimes[4]},
			})
        end)
        task.delay(hittimes[5], function()
            Server.Visuals.Ranged(Character.HumanoidRootPart.Position, 300, {
				Module = "Weapons",
				Function = "GrandCleave",
				Arguments = { Character, "Slash2"},
			})

			-- Play Swing2 sound effect
			Library.PlaySound(Character.HumanoidRootPart, Replicated.Assets.SFX.Skills.GrandCleave.Swing2, true, 0.1)
			Library.PlaySound(Character.HumanoidRootPart, Replicated.Assets.SFX.Skills.GrandCleave.Woosh2, true, 0.1)

			-- Add hitbox for Slash2
			local Hitbox = Server.Modules.Hitbox
			local Entity = Server.Modules["Entities"].Get(Character)

			if Entity then
				-- Apply range multiplier to hitbox
				local baseSize = Vector3.new(10, 10, 12)
				local hitboxSize = baseSize * rangeMultiplier

				local HitTargets = Hitbox.SpatialQuery(
					Character,
					hitboxSize,
					Entity:GetCFrame() * CFrame.new(0, 0, -5), -- In front of player
					false -- Don't visualize
				)

				local hitSomething = false
				for _, Target in pairs(HitTargets) do
					if Target ~= Character and Target:IsA("Model") then
						-- Apply damage multiplier
						local damageTable = table.clone(Skills[Weapon][script.Name]["Slash2"])
						damageTable.Damage = (damageTable.Damage or 0) * damageMultiplier

						Server.Modules.Damage.Tag(Character, Target, damageTable)
						print("Grand Cleave Slash2 hit:", Target.Name, "Damage:", damageTable.Damage)
						hitSomething = true
					end
				end

				-- Play Hit2 sound if we hit something
				if hitSomething then
					Library.PlaySound(Character.HumanoidRootPart, Replicated.Assets.SFX.Skills.GrandCleave.Hit2, true, 0.1)
				end
			end
        end)
        task.delay(hittimes[7], function()
            Server.Visuals.Ranged(Character.HumanoidRootPart.Position, 300, {
				Module = "Weapons",
				Function = "GrandCleave",
				Arguments = { Character, "Slash3"},
			})

			-- Play Swing3 sound effect
			Library.PlaySound(Character.HumanoidRootPart, Replicated.Assets.SFX.Skills.GrandCleave.Swing3, true, 0.1)
			Library.PlaySound(Character.HumanoidRootPart, Replicated.Assets.SFX.Skills.GrandCleave.Woosh3, true, 0.1)

			-- Add hitbox for Slash3 (final slash with block break)
			local Hitbox = Server.Modules.Hitbox
			local Entity = Server.Modules["Entities"].Get(Character)

			if Entity then
				-- Apply range multiplier to hitbox
				local baseSize = Vector3.new(10, 10, 12)
				local hitboxSize = baseSize * rangeMultiplier

				local HitTargets = Hitbox.SpatialQuery(
					Character,
					hitboxSize,
					Entity:GetCFrame() * CFrame.new(0, 0, -5), -- In front of player
					false -- Don't visualize
				)

				local hitSomething = false
				for _, Target in pairs(HitTargets) do
					if Target ~= Character and Target:IsA("Model") then
						-- Apply damage multiplier
						local damageTable = table.clone(Skills[Weapon][script.Name]["Slash3"])
						damageTable.Damage = (damageTable.Damage or 0) * damageMultiplier

						Server.Modules.Damage.Tag(Character, Target, damageTable)
						print("Grand Cleave Slash3 hit:", Target.Name, "Damage:", damageTable.Damage)
						hitSomething = true
					end
				end

				-- Play Hit3 sound if we hit something
				if hitSomething then
					Library.PlaySound(Character.HumanoidRootPart, Replicated.Assets.SFX.Skills.GrandCleave.Hit3, true, 0.1)
				end
			end
        end)
        task.delay(hittimes[8], function()
            Server.Visuals.Ranged(Character.HumanoidRootPart.Position, 300, {
				Module = "Weapons",
				Function = "GrandCleave",
				Arguments = { Character, "Drag", hittimes[9] - hittimes[8]},
			})
        end)
		end
	end
})

return GrandCleave
