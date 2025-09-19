local Client = require(script.Parent.Parent)
local DialogueTracker = {}

local world = require(game:GetService("ReplicatedStorage").Modules.ECS.jecs_world)
local comps = require(game:GetService("ReplicatedStorage").Modules.ECS.jecs_components)
local ref = require(game:GetService("ReplicatedStorage").Modules.ECS.jecs_ref)
local Players = game:GetService("Players")
local Replicated = game:GetService("ReplicatedStorage")

DialogueTracker.Start = function()
    print("starting dialogue tracker bro bro")
    local Character = Client.Character
    local pent = ref.get("local_player", Players:GetPlayerFromCharacter(Character))
    Character:GetAttributeChangedSignal("Commence"):Connect(function()
		print("Changed cuh")
		print(world:get(pent, comps.Dialogue))
		local effmod = require(Replicated.Effects.Base)
		effmod.Commence(world:get(pent, comps.Dialogue))
		-- Visuals.FireClient(
		-- 	Players.LocalPlayer,
		-- 	{ Module = "Base", Function = "Commence", Arguments = { wrld:get(pent, comps.Dialogue) } }
		-- )
	end)
end

return DialogueTracker