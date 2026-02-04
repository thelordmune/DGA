--[[
    Dialogue Proximity Module

    Replaces the ECS dialogue checker with a straightforward proximity detection
    Shows Prompt UI on a SurfaceGui next to NPCs
]]

local DialogueProximity = {}
local CSystem = require(script.Parent)

-- local TweenService = CSystem.Service.TweenService
local ReplicatedStorage = CSystem.Service.ReplicatedStorage
local Players = CSystem.Service.Players

local Fusion = require(ReplicatedStorage.Modules.Fusion)
local scoped = Fusion.scoped

-- Pre-require ECS modules once at load time
local world = require(ReplicatedStorage.Modules.ECS.jecs_world)
local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)
local ref = require(ReplicatedStorage.Modules.ECS.jecs_ref)

-- PERFORMANCE: Pre-require Prompt component at load time, not inside function
local PromptComponent = require(ReplicatedStorage.Client.Components.Prompt)

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()

-- Settings
local DETECTION_RANGE = 10
local CHECK_INTERVAL = 0.5

-- ⚡ PERFORMANCE: Cache dialogue folder reference
local cachedDialogueFolder = nil

-- State tracking
local currentNearbyNPC = nil
local currentHighlight = nil
local promptScope = nil
local promptStarted = nil
local promptFadeIn = nil
local promptTextStart = nil

-- ⚡ PERFORMANCE OPTIMIZATION: Store task thread for cleanup
local proximityThread = nil

local function createPromptUI(npc)
    if promptScope then
        promptScope:doCleanup()
        promptScope = nil
    end

    local primaryPart = npc.PrimaryPart or npc:FindFirstChild("HumanoidRootPart")
    if not primaryPart then
        return
    end

    -- Find or create a SurfaceGui
    local surfaceGui = primaryPart:FindFirstChild("PromptSurfaceGui")
    if not surfaceGui then
        surfaceGui = Instance.new("SurfaceGui")
        surfaceGui.Name = "PromptSurfaceGui"
        surfaceGui.Face = Enum.NormalId.Top
        surfaceGui.Parent = primaryPart
        surfaceGui.AlwaysOnTop = true
        surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
        surfaceGui.PixelsPerStud = 50
    end

    -- Create Fusion scope with Prompt component (using pre-required module)
    promptScope = scoped(Fusion, {
        Prompt = PromptComponent,
    })

    -- Create reactive values
    promptStarted = promptScope:Value(false)
    promptFadeIn = promptScope:Value(0)
    promptTextStart = promptScope:Value(false)

    -- Create the prompt component
    promptScope.Prompt(promptScope, {
        Parent = surfaceGui,
        Started = promptStarted,
        FadeIn = promptFadeIn,
        TextStart = promptTextStart,
    })
end

local function showPromptUI()
    if promptStarted then
        promptStarted:set(true)
        task.wait(0.1)
        promptFadeIn:set(1)
        task.wait(0.3)
        promptTextStart:set(true)
    end
end

local function hidePromptUI()
    if promptStarted then
        promptTextStart:set(false)
        task.wait(0.1)
        promptFadeIn:set(0)
        task.wait(0.3)
        promptStarted:set(false)
    end
end

local function addHighlight(npc)
    if currentHighlight then
        currentHighlight:Destroy()
    end

    local highlight = Instance.new("Highlight")
    highlight.Name = "DialogueHighlight"
    highlight.Adornee = npc
    highlight.FillColor = Color3.fromRGB(255, 255, 150)
    highlight.OutlineColor = Color3.fromRGB(255, 255, 100)
    highlight.FillTransparency = 0.7
    highlight.OutlineTransparency = 0.3
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Parent = npc

    currentHighlight = highlight
end

local function removeHighlight()
    if currentHighlight then
        currentHighlight:Destroy()
        currentHighlight = nil
    end
end

local function findClosestNPC()
    if not character or not character.Parent then
        return nil
    end

    -- Try PrimaryPart first, then HumanoidRootPart as fallback
    local root = character.PrimaryPart or character:FindFirstChild("HumanoidRootPart")
    if not root then
        return nil
    end

    local playerPos = root.Position
    local closestNPC = nil
    local closestDistanceSq = DETECTION_RANGE * DETECTION_RANGE -- Use squared distance to avoid sqrt

    -- ⚡ PERFORMANCE: Use cached folder reference, but validate it still exists
    if not cachedDialogueFolder or not cachedDialogueFolder.Parent then
        cachedDialogueFolder = workspace:FindFirstChild("World") and workspace.World:FindFirstChild("Dialogue")
    end

    if cachedDialogueFolder then
        for _, npc in cachedDialogueFolder:GetChildren() do
            -- Check for HumanoidRootPart or PrimaryPart on NPC
            local npcRoot = npc:FindFirstChild("HumanoidRootPart") or npc.PrimaryPart
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

    return closestNPC
end

local function updateProximity()
    local nearbyNPC = findClosestNPC()

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
    -- ⚡ PERFORMANCE OPTIMIZATION: Cancel proximity thread
    if proximityThread then
        task.cancel(proximityThread)
        proximityThread = nil
    end

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

    -- ⚡ Store the proximity thread for cleanup
    proximityThread = task.spawn(function()
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