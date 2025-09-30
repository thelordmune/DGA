local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Include
raycastParams.FilterDescendantsInstances = { workspace.World.Map.Zones }
raycastParams.IgnoreWater = true

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local INTERVAL = 0.75
local lastCheck = 0

-- Debug settings
local DEBUG_ENABLED = false
local function DebugPrint(message, ...)
    if DEBUG_ENABLED then
        print("[DialogueCheck Debug] " .. message, ...)
    end
end

repeat task.wait() until game:IsLoaded()

DebugPrint("🎭 DIALOGUE CHECK SYSTEM INITIALIZATION STARTED")
DebugPrint("✅ Game loaded, player:", player.Name)

-- Validate initial character
if character then
    DebugPrint("✅ Initial character found:", character.Name)
else
    DebugPrint("⚠️ No initial character, waiting for CharacterAdded...")
end

player.CharacterAdded:Connect(function(newCharacter)
    character = newCharacter
    DebugPrint("🔄 Character changed to:", newCharacter.Name)

    -- Validate new character components
    local root = newCharacter:FindFirstChild("HumanoidRootPart")
    local humanoid = newCharacter:FindFirstChildOfClass("Humanoid")

    if root then
        DebugPrint("✅ HumanoidRootPart found in new character")
    else
        DebugPrint("❌ No HumanoidRootPart in new character!")
    end

    if humanoid then
        DebugPrint("✅ Humanoid found in new character, health:", humanoid.Health)
    else
        DebugPrint("❌ No Humanoid in new character!")
    end
end)

DebugPrint("📦 Loading ECS modules...")

local ref = require(ReplicatedStorage.Modules.ECS.jecs_ref)
local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)
local world = require(ReplicatedStorage.Modules.ECS.jecs_world)

local Sift = require(ReplicatedStorage.Modules.Imports.Sift)

-- local Packets = require(ReplicatedStorage.Modules.Packets)

DebugPrint("✅ ECS modules loaded successfully")

-- Validate workspace structure
DebugPrint("🗺️ Checking workspace structure...")
local worldFolder = workspace:FindFirstChild("World")
if worldFolder then
    DebugPrint("✅ World folder found")
    local dialogueFolder = worldFolder:FindFirstChild("Dialogue")
    if dialogueFolder then
        local npcCount = #dialogueFolder:GetChildren()
        DebugPrint("✅ Dialogue folder found with", npcCount, "NPCs")

        -- List all NPCs for debugging
        for i, npc in pairs(dialogueFolder:GetChildren()) do
            local hasRoot = npc:FindFirstChild("HumanoidRootPart") ~= nil
            DebugPrint("  📍 NPC", i .. ":", npc.Name, "- Has HumanoidRootPart:", hasRoot)
        end
    else
        DebugPrint("❌ No Dialogue folder found in World!")
    end
else
    DebugPrint("❌ No World folder found in workspace!")
end

-- Validate player entity setup
DebugPrint("🎮 Checking player entity setup...")
local pEntity = ref.get("player", player)
if pEntity then
    DebugPrint("✅ Player entity found:", pEntity)

    local dialogueComp = world:get(pEntity, comps.Dialogue)
    if dialogueComp then
        DebugPrint("✅ Dialogue component found:", dialogueComp)
    else
        DebugPrint("⚠️ No Dialogue component found, will create when needed")
    end
else
    DebugPrint("❌ Could not get player entity!")
end

DebugPrint("✅ DIALOGUE CHECK SYSTEM INITIALIZATION COMPLETE")
DebugPrint("⏱️ System will check for nearby NPCs every", INTERVAL, "seconds")

local function findCharacter(character): Model?
    if not character then
        DebugPrint("No character provided to findCharacter")
        return nil
    end

    local pent = ref.get("player", player)  -- Fixed: Use "player" instead of "local_player"
    DebugPrint("Player entity:", pent)

    local root = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChildOfClass("Humanoid")

    if not root then
        DebugPrint("No HumanoidRootPart found in character")
        return nil
    end
    if not humanoid then
        DebugPrint("No Humanoid found in character")
        return nil
    end
    if humanoid.Health <= 0 then
        DebugPrint("Character is dead, health:", humanoid.Health)
        return nil
    end

    local dialogueFolder = workspace.World:FindFirstChild("Dialogue")
    if not dialogueFolder then
        DebugPrint("WARNING: No Dialogue folder found in workspace.World")
        return nil
    end

    local npcCount = #dialogueFolder:GetChildren()
    DebugPrint("Checking", npcCount, "NPCs in dialogue folder")

    for _, npc in dialogueFolder:GetChildren() do
        local npcroot = npc:FindFirstChild("HumanoidRootPart")
        if character and npcroot then
            local distance = (root.Position - npcroot.Position).Magnitude
            DebugPrint("Distance to", npc.Name, ":", math.floor(distance * 100) / 100)
            
            if distance <= 10 then
                if not character:GetAttribute("Commence") then
                    character:SetAttribute("Commence", true)
                    DebugPrint("Set Commence to true for", npc.Name)
                end
                DebugPrint("Found nearby NPC:", npc.Name)
                return npc
            end
            if distance > 10 then
                if character:GetAttribute("Commence") then
                    character:SetAttribute("Commence", false)
                    DebugPrint("Set Commence to false, too far from", npc.Name)
                end
            end
        else
            if not npcroot then
                DebugPrint("NPC", npc.Name, "has no HumanoidRootPart")
            end
        end
    end

    DebugPrint("No nearby NPCs found")
    return nil
end

local function sendinrange(character)
    DebugPrint("sendinrange called")
    local model = findCharacter(character)

    local pEntity = ref.get("player", player)  -- Fixed: Use "player" instead of "local_player"
    
    if not pEntity then
        DebugPrint("ERROR: Could not get player entity")
        return
    end

    local dialogueComp = world:get(pEntity, comps.Dialogue)
    if not dialogueComp then
		world:set(pEntity, comps.Dialogue, { inrange = false })
        DebugPrint("ERROR: No Dialogue component found for player entity")
        return
    end

    if not model then
        DebugPrint("No model found, setting inrange to false")
        if dialogueComp.inrange ~= nil then
            world:set(
                pEntity,
                comps.Dialogue,
                Sift.Dictionary.mergeDeep(dialogueComp, { inrange = false })
            )
            DebugPrint("Set inrange to false in ECS")
        end
        return
    end

    local inrange = dialogueComp.inrange
    DebugPrint("Current inrange status:", inrange)
    
    if inrange == true then
        DebugPrint("Already in range, skipping")
        return
    end

    lastCheck = os.clock()
    world:set(
        pEntity,
        comps.Dialogue,
        Sift.Dictionary.mergeDeep(
            dialogueComp,
            { inrange = true, npc = model, name = model.Name }
        )
    )
    DebugPrint("Set inrange to true for NPC:", model.Name)
end

function DetectRange()
    local currentTime = os.clock()
    if currentTime - lastCheck < INTERVAL then
        return
    end

    DebugPrint("DetectRange running, character exists:", character ~= nil)

    if character then
        sendinrange(character)
    else
        DebugPrint("No character available")
    end
end

-- Function to toggle debugging
local function SetDebugging(enabled)
    DEBUG_ENABLED = enabled
    DebugPrint("Debugging " .. (enabled and "enabled" or "disabled"))
end

return {
    run = function()
        DetectRange()
    end,
    settings = {
        phase = "Heartbeat",
        depends_on = { "PlayerAdded" },
        client_only = true,
    },
    SetDebugging = SetDebugging,
}