-- Monitor existing wanderer spawn points in workspace
local wanderersFolder = workspace:FindFirstChild("Wanderers")

if wanderersFolder then
    print("Found existing Wanderers folder with", #wanderersFolder:GetChildren(), "spawn points")

    -- List all existing spawn points
    for _, part in pairs(wanderersFolder:GetChildren()) do
        if part:IsA("BasePart") then
            -- print("Wanderer spawn point:", part.Name, "at position", part.Position)
        end
    end
else
    warn("Wanderers folder not found in workspace - make sure it exists in the game")
end

-- Monitor wanderer spawns
task.spawn(function()
    while true do
        task.wait(10) -- Check every 10 seconds

        if wanderersFolder then
            local spawnCount = #wanderersFolder:GetChildren()
            local wandererCount = 0

            -- Count existing wanderer NPCs
            for _, region in pairs(workspace.World.Live:GetChildren()) do
                if region:FindFirstChild("NPCs") then
                    for _, npcFolder in pairs(region.NPCs:GetChildren()) do
                        if string.find(npcFolder.Name, "Wanderer") then
                            if npcFolder:FindFirstChild("Actor") and npcFolder.Actor:FindFirstChildOfClass("Model") then
                                wandererCount = wandererCount + 1
                            end
                        end
                    end
                end
            end

            print("Wanderer Status - Spawn Points:", spawnCount, "Active Wanderers:", wandererCount)
        else
            print("Wanderers folder not found - wanderer monitoring disabled")
            break -- Exit the monitoring loop if folder doesn't exist
        end
    end
end)
