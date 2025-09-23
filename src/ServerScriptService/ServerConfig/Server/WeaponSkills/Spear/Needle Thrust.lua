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

        Server.Modules.Combat.Trail(Character, true)

		Server.Packets.Bvel.sendTo({ Character = Character, duration = hittimes[1], Name = "NTBvel" }, Player)

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

                        for _, Target in pairs(HitTargets) do
                            if Target ~= Character and Target:IsA("Model") then
                                Server.Modules.Damage.Tag(Character, Target, Skills[Weapon][script.Name]["DamageTable"])
                                print("Needle Thrust hit:", Target.Name)
                            end
                        end
                    end
        end)
	end
	-- print("activating skill; " .. script.Name)
end
