local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local wait = task.wait
local Fusion = require(ReplicatedStorage.Modules.Fusion)
local Children, scoped, peek, out, OnEvent, Value, Computed, Tween =
	Fusion.Children, Fusion.scoped, Fusion.peek, Fusion.Out, Fusion.OnEvent, Fusion.Value, Fusion.Computed, Fusion.Tween
local RichText = require(ReplicatedStorage.Modules.RichText)
local Controller = {}
local Bridges = require(ReplicatedStorage.Modules.Bridges)
local QuestData = require(ReplicatedStorage.Modules.Quests)

local PromptTypeWaitTime = 0.0075 -- Set to 0 to remove type writer effect
local PromptWaitTime = 1

local Player = game.Players.LocalPlayer
local PlayerGui = Player.PlayerGui
local camera = game.Workspace.CurrentCamera
local QuestManager = require(ReplicatedStorage.Modules.Utils.QuestManager)

local uidisable = PlayerGui:FindFirstChild("ScreenGui")

local Client = require(ReplicatedStorage.Client)

-- Debug settings
local DEBUG_ENABLED = false
local function DebugPrint(message, ...)
	if DEBUG_ENABLED then
		print("[Dialogue Debug] " .. message, ...)
	end
end

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

function GetRootNode(Tree)
	DebugPrint("Getting root node from tree: " .. tostring(Tree))
	for _, Node in pairs(Tree:GetChildren()) do
		if Node:GetAttribute("Type") == "DialogueRoot" then
			DebugPrint("Found root node: " .. tostring(Node))
			return Node
		end
	end
	DebugPrint("No root node found in tree")
	return nil
end

function GetNodeFromValue(Value)
	DebugPrint("Getting node from value: " .. tostring(Value))
	local node = Value:FindFirstAncestorWhichIsA("Configuration")
	DebugPrint("Found node: " .. tostring(node))
	return node
end

