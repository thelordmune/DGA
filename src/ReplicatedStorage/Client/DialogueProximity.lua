--[[
	Dialogue Proximity Module

	Replaces the ECS dialogue checker with a straightforward proximity detection
	Shows Prompt UI on a SurfaceGui next to NPCs
]]

local DialogueProximity = {}
local CSystem = require(script.Parent)

local TweenService = CSystem.Service.TweenService
local ReplicatedStorage = CSystem.Service.ReplicatedStorage
local Players = CSystem.Service.Players

local Fusion = require(ReplicatedStorage.Modules.Fusion)
local scoped = Fusion.scoped

-- Pre-require ECS modules once at load time
local world = require(ReplicatedStorage.Modules.ECS.jecs_world)
local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)
local ref = require(ReplicatedStorage.Modules.ECS.jecs_ref)

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()

-- Settings
local DETECTION_RANGE = 10
local CHECK_INTERVAL = 0.5

-- State tracking
local currentNearbyNPC = nil
local currentHighlight = nil
local promptScope = nil
local promptStarted = nil
local promptFadeIn = nil
local promptTextStart = nil

local function isWandererNPC(npc)
	local hrp = npc:FindFirstChild("HumanoidRootPart")
	if hrp and hrp:GetAttribute("IsWandererNPC") then
		return true
	end
	return npc.Name:lower():find("wanderer") ~= nil
end

local function getWandererIdentity(npc)
	return {
		name = npc:GetAttribute("NPCName") or npc.Name,
		occupation = npc:GetAttribute("Occupation") or "",
		occupationType = npc:GetAttribute("OccupationType") or "Civilian",
		personality = npc:GetAttribute("Personality") or "Professional",
	}
end

local function getRelationshipTier(npc)
	return npc:GetAttribute("RelationshipTier") or "Stranger"
end

local function createPromptUI(npc)
	if promptScope then
		promptScope:doCleanup()
	end

	local isWanderer = isWandererNPC(npc)
	local guiParent

	if isWanderer then
		local hrp = npc:FindFirstChild("HumanoidRootPart")
		if not hrp then return end

		local existingGui = hrp:FindFirstChild("WandererPromptGui")
		if existingGui then
			existingGui:Destroy()
		end

		local billboardGui = Instance.new("BillboardGui")
		billboardGui.Name = "WandererPromptGui"
		billboardGui.Adornee = hrp
		billboardGui.Size = UDim2.fromOffset(200, 200)
		billboardGui.StudsOffset = Vector3.new(0, 4, 0)
		billboardGui.AlwaysOnTop = true
		billboardGui.MaxDistance = 15
		billboardGui.Parent = hrp

		guiParent = billboardGui
	else
		local head = npc:FindFirstChild("Torso") and npc:FindFirstChild("Torso"):FindFirstChild("Part")
		local surfaceGui = head and head:FindFirstChild("PromptSurfaceGui")
		if not surfaceGui and head then
			surfaceGui = Instance.new("SurfaceGui")
			surfaceGui.Name = "PromptSurfaceGui"
			surfaceGui.Face = Enum.NormalId.Front
			surfaceGui.Parent = head
			surfaceGui.AlwaysOnTop = true
			surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			surfaceGui.PixelsPerStud = 50
		end

		guiParent = surfaceGui
	end

	if not guiParent then return end

	promptScope = scoped(Fusion, {
		Prompt = require(ReplicatedStorage.Client.Components.Prompt),
	})

	promptStarted = promptScope:Value(false)
	promptFadeIn = promptScope:Value(false)
	promptTextStart = promptScope:Value(false)

	local npcDisplayName = npc.Name
	local occupation = ""
	local relationshipTier = "Stranger"

	if isWanderer then
		local identity = getWandererIdentity(npc)
		npcDisplayName = identity.name
		occupation = identity.occupation
		relationshipTier = getRelationshipTier(npc)
	end

	promptScope:Prompt({
		begin = promptStarted,
		fadein = promptFadeIn,
		textstart = promptTextStart,
		npcName = npcDisplayName,
		occupation = occupation,
		relationshipTier = relationshipTier,
		isWanderer = isWanderer,
		Parent = guiParent,
	})
end

local function showPromptUI()
	if promptStarted then
		promptStarted:set(true)
	end
end

local function hidePromptUI()
	if promptStarted then
		promptStarted:set(false)
	end
end

local function addHighlight(npc)
	if currentHighlight then
		currentHighlight:Destroy()
	end

	local highlight = Instance.new("Highlight")
	highlight.Name = "DialogueHighlight"
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.FillTransparency = 1
	highlight.OutlineTransparency = 1
	highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
	highlight.Parent = npc

	local tween = TweenService:Create(
		highlight,
		TweenInfo.new(0.5, Enum.EasingStyle.Circular, Enum.EasingDirection.Out),
		{OutlineTransparency = 0}
	)
	tween:Play()

	currentHighlight = highlight
end

