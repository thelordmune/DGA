--[[
    Quest Failure System
    
    Handles quest failure when player dies:
    - Removes ActiveQuest component
    - Removes QuestItemCollected component
    - Removes quest items from inventory
    - Cleans up quest-specific spawned items
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local jecs = require(ReplicatedStorage.Modules.Imports.jecs)
local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)
local world = require(ReplicatedStorage.Modules.ECS.jecs_world)
local ref = require(ReplicatedStorage.Modules.ECS.jecs_ref)
local InventoryManager = require(ReplicatedStorage.Modules.Utils.InventoryManager)

-- Track player death connections
local deathConnections = {}

local function failQuest(playerEntity, player)
    ---- print(`[Quest Failure] ❌ Player {player.Name} died - failing active quest`)

    -- Get active quest info before removing
    local activeQuest = world:get(playerEntity, comps.ActiveQuest)
    if activeQuest then
        ---- print(`[Quest Failure] Failing quest: {activeQuest.npcName} - {activeQuest.questName}`)

        -- Remove quest items from inventory based on quest
        if activeQuest.npcName == "Magnus" and activeQuest.questName == "Missing Pocketwatch" then
            -- Remove pocketwatch from inventory
            local success = InventoryManager.removeItem(playerEntity, "Pocketwatch", 1)
            if success then
                ---- print("[Quest Failure] ✅ Removed Pocketwatch from inventory")
            else
                warn("[Quest Failure] ⚠️ Failed to remove Pocketwatch from inventory (might not have it)")
            end

            -- Clean up any spawned pocketwatch in the world
            local questFolder = workspace.World.Quests:FindFirstChild("Magnus")
            if questFolder then
                for _, child in ipairs(questFolder:GetDescendants()) do
                    if child.Name == "Pocketwatch" then
                        child:Destroy()
                        ---- print("[Quest Failure] ✅ Destroyed spawned Pocketwatch in world")
                    end
                end
            end
        end

        -- Remove quest components
        world:remove(playerEntity, comps.ActiveQuest)
        ---- print("[Quest Failure] ✅ Removed ActiveQuest component")
    else
        ---- print("[Quest Failure] ⚠️ No active quest found")
    end

    -- Remove quest item collected component
    if world:has(playerEntity, comps.QuestItemCollected) then
        world:remove(playerEntity, comps.QuestItemCollected)
        ---- print("[Quest Failure] ✅ Removed QuestItemCollected component")
    end

    -- Remove quest data component
    if world:has(playerEntity, comps.QuestData) then
        world:remove(playerEntity, comps.QuestData)
        ---- print("[Quest Failure] ✅ Removed QuestData component")
    end

    -- Remove quest accepted component (in case it's still there)
    if world:has(playerEntity, comps.QuestAccepted) then
        world:remove(playerEntity, comps.QuestAccepted)
        ---- print("[Quest Failure] ✅ Removed QuestAccepted component")
    end

    ---- print(`[Quest Failure] ✅ Quest failure complete for {player.Name}`)
end

local function setupDeathListener(playerEntity, player, character)
    -- Disconnect old connection if it exists
    if deathConnections[player] then
        deathConnections[player]:Disconnect()
        deathConnections[player] = nil
    end
    
    local humanoid = character:WaitForChild("Humanoid")
    
    deathConnections[player] = humanoid.Died:Connect(function()
        ---- print(`[Quest Failure] {player.Name} died`)
        
        -- Check if player has an active quest
        if world:has(playerEntity, comps.ActiveQuest) then
            failQuest(playerEntity, player)
        end
    end)
end

local function questfailure(world)
    -- Set up death listeners for all players with entities
    for _, player in ipairs(Players:GetPlayers()) do
        local playerEntity = ref.get("player", player)
        if playerEntity and world:contains(playerEntity) then
            local character = player.Character
            if character and character:FindFirstChild("Humanoid") then
                -- Only set up if we don't already have a connection
                if not deathConnections[player] then
                    setupDeathListener(playerEntity, player, character)
                end
            end
        end
    end
end

-- Clean up connections when players leave
Players.PlayerRemoving:Connect(function(player)
    if deathConnections[player] then
        deathConnections[player]:Disconnect()
        deathConnections[player] = nil
    end
end)

return {
    run = function(world)
        questfailure(world)
    end,
    settings = {
        phase = "Heartbeat",
        paused = false
    }
}

