local InputModule = {}
InputModule.__index = InputModule
local self = setmetatable({}, InputModule)

local Player = game:GetService("Players").LocalPlayer

type Dia = {
	npc: Model,
	name: string,
	inrange: boolean,
	state: string,
	currentnode: Configuration,
}
local Replicated = game:GetService("ReplicatedStorage")
local world = require(game:GetService("ReplicatedStorage").Modules.ECS.jecs_world)
local comps = require(game:GetService("ReplicatedStorage").Modules.ECS.jecs_components)
local ref = require(game:GetService("ReplicatedStorage").Modules.ECS.jecs_ref)
local Bridges = require(Replicated.Modules.Bridges)

local pent = ref.get("local_player", game:GetService("Players").LocalPlayer)

self.LastInput = os.clock()

local dialogueController = require(Replicated.Client.Dialogue)



InputModule.InputBegan = function(_, Client)
	if Client.Character:GetAttribute("Commence") == true then
		print("commencing bro bro")
		local Dialogue: Dia = world:get(pent, comps.Dialogue)
		if Dialogue then
			print("firing dialogue interaction")
			dialogueController:Start(Dialogue)
		end
		return
	end
	Client.Packets.Equip.send({})

end

InputModule.InputEnded = function(_, Client)
	--Client.Packets.Attack.send({Held = false})
end

InputModule.InputChanged = function()

end

return InputModule
