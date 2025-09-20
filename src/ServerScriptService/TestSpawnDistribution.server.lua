-- Test script to verify spawn distribution is working

local function testSpawnDistribution()
    print("=== TESTING SPAWN DISTRIBUTION ===")
    
    -- Wait for game to load
    task.wait(3)
    
    -- Check if spawn points exist
    local world = workspace:FindFirstChild("World")
    if not world then
        print("❌ World folder not found")
        return
    end
    
    local spawns = world:FindFirstChild("Spawns")
    if not spawns then
        print("❌ Spawns folder not found")
        return
    end
    
    local leftGuard = spawns:FindFirstChild("LeftGuard")
    local rightGuard = spawns:FindFirstChild("RightGuard")
    
    if leftGuard then
        print("✅ LeftGuard spawn found at:", leftGuard.Position)
    else
        print("❌ LeftGuard spawn not found")
    end
    
    if rightGuard then
        print("✅ RightGuard spawn found at:", rightGuard.Position)
    else
        print("❌ RightGuard spawn not found")
    end
    
    -- Check if NPCs are spawning
    local live = world:FindFirstChild("Live")
    if live then
        local forest = live:FindFirstChild("Forest")
        if forest then
            local npcs = forest:FindFirstChild("NPCs")
            if npcs then
                print("✅ NPCs folder found with", #npcs:GetChildren(), "NPCs")
                for i, npc in pairs(npcs:GetChildren()) do
                    if npc:IsA("Model") and npc:FindFirstChild("HumanoidRootPart") then
                        print("- NPC", i .. ":", npc.Name, "at position:", npc.HumanoidRootPart.Position)
                    end
                end
            else
                print("❌ NPCs folder not found in Forest")
            end
        else
            print("❌ Forest region not found in Live")
        end
    else
        print("❌ Live folder not found")
    end
    
    print("=== END TEST ===")
end

-- Run test
testSpawnDistribution()

-- Monitor for new NPCs
workspace.DescendantAdded:Connect(function(descendant)
    if descendant:IsA("Model") and descendant.Name:find("Bandit") and descendant:FindFirstChild("HumanoidRootPart") then
        print("🎯 NEW BANDIT SPAWNED:", descendant.Name, "at position:", descendant.HumanoidRootPart.Position)
    end
end)
