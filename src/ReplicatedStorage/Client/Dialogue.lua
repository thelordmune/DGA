local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")
local wait = task.wait
local Fusion = require(ReplicatedStorage.Modules.Fusion)
local Children, scoped, peek, out, OnEvent, Value, Computed, Tween =
	Fusion.Children, Fusion.scoped, Fusion.peek, Fusion.Out, Fusion.OnEvent, Fusion.Value, Fusion.Computed, Fusion.Tween
local RichText = require(ReplicatedStorage.Modules.RichText)
local Controller = {}
local Bridges = require(ReplicatedStorage.Modules.Bridges)
local QuestData = require(ReplicatedStorage.Modules.Quests)
local WandererDialogue = require(ReplicatedStorage.Modules.WandererDialogue)

-- UI Sounds
local openUISound = ReplicatedStorage.Assets.SFX.MISC.OpenUI
local closeUISound = ReplicatedStorage.Assets.SFX.MISC.CloseUI

local PromptTypeWaitTime = 0.0075 -- Set to 0 to remove type writer effect
local PromptWaitTime = 1

local Player = game.Players.LocalPlayer
local PlayerGui = Player.PlayerGui
local camera = game.Workspace.CurrentCamera
local QuestManager = require(ReplicatedStorage.Modules.Utils.QuestManager)

local uidisable = PlayerGui:FindFirstChild("ScreenGui")

local Client = require(ReplicatedStorage.Client)

--   settings
-- local  _ENABLED = false -- ENABLED FOR  GING
-- local function  ---- print(message, ...)
-- 	if  _ENABLED then
-- 		---- print("[Dialogue]", message, ...)
-- 	end
-- end

wait(5)
-- PlayerGui:WaitForChild("Dialogue")

local Interface = PlayerGui:FindFirstChild("DialogueHolder")

local scope = scoped(Fusion, { Dialogue = require(ReplicatedStorage.Client.Components.DialogueComp) })

local qscope = scoped(Fusion, { QuestComp = require(ReplicatedStorage.Client.Components.Quests) })

local dpText = scope:Value("")
local npc = scope:Value("")
--local model = scope:Value(nil)
local begin = scope:Value(false)
local fadein = scope:Value(false)
local resp = scope:Value({})
local respMode = scope:Value(false)
local par = Interface

local questFramein = scope:Value(false)
local questDescription = scope:Value("")
local questHeader = scope:Value("")

local pendingQuest = nil
local currentQuestUI = nil

-- local fIn = scope:Value(false)
-- local description = scope:Value("")
-- local header = scope:Value

local CurrentParams = nil
local SkipTyping = false
local CanSkip = false
local CurrentDialogueUI = nil
local CurrentNode = nil -- Track the current dialogue node for AutoClose support
local InrangeMonitorConnection = nil -- Track the inrange monitoring connection
local HealthChangedConnection = nil -- Track health monitoring connection
local CombatMonitorConnection = nil -- Track combat state monitoring connection

