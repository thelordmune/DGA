local Client = require(script.Parent.Parent)
local DialogueTracker = {}

local world = require(game:GetService("ReplicatedStorage").Modules.ECS.jecs_world)
local comps = require(game:GetService("ReplicatedStorage").Modules.ECS.jecs_components)
local ref = require(game:GetService("ReplicatedStorage").Modules.ECS.jecs_ref)
local Players = game:GetService("Players")
local Replicated = game:GetService("ReplicatedStorage")

--   settings
-- local  _ENABLED = false
-- local function  ---- print(message, ...)
--     if  _ENABLED then
--         ---- print("[DialogueTracker  ] " .. message, ...)
--     end
-- end

DialogueTracker.Start = function()
     ---- print("🎭 DIALOGUE TRACKER INITIALIZATION STARTED")

    -- Validate Client and Character
    if not Client then
         ---- print("❌ ERROR: Client module not found!")
        return
    end

    local Character = Client.Character
    if not Character then
         ---- print("❌ ERROR: No character found in Client!")
        return
    end

     ---- print("✅ Character found:", Character.Name)

    -- Validate ECS components
    local player = Players:GetPlayerFromCharacter(Character)
    if not player then
         ---- print("❌ ERROR: Could not get player from character!")
        return
    end

     ---- print("✅ Player found:", player.Name)

    local pent = ref.get("local_player")  -- No second parameter needed for local_player
    if not pent then
         ---- print("❌ ERROR: Could not get player entity from ref!")
        return
    end

     ---- print("✅ Player entity found:", pent)

    -- Check if Dialogue component exists
    local dialogueComp = world:get(pent, comps.Dialogue)
    if not dialogueComp then
         ---- print("⚠️ WARNING: No Dialogue component found, creating one...")
        world:set(pent, comps.Dialogue, { npc = nil, name = "none", inrange = false, state = "interact" })
        dialogueComp = world:get(pent, comps.Dialogue)
    end

     ---- print("✅ Dialogue component:", dialogueComp)

    -- Check for Effects module
    local effectsSuccess, effmod = pcall(require, Replicated.Effects.Misc)
    if not effectsSuccess then
         ---- print("❌ ERROR: Could not load Effects.Base module:", effmod)
        return
    end

     ---- print("✅ Effects module loaded successfully")

    -- Set up the Commence attribute listener
     ---- print("🔗 Setting up Commence attribute listener...")

    Character:GetAttributeChangedSignal("Commence"):Connect(function()
        local commenceValue = Character:GetAttribute("Commence")
         ---- print("🎯 Commence attribute changed to:", commenceValue)

        local currentDialogue = world:get(pent, comps.Dialogue)
         ---- print("📋 Current dialogue component:", currentDialogue)

        if currentDialogue then
            if commenceValue then
                 ---- print("🚀 Triggering dialogue commence (player in range) with data:", currentDialogue)
            else
                 ---- print("🚪 Triggering dialogue commence (player left range) with data:", currentDialogue)
            end

            local success, err = pcall(effmod.Commence, currentDialogue)
            if not success then
                 ---- print("❌ ERROR in effmod.Commence:", err)
            else
                 ---- print("✅ Dialogue commence triggered successfully")
            end
        else
             ---- print("⏸️ No dialogue data available")
        end
    end)

     ---- print("✅ DIALOGUE TRACKER INITIALIZATION COMPLETE")
     ---- print("👂 Now listening for Commence attribute changes on character:", Character.Name)
end

-- Function to toggle  ging
-- DialogueTracker.Set ging = function(enabled)
--      _ENABLED = enabled
--      ---- print(" ging " .. (enabled and "enabled" or "disabled"))
-- end

return DialogueTracker