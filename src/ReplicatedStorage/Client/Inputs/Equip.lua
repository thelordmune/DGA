local InputModule = {}
InputModule.__index = InputModule
local self = setmetatable({}, InputModule)

local Replicated = game:GetService("ReplicatedStorage")

self.LastInput = os.clock()

local dialogueController = require(Replicated.Client.Dialogue)



InputModule.InputBegan = function(_, Client)
	if Client.Character:GetAttribute("Commence") == true then
		---- print("commencing bro bro")

		-- Check if player is in combat
		if _G.PlayerInCombat then
			warn("Cannot talk to NPC while in combat!")
			return
		end

		-- Get NPC name from character attribute (set by DialogueProximity)
		local npcName = Client.Character:GetAttribute("NearbyNPC")

		if npcName then
			---- print("firing dialogue interaction for NPC:", npcName)

			-- Find the NPC model in workspace
			local dialogueFolder = workspace.World:FindFirstChild("Dialogue")
			local npcModel = dialogueFolder and dialogueFolder:FindFirstChild(npcName)

			-- Hide the proximity prompt when dialogue starts
			if _G.DialogueProximity_HidePrompt then
				_G.DialogueProximity_HidePrompt()
			end

			-- Pass the correct params format that OnEvent expects
			dialogueController:Start({
				name = npcName,
				npc = npcModel
			})
		else
			warn("No NearbyNPC attribute found on character")
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
