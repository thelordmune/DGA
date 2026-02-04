local Handler = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ECS imports
local world = require(ReplicatedStorage.Modules.ECS.jecs_world)
local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)
local jecsRef = require(ReplicatedStorage.Modules.ECS.jecs_ref)

-- Packets for client notification
local Packets = require(ReplicatedStorage.Modules.Packets)

Handler.OnInteract = function(Player, npcModel)
	-- Get NPC identity from attributes
	local npcName = npcModel:GetAttribute("NPCName") or npcModel.Name
	local occupation = npcModel:GetAttribute("Occupation") or "Citizen"
	local personality = npcModel:GetAttribute("Personality") or "Friendly"
	local npcId = npcModel:GetAttribute("NPCId") or npcModel.Name
	local chronoId = npcModel:GetAttribute("ChronoId") or 0 -- Chrono replication ID

	print(`[Dialogue] Player {Player.Name} interacted with {npcName} ({occupation}), ChronoId: {chronoId}`)

	local character = Player.Character
	if not character then return end

	-- Get the player's ECS entity using the proper jecs_ref API
	local playerEntity = jecsRef.get("player", Player)
	if not playerEntity then
		warn("[Dialogue] Player entity not found in ECS for:", Player.Name)
		return
	end

	-- Check if player already has an active dialogue
	if world:has(playerEntity, comps.Dialogue) then
		local existingDialogue = world:get(playerEntity, comps.Dialogue)
		if existingDialogue and existingDialogue.state == "active" then
			-- Already in dialogue, don't interrupt
			print("[Dialogue] Player already in dialogue")
			return
		end
	end

	-- Set dialogue component on player
	world:set(playerEntity, comps.Dialogue, {
		npc = npcModel,
		name = npcName,
		inrange = true,
		state = "active",
	})

	-- Send packet to client to trigger dialogue UI
	Packets.StartDialogue.sendTo({
		NPCName = npcName,
		Occupation = occupation,
		Personality = personality,
		NPCId = npcId,
		ChronoId = chronoId,
	}, Player)

	print(`[Dialogue] Started dialogue with {npcName}, sent packet to client`)
end

return Handler
