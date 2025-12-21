local InputModule = {}
InputModule.__index = InputModule
local self = setmetatable({}, InputModule)

local Replicated = game:GetService("ReplicatedStorage")

self.LastInput = os.clock()

local dialogueController = require(Replicated.Client.Dialogue)



InputModule.InputBegan = function(_, Client)
	-- Check for object interaction first
	if Client.Character:GetAttribute("CanInteract") == true then
		local objectId = Client.Character:GetAttribute("NearbyObject")

		if objectId then
			---- print("Interacting with object:", objectId)

			-- Hide the object prompt
			if _G.ObjectInteraction_HidePrompt then
				_G.ObjectInteraction_HidePrompt()
			end

			-- Fire interaction event to server
			Client.Packets.ObjectInteract.send({ ObjectId = objectId })
		end
		return
	end

	-- Check for NPC dialogue
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

			-- If not in Dialogue folder, check Live folder for wanderer NPCs
			if not npcModel then
				local liveFolder = workspace.World:FindFirstChild("Live")
				if liveFolder then
					-- Search for the NPC in Live folder (wanderers are nested in Actor containers)
					for _, descendant in liveFolder:GetDescendants() do
						if descendant:IsA("Model") and descendant.Name == npcName then
							npcModel = descendant
							break
						end
					end
				end
			end

			-- Check if this is a wanderer NPC and use "Wanderer" as dialogue name
			local dialogueName = npcName
			local displayName = npcName
			local npcOccupation = nil
			local npcPersonality = nil

			if npcModel and npcModel.Name:lower():find("wanderer") then
				dialogueName = "Wanderer"
				-- Get the wanderer's identity from attributes (set by mobs.luau)
				-- Try model first, then HRP as fallback
				displayName = npcModel:GetAttribute("NPCName") or "Citizen"
				npcOccupation = npcModel:GetAttribute("Occupation")
				npcPersonality = npcModel:GetAttribute("Personality")

				-- Fallback to HRP if model attributes not found
				if not npcOccupation or not npcPersonality then
					local hrp = npcModel:FindFirstChild("HumanoidRootPart")
					if hrp then
						displayName = displayName ~= "Citizen" and displayName or hrp:GetAttribute("NPCName") or "Citizen"
						npcOccupation = npcOccupation or hrp:GetAttribute("Occupation")
						npcPersonality = npcPersonality or hrp:GetAttribute("Personality")
					end
				end
			end

			-- Hide the proximity prompt when dialogue starts
			if _G.DialogueProximity_HidePrompt then
				_G.DialogueProximity_HidePrompt()
			end

			-- Pass the correct params format that OnEvent expects
			dialogueController:Start({
				name = dialogueName,
				displayName = displayName,
				occupation = npcOccupation,
				personality = npcPersonality,
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
