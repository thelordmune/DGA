local Replicated = game:GetService("ReplicatedStorage")
local Client = require(Replicated.Client)

return function()
    local item = Replicated.Assets.Quest_Items.Pocketwatch:Clone()
    local randomspots = workspace.World.Quests.Magnus:GetChildren()
    local randomspot = randomspots[math.random(1, #randomspots)]
    item:SetPrimaryPartCFrame(randomspot.CFrame)
    item.Parent = randomspot

    local clickdetetor = item.ClickDetector
    clickdetetor.MouseClick:Connect(function()
        item:Destroy()
        Client.Packets.Quests.send({
            Module = "Magnus",
            Function = "End",
            Arguments = {},
        })
    end)
end