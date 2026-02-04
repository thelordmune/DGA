--[[
    Object Interaction Module

    Detects proximity to interactable objects and shows E prompt.
    Uses CollectionService to efficiently find objects tagged with "Interactable".
]]

local ObjectInteraction = {}
local CSystem = require(script.Parent)

-- local TweenService = CSystem.Service.TweenService
-- local RunService = CSystem.Service.RunService
local ReplicatedStorage = CSystem.Service.ReplicatedStorage
local Players = CSystem.Service.Players
local CollectionService = CSystem.Service.CollectionService

local Fusion = require(ReplicatedStorage.Modules.Fusion)
local scoped = Fusion.scoped

local player = Players.LocalPlayer

-- Settings
local DETECTION_RANGE = 10
local CHECK_INTERVAL = 0.5
local INTERACTABLE_TAG = "Interactable"

-- State tracking
local currentNearbyObject = nil
local currentHighlight = nil
local promptScope = nil
local promptStarted = nil
local promptFadeIn = nil
local promptTextStart = nil
-- local lastCheckTime = 0
local character = nil

-- ⚡ PERFORMANCE OPTIMIZATION: Store task thread for cleanup
local proximityThread = nil

local function createPromptUI(obj, promptText)
    if promptScope then
        promptScope:doCleanup()
        promptScope = nil
    end

    local primaryPart = obj:IsA("Model") and (obj.PrimaryPart or obj:FindFirstChild("HumanoidRootPart")) or obj

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

    -- Create Fusion scope with Prompt component
    promptScope = scoped(Fusion, {
        Prompt = require(ReplicatedStorage.Client.Components.Prompt),
    })

    -- Create reactive values (these need to be passed to Prompt, which will use :set() on them)
    promptStarted = promptScope:Value(false)
    promptFadeIn = promptScope:Value(false)
    promptTextStart = promptScope:Value(false)

    -- Create the prompt component with correct prop names (lowercase to match Prompt.lua expectations)
    promptScope.Prompt(promptScope, {
        Parent = surfaceGui,
        begin = promptStarted,      -- Prompt.lua line 182: local started = props.begin
        fadein = promptFadeIn,      -- Prompt.lua line 183: local fadein = props.fadein
        textstart = promptTextStart, -- Prompt.lua line 184: local textstart = props.textstart
        npcName = promptText or "Interact",
    })
end

local function showPromptUI()
    if promptStarted then
        promptStarted:set(true)
        -- Note: fadein and textstart are driven by Computed in Prompt.lua based on 'begin' value
    end
end

local function hidePromptUI()
    if promptStarted then
        promptStarted:set(false)
        -- Note: fadein and textstart are driven by Computed in Prompt.lua based on 'begin' value
    end
end

local function addHighlight(obj)
    if currentHighlight then
        currentHighlight:Destroy()
    end

    local highlight = Instance.new("Highlight")
    highlight.Name = "InteractionHighlight"
    highlight.Adornee = obj
    highlight.FillColor = Color3.fromRGB(100, 200, 255)
    highlight.OutlineColor = Color3.fromRGB(50, 150, 255)
    highlight.FillTransparency = 0.7
    highlight.OutlineTransparency = 0.3
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Parent = obj

    currentHighlight = highlight
end

local function removeHighlight()
    if currentHighlight then
        currentHighlight:Destroy()
        currentHighlight = nil
    end
end

local function findClosestInteractable()
    if not character or not character.PrimaryPart then
        return nil
    end

    local root = character.PrimaryPart
    if not root then
        return nil
    end

    local playerPos = root.Position
    local closestObject = nil
    local closestDistanceSq = DETECTION_RANGE * DETECTION_RANGE

    -- Use CollectionService to get only tagged interactable objects (much faster)
    for _, obj in CollectionService:GetTagged(INTERACTABLE_TAG) do
        local objPos
        if obj:IsA("Model") then
            local primaryPart = obj.PrimaryPart or obj:FindFirstChild("HumanoidRootPart")
            if primaryPart then
                objPos = primaryPart.Position
            end
        elseif obj:IsA("BasePart") then
            objPos = obj.Position
        end

        if objPos then
            local offset = playerPos - objPos
            local distanceSq = offset.X * offset.X + offset.Y * offset.Y + offset.Z * offset.Z
            if distanceSq <= closestDistanceSq then
                closestObject = obj
                closestDistanceSq = distanceSq
            end
        end
    end

    return closestObject
end

local function updateProximity()
    local closestObject = findClosestInteractable()

    if closestObject ~= currentNearbyObject then
        -- Clean up previous object
        if currentNearbyObject then
            removeHighlight()
            hidePromptUI()
            if character then
                character:SetAttribute("NearbyObject", nil)
                character:SetAttribute("CanInteract", false)
            end
        end

        -- Set up new object
        currentNearbyObject = closestObject
        if closestObject then
            -- Get interactable data from attributes
            local promptText = closestObject:GetAttribute("PromptText") or "Interact"
            local objectId = closestObject:GetAttribute("ObjectId") or closestObject.Name

            createPromptUI(closestObject, promptText)
            showPromptUI()
            addHighlight(closestObject)
            if character then
                character:SetAttribute("NearbyObject", objectId)
                character:SetAttribute("CanInteract", true)
            end
        end
    end
end

local function cleanup()
    -- ⚡ PERFORMANCE OPTIMIZATION: Cancel proximity thread
    if proximityThread then
        task.cancel(proximityThread)
        proximityThread = nil
        print("[ObjectInteraction] 🧹 Cancelled proximity thread")
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
    currentNearbyObject = nil

    if character then
        character:SetAttribute("NearbyObject", nil)
        character:SetAttribute("CanInteract", false)
    end

    print("[ObjectInteraction] 🧹 Cleanup complete")
end

-- Initialize
task.spawn(function()
    repeat task.wait() until game:IsLoaded()

    character = player.Character or player.CharacterAdded:Wait()

    -- Update character reference when respawning
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

    _G.ObjectInteraction_Cleanup = cleanup
    _G.ObjectInteraction_HidePrompt = hidePromptUI

    task.wait(1)
    updateProximity()
end)

return ObjectInteraction