local function removeHighlight()
	if not currentHighlight then return end

	local tween = TweenService:Create(
		currentHighlight,
		TweenInfo.new(0.5, Enum.EasingStyle.Circular, Enum.EasingDirection.Out),
		{OutlineTransparency = 1}
	)
	tween:Play()
	tween.Completed:Connect(function()
		if currentHighlight then
			currentHighlight:Destroy()
			currentHighlight = nil
		end
	end)
end

local function findNearbyNPC()
	if not character then return nil end

	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")

	if not root or not humanoid or humanoid.Health <= 0 then
		return nil
	end

	local playerPos = root.Position
	local closestNPC = nil
	local closestDistanceSq = DETECTION_RANGE * DETECTION_RANGE -- Use squared distance to avoid sqrt

	local dialogueFolder = workspace.World:FindFirstChild("Dialogue")
	if dialogueFolder then
		for _, npc in dialogueFolder:GetChildren() do
			local npcRoot = npc:FindFirstChild("HumanoidRootPart")
			if npcRoot then
				local offset = playerPos - npcRoot.Position
				local distanceSq = offset.X * offset.X + offset.Y * offset.Y + offset.Z * offset.Z
				if distanceSq <= closestDistanceSq then
					closestNPC = npc
					closestDistanceSq = distanceSq
				end
			end
		end
	end

	-- Only check Live folder for wanderer NPCs using GetChildren on direct children
	-- This avoids expensive GetDescendants call
	local liveFolder = workspace.World:FindFirstChild("Live")
	if liveFolder then
		for _, child in liveFolder:GetChildren() do
			if child:IsA("Model") then
				local npcRoot = child:FindFirstChild("HumanoidRootPart")
				if npcRoot and isWandererNPC(child) then
					local offset = playerPos - npcRoot.Position
					local distanceSq = offset.X * offset.X + offset.Y * offset.Y + offset.Z * offset.Z
					if distanceSq <= closestDistanceSq then
						closestNPC = child
						closestDistanceSq = distanceSq
					end
				end
			elseif child:IsA("Folder") then
				-- Check one level deep into subfolders
				for _, subChild in child:GetChildren() do
					if subChild:IsA("Model") then
						local npcRoot = subChild:FindFirstChild("HumanoidRootPart")
						if npcRoot and isWandererNPC(subChild) then
							local offset = playerPos - npcRoot.Position
							local distanceSq = offset.X * offset.X + offset.Y * offset.Y + offset.Z * offset.Z
							if distanceSq <= closestDistanceSq then
								closestNPC = subChild
								closestDistanceSq = distanceSq
							end
						end
					end
				end
			end
		end
	end

	return closestNPC
end

local function updateProximity()
	local nearbyNPC = findNearbyNPC()

	if nearbyNPC ~= currentNearbyNPC then
		if nearbyNPC then
			addHighlight(nearbyNPC)
			createPromptUI(nearbyNPC)
			showPromptUI()

			if character then
				character:SetAttribute("Commence", true)
				character:SetAttribute("NearbyNPC", nearbyNPC.Name)
			end

			pcall(function()
				local pent = ref.get("local_player")
				if pent then
					local dialogueComp = world:get(pent, comps.Dialogue)
					if dialogueComp then
						dialogueComp.inrange = true
						dialogueComp.npc = nearbyNPC
						dialogueComp.name = nearbyNPC.Name
						world:set(pent, comps.Dialogue, dialogueComp)
					end
				end
			end)
		else
			removeHighlight()
			hidePromptUI()

			if character then
				character:SetAttribute("Commence", false)
				character:SetAttribute("NearbyNPC", nil)
			end

			pcall(function()
				local pent = ref.get("local_player")
				if pent then
					local dialogueComp = world:get(pent, comps.Dialogue)
					if dialogueComp then
						dialogueComp.inrange = false
						dialogueComp.npc = nil
						dialogueComp.name = "none"
						world:set(pent, comps.Dialogue, dialogueComp)
					end
				end
			end)
		end

		currentNearbyNPC = nearbyNPC
	end
end

local function cleanup()
	if currentHighlight then
		currentHighlight:Destroy()
		currentHighlight = nil
	end
	if promptScope then
		promptScope:doCleanup()
		promptScope = nil
		promptStarted = nil
		promptFadeIn = nil
		promptTextStart = nil
	end
	currentNearbyNPC = nil

	if character then
		character:SetAttribute("Commence", false)
		character:SetAttribute("NearbyNPC", nil)
	end
end

-- Initialize
task.spawn(function()
	repeat task.wait() until game:IsLoaded()

	player.CharacterAdded:Connect(function(newCharacter)
		character = newCharacter
		cleanup()
	end)

	-- Use a simple task loop instead of Heartbeat for interval checks
	-- This is more efficient as it doesn't run every frame
	task.spawn(function()
		while true do
			task.wait(CHECK_INTERVAL)
			updateProximity()
		end
	end)

	_G.DialogueProximity_HidePrompt = hidePromptUI
	_G.DialogueProximity_Cleanup = cleanup

	task.wait(1)
	updateProximity()
end)

return DialogueProximity
