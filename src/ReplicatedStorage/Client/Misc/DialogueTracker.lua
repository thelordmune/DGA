local Client = require(script.Parent.Parent)
local DialogueTracker = {}

local world = require(game:GetService("ReplicatedStorage").Modules.ECS.jecs_world)
local comps = require(game:GetService("ReplicatedStorage").Modules.ECS.jecs_components)
local ref = require(game:GetService("ReplicatedStorage").Modules.ECS.jecs_ref)
local Players = game:GetService("Players")
local Replicated = game:GetService("ReplicatedStorage")

-- Debug settings
local DEBUG_ENABLED = false
local function DebugPrint(message, ...)
    if DEBUG_ENABLED then
        print("[DialogueTracker Debug] " .. message, ...)
    end
end

DialogueTracker.Start = function()
    DebugPrint("🎭 DIALOGUE TRACKER INITIALIZATION STARTED")

    -- Validate Client and Character
    if not Client then
        DebugPrint("❌ ERROR: Client module not found!")
        return
    end

    local Character = Client.Character
    if not Character then
        DebugPrint("❌ ERROR: No character found in Client!")
        return
    end

    DebugPrint("✅ Character found:", Character.Name)

    -- Validate ECS components
    local player = Players:GetPlayerFromCharacter(Character)
    if not player then
        DebugPrint("❌ ERROR: Could not get player from character!")
        return
    end

    DebugPrint("✅ Player found:", player.Name)

    local pent = ref.get("local_player")  -- No second parameter needed for local_player
    if not pent then
        DebugPrint("❌ ERROR: Could not get player entity from ref!")
        return
    end

    DebugPrint("✅ Player entity found:", pent)

    -- Check if Dialogue component exists
    local dialogueComp = world:get(pent, comps.Dialogue)
    if not dialogueComp then
        DebugPrint("⚠️ WARNING: No Dialogue component found, creating one...")
        world:set(pent, comps.Dialogue, { npc = nil, name = "none", inrange = false, state = "interact" })
        dialogueComp = world:get(pent, comps.Dialogue)
    end

    DebugPrint("✅ Dialogue component:", dialogueComp)

    -- Check for Effects module
    local effectsSuccess, effmod = pcall(require, Replicated.Effects.Base)
    if not effectsSuccess then
        DebugPrint("❌ ERROR: Could not load Effects.Base module:", effmod)
        return
    end

    DebugPrint("✅ Effects module loaded successfully")

    -- Set up the Commence attribute listener
    DebugPrint("🔗 Setting up Commence attribute listener...")

    Character:GetAttributeChangedSignal("Commence"):Connect(function()
        local commenceValue = Character:GetAttribute("Commence")
        DebugPrint("🎯 Commence attribute changed to:", commenceValue)

        local currentDialogue = world:get(pent, comps.Dialogue)
        DebugPrint("📋 Current dialogue component:", currentDialogue)

        if currentDialogue then
            if commenceValue then
                DebugPrint("🚀 Triggering dialogue commence (player in range) with data:", currentDialogue)
            else
                DebugPrint("🚪 Triggering dialogue commence (player left range) with data:", currentDialogue)
            end

            local success, err = pcall(effmod.Commence, currentDialogue)
            if not success then
                DebugPrint("❌ ERROR in effmod.Commence:", err)
            else
                DebugPrint("✅ Dialogue commence triggered successfully")
            end
        else
            DebugPrint("⏸️ No dialogue data available")
        end
    end)

    DebugPrint("✅ DIALOGUE TRACKER INITIALIZATION COMPLETE")
    DebugPrint("👂 Now listening for Commence attribute changes on character:", Character.Name)
end

-- Function to toggle debugging
DialogueTracker.SetDebugging = function(enabled)
    DEBUG_ENABLED = enabled
    DebugPrint("Debugging " .. (enabled and "enabled" or "disabled"))
end

return DialogueTracker