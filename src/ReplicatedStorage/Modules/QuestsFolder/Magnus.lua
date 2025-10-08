local Replicated = game:GetService("ReplicatedStorage")
local Client = require(Replicated.Client)
local ref = require(Replicated.Modules.ECS.jecs_ref)
local world = require(Replicated.Modules.ECS.jecs_world)
local comps = require(Replicated.Modules.ECS.jecs_components)

return function()
    local item = Replicated.Assets.Quest_Items.Pocketwatch:Clone()
    local randomspots = workspace.World.Quests.Magnus:GetChildren()
    local randomspot = randomspots[math.random(1, #randomspots)]
    item:SetPrimaryPartCFrame(randomspot.CFrame)
    item.Parent = randomspot

    local clickdetetor = item.ClickDetector
    clickdetetor.MouseClick:Connect(function()
        item:Destroy()

        -- Set QuestItemCollected component (don't end the quest yet!)
        local playerEntity = ref.get("local_player")
        if playerEntity then
            world:set(playerEntity, comps.QuestItemCollected, {
                npcName = "Magnus",
                questName = "Missing Pocketwatch",
                itemName = "Pocketwatch",
                collectedTime = os.clock(),
            })
            print("[Magnus Quest] Pocketwatch collected! Return to Magnus to complete the quest.")
        end
    end)
end