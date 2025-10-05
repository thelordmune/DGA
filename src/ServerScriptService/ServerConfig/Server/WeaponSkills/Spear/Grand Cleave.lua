local ServerStorage = game:GetService("ServerStorage")
local Replicated = game:GetService("ReplicatedStorage")
local Library = require(Replicated.Modules.Library)
local Skills = require(ServerStorage.Stats._Skills)

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
		Weapon = Character:GetAttribute("Weapon") or "Spear"
	else
		Weapon = Global.GetData(Player).Weapon
	end

	local PlayerObject = Server.Modules["Players"].Get(Player)
	local Animation = Replicated.Assets.Animations.Skills.Weapons[Weapon][script.Name]

	if Server.Library.StateCount(Character.Actions) or Server.Library.StateCount(Character.Stuns) then
		return
	end

	-- For NPCs, skip the PlayerObject.Keys check
	local canUseSkill = isNPC or (PlayerObject and PlayerObject.Keys)

	if canUseSkill and not Server.Library.CheckCooldown(Character, script.Name) then
		Server.Library.SetCooldown(Character, script.Name, 2.5)
		Server.Library.StopAllAnims(Character)

		local Move = Library.PlayAnimation(Character, Animation)
		-- Move:Play()
		local animlength = Move.Length

		Server.Library.TimedState(Character.Actions, script.Name, Move.Length)
		Server.Library.TimedState(Character.Speeds, "AlcSpeed4", Move.Length)

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

			-- Add hitbox for Slash1
			local Hitbox = Server.Modules.Hitbox
			local Entity = Server.Modules["Entities"].Get(Character)

			if Entity then
				local HitTargets = Hitbox.SpatialQuery(
					Character,
					Vector3.new(10, 10, 12), -- Increased hitbox size from (8,8,10) to (10,10,12)
					Entity:GetCFrame() * CFrame.new(0, 0, -5), -- In front of player
					false -- Don't visualize
				)

				for _, Target in pairs(HitTargets) do
					if Target ~= Character and Target:IsA("Model") then
						Server.Modules.Damage.Tag(Character, Target, Skills[Weapon][script.Name]["Slash1"])
						print("Grand Cleave Slash1 hit:", Target.Name)
					end
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

			-- Add hitbox for Slash2
			local Hitbox = Server.Modules.Hitbox
			local Entity = Server.Modules["Entities"].Get(Character)

			if Entity then
				local HitTargets = Hitbox.SpatialQuery(
					Character,
					Vector3.new(10, 10, 12), -- Increased hitbox size from (8,8,10) to (10,10,12)
					Entity:GetCFrame() * CFrame.new(0, 0, -5), -- In front of player
					false -- Don't visualize
				)

				for _, Target in pairs(HitTargets) do
					if Target ~= Character and Target:IsA("Model") then
						Server.Modules.Damage.Tag(Character, Target, Skills[Weapon][script.Name]["Slash2"])
						print("Grand Cleave Slash2 hit:", Target.Name)
					end
				end
			end
        end)
        task.delay(hittimes[7], function()
            Server.Visuals.Ranged(Character.HumanoidRootPart.Position, 300, {
				Module = "Weapons",
				Function = "GrandCleave",
				Arguments = { Character, "Slash3"},
			})

			-- Add hitbox for Slash3 (final slash with block break)
			local Hitbox = Server.Modules.Hitbox
			local Entity = Server.Modules["Entities"].Get(Character)

			if Entity then
				local HitTargets = Hitbox.SpatialQuery(
					Character,
					Vector3.new(10, 10, 12), -- Increased hitbox size from (8,8,10) to (10,10,12)
					Entity:GetCFrame() * CFrame.new(0, 0, -5), -- In front of player
					false -- Don't visualize
				)

				for _, Target in pairs(HitTargets) do
					if Target ~= Character and Target:IsA("Model") then
						Server.Modules.Damage.Tag(Character, Target, Skills[Weapon][script.Name]["Slash3"])
						print("Grand Cleave Slash3 hit:", Target.Name)
					end
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