function GetOutputNodes(InputNode)
	DebugPrint("Getting output nodes from: " .. tostring(InputNode))
	local Nodes = {}

	for _, Output in pairs(InputNode:GetDescendants()) do
		if Output.Parent.Name == "Outputs" and Output.Value ~= nil then
			local Node = GetNodeFromValue(Output.Value)
			if not table.find(Nodes, Node) then
				table.insert(Nodes, Node)
				DebugPrint("Added output node: " .. tostring(Node))
			end
		end
	end

	DebugPrint("Found " .. #Nodes .. " output nodes")
	return Nodes
end

function GetInputNodes(InputNode)
	DebugPrint("Getting input nodes from: " .. tostring(InputNode))
	local Nodes = {}

	for _, Input in pairs(InputNode:GetDescendants()) do
		if Input.Parent.Name == "Inputs" and Input.Value ~= nil then
			local Node = GetNodeFromValue(Input.Value)
			if not table.find(Nodes, Node) then
				table.insert(Nodes, Node)
				DebugPrint("Added input node: " .. tostring(Node))
			end
		end
	end

	DebugPrint("Found " .. #Nodes .. " input nodes")
	return Nodes
end

function GetInputs(Node)
	DebugPrint("Getting inputs from node: " .. tostring(Node))
	local Inputs = {}

	for _, Input in pairs(Node:GetDescendants()) do
		if Input.Parent.Name == "Inputs" and Input.Value ~= nil then
			table.insert(Inputs, Input)
			DebugPrint("Added input: " .. tostring(Input))
		end
	end

	DebugPrint("Found " .. #Inputs .. " inputs")
	return Inputs
end

function GetHighestPriorityNode(Nodes)
	DebugPrint("Getting highest priority node from " .. #Nodes .. " nodes")
	local HighestPriority = 0
	local ChosenNode = nil

	for _, Node in pairs(Nodes) do
		local priority = Node:GetAttribute("Priority") or 0
		DebugPrint("Node " .. tostring(Node) .. " has priority: " .. priority)
		if priority > HighestPriority then
			HighestPriority = priority
			ChosenNode = Node
			DebugPrint("New highest priority node: " .. tostring(Node))
		end
	end

	DebugPrint("Selected node: " .. tostring(ChosenNode))
	return ChosenNode
end

function FindNodeWithPriority(Nodes, Priority)
	DebugPrint("Finding node with priority: " .. Priority)
	for _, Node in pairs(Nodes) do
		if Node:GetAttribute("Priority") == Priority then
			DebugPrint("Found node: " .. tostring(Node))
			return Node
		end
	end
	DebugPrint("No node found with priority: " .. Priority)
	return nil
end

function GetLowestPriorityNode(Nodes)
	DebugPrint("Getting lowest priority node from " .. #Nodes .. " nodes")
	local LowestPriority = math.huge
	local ChosenNode = nil

	for _, Node in pairs(Nodes) do
		local priority = Node:GetAttribute("Priority") or math.huge
		DebugPrint("Node " .. tostring(Node) .. " has priority: " .. priority)
		if priority < LowestPriority then
			LowestPriority = priority
			ChosenNode = Node
			DebugPrint("New lowest priority node: " .. tostring(Node))
		end
	end

	DebugPrint("Selected node: " .. tostring(ChosenNode))
	return ChosenNode
end

function ClearResponses()
	DebugPrint("Clearing responses")
	if CurrentDialogueUI and CurrentDialogueUI:FindFirstChild("ResponseFrame") then
		local responseCount = 0
		for _, Response in pairs(CurrentDialogueUI.ResponseFrame:GetChildren()) do
			if Response:IsA("TextButton") and Response.Visible then
				responseCount = responseCount + 1
				Response:Destroy()
			end
		end
		DebugPrint("Cleared " .. responseCount .. " responses")
	else
		DebugPrint("No response frame found to clear")
	end
end

function FindNodeType(Nodes, Type)
	DebugPrint("Finding node of type: " .. Type)
	for _, Node in pairs(Nodes) do
		if Node:GetAttribute("Type") == Type then
			DebugPrint("Found node: " .. tostring(Node))
			return Node
		end
	end
	DebugPrint("No node found of type: " .. Type)
	return nil
end

function FindInput(Inputs, Name)
	DebugPrint("Finding input with name: " .. Name)
	for _, Input in pairs(Inputs) do
		if Input.Value and Input.Value.Name == Name then
			DebugPrint("Found input: " .. tostring(Input))
			return Input.Value
		end
	end
	DebugPrint("No input found with name: " .. Name)
	return nil
end

function FireEvents(Node)
	DebugPrint("Firing events for node: " .. tostring(Node))
	local eventCount = 0
	for _, Event in pairs(Node:GetChildren()) do
		if Event:IsA("RemoteEvent") then
			DebugPrint("Firing remote event: " .. tostring(Event))
			Event:FireServer(Node)
			eventCount = eventCount + 1
		elseif Event:IsA("BindableEvent") then
			DebugPrint("Firing bindable event: " .. tostring(Event))
			Event:Fire(Node)
			eventCount = eventCount + 1
		end
	end
	DebugPrint("Fired " .. eventCount .. " events")
end

function RunCommands(Node, Params)
	DebugPrint("Running commands for node: " .. tostring(Node))
	local commandCount = 0
	for _, InputNode in pairs(GetInputNodes(Node)) do
		if InputNode:GetAttribute("Type") ~= "Condition" and InputNode:FindFirstChildWhichIsA("ModuleScript") then
			if #GetInputs(InputNode) <= 0 then
				local Function = require(InputNode:FindFirstChildWhichIsA("ModuleScript"))
				DebugPrint("Running command: " .. tostring(InputNode:FindFirstChildWhichIsA("ModuleScript")))
				if Function.Run then
					Close(Params)
					Function.Run()
					commandCount = commandCount + 1
				end
			end
		end
	end
	DebugPrint("Ran " .. commandCount .. " commands")
end

function CheckForCondition(Node)
	DebugPrint("Checking conditions for node: " .. tostring(Node))
	local conditionCount = 0
	for _, InputNode in pairs(GetInputNodes(Node)) do
		if InputNode:GetAttribute("Type") == "Condition" and InputNode:FindFirstChildWhichIsA("ModuleScript") then
			if #GetInputs(InputNode) <= 0 then
				local Function = require(InputNode:FindFirstChildWhichIsA("ModuleScript"))
				DebugPrint("Checking condition: " .. tostring(InputNode:FindFirstChildWhichIsA("ModuleScript")))
				if Function.Run then
					local result = Function.Run()
					DebugPrint("Condition result: " .. tostring(result))
					if result ~= Node:GetAttribute("Priority") then
						DebugPrint("Condition failed, skipping node")
						return true
					end
				end
				conditionCount = conditionCount + 1
			end
		end
	end
	DebugPrint("Checked " .. conditionCount .. " conditions, all passed")
	return false
end

function ToggleLock(Node)
	DebugPrint("Toggling lock for node: " .. tostring(Node))
	local toggleCount = 0
	for _, Input in pairs(GetInputs(Node)) do
		if Input.Value and Input.Value.Name == "Toggle" then
			DebugPrint("Toggling input: " .. tostring(Input.Value))
			Input.Value.Value = not Input.Value.Value
			toggleCount = toggleCount + 1
		end
	end
	DebugPrint("Toggled " .. toggleCount .. " locks")
end

function IsLocked(Node)
	DebugPrint("Checking if node is locked: " .. tostring(Node))
	local LockNode = FindNodeType(GetInputNodes(Node), "Lock")

	if LockNode and LockNode.Toggle and LockNode.Toggle.Value == true then
		local LockFound = false

		for _, Input in pairs(GetInputs(Node)) do
			if Input.Value and Input.Value.Name == "MainPathway" and Input.Value.Parent == LockNode then
				LockFound = true
				DebugPrint("Node is locked")
				break
			end
		end

		return LockFound
	else
		DebugPrint("Node is not locked")
		return false
	end
end

function RunInternalCommands(Node)
	DebugPrint("Running internal commands for node: " .. tostring(Node))
	if Node:FindFirstChildWhichIsA("ModuleScript") then
		local moduleScript = Node:FindFirstChildWhichIsA("ModuleScript")
		DebugPrint("Found module script: " .. tostring(moduleScript))
		local Function = require(moduleScript)
		if Function.Run then
			DebugPrint("Running internal command")
			Function.Run()
		else
			DebugPrint("ERROR: Module found inside a node does not have a .Run function!")
			error("Module found inside a node does not have a .Run function!")
		end
	else
		DebugPrint("No internal commands found")
	end
end

function CommonNodeFunctions(Node, Params)
	DebugPrint("Running common functions for node: " .. tostring(Node))
	RunCommands(Node, Params)
	ToggleLock(Node)
	FireEvents(Node)
	RunInternalCommands(Node)
end

function CreateResponseButton(Node, Params)
	DebugPrint("Creating response button for node: " .. tostring(Node))
	if not CurrentDialogueUI or not CurrentDialogueUI:FindFirstChild("ResponseFrame") then
		DebugPrint("ERROR: No response frame found")
		return
	end

	local ResponseFrame = CurrentDialogueUI.ResponseFrame

	local NewResponse = Instance.new("TextButton")
	NewResponse.Name = "Response"
	NewResponse.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	NewResponse.BackgroundTransparency = 1
	NewResponse.BorderSizePixel = 0
	NewResponse.Size = UDim2.new(1, 0, 0, 40)
	NewResponse.Text = ""
	NewResponse.TextColor3 = Color3.fromRGB(255, 255, 255)
	NewResponse.TextSize = 14
	NewResponse.LayoutOrder = Node:GetAttribute("Priority") or 0
	NewResponse.Parent = ResponseFrame

	-- Add styling elements similar to your Fusion component
	local Background = Instance.new("ImageLabel")
	Background.Name = "Background"
	Background.Image = "rbxassetid://85774200010476"
	Background.ScaleType = Enum.ScaleType.Slice
	Background.SliceCenter = Rect.new(10, 17, 561, 274)
	Background.BackgroundTransparency = 1
	Background.Size = UDim2.new(1, 0, 1, 0)
	Background.Parent = NewResponse

	local Border = Instance.new("ImageLabel")
	Border.Name = "Border"
	Border.Image = "rbxassetid://121279258155271"
	Border.BackgroundTransparency = 1
	Border.Size = UDim2.new(1, 0, 1, 0)
	Border.Parent = NewResponse

	local TextLabel = Instance.new("TextLabel")
	TextLabel.Name = "Text"
	TextLabel.BackgroundTransparency = 1
	TextLabel.Size = UDim2.new(1, -20, 1, 0)
	TextLabel.Position = UDim2.new(0, 10, 0, 0)
	TextLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	TextLabel.TextSize = 14
	TextLabel.TextWrapped = true
	TextLabel.TextXAlignment = Enum.TextXAlignment.Left
	TextLabel.Font = Enum.Font.SourceSans
	TextLabel.Text = Node.Text and Node.Text.Value or "No text"
	TextLabel.Parent = NewResponse

	NewResponse.Activated:Connect(function()
		DebugPrint("Response button activated: " .. tostring(Node))
		CommonNodeFunctions(Node, Params)
		LoadNodes(GetOutputNodes(Node), Params)
	end)

	DebugPrint("Response button created successfully")
	return NewResponse
end

function LoadNode(Node, Params)
	local Type = Node:GetAttribute("Type") or "Unknown"
	DebugPrint("Loading node: " .. tostring(Node) .. " of type: " .. Type)

	if IsLocked(Node) then
		DebugPrint("Node is locked, skipping")
		return
	end

	if not CurrentDialogueUI then
		DebugPrint("ERROR: No dialogue UI found")
		return
	end

	if CheckForCondition(Node) then
		DebugPrint("Condition check failed, skipping node")
		return
	end

	if Node.Name == "Accept" and Params then
			QuestManager.acceptQuest(Player, Params.name, "Missing Pocketwatch")

			pendingQuest = {
				npcName = Params.name,
				questName = "Missing Pocketwatch",
			}
			
		end

	if Type == "Response" then
		DebugPrint("Loading response node")
		CreateResponseButton(Node, Params)
	elseif Type == "Prompt" then
		DebugPrint("Loading prompt node")
		CommonNodeFunctions(Node, Params)

		-- Update the dialogue UI with the new text


		if CurrentDialogueUI then
			local textLabel = CurrentDialogueUI:FindFirstChild("Text", true)
			local npcNameLabel = CurrentDialogueUI:FindFirstChild("NPCName", true)

			if textLabel and Node.Text then
				DebugPrint("Updating text label with: " .. Node.Text.Value)
				RichText.ClearText(textLabel)
				dpText:set("")
				task.wait(1)
				dpText:set(Node.Text.Value)
				-- RichText.AnimateText(Node.Text.Value, textLabel, 0.05, Enum.Font.SourceSans, "fade diverge", 1, 14)
			else
				DebugPrint("WARNING: Text label or node text not found")
			end

			if npcNameLabel then
				DebugPrint("Updating NPC name to: " .. (CurrentParams and CurrentParams.name or "?"))
				npcNameLabel.Text = CurrentParams and CurrentParams.name or "?"
			else
				DebugPrint("WARNING: NPC name label not found")
			end
		end

		DebugPrint("Waiting " .. PromptWaitTime .. " seconds before loading next nodes")
		task.wait(PromptWaitTime)
		LoadNodes(GetOutputNodes(Node), Params)
	elseif Node:FindFirstChildWhichIsA("ModuleScript") then
		DebugPrint("Loading module node")
		CommonNodeFunctions(Node, Params)
		FireEvents(Node)
		LoadNodes(GetOutputNodes(Node), Params)
	else
		DebugPrint("WARNING: Unknown node type: " .. Type)
	end
end

function Close(Params)
	DebugPrint("Closing dialogue")
	if CurrentDialogueUI then
		DebugPrint("Destroying current dialogue UI")
		CurrentDialogueUI:Destroy()
		CurrentDialogueUI = nil
	else
		DebugPrint("No current dialogue UI to destroy")
	end

	uidisable.Enabled = true
	CurrentParams = nil
	-- scope:doCleanup()

	if pendingQuest then
		DebugPrint("Showing quest popup after dialogue close")
		task.wait(0.5)
		ShowQuestPopup(pendingQuest.npcName, pendingQuest.questName)
		pendingQuest = nil
	end

	DebugPrint("Dialogue closed")
end

function GetResponses(Nodes)
	DebugPrint("Getting responses from " .. #Nodes .. " nodes")
	local responseData = {}

	for _, Node in (Nodes or {}) do
		if Node:GetAttribute("Type") == "Response" and not IsLocked(Node) and not CheckForCondition(Node) then
			local responseText = Node.Text and Node.Text.Value or "No text"
			local priority = Node:GetAttribute("Priority") or 0

			table.insert(responseData, {
				text = responseText,
				order = priority,
				node = Node,
			})
			DebugPrint("Added response: " .. responseText .. " (priority: " .. priority .. ")")
		end
	end

	table.sort(responseData, function(a, b)
		return a.order < b.order
	end)

	DebugPrint("Found " .. #responseData .. " responses")
	return responseData
end

function LoadNodes(Nodes, Params)
	DebugPrint("Loading " .. #Nodes .. " nodes")
	if #Nodes <= 0 then
		DebugPrint("No nodes to load, closing dialogue")
		Close(Params)
	else
		local responseNodes = {}
		for _, Node in Nodes do
			if Node:GetAttribute("Type") == "Response" then
				table.insert(responseNodes, Node)
			end
		end
		resp:set(GetResponses(responseNodes))

		if not peek(respMode) then
			print("Setting response mode to true")
			respMode:set(true)
		end

		ClearResponses()
		for _, Node in pairs(Nodes) do
			LoadNode(Node, Params)
		end
	end
end

function ShowQuestPopup(npcName, questName)
	DebugPrint("Showing quest popup for: " .. npcName .. " - " .. questName)

	local questData = QuestData[npcName][questName]
	if not questData then
		DebugPrint("ERROR: Quest data not found for: " .. npcName .. " - " .. questName)
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

	print("Sending quest packet")
			Client.Packets.Quests.send({
				Module = "Magnus",
				Function = "Start",
				Arguments = {},
			})

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
	DebugPrint("OnEvent triggered with params: " .. tostring(Params))
	if CurrentDialogueUI then
		DebugPrint("Dialogue UI already active, ignoring event")
		return
	end

	if not Params or not Params.name then
		DebugPrint("ERROR: Invalid parameters received")
		return
	end

	DebugPrint("Looking for dialogue tree: " .. Params.name)
	local DialogueTree = ReplicatedStorage.Dialogues:FindFirstChild(tostring(Params.name))

	if not DialogueTree then
		DebugPrint("ERROR: Dialogue tree not found: " .. Params.name)
		return
	end

	local RootNode = GetRootNode(DialogueTree)

	if not RootNode then
		DebugPrint("ERROR: Root node not found in dialogue tree")
		return
	end

	if uidisable then
		uidisable.Enabled = false
	end

	-- Create the new Fusion-based UI
	DebugPrint("Creating Fusion dialogue UI")

	local Target = scope:New("ScreenGui")({
		Name = "DialogueHolder",
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = Player.PlayerGui,
	})

	local parent = Target

	-- Store the created UI
	scope:Dialogue({
		displayText = dpText or "",
		npcname = Params.name,
		start = begin,
		Parent = parent,
		fade = fadein,
		responses = resp,
		responseMode = respMode,
	})

	-- Find the actual UI instance in the player's GUI
	CurrentDialogueUI = parent:FindFirstChild("Frame") -- Adjust this based on your actual UI structure
	DebugPrint("Dialogue UI created: " .. tostring(CurrentDialogueUI))

	task.wait(1)

	DebugPrint("Starting fade animation")
	fadein:set(true)
	begin:set(true)

	CurrentParams = Params or {}
	DebugPrint("Current params set: " .. tostring(CurrentParams))

	for _, Condition in pairs(DialogueTree:GetChildren()) do
		if Condition:GetAttribute("Type") == "Condition" then
			DebugPrint("Resetting condition: " .. tostring(Condition))
			Condition:SetAttribute("ReturnedValue", nil)
		end
	end

	LoadNodes(GetOutputNodes(RootNode), Params)
end

function Controller:Start(data)
	DebugPrint("Controller Start called with data: " .. tostring(data))
	OnEvent(data)
end

-- Add a function to toggle debugging
function Controller:SetDebugging(enabled)
	DEBUG_ENABLED = enabled
	DebugPrint("Debugging " .. (enabled and "enabled" or "disabled"))
end

DebugPrint("Dialogue controller initialized")
return Controller
