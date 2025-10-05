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
	local VictimAnimation = Replicated.Assets.Animations.Skills.Weapons[Weapon]["Victim"]

	if Server.Library.StateCount(Character.Actions) or Server.Library.StateCount(Character.Stuns) then
		return
	end

	-- For NPCs, skip the PlayerObject.Keys check
	local canUseSkill = isNPC or (PlayerObject and PlayerObject.Keys)

	if canUseSkill and not Server.Library.CheckCooldown(Character, script.Name) then
		-- Different cooldowns for NPCs vs Players
		local cooldown = isNPC and 14 or 7 -- NPCs: 14 seconds, Players: 7 seconds
		Server.Library.SetCooldown(Character, script.Name, cooldown)
		Server.Library.StopAllAnims(Character)

		local Move = Library.PlayAnimation(Character, Animation)
		-- Move:Play()
		local animlength = Move.Length
		local endlag = 0.5 -- Endlag after animation completes

		Server.Library.TimedState(Character.Actions, script.Name, Move.Length + endlag)
		Server.Library.TimedState(Character.Speeds, "AlcSpeed-0", Move.Length + endlag)
		Server.Library.TimedState(Character.Stuns, "NoRotate", Move.Length + endlag)

		-- Add invincibility to attacker during the entire move
		Server.Library.TimedState(Character.IFrames, "StrategistCombo", Move.Length)

		-- Prevent attacker from using other moves during combo (including endlag)
		Server.Library.TimedState(Character.Stuns, "StrategistComboLock", Move.Length + endlag)

		local hittimes = {}
		for i, fraction in Skills[Weapon][script.Name].HitTimes do
			hittimes[i] = fraction * animlength
		end

		-- Check for hit at first hittime
		task.delay(hittimes[1], function()
			local HitTargets = Server.Modules.Hitbox.SpatialQuery(
				Character,
				Vector3.new(8, 8, 8), -- Adjust hitbox size as needed
				Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, -4), -- Adjust position as needed
				false
			)

			if #HitTargets > 0 then
				-- Hit detected, check for block/parry before starting combo
				local Target = nil
				for _, HitTarget in pairs(HitTargets) do
					if HitTarget ~= Character then
						Target = HitTarget

						-- Check if target is blocking or parrying
						local isBlocking = Server.Library.StateCheck(Target.Frames, "Blocking")
						local isParrying = Server.Library.StateCheck(Target.Frames, "Parry")

						-- Check if block is valid (not from behind)
						local isBehind = (Target.HumanoidRootPart.CFrame:Inverse() * Character.HumanoidRootPart.CFrame).Z > 1

						if isParrying then
							-- Target parried the attack - cancel combo and stun attacker
							print(string.format("[Strategist Combination] %s PARRIED by %s - combo cancelled!", Character.Name, Target.Name))

							-- Stop attacker's animation and states
							Server.Library.StopAllAnims(Character)
							Server.Library.RemoveState(Character.Actions, script.Name)
							Server.Library.RemoveState(Character.Speeds, "AlcSpeed-0")
							Server.Library.RemoveState(Character.Stuns, "NoRotate")
							Server.Library.RemoveState(Character.IFrames, "StrategistCombo")
							Server.Library.RemoveState(Character.Stuns, "StrategistComboLock")

							-- Apply parry stun to attacker
							Server.Library.TimedState(Character.Speeds, "ParrySpeedSet4", 1.2)
							Server.Library.TimedState(Character.Stuns, "ParryStun", 1.2)

							-- Reset parry cooldown for defender
							Server.Library.ResetCooldown(Target, "Parry")

							-- Play parry effects
							Server.Library.PlaySound(
								Target,
								Replicated.Assets.SFX.Parries:GetChildren()[math.random(1, #Replicated.Assets.SFX.Parries:GetChildren())]
							)
							Server.Visuals.Ranged(
								Target.HumanoidRootPart.Position,
								300,
								{ Module = "Base", Function = "Parry", Arguments = { Target, Character, 5 } }
							)

							return -- Cancel the combo
						elseif isBlocking and not isBehind then
							-- Target blocked the attack - cancel combo
							print(string.format("[Strategist Combination] %s BLOCKED by %s - combo cancelled!", Character.Name, Target.Name))

							-- Stop attacker's animation and states
							Server.Library.StopAllAnims(Character)
							Server.Library.RemoveState(Character.Actions, script.Name)
							Server.Library.RemoveState(Character.Speeds, "AlcSpeed-0")
							Server.Library.RemoveState(Character.Stuns, "NoRotate")
							Server.Library.RemoveState(Character.IFrames, "StrategistCombo")
							Server.Library.RemoveState(Character.Stuns, "StrategistComboLock")

							-- Play block effects
							local BlockedSounds = Replicated.Assets.SFX.Weapons[Weapon]:FindFirstChild("Blocked")
							if BlockedSounds then
								Server.Library.PlaySound(Target, BlockedSounds:GetChildren()[math.random(1, #BlockedSounds:GetChildren())])
							end

							-- Apply chip damage to blocker's posture
							if Target:FindFirstChild("Posture") then
								Target.Posture.Value = Target.Posture.Value + 10 -- Chip damage
							end

							return -- Cancel the combo
						end

						-- No block/parry - continue with combo
						Library.PlayAnimation(Target, VictimAnimation)

						-- Lock victim in place during the combo
						Server.Library.TimedState(Target.Actions, "StrategistVictim", animlength)
						Server.Library.TimedState(Target.Speeds, "AlcSpeed-0", animlength)
						Server.Library.TimedState(Target.Stuns, "NoRotate", animlength)

						-- Add invincibility to victim (but allow damage from attacker via special check in Damage.lua)
						Server.Library.TimedState(Target.IFrames, "StrategistComboVictim", animlength)

						-- Anchor victim's position
						local victimRoot = Target:FindFirstChild("HumanoidRootPart")
						if victimRoot then
							-- Clean up any existing body movers first
							for _, child in ipairs(victimRoot:GetChildren()) do
								if child:IsA("BodyPosition") or child:IsA("BodyGyro") or child:IsA("BodyVelocity") or child:IsA("LinearVelocity") then
									child:Destroy()
								end
							end

							local originalCFrame = victimRoot.CFrame
							local positionLock = Instance.new("BodyPosition")
							positionLock.Name = "StrategistComboLock"
							positionLock.Position = originalCFrame.Position
							positionLock.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
							positionLock.P = 10000
							positionLock.D = 500
							positionLock.Parent = victimRoot

							-- Remove position lock when combo ends
							task.delay(animlength, function()
								if positionLock and positionLock.Parent then
									positionLock:Destroy()
								end

								-- Extra cleanup - remove any lingering body movers
								if victimRoot and victimRoot.Parent then
									for _, child in ipairs(victimRoot:GetChildren()) do
										if child:IsA("BodyPosition") or child:IsA("BodyGyro") then
											child:Destroy()
										end
									end
								end
							end)
						end

						break -- Only need one victim for the animation check
					end
				end

				if not Target then return end

				-- Sweep hit (hittime 1)
                Server.Visuals.Ranged(Character.HumanoidRootPart.Position, 300, {
							Module = "Base",
							Function = "SC",
							Arguments = { Character, "Sweep"},
						})
				Server.Modules.Damage.Tag(Character, Target, Skills[Weapon][script.Name]["Sweep"])

				-- Up hit (hittime 2)
                task.delay(hittimes[2] - hittimes[1], function()
                    Server.Visuals.Ranged(Character.HumanoidRootPart.Position, 300, {
							Module = "Base",
							Function = "SC",
							Arguments = { Character, "Up"},
						})
					Server.Modules.Damage.Tag(Character, Target, Skills[Weapon][script.Name]["Up"])
                end)

				-- Down hit (hittime 3)
                task.delay(hittimes[3] - hittimes[1], function()
                    Server.Visuals.Ranged(Character.HumanoidRootPart.Position, 300, {
							Module = "Base",
							Function = "SC",
							Arguments = { Character, "Down"},
						})
					Server.Modules.Damage.Tag(Character, Target, Skills[Weapon][script.Name]["Down"])
                end)

				-- Ground hit (hittime 4)
                task.delay(hittimes[4] - hittimes[1], function()
                    Server.Visuals.Ranged(Character.HumanoidRootPart.Position, 300, {
							Module = "Base",
							Function = "SC",
							Arguments = { Character, "groundye"},
                    })
					Server.Modules.Damage.Tag(Character, Target, Skills[Weapon][script.Name]["groundye"])
                end)

				-- Fire hits (12 rapid hits - hittimes 5 through 16)
                for i = 5, 16 do
					local hitIndex = i  -- Capture the current value of i
					local delayTime = hittimes[hitIndex] - hittimes[1]
					local fireType = (hitIndex % 2 == 1) and "LFire" or "RFire"

					print(`Scheduling fire hit {hitIndex} at delay {delayTime} with type {fireType}`)

                    task.delay(delayTime, function()
						print(`Executing fire hit {hitIndex} with type {fireType}`)
                        Server.Visuals.Ranged(Character.HumanoidRootPart.Position, 300, {
                            Module = "Base",
                            Function = "SC",
                            Arguments = { Character, fireType},
                        })
                        Server.Visuals.Ranged(Character.HumanoidRootPart.Position, 300, {
                            Module = "Base",
                            Function = "SC",
                            Arguments = { Character, "groundye"},
                        })
						Server.Modules.Damage.Tag(Character, Target, Skills[Weapon][script.Name][fireType])
                    end)
                end
			else
				-- No hit, cancel attacker animation
				Move:Stop()
				Server.Library.RemoveState(Character.Actions, script.Name)
				Server.Library.RemoveState(Character.Speeds, "AlcSpeed-0")
				Server.Library.RemoveState(Character.Stuns, "NoRotate")
			end
		end)
	end
end
