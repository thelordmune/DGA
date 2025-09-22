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
		for i, fraction in Skills[Weapon][script.Name].HitTimes do
			hittimes[i] = fraction * animlength
		end

        task.delay(hittimes[1], function()
            Server.Visuals.Ranged(Character.HumanoidRootPart.Position, 300, {
				Module = "Weapons",
				Function = "GrandCleave",
				Arguments = { Character, "Slash1"},
			})
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
        end)
        task.delay(hittimes[7], function()
            Server.Visuals.Ranged(Character.HumanoidRootPart.Position, 300, {
				Module = "Weapons",
				Function = "GrandCleave",
				Arguments = { Character, "Slash3"},
			})
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
