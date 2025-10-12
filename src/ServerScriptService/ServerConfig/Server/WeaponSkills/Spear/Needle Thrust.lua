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
		--print(`[Needle Thrust Server] ========== MOVE START ==========`)
		--print(`[Needle Thrust Server] Starting Position: {startPos}`)
		--print(`[Needle Thrust Server] Starting Velocity: {startVel}`)

		-- Stop ALL animations first (including dash) to prevent animation root motion from interfering
		--print(`[Needle Thrust Server] Stopping all animations for {Player.Name}`)
		Server.Library.StopAllAnims(Character)

		-- Remove any existing body movers FIRST and wait for it to complete
		--print(`[Needle Thrust Server] Sending RemoveBvel to {Player.Name}`)
		Server.Packets.Bvel.sendTo({Character = Character, Name = "RemoveBvel"},Player)
		--print(`[Needle Thrust Server] Waiting 0.1s for cleanup and animation stop...`)
		task.wait(0.1) -- Increased delay to ensure animations stop and RemoveBvel completes
		--print(`[Needle Thrust Server] Cleanup wait complete, continuing...`)

		Server.Library.SetCooldown(Character, script.Name, 5) -- Increased from 2.5 to 5 seconds

		local Move = Library.PlayAnimation(Character, Animation)
		-- Move:Play()
		local animlength = Move.Length

		Server.Library.TimedState(Character.Actions, script.Name, Move.Length)
		Server.Library.TimedState(Character.Speeds, "AlcSpeed-0", Move.Length)

		-- Initialize hyperarmor tracking for this move
		Character:SetAttribute("HyperarmorDamage", 0)
		Character:SetAttribute("HyperarmorMove", script.Name)

		-- Start hyperarmor visual indicator (white highlight)
		Server.Visuals.Ranged(Character.HumanoidRootPart.Position, 300, {
			Module = "Misc",
			Function = "StartHyperarmor",
			Arguments = { Character }
		})

		-- Clean up hyperarmor data and visual when move ends
		task.delay(Move.Length, function()
			if Character and Character.Parent then
				Character:SetAttribute("HyperarmorDamage", nil)
				Character:SetAttribute("HyperarmorMove", nil)

				-- Remove hyperarmor visual
				Server.Visuals.Ranged(Character.HumanoidRootPart.Position, 300, {
					Module = "Misc",
					Function = "RemoveHyperarmor",
					Arguments = { Character }
				})

				-- Track ending position
				local endPos = Character.HumanoidRootPart.Position
				local endVel = Character.HumanoidRootPart.AssemblyLinearVelocity
				local distance = (endPos - startPos).Magnitude
				--print(`[Needle Thrust Server] ========== MOVE END ==========`)
				--print(`[Needle Thrust Server] Ending Position: {endPos}`)
				--print(`[Needle Thrust Server] Ending Velocity: {endVel}`)
				--print(`[Needle Thrust Server] Total Distance Traveled: {distance} studs`)
				--print(`[Needle Thrust Server] ====================================`)
			end
		end)

		local hittimes = {}
		for i, fraction in Skills[Weapon][script.Name].HitTime do
			hittimes[i] = fraction * animlength
		end

        --print(tostring(hittimes[1]))

        Server.Modules.Combat.Trail(Character, true)

		-- Play NT1 sound effect (start of thrust)
		Library.PlaySound(Character.HumanoidRootPart, Replicated.Assets.SFX.Skills.NeedleThrust.NT1, true, 0.1)

		-- Send to player (they have network ownership)
		Server.Packets.Bvel.sendTo({ Character = Character, duration = hittimes[1], Name = "NTBvel", Targ = Character }, Player)

        Server.Visuals.Ranged(Character.HumanoidRootPart.Position, 300, {
						Module = "Base",
						Function = "NeedleThrust",
						Arguments = {Character, "Start"}
					})

        task.delay(hittimes[1], function()
             Server.Visuals.Ranged(Character.HumanoidRootPart.Position, 300, {
						Module = "Base",
						Function = "NeedleThrust",
						Arguments = {Character, "Hit"}
					})

			-- Play NT2 sound effect (thrust impact)
			Library.PlaySound(Character.HumanoidRootPart, Replicated.Assets.SFX.Skills.NeedleThrust.NT2, true, 0.1)

                    Server.Modules.Combat.Trail(Character, false)

                    -- Add hitbox for Needle Thrust - long lengthwise hitbox
                    local Hitbox = Server.Modules.Hitbox
                    local Entity = Server.Modules["Entities"].Get(Character)

                    if Entity then
                        local HitTargets = Hitbox.SpatialQuery(
                            Character,
                            Vector3.new(5, 7, 18), -- Increased hitbox size from (4,6,16) to (5,7,18)
                            Entity:GetCFrame() * CFrame.new(0, 0, -8), -- In front of player
                            false -- Don't visualize
                        )

                        local hitSomething = false
                        for _, Target in pairs(HitTargets) do
                            if Target ~= Character and Target:IsA("Model") then
                                Server.Modules.Damage.Tag(Character, Target, Skills[Weapon][script.Name]["DamageTable"])
                                --print("Needle Thrust hit:", Target.Name)
                                hitSomething = true
                            end
                        end

                        -- Play NT3 sound if we hit an opponent
                        if hitSomething then
                            Library.PlaySound(Character.HumanoidRootPart, Replicated.Assets.SFX.Skills.NeedleThrust.NT3, true, 0.1)
                        end
                    end
        end)
	end
	-- --print("activating skill; " .. script.Name)
end
