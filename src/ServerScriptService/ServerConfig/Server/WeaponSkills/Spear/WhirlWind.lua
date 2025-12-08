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

	-- WEAPON CHECK: This skill requires Spear weapon
	if Weapon ~= "Spear" then
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
		-- Track starting position
		local startPos = Character.HumanoidRootPart.Position
		local startVel = Character.HumanoidRootPart.AssemblyLinearVelocity
		---- print(`[Needle Thrust Server] ========== MOVE START ==========`)
		---- print(`[Needle Thrust Server] Starting Position: {startPos}`)
		---- print(`[Needle Thrust Server] Starting Velocity: {startVel}`)

		-- Stop ALL animations first (including dash) to prevent animation root motion from interfering
		---- print(`[Needle Thrust Server] Stopping all animations for {Player.Name}`)
		Server.Library.StopAllAnims(Character)

		-- Remove any existing body movers FIRST and wait for it to complete
		---- print(`[Needle Thrust Server] Sending RemoveBvel to {Player.Name}`)
		Server.Packets.Bvel.sendTo({Character = Character, Name = "RemoveBvel"},Player)
		---- print(`[Needle Thrust Server] Waiting 0.1s for cleanup and animation stop...`) -- Increased delay to ensure animations stop and RemoveBvel completes
		---- print(`[Needle Thrust Server] Cleanup wait complete, continuing...`)

		Server.Library.SetCooldown(Character, script.Name, 5) -- Increased from 2.5 to 5 seconds

		local Move = Library.PlayAnimation(Character, Animation)
		-- Move:Play()
		local animlength = Move.Length

		Server.Library.TimedState(Character.Actions, script.Name, Move.Length)
		Server.Library.TimedState(Character.Speeds, "AlcSpeed-0", Move.Length)

        local hittimes = {}
		for i, fraction in Skills[Weapon][script.Name].Hittimes do
			hittimes[i] = fraction * animlength
		end

        task.delay(hittimes[1], function()
            Server.Visuals.Ranged(Character.HumanoidRootPart.Position, 300, {
				Module = "Weapons",
				Function = "WhirlWind",
				Arguments = { Character, "Start"},
			})
        end)
        task.delay(hittimes[2], function()
            Server.Visuals.Ranged(Character.HumanoidRootPart.Position, 300, {
				Module = "Weapons",
				Function = "WhirlWind",
				Arguments = { Character, "Jump"},
			})
            Server.Packets.Bvel.sendTo({ Character = Character, duration = hittimes[3] - hittimes[2], Name = "NTBvel", Targ = Character }, Player)
        end)
        task.delay(hittimes[3], function()
            Server.Visuals.Ranged(Character.HumanoidRootPart.Position, 300, {
				Module = "Weapons",
				Function = "WhirlWind",
				Arguments = { Character, "TT"},
			})
        end)
        task.delay(hittimes[4], function()
            Server.Visuals.Ranged(Character.HumanoidRootPart.Position, 300, {
				Module = "Weapons",
				Function = "WhirlWind",
				Arguments = { Character, "SS"},
			})

			-- Hitbox on hittime4
			local Hitbox = Server.Modules.Hitbox
			local Entity = Server.Modules["Entities"].Get(Character)
			if Entity then
				local HitTargets = Hitbox.SpatialQuery(
					Character,
					Vector3.new(12, 8, 12), -- Spinning AOE hitbox
					Entity:GetCFrame() * CFrame.new(0, 0, 0),
					false
				)

				for _, Target in pairs(HitTargets) do
					Server.Modules.Damage.Tag(Character, Target, {
						Damage = 8,
						PostureDamage = 12,
						Stun = 0.4,
						BlockBreak = false,
						M1 = false,
						M2 = false,
						FX = Replicated.Assets.VFX.Blood.Attachment,
					})
				end
			end
        end)
        task.delay(hittimes[5], function()
            Server.Visuals.Ranged(Character.HumanoidRootPart.Position, 300, {
				Module = "Weapons",
				Function = "WhirlWind",
				Arguments = { Character, "TTR"},
			})
        end)
        task.delay(hittimes[6], function()
            Server.Visuals.Ranged(Character.HumanoidRootPart.Position, 300, {
				Module = "Weapons",
				Function = "WhirlWind",
				Arguments = { Character, "SS2"},
			})

			-- Hitbox on hittime6
			local Hitbox = Server.Modules.Hitbox
			local Entity = Server.Modules["Entities"].Get(Character)
			if Entity then
				local HitTargets = Hitbox.SpatialQuery(
					Character,
					Vector3.new(12, 8, 12), -- Spinning AOE hitbox
					Entity:GetCFrame() * CFrame.new(0, 0, 0),
					false
				)

				for _, Target in pairs(HitTargets) do
					Server.Modules.Damage.Tag(Character, Target, {
						Damage = 8,
						PostureDamage = 12,
						Stun = 0.4,
						BlockBreak = false,
						M1 = false,
						M2 = false,
						FX = Replicated.Assets.VFX.Blood.Attachment,
					})
				end
			end
        end)
        task.delay(hittimes[7], function()
            Server.Visuals.Ranged(Character.HumanoidRootPart.Position, 300, {
				Module = "Weapons",
				Function = "WhirlWind",
				Arguments = { Character, "End"},
			})

			-- Light screenshake on hittime7
			Server.Visuals.Ranged(Character.HumanoidRootPart.Position, 300, {
				Module = "Base",
				Function = "Shake",
				Arguments = { 0.3, 20, Character.HumanoidRootPart.Position },
			})

			-- Crater at impact position on hittime7
			local craterPosition = Character.HumanoidRootPart.Position + Vector3.new(0, -2.5, 0)
			Server.Visuals.Ranged(Character.HumanoidRootPart.Position, 300, {
				Module = "Base",
				Function = "WhirlWindCrater",
				Arguments = { craterPosition },
			})
        end)
    end
end