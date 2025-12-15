--[[
	Dialogue Builder
	
	Converts clean module-based dialogue definitions into Configuration structures
	that the existing dialogue system can read.
	
	Usage:
		local DialogueBuilder = require(ReplicatedStorage.Modules.Utils.DialogueBuilder)
		DialogueBuilder.BuildAll() -- Builds all dialogue from DialogueData folder
		
	Or for a specific NPC:
		DialogueBuilder.BuildDialogue("Magnus")
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DialogueBuilder = {}

-- Create the Dialogues folder if it doesn't exist
local function getDialoguesFolder()
	local dialoguesFolder = ReplicatedStorage:FindFirstChild("Dialogues")
	if not dialoguesFolder then
		dialoguesFolder = Instance.new("Folder")
		dialoguesFolder.Name = "Dialogues"
		dialoguesFolder.Parent = ReplicatedStorage
	end
	return dialoguesFolder
end

-- Create a dialogue node (Configuration)
local function createNode(nodeData, parentFolder)
	local node = Instance.new("Configuration")
	node.Name = nodeData.Name
	node.Parent = parentFolder
	
	-- Set attributes
	if nodeData.Type then
		node:SetAttribute("Type", nodeData.Type)
	end

	if nodeData.Priority then
		node:SetAttribute("Priority", nodeData.Priority)
	end

	if nodeData.AutoClose then
		node:SetAttribute("AutoClose", nodeData.AutoClose)
	end
	
	-- Add text if present
	if nodeData.Text then
		local textValue = Instance.new("StringValue")
		textValue.Name = "Text"
		textValue.Value = nodeData.Text
		textValue.Parent = node
	end
	
	-- Create Inputs folder
	local inputsFolder = Instance.new("Folder")
	inputsFolder.Name = "Inputs"
	inputsFolder.Parent = node
	
	-- Create Outputs folder
	local outputsFolder = Instance.new("Folder")
	outputsFolder.Name = "Outputs"
	outputsFolder.Parent = node
	
	-- Add quest data if present
	if nodeData.Quest then
		local questFolder = Instance.new("Folder")
		questFolder.Name = "Quest"
		questFolder.Parent = node

		-- Store quest data as attributes for easier access
		if nodeData.Quest.Action then
			questFolder:SetAttribute("Action", nodeData.Quest.Action)
		end

		if nodeData.Quest.QuestName then
			questFolder:SetAttribute("QuestName", nodeData.Quest.QuestName)
		end
	end
	
	-- Store condition data for later (will be created as separate node and connected)
	if nodeData.Condition then
		node:SetAttribute("_ConditionModule", nodeData.Condition.Module)
		if nodeData.Condition.Args and #nodeData.Condition.Args > 0 then
			node:SetAttribute("_ConditionArgs", table.concat(nodeData.Condition.Args, ","))
		end
	end
	
	-- Handle responses (for Response type nodes)
	if nodeData.Responses then
		for i, response in ipairs(nodeData.Responses) do
			local responseNode = Instance.new("Configuration")
			responseNode.Name = "Response" .. i
			responseNode:SetAttribute("Type", "Response")
			responseNode:SetAttribute("Priority", i - 1)
			responseNode.Parent = node
			
			-- Add response text
			local responseText = Instance.new("StringValue")
			responseText.Name = "Text"
			responseText.Value = response.Text
			responseText.Parent = responseNode
			
			-- Create outputs folder for response
			local responseOutputsFolder = Instance.new("Folder")
			responseOutputsFolder.Name = "Outputs"
			responseOutputsFolder.Parent = responseNode
			
			-- Store output names for later connection
			responseNode:SetAttribute("_OutputNames", table.concat(response.Outputs or {}, ","))
		end
	end
	
	-- Store output names for later connection (after all nodes are created)
	if nodeData.Outputs then
		node:SetAttribute("_OutputNames", table.concat(nodeData.Outputs, ","))
	end
	
	return node
end

-- Connect nodes after all are created
local function connectNodes(dialogueFolder)
	for _, node in ipairs(dialogueFolder:GetChildren()) do
		if node:IsA("Configuration") then
			-- Create condition node if needed
			local conditionModule = node:GetAttribute("_ConditionModule")
			if conditionModule then
				local conditionNode = Instance.new("Configuration")
				conditionNode.Name = "Condition_" .. node.Name
				conditionNode:SetAttribute("Type", "Condition")
				conditionNode:SetAttribute("Priority", node:GetAttribute("Priority") or 0)
				conditionNode:SetAttribute("ModuleName", conditionModule)

				local conditionArgs = node:GetAttribute("_ConditionArgs")
				if conditionArgs then
					conditionNode:SetAttribute("Args", conditionArgs)
				end

				-- Create Inputs folder for condition node
				local conditionInputsFolder = Instance.new("Folder")
				conditionInputsFolder.Name = "Inputs"
				conditionInputsFolder.Parent = conditionNode

				conditionNode.Parent = dialogueFolder

				-- Connect condition as input to the dialogue node
				local nodeInputsFolder = node:FindFirstChild("Inputs")
				if nodeInputsFolder then
					local inputValue = Instance.new("ObjectValue")
					inputValue.Name = "Input" .. #nodeInputsFolder:GetChildren() + 1
					inputValue.Value = conditionNode
					inputValue.Parent = nodeInputsFolder
				end

				-- Clean up temporary attributes
				node:SetAttribute("_ConditionModule", nil)
				node:SetAttribute("_ConditionArgs", nil)
			end

			local outputNames = node:GetAttribute("_OutputNames")
			if outputNames and outputNames ~= "" then
				local outputsFolder = node:FindFirstChild("Outputs")
				if outputsFolder then
					local outputs = string.split(outputNames, ",")
					for i, outputName in ipairs(outputs) do
						local targetNode = dialogueFolder:FindFirstChild(outputName)
						if targetNode then
							local outputValue = Instance.new("ObjectValue")
							outputValue.Name = "Output" .. i
							outputValue.Value = targetNode
							outputValue.Parent = outputsFolder

							-- Also create input reference in target node
							local targetInputsFolder = targetNode:FindFirstChild("Inputs")
							if targetInputsFolder then
								local inputValue = Instance.new("ObjectValue")
								inputValue.Name = "Input" .. #targetInputsFolder:GetChildren() + 1
								inputValue.Value = node
								inputValue.Parent = targetInputsFolder
							end
						else
							warn("[DialogueBuilder] Output node not found:", outputName, "for node:", node.Name)
						end
					end
				end

				-- Clean up temporary attribute
				node:SetAttribute("_OutputNames", nil)
			end
			
			-- Connect response nodes
			for _, child in ipairs(node:GetChildren()) do
				if child:IsA("Configuration") and child:GetAttribute("Type") == "Response" then
					local responseOutputNames = child:GetAttribute("_OutputNames")
					if responseOutputNames and responseOutputNames ~= "" then
						local responseOutputsFolder = child:FindFirstChild("Outputs")
						if responseOutputsFolder then
							local outputs = string.split(responseOutputNames, ",")
							for i, outputName in ipairs(outputs) do
								local targetNode = dialogueFolder:FindFirstChild(outputName)
								if targetNode then
									local outputValue = Instance.new("ObjectValue")
									outputValue.Name = "Output" .. i
									outputValue.Value = targetNode
									outputValue.Parent = responseOutputsFolder
								end
							end
						end
						
						-- Clean up temporary attribute
						child:SetAttribute("_OutputNames", nil)
					end
				end
			end
		end
	end
end

-- Build dialogue for a specific NPC
function DialogueBuilder.BuildDialogue(npcName)
	---- print("[DialogueBuilder] Building dialogue for:", npcName)
	
	-- Load the dialogue data module
	local dialogueDataFolder = ReplicatedStorage.Modules:FindFirstChild("DialogueData")
	if not dialogueDataFolder then
		warn("[DialogueBuilder] DialogueData folder not found!")
		return false
	end
	
	local dialogueModule = dialogueDataFolder:FindFirstChild(npcName)
	if not dialogueModule then
		warn("[DialogueBuilder] Dialogue module not found for:", npcName)
		return false
	end
	
	local success, dialogueData = pcall(require, dialogueModule)
	if not success then
		warn("[DialogueBuilder] Failed to load dialogue module:", npcName, dialogueData)
		return false
	end
	
	-- Get or create dialogues folder
	local dialoguesFolder = getDialoguesFolder()
	
	-- Remove existing dialogue if it exists
	local existingDialogue = dialoguesFolder:FindFirstChild(npcName)
	if existingDialogue then
		existingDialogue:Destroy()
	end
	
	-- Create new dialogue folder
	local npcDialogueFolder = Instance.new("Folder")
	npcDialogueFolder.Name = npcName
	npcDialogueFolder.Parent = dialoguesFolder
	
	-- Create all nodes
	for _, nodeData in ipairs(dialogueData.Nodes) do
		createNode(nodeData, npcDialogueFolder)
	end
	
	-- Connect all nodes
	connectNodes(npcDialogueFolder)
	
	---- print("[DialogueBuilder] ✅ Successfully built dialogue for:", npcName)
	return true
end

-- Build all dialogues from DialogueData folder
function DialogueBuilder.BuildAll()
	---- print("[DialogueBuilder] Building all dialogues...")
	
	local dialogueDataFolder = ReplicatedStorage.Modules:FindFirstChild("DialogueData")
	if not dialogueDataFolder then
		warn("[DialogueBuilder] DialogueData folder not found!")
		return
	end
	
	local builtCount = 0
	for _, dialogueModule in ipairs(dialogueDataFolder:GetChildren()) do
		if dialogueModule:IsA("ModuleScript") then
			if DialogueBuilder.BuildDialogue(dialogueModule.Name) then
				builtCount = builtCount + 1
			end
		end
	end
	
	---- print("[DialogueBuilder] ✅ Built", builtCount, "dialogue trees")
end

return DialogueBuilder

