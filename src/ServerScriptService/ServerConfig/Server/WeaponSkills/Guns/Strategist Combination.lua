local ServerStorage = game:GetService("ServerStorage")
local Replicated = game:GetService("ReplicatedStorage")
local Library = require(Replicated.Modules.Library)
local Skills = require(ServerStorage.Stats._Skills)

local Global = require(Replicated.Modules.Shared.Global)
return function(Player, Data, Server)
	local Character = Player.Character

	if not Character or not Character:GetAttribute("Equipped") then
		return
	end
	local Weapon = Global.GetData(Player).Weapon
	local PlayerObject = Server.Modules["Players"].Get(Player)
	local Animation = Replicated.Assets.Animations.Skills.Weapons[Weapon][script.Name]
	local VictimAnimation = Replicated.Assets.Animations.Skills.Weapons[Weapon]["Victim"]

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
		Server.Library.TimedState(Character.Stuns, "NoRotate", Move.Length)

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
				-- Hit detected, play victim animation and continue
				for _, Target in pairs(HitTargets) do
					if Target ~= Character then
						Library.PlayAnimation(Target, VictimAnimation)
						-- VictimMove:Play()
						
						-- Apply damage or other effects here
						break -- Only need one victim for the animation check
					end
				end
                Server.Visuals.Ranged(Character.HumanoidRootPart.Position, 300, {
							Module = "Base",
							Function = "SC",
							Arguments = { Character, "Sweep"},
						})
                        task.delay(hittimes[2], function()
                            -- Server.Modules.Combat.Damage(Character, Target, Skills[Weapon][script.Name].DamageTable)
                            Server.Visuals.Ranged(Character.HumanoidRootPart.Position, 300, {
							Module = "Base",
							Function = "SC",
							Arguments = { Character, "Up"},
						})
                        end)
                        task.delay(hittimes[3] - .15, function()
                            -- Server.Modules.Combat.Damage(Character, Target, Skills[Weapon][script.Name].DamageTable)
                            Server.Visuals.Ranged(Character.HumanoidRootPart.Position, 300, {
							Module = "Base",
							Function = "SC",
							Arguments = { Character, "Down"},
						})
                        end)
                        task.delay(hittimes[4], function()
                            Server.Visuals.Ranged(Character.HumanoidRootPart.Position, 300, {
							Module = "Base",
							Function = "SC",
							Arguments = { Character, "groundye"},
                            })
                        end)
                        for i = 5, 16 do
							-- Server.Modules.Damage.Tag(Character, Target, Moves.Flame.Firestorm["DamageTableStart"])
                            task.delay(hittimes[i], function()
                                local fireType = (i % 2 == 1) and "LFire" or "RFire"
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