-- Function to replace placeholders in dialogue text (module-level for reuse)
local function processDialogueText(text)
	if not text or not CurrentParams then return text end

	local processed = text
	local name = CurrentParams.displayName or CurrentParams.name or "Citizen"
	local occupation = CurrentParams.occupation or "citizen"
	local personality = CurrentParams.personality or "Professional"

	-- Basic placeholders
	processed = processed:gsub("{name}", name)
	processed = processed:gsub("{occupation}", occupation)
	processed = processed:gsub("{personality}", personality)

	-- Use WandererDialogue for dynamic content
	-- Greeting (personality-based)
	if processed:find("{greeting}") then
		local personalityData = WandererDialogue.PersonalityText[personality]
		if personalityData and personalityData.greetings then
			local greetings = personalityData.greetings
			local greeting = greetings[math.random(#greetings)] or "Hello. "
			processed = processed:gsub("{greeting}", greeting)
		else
			processed = processed:gsub("{greeting}", "Hello. ")
		end
	end

	-- Occupation intro
	if processed:find("{intro}") then
		local occData = WandererDialogue.Occupations[occupation]
		if occData and occData.intro then
			local intro = WandererDialogue.processText(occData.intro, personality)
			processed = processed:gsub("{intro}", intro)
		else
			processed = processed:gsub("{intro}", "I work around here.")
		end
	end

	-- Work response (occupation-specific)
	if processed:find("{work_response}") then
		local response = WandererDialogue.getTopicResponse(occupation, "work", personality)
		processed = processed:gsub("{work_response}", response)
	end

	-- Town response (occupation-specific)
	if processed:find("{town_response}") then
		local response = WandererDialogue.getTopicResponse(occupation, "town", personality)
		processed = processed:gsub("{town_response}", response)
	end

	-- Rumors response (occupation-specific)
	if processed:find("{rumors_response}") then
		local response = WandererDialogue.getTopicResponse(occupation, "rumors", personality)
		processed = processed:gsub("{rumors_response}", response)
	end

	-- Farewell (personality-based)
	if processed:find("{farewell}") then
		local farewell = WandererDialogue.getFarewell(personality)
		processed = processed:gsub("{farewell}", farewell)
	end

	-- Ask options (occupation-specific question text)
	if processed:find("{ask_work}") or processed:find("{ask_town}") or processed:find("{ask_rumors}") then
		local askOptions = WandererDialogue.getAskOptions(occupation)
		processed = processed:gsub("{ask_work}", askOptions.work)
		processed = processed:gsub("{ask_town}", askOptions.town)
		processed = processed:gsub("{ask_rumors}", askOptions.rumors)
	end

	-- Work detail responses (follow-up conversations)
	if processed:find("{work_detail_1}") then
		local response = WandererDialogue.getTopicResponse(occupation, "work_detail_1", personality)
		processed = processed:gsub("{work_detail_1}", response)
	end
	if processed:find("{work_detail_2}") then
		local response = WandererDialogue.getTopicResponse(occupation, "work_detail_2", personality)
		processed = processed:gsub("{work_detail_2}", response)
	end
	if processed:find("{work_detail_3}") then
		local response = WandererDialogue.getTopicResponse(occupation, "work_detail_3", personality)
		processed = processed:gsub("{work_detail_3}", response)
	end

	-- Town detail responses (follow-up conversations)
	if processed:find("{town_detail_1}") then
		local response = WandererDialogue.getTopicResponse(occupation, "town_detail_1", personality)
		processed = processed:gsub("{town_detail_1}", response)
	end
	if processed:find("{town_detail_2}") then
		local response = WandererDialogue.getTopicResponse(occupation, "town_detail_2", personality)
		processed = processed:gsub("{town_detail_2}", response)
	end
	if processed:find("{town_detail_3}") then
		local response = WandererDialogue.getTopicResponse(occupation, "town_detail_3", personality)
		processed = processed:gsub("{town_detail_3}", response)
	end

	-- Rumors detail responses (follow-up conversations)
	if processed:find("{rumors_detail_1}") then
		local response = WandererDialogue.getTopicResponse(occupation, "rumors_detail_1", personality)
		processed = processed:gsub("{rumors_detail_1}", response)
	end
	if processed:find("{rumors_detail_2}") then
		local response = WandererDialogue.getTopicResponse(occupation, "rumors_detail_2", personality)
		processed = processed:gsub("{rumors_detail_2}", response)
	end
	if processed:find("{rumors_detail_3}") then
		local response = WandererDialogue.getTopicResponse(occupation, "rumors_detail_3", personality)
		processed = processed:gsub("{rumors_detail_3}", response)
	end

	-- Personal responses (about themselves)
	if processed:find("{personal_intro}") then
		local response = WandererDialogue.getPersonalIntro(occupation, personality)
		processed = processed:gsub("{personal_intro}", response)
	end
	if processed:find("{personal_history}") then
		local response = WandererDialogue.getTopicResponse(occupation, "personal_history", personality)
		processed = processed:gsub("{personal_history}", response)
	end
	if processed:find("{personal_family}") then
		local response = WandererDialogue.getTopicResponse(occupation, "personal_family", personality)
		processed = processed:gsub("{personal_family}", response)
	end
	if processed:find("{personal_hopes}") then
		local response = WandererDialogue.getTopicResponse(occupation, "personal_hopes", personality)
		processed = processed:gsub("{personal_hopes}", response)
	end

	-- Pickpocket result (handled by server, but provide default)
	if processed:find("{pickpocket_result}") then
		-- This will be replaced by the server's actual result
		-- Default text shown briefly before server response
		processed = processed:gsub("{pickpocket_result}", "You reach for their belongings...")
	end

	return processed
end

function GetRootNode(Tree)
	 ---- print("Getting root node from tree: " .. tostring(Tree))
	for _, Node in pairs(Tree:GetChildren()) do
		if Node:GetAttribute("Type") == "DialogueRoot" then
			 ---- print("Found root node: " .. tostring(Node))
			return Node
		end
	end
	 ---- print("No root node found in tree")
	return nil
end

function GetNodeFromValue(Value)
	 ---- print("Getting node from value: " .. tostring(Value))
	-- If Value is already a Configuration, return it directly
	if Value:IsA("Configuration") then
		 ---- print("Found node (direct): " .. tostring(Value))
		return Value
	end
	-- Otherwise, try to find Configuration ancestor (old system)
	local node = Value:FindFirstAncestorWhichIsA("Configuration")
	 ---- print("Found node (ancestor): " .. tostring(node))
	return node
end

function GetOutputNodes(InputNode)
	 ---- print("Getting output nodes from: " .. tostring(InputNode))
	local Nodes = {}

	--  : Show what's in the node
	local outputsFolder = InputNode:FindFirstChild("Outputs")
	if outputsFolder then
		 ---- print("Outputs folder found, children:", #outputsFolder:GetChildren())
		for _, child in ipairs(outputsFolder:GetChildren()) do
			 ---- print("  Output child:", child.Name, child.ClassName, "Value:", child:IsA("ObjectValue") and child.Value or "N/A")
		end
	else
		 ---- print("No Outputs folder found in node!")
	end

	for _, Output in pairs(InputNode:GetDescendants()) do
		if Output.Parent.Name == "Outputs" and Output.Value ~= nil then
			 ---- print("Processing output:", Output.Name, "Value type:", typeof(Output.Value))
			local Node = GetNodeFromValue(Output.Value)
			if not table.find(Nodes, Node) then
				table.insert(Nodes, Node)
				 ---- print("Added output node: " .. tostring(Node))
			end
		end
	end

	 ---- print("Found " .. #Nodes .. " output nodes")
	return Nodes
end

function GetInputNodes(InputNode)
	 ---- print("Getting input nodes from: " .. tostring(InputNode))
	local Nodes = {}

	for _, Input in pairs(InputNode:GetDescendants()) do
		if Input.Parent.Name == "Inputs" and Input.Value ~= nil then
			local Node = GetNodeFromValue(Input.Value)
			if not table.find(Nodes, Node) then
				table.insert(Nodes, Node)
				 ---- print("Added input node: " .. tostring(Node))
			end
		end
	end

	 ---- print("Found " .. #Nodes .. " input nodes")
	return Nodes
end

function GetInputs(Node)
	 ---- print("Getting inputs from node: " .. tostring(Node))
	local Inputs = {}

	for _, Input in pairs(Node:GetDescendants()) do
		if Input.Parent.Name == "Inputs" and Input.Value ~= nil then
			table.insert(Inputs, Input)
			 ---- print("Added input: " .. tostring(Input))
		end
	end

	 ---- print("Found " .. #Inputs .. " inputs")
	return Inputs
end

function GetHighestPriorityNode(Nodes)
	 ---- print("Getting highest priority node from " .. #Nodes .. " nodes")
	local HighestPriority = 0
	local ChosenNode = nil

	for _, Node in pairs(Nodes) do
		local priority = Node:GetAttribute("Priority") or 0
		 ---- print("Node " .. tostring(Node) .. " has priority: " .. priority)
		if priority > HighestPriority then
			HighestPriority = priority
			ChosenNode = Node
			 ---- print("New highest priority node: " .. tostring(Node))
		end
	end

	 ---- print("Selected node: " .. tostring(ChosenNode))
	return ChosenNode
end

function FindNodeWithPriority(Nodes, Priority)
	 ---- print("Finding node with priority: " .. Priority)
	for _, Node in pairs(Nodes) do
		if Node:GetAttribute("Priority") == Priority then
			 ---- print("Found node: " .. tostring(Node))
			return Node
		end
	end
	 ---- print("No node found with priority: " .. Priority)
	return nil
end

function GetLowestPriorityNode(Nodes)
	 ---- print("Getting lowest priority node from " .. #Nodes .. " nodes")
	local LowestPriority = math.huge
	local ChosenNode = nil

	for _, Node in pairs(Nodes) do
		local priority = Node:GetAttribute("Priority") or math.huge
		 ---- print("Node " .. tostring(Node) .. " has priority: " .. priority)
		if priority < LowestPriority then
			LowestPriority = priority
			ChosenNode = Node
			 ---- print("New lowest priority node: " .. tostring(Node))
		end
	end

	 ---- print("Selected node: " .. tostring(ChosenNode))
	return ChosenNode
end

function ClearResponses()
	 ---- print("Clearing responses")
	if CurrentDialogueUI and CurrentDialogueUI:FindFirstChild("ResponseFrame") then
		local responseCount = 0
		for _, Response in pairs(CurrentDialogueUI.ResponseFrame:GetChildren()) do
			if Response:IsA("TextButton") and Response.Visible then
				responseCount = responseCount + 1
				Response:Destroy()
			end
		end
		 ---- print("Cleared " .. responseCount .. " responses")
	else
		 ---- print("No response frame found to clear")
	end
end

function FindNodeType(Nodes, Type)
	 ---- print("Finding node of type: " .. Type)
	for _, Node in pairs(Nodes) do
		if Node:GetAttribute("Type") == Type then
			 ---- print("Found node: " .. tostring(Node))
			return Node
		end
	end
	 ---- print("No node found of type: " .. Type)
	return nil
end

function FindInput(Inputs, Name)
	 ---- print("Finding input with name: " .. Name)
	for _, Input in pairs(Inputs) do
		if Input.Value and Input.Value.Name == Name then
			 ---- print("Found input: " .. tostring(Input))
			return Input.Value
		end
	end
	 ---- print("No input found with name: " .. Name)
	return nil
end

function FireEvents(Node)
	 ---- print("Firing events for node: " .. tostring(Node))
	local eventCount = 0
	for _, Event in pairs(Node:GetChildren()) do
		if Event:IsA("RemoteEvent") then
			 ---- print("Firing remote event: " .. tostring(Event))
			Event:FireServer(Node)
			eventCount = eventCount + 1
		elseif Event:IsA("BindableEvent") then
			 ---- print("Firing bindable event: " .. tostring(Event))
			Event:Fire(Node)
			eventCount = eventCount + 1
		end
	end
	 ---- print("Fired " .. eventCount .. " events")
end

function RunCommands(Node, Params)
	 ---- print("Running commands for node: " .. tostring(Node))
	local commandCount = 0
	for _, InputNode in pairs(GetInputNodes(Node)) do
		if InputNode:GetAttribute("Type") ~= "Condition" and InputNode:FindFirstChildWhichIsA("ModuleScript") then
			if #GetInputs(InputNode) <= 0 then
				local Function = require(InputNode:FindFirstChildWhichIsA("ModuleScript"))
				 ---- print("Running command: " .. tostring(InputNode:FindFirstChildWhichIsA("ModuleScript")))
				if Function.Run then
					Close(Params)
					Function.Run()
					commandCount = commandCount + 1
				end
			end
		end
	end
	 ---- print("Ran " .. commandCount .. " commands")
end

function CheckForCondition(Node)
	 ---- print("Checking conditions for node: " .. Node.Name)
	local inputNodes = GetInputNodes(Node)
	 ---- print("  Found " .. #inputNodes .. " input nodes")

	local conditionCount = 0
	for _, InputNode in pairs(inputNodes) do
		local inputType = InputNode:GetAttribute("Type")
		 ---- print("  Input node: " .. InputNode.Name .. " (Type: " .. tostring(inputType) .. ")")

		if inputType == "Condition" then
			if #GetInputs(InputNode) <= 0 then
				local conditionPassed = false

				-- Check for ModuleScript-based condition (old system)
				local moduleScript = InputNode:FindFirstChildWhichIsA("ModuleScript")
				if moduleScript then
					local Function = require(moduleScript)
					 ---- print("  Checking condition (ModuleScript): " .. tostring(moduleScript))
					if Function.Run then
						local result = Function.Run()
						 ---- print("  Condition result: " .. tostring(result))
						conditionPassed = result
					end
				-- Check for attribute-based condition (new module system)
				elseif InputNode:GetAttribute("ModuleName") then
					local moduleName = InputNode:GetAttribute("ModuleName")
					local argsString = InputNode:GetAttribute("Args") or ""
					 ---- print("  Checking condition (Attribute): " .. moduleName .. " with args: " .. argsString)

					-- Load the condition module
					local conditionModule = ReplicatedStorage.Modules.Utils.DialogueConditions:FindFirstChild(moduleName)
					if conditionModule then
						local success, Function = pcall(require, conditionModule)
						if success and Function.Run then
							-- Parse args from attribute
							local args = {}
							if argsString ~= "" then
								args = string.split(argsString, ",")
								-- Trim whitespace from args
								for i, arg in ipairs(args) do
									args[i] = arg:match("^%s*(.-)%s*$")
								end
							end

							-- Call the condition with args
							 ---- print("  Calling condition with args:", table.concat(args, ", "))
							local result = Function.Run(table.unpack(args))
							 ---- print("  ✅ Condition result: " .. tostring(result))
							conditionPassed = result
						else
							warn("[Dialogue] Failed to load condition module:", moduleName)
						end
					else
						warn("[Dialogue] Condition module not found:", moduleName)
					end
				else
					 ---- print("  ⚠️ Condition node has no ModuleScript or ModuleName attribute")
				end

				-- If condition failed, skip this node
				if not conditionPassed then
					 ---- print("  ❌ Condition failed for node: " .. Node.Name)
					return true
				end

				conditionCount = conditionCount + 1
			end
		end
	end
	 ---- print("  ✅ Checked " .. conditionCount .. " conditions, all passed for node: " .. Node.Name)
	return false
end

function ToggleLock(Node)
	 ---- print("Toggling lock for node: " .. tostring(Node))
	local toggleCount = 0
	for _, Input in pairs(GetInputs(Node)) do
		if Input.Value and Input.Value.Name == "Toggle" then
			 ---- print("Toggling input: " .. tostring(Input.Value))
			Input.Value.Value = not Input.Value.Value
			toggleCount = toggleCount + 1
		end
	end
	 ---- print("Toggled " .. toggleCount .. " locks")
end

function IsLocked(Node)
	 ---- print("Checking if node is locked: " .. tostring(Node))
	local LockNode = FindNodeType(GetInputNodes(Node), "Lock")

	if LockNode and LockNode.Toggle and LockNode.Toggle.Value == true then
		local LockFound = false

		for _, Input in pairs(GetInputs(Node)) do
			if Input.Value and Input.Value.Name == "MainPathway" and Input.Value.Parent == LockNode then
				LockFound = true
				 ---- print("Node is locked")
				break
			end
		end

		return LockFound
	else
		 ---- print("Node is not locked")
		return false
	end
end

function RunInternalCommands(Node)
	 ---- print("Running internal commands for node: " .. tostring(Node))
	if Node:FindFirstChildWhichIsA("ModuleScript") then
		local moduleScript = Node:FindFirstChildWhichIsA("ModuleScript")
		 ---- print("Found module script: " .. tostring(moduleScript))
		local Function = require(moduleScript)
		if Function.Run then
			 ---- print("Running internal command")
			Function.Run()
		else
			 ---- print("ERROR: Module found inside a node does not have a .Run function!")
			error("Module found inside a node does not have a .Run function!")
		end
	else
		 ---- print("No internal commands found")
	end
end

function CommonNodeFunctions(Node, Params)
	 ---- print("Running common functions for node: " .. tostring(Node))
	RunCommands(Node, Params)
	ToggleLock(Node)
	FireEvents(Node)
	RunInternalCommands(Node)
end

-- Response buttons are now created by DialogueComp using Fusion
-- This function is no longer needed but kept for reference
function CreateResponseButton(Node, Params)
	 ---- print("CreateResponseButton called (deprecated - using DialogueComp instead)")
	-- Responses are now handled by the DialogueComp component via the resp Fusion Value
	-- The actual button creation and click handling happens in DialogueComp.lua
	return nil
end

function LoadNode(Node, Params)
	local Type = Node:GetAttribute("Type") or "Unknown"
	 ---- print("Loading node: " .. tostring(Node) .. " of type: " .. Type)

	-- Track current node for AutoClose support
	CurrentNode = Node

	if IsLocked(Node) then
		 ---- print("Node is locked, skipping")
		return
	end

	if not CurrentDialogueUI then
		 ---- print("ERROR: No dialogue UI found")
		return
	end

	if CheckForCondition(Node) then
		 ---- print("Condition check failed, skipping node")
		return
	end

	-- Handle quest actions
	local questFolder = Node:FindFirstChild("Quest")
	if questFolder then
		local questAction = questFolder:GetAttribute("Action")
		local questName = questFolder:GetAttribute("QuestName")

		 ---- print("Quest action found:", questAction, questName)

		if (questAction == "Accept" or questAction == "Start") and Params then
			QuestManager.acceptQuest(Player, Params.name, questName)
			pendingQuest = {
				npcName = Params.name,
				questName = questName,
			}
		elseif questAction == "CompleteGood" or questAction == "CompleteEvil" then
			-- Send quest completion to server with alignment choice
			 ---- print("🎯 Sending quest completion to server:")
			 ---- print("  NPC:", Params.name)
			 ---- print("  Quest Name:", questName)
			 ---- print("  Choice:", questAction)

			-- Arguments must be an array for ByteNet
			Client.Packets.Quests.send({
				Module = Params.name,
				Function = "Complete",
				Arguments = {questName, questAction}, -- Send as array: [questName, choice]
			})
		elseif questAction == "Pickpocket" then
			-- Handle pickpocket action - send to server and wait for result
			local npcModel = Params and Params.model
			local npcId = npcModel and tostring(npcModel:GetAttribute("NPCId") or npcModel.Name) or "Unknown"
			local occupation = npcModel and npcModel:GetAttribute("Occupation") or "Civilian"

			-- Send pickpocket request to server
			Client.Packets.Pickpocket.send({
				NPCId = npcId,
				Occupation = occupation,
			})

			-- The result will be handled by the PickpocketResult listener below
		else
			-- Handle custom quest actions (like "Teleport")
			-- Send to server to call the quest module's function
			 ---- print("🎯 Sending custom quest action to server:")
			 ---- print("  NPC:", Params.name)
			 ---- print("  Action:", questAction)
			 ---- print("  Quest Name:", questName)

			Client.Packets.Quests.send({
				Module = Params.name,
				Function = questAction, -- The action name is the function name (e.g., "Teleport")
				Arguments = {questName}, -- Send quest name as argument
			})
		end
	end

	-- Legacy support for old Accept node name
	if Node.Name == "Accept" and Params and not questFolder then
		QuestManager.acceptQuest(Player, Params.name, "Missing Pocketwatch")
		pendingQuest = {
			npcName = Params.name,
			questName = "Missing Pocketwatch",
		}
	end

	if Type == "Response" then
		 ---- print("Loading response node (handled by DialogueComp)")
		-- Response buttons are now created by DialogueComp via the resp Fusion Value
		-- No need to create buttons here anymore
	elseif Type == "Prompt" then
		 ---- print("Loading prompt node")
		CommonNodeFunctions(Node, Params)

		-- Update the dialogue UI with the new text


		if CurrentDialogueUI then
			-- Look for TextPlusContainer instead of Text
			local textContainer = CurrentDialogueUI:FindFirstChild("TextPlusContainer", true)
			local npcNameLabel = CurrentDialogueUI:FindFirstChild("NPCName", true)

			 ---- print("CurrentDialogueUI found:", CurrentDialogueUI)
			 ---- print("TextPlusContainer found:", textContainer)
			 ---- print("Node.Text:", Node.Text)

			if textContainer and Node.Text then
				 ---- print("Updating text with TextPlus: " .. Node.Text.Value)
				 ---- print("Setting dpText to empty")
				dpText:set("")
				task.wait(0.1)
				local processedText = processDialogueText(Node.Text.Value)
				 ---- print("Setting dpText to:", processedText)
				dpText:set(processedText)
			elseif Node.Text then
				-- Fallback: just set the text even if container not found yet
				 ---- print("TextPlusContainer not found, setting text anyway: " .. Node.Text.Value)
				 ---- print("Setting dpText to empty")
				dpText:set("")
				task.wait(0.1)
				local processedText = processDialogueText(Node.Text.Value)
				 ---- print("Setting dpText to:", processedText)
				dpText:set(processedText)
			else
				 ---- print("WARNING: Node.Text not found")
			end

			if npcNameLabel then
				 ---- print("Updating NPC name to: " .. (CurrentParams and CurrentParams.name or "?"))
				npcNameLabel.Text = CurrentParams and CurrentParams.name or "?"
			else
				 ---- print("WARNING: NPC name label not found")
			end
		else
			 ---- print("WARNING: CurrentDialogueUI is nil!")
		end

		 ---- print("Waiting " .. PromptWaitTime .. " seconds before loading next nodes")
		task.wait(PromptWaitTime)
		LoadNodes(GetOutputNodes(Node), Params)
	elseif Node:FindFirstChildWhichIsA("ModuleScript") then
		 ---- print("Loading module node")
		CommonNodeFunctions(Node, Params)
		FireEvents(Node)
		LoadNodes(GetOutputNodes(Node), Params)
	else
		 ---- print("WARNING: Unknown node type: " .. Type)
	end
end

function Close(Params)
	 ---- print("Closing dialogue")

	-- Disconnect monitoring connections
	if InrangeMonitorConnection then
		InrangeMonitorConnection:Disconnect()
		InrangeMonitorConnection = nil
		 ---- print("Disconnected inrange monitor")
	end

	if HealthChangedConnection then
		HealthChangedConnection:Disconnect()
		HealthChangedConnection = nil
		 ---- print("Disconnected health monitor")
	end

	if CombatMonitorConnection then
		CombatMonitorConnection:Disconnect()
		CombatMonitorConnection = nil
		 ---- print("Disconnected combat monitor")
	end

	-- Send relationship progress for wanderer NPCs
	if CurrentParams and CurrentParams.name == "Wanderer" and CurrentParams.npc then
		local npcModel = CurrentParams.npc
		local npcId = npcModel:GetAttribute("NPCId")

		if npcId then
			-- Gather appearance data to save if they become friends
			local appearance = {
				outfitId = npcModel:GetAttribute("OutfitId"),
				race = npcModel:GetAttribute("Race"),
				gender = npcModel:GetAttribute("Gender"),
				hairId = npcModel:GetAttribute("HairId"),
				skinColor = npcModel:GetAttribute("SkinColor"),
			}

			-- Send relationship progress to server
			Client.Packets.NPCRelationship.send({
				Action = "Interact",
				NPCId = npcId,
				NPCName = CurrentParams.displayName or "Citizen",
				Occupation = CurrentParams.occupation or "Civilian",
				Personality = CurrentParams.personality or "Professional",
				Appearance = appearance,
			})
			---- print("[Dialogue] Sent relationship progress for NPC:", npcId)
		end
	end

	if CurrentDialogueUI then
		 ---- print("Animating dialogue close")

		-- Play close UI sound
		local closeSound = closeUISound:Clone()
		closeSound.Parent = SoundService
		closeSound:Play()
		Debris:AddItem(closeSound, closeSound.TimeLength)

		-- Animate out
		if fadein and begin then
			fadein:set(false)
			begin:set(false)
			task.wait(1.2) -- Wait for animation to complete
		end

		 ---- print("Destroying current dialogue UI")
		CurrentDialogueUI:Destroy()
		CurrentDialogueUI = nil
	else
		 ---- print("No current dialogue UI to destroy")
	end
	if uidisable then
		uidisable.Enabled = true
	end
	--uidisable.Enabled = true
	CurrentParams = nil
	-- scope:doCleanup()

	if pendingQuest then
		 ---- print("Showing quest popup after dialogue close")
		task.wait(0.5)
		ShowQuestPopup(pendingQuest.npcName, pendingQuest.questName)
		pendingQuest = nil
	end

	 ---- print("Dialogue closed")
end

function GetResponses(Nodes)
	 ---- print("Getting responses from " .. #Nodes .. " nodes")
	local responseData = {}

	for _, Node in (Nodes or {}) do
		if Node:GetAttribute("Type") == "Response" and not IsLocked(Node) and not CheckForCondition(Node) then
			local responseText = Node.Text and Node.Text.Value or "No text"
			-- Process placeholders in response text (for occupation-specific ask options)
			responseText = processDialogueText(responseText)
			local priority = Node:GetAttribute("Priority") or 0

			table.insert(responseData, {
				text = responseText,
				order = priority,
				node = Node,
			})
			 ---- print("Added response: " .. responseText .. " (priority: " .. priority .. ")")
		end
	end

	table.sort(responseData, function(a, b)
		return a.order < b.order
	end)

	 ---- print("Found " .. #responseData .. " responses")
	return responseData
end

function LoadNodes(Nodes, Params)
	 ---- print("Loading " .. #Nodes .. " nodes")
	if #Nodes <= 0 then
		 ---- print("No nodes to load, waiting for animation to finish then auto-closing")
		-- Check if the current node has AutoClose attribute for faster closing
		local autoCloseDelay = 2 -- Default: 2s animation + 3s reading = 5s total
		if CurrentNode and CurrentNode:GetAttribute("AutoClose") then
			autoCloseDelay = 5 -- Fast close: 1.5s total
			 ---- print("AutoClose enabled, using fast close delay")
		else
			-- Wait for text animation to complete (estimate based on text length)
			-- Average text is ~80 chars * 0.015s = 1.2s + 0.5s buffer = ~2s
			task.wait(2)
			-- Then wait additional time for player to read
			 ---- print("Animation complete, waiting 3 seconds for player to read")
			autoCloseDelay = 8
		end
		task.wait(autoCloseDelay)
		 ---- print("Auto-closing dialogue now")
		Close(Params)
	else
		-- Filter nodes by conditions and priority
		local validNodes = {}
		local promptNodes = {}
		local responseNodes = {}

		for _, Node in Nodes do
			local nodeType = Node:GetAttribute("Type")

			-- Check if node passes its condition
			local passesCondition = not CheckForCondition(Node)

			if passesCondition and not IsLocked(Node) then
				table.insert(validNodes, Node)

				if nodeType == "Prompt" then
					table.insert(promptNodes, Node)
				elseif nodeType == "Response" then
					table.insert(responseNodes, Node)
				end

				 ---- print("Valid node: " .. Node.Name .. " (Type: " .. nodeType .. ", Priority: " .. (Node:GetAttribute("Priority") or 0) .. ")")
			else
				 ---- print("Skipping node (failed condition or locked): " .. Node.Name)
			end
		end

		-- If we have prompt nodes, pick the highest priority one
		if #promptNodes > 0 then
			local chosenPrompt = GetHighestPriorityNode(promptNodes)
			if chosenPrompt then
				 ---- print("Loading highest priority prompt: " .. chosenPrompt.Name)
				LoadNode(chosenPrompt, Params)
				return
			end
		end

		-- If we have response nodes, show them all
		if #responseNodes > 0 then
			local responseData = GetResponses(responseNodes)
			---- print("[Dialogue] Setting responses:", #responseData, "responses")
			for i, r in ipairs(responseData) do
				---- print("  Response", i, ":", r.text, "node:", r.node)
			end
			resp:set(responseData)

			if not peek(respMode) then
				---- print("[Dialogue] Setting response mode to true")
				respMode:set(true)
			end

			-- Don't call ClearResponses() - Fusion handles button lifecycle automatically
			-- Just load the nodes for any side effects (quest actions, etc.)
			for _, Node in pairs(responseNodes) do
				LoadNode(Node, Params)
			end
			return
		end

		-- Fallback: load all valid nodes
		if #validNodes > 0 then
			-- Don't call ClearResponses() - Fusion handles button lifecycle
			for _, Node in pairs(validNodes) do
				LoadNode(Node, Params)
			end
		else
			 ---- print("No valid nodes found, closing dialogue")
			Close(Params)
		end
	end
end

function ShowQuestPopup(npcName, questName)
	 ---- print("Showing quest popup for: " .. npcName .. " - " .. questName)

	local questData = QuestData[npcName][questName]
	if not questData then
		 ---- print("ERROR: Quest data not found for: " .. npcName .. " - " .. questName)
		return
	end

	if currentQuestUI then
		currentQuestUI:Destroy()
		currentQuestUI = nil
	end
	if qscope then
		qscope:doCleanup()
	end

	local questTarget = qscope:New("ScreenGui")({
		Name = "QuestPopup",
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = Player.PlayerGui,
	})

			qscope:QuestComp({
				descriptionText = questData.Description,
				headerText = questName,
				framein = questFramein,
				Parent = questTarget
			})

	currentQuestUI = questTarget

	-- Quest packet is already sent by QuestManager.acceptQuest()
	-- No need to send it again here

	task.wait(0.5)
	questFramein:set(true)

	task.spawn(function()
		task.wait(5)
		if questFramein then
			questFramein:set(false)
			task.wait(1)
			if currentQuestUI then
				currentQuestUI:Destroy()
				currentQuestUI = nil
			end
			if qscope then
				qscope:doCleanup()
			end
		end
	end)
end

function OnEvent(Params)
	 ---- print("OnEvent triggered with params: " .. tostring(Params))

	-- Close existing dialogue first
	if CurrentDialogueUI then
		 ---- print("Closing existing dialogue UI before opening new one")
		Close(Params)
		task.wait(0.1) -- Small delay to ensure cleanup
	end

	if not Params or not Params.name then
		 ---- print("ERROR: Invalid parameters received")
		return
	end

	 ---- print("Looking for dialogue tree: " .. Params.name)

	-- Check if Dialogues folder exists
	local dialoguesFolder = ReplicatedStorage:FindFirstChild("Dialogues")
	if not dialoguesFolder then
		warn("[Dialogue] ❌ Dialogues folder not found! Building dialogues...")
		-- Try to build dialogues
		local DialogueBuilder = ReplicatedStorage.Modules.Utils:FindFirstChild("DialogueBuilder")
		if DialogueBuilder then
			local success, builder = pcall(require, DialogueBuilder)
			if success then
				builder.BuildAll()
				dialoguesFolder = ReplicatedStorage:FindFirstChild("Dialogues")
			end
		end

		if not dialoguesFolder then
			warn("[Dialogue] ❌ Failed to build dialogues! Cannot show dialogue.")
			return
		end
	end

	local DialogueTree = dialoguesFolder:FindFirstChild(tostring(Params.name))

	if not DialogueTree then
		 ---- print("ERROR: Dialogue tree not found: " .. Params.name)
		warn("[Dialogue] ❌ Available dialogues:", dialoguesFolder:GetChildren())
		return
	end

	local RootNode = GetRootNode(DialogueTree)

	if not RootNode then
		 ---- print("ERROR: Root node not found in dialogue tree")
		return
	end

	if uidisable then
		uidisable.Enabled = false
	end

	-- Clear any existing dialogue state BEFORE creating UI
	 ---- print("Clearing previous dialogue state")

	-- Force reset all state values to ensure fresh start (fixes dialogue after death)
	dpText:set("")
	task.wait(0.05) -- Small delay to ensure state clears
	resp:set({})
	respMode:set(false)
	begin:set(false)
	fadein:set(false)

	-- Create the new Fusion-based UI
	 ---- print("Creating Fusion dialogue UI")

	local Target = scope:New("ScreenGui")({
		Name = "DialogueHolder",
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = Player.PlayerGui,
	})

	local parent = Target

	-- Store the created UI
	 ---- print("Creating dialogue with dpText:", dpText, "begin:", begin, "fadein:", fadein)
	scope:Dialogue({
		displayText = dpText,
		npcname = Params.displayName or Params.name,
		start = begin,
		Parent = parent,
		fade = fadein,
		responses = resp,
		responseMode = respMode,
	})

	-- Find the actual UI instance in the player's GUI
	CurrentDialogueUI = parent:FindFirstChild("Frame") -- Adjust this based on your actual UI structure
	 ---- print("Dialogue UI created: " .. tostring(CurrentDialogueUI))

	task.wait(1)

	 ---- print("Starting fade animation")
	fadein:set(true)
	begin:set(true)

	-- Play open UI sound
	local openSound = openUISound:Clone()
	openSound.Parent = SoundService
	openSound:Play()
	Debris:AddItem(openSound, openSound.TimeLength)

	CurrentParams = Params or {}
	 ---- print("Current params set: " .. tostring(CurrentParams))

	-- Clear any old manually-created buttons (from previous dialogue system)
	ClearResponses()

	for _, Condition in pairs(DialogueTree:GetChildren()) do
		if Condition:GetAttribute("Type") == "Condition" then
			 ---- print("Resetting condition: " .. tostring(Condition))
			Condition:SetAttribute("ReturnedValue", nil)
		end
	end

	-- Set up inrange monitoring to close dialogue if player leaves NPC range
	 ---- print("Setting up inrange monitoring...")
	local world = require(ReplicatedStorage.Modules.ECS.jecs_world)
	local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)
	local ref = require(ReplicatedStorage.Modules.ECS.jecs_ref)

	local pent = ref.get("local_player")
	if pent then
		local lastInrangeState = true -- Dialogue just started, so we're in range

		-- Monitor the Dialogue component's inrange state
		InrangeMonitorConnection = game:GetService("RunService").Heartbeat:Connect(function()
			local dialogueComp = world:get(pent, comps.Dialogue)
			if dialogueComp then
				local currentInrange = dialogueComp.inrange

				-- If inrange state changed from true to false, close dialogue
				if lastInrangeState and not currentInrange then
					 ---- print("⚠️ Player left NPC range during dialogue, closing...")
					Close(Params)
				end

				lastInrangeState = currentInrange
			end
		end)
		 ---- print("✅ Inrange monitoring active")
	end

	-- Set up health monitoring to close dialogue if player gets hit
	 ---- print("Setting up health monitoring...")
	if Player.Character then
		local humanoid = Player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			local lastHealth = humanoid.Health

			HealthChangedConnection = humanoid.HealthChanged:Connect(function(newHealth)
				-- If health decreased (player got hit), close dialogue
				if newHealth < lastHealth then
					 ---- print("⚠️ Player took damage during dialogue, closing...")
					Close(Params)
				end
				lastHealth = newHealth
			end)
			 ---- print("✅ Health monitoring active")
		end
	end

	-- Set up combat state monitoring to close dialogue if player enters combat
	 ---- print("Setting up combat state monitoring...")
	CombatMonitorConnection = game:GetService("RunService").Heartbeat:Connect(function()
		if _G.PlayerInCombat then
			 ---- print("⚠️ Player entered combat during dialogue, closing...")
			Close(Params)
		end
	end)
	 ---- print("✅ Combat state monitoring active")

	LoadNodes(GetOutputNodes(RootNode), Params)
end

function Controller:Start(data)
	 ---- print("Controller Start called with data: " .. tostring(data))
	OnEvent(data)
end

-- Add a function to toggle  ging
-- function Controller:Set ging(enabled)
-- 	 _ENABLED = enabled
-- 	 ---- print(" ging " .. (enabled and "enabled" or "disabled"))
-- end

-- Handle response button clicks from DialogueComp
function Controller.HandleResponseClick(node)
	 ---- print("HandleResponseClick called for node:", node)

	if not node then
		warn("[Dialogue] HandleResponseClick: No node provided")
		return
	end

	-- Get the current params (stored when dialogue was opened)
	local params = CurrentParams

	-- Clear responses immediately when clicked
	---- print("[Dialogue] Clearing responses after button click")
	resp:set({})
	respMode:set(false)

	-- Execute common node functions (quest actions, etc.)
	CommonNodeFunctions(node, params)

	-- Load the next nodes (outputs of this response)
	local outputNodes = GetOutputNodes(node)
	LoadNodes(outputNodes, params)
end

-- Listen for pickpocket results from server
Client.Packets.PickpocketResult.listen(function(data)
	if not data then return end

	local resultText = ""

	if data.Success then
		-- Success - show what they got
		if data.Money and data.Money > 0 then
			resultText = "You successfully pickpocketed " .. data.Money .. " Cenz"
			if data.Item then
				resultText = resultText .. " and a " .. data.Item .. "!"
			else
				resultText = resultText .. "!"
			end
		elseif data.Item then
			resultText = "You successfully pickpocketed a " .. data.Item .. "!"
		else
			resultText = "You found nothing of value..."
		end
	else
		-- Failed - guards spawning
		if data.GuardsSpawning then
			resultText = "You were caught! Guards are on their way!"
		else
			resultText = "You were caught! The NPC is now hostile."
		end
	end

	-- Update the dialogue text
	dpText:set(resultText)

	-- Guards are spawned server-side in Pickpocket.lua if data.GuardsSpawning is true

	-- Close dialogue after a short delay
	task.delay(2, function()
		if CurrentDialogueUI then
			Close(CurrentParams)
		end
	end)
end)

 ---- print("Dialogue controller initialized")
return Controller