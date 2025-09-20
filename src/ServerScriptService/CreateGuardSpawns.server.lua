-- Simple script to create guard spawn points for testing

local function createSpawnPoints()
    -- Ensure World folder exists
    local world = workspace:FindFirstChild("World")
    if not world then
        world = Instance.new("Folder")
        world.Name = "World"
        world.Parent = workspace
        print("Created World folder")
    end
    
    -- Ensure Spawns folder exists
    local spawns = world:FindFirstChild("Spawns")
    if not spawns then
        spawns = Instance.new("Folder")
        spawns.Name = "Spawns"
        spawns.Parent = world
        print("Created Spawns folder")
    end
    
    -- Create LeftGuard spawn
    local leftGuard = spawns:FindFirstChild("LeftGuard")
    if not leftGuard then
        leftGuard = Instance.new("Part")
        leftGuard.Name = "LeftGuard"
        leftGuard.Size = Vector3.new(4, 1, 4)
        leftGuard.Material = Enum.Material.Neon
        leftGuard.BrickColor = BrickColor.new("Bright red")
        leftGuard.Anchored = true
        leftGuard.CanCollide = false
        leftGuard.Position = Vector3.new(-20, 5, 0)
        leftGuard.Parent = spawns
        print("Created LeftGuard spawn at", leftGuard.Position)
    end
    
    -- Create RightGuard spawn
    local rightGuard = spawns:FindFirstChild("RightGuard")
    if not rightGuard then
        rightGuard = Instance.new("Part")
        rightGuard.Name = "RightGuard"
        rightGuard.Size = Vector3.new(4, 1, 4)
        rightGuard.Material = Enum.Material.Neon
        rightGuard.BrickColor = BrickColor.new("Bright blue")
        rightGuard.Anchored = true
        rightGuard.CanCollide = false
        rightGuard.Position = Vector3.new(20, 5, 0)
        rightGuard.Parent = spawns
        print("Created RightGuard spawn at", rightGuard.Position)
    end
    
    -- Ensure Live folder exists
    local live = world:FindFirstChild("Live")
    if not live then
        live = Instance.new("Folder")
        live.Name = "Live"
        live.Parent = world
        print("Created Live folder")
    end
end

-- Run immediately
createSpawnPoints()

print("=== GUARD SPAWN SETUP COMPLETE ===")
print("LeftGuard spawn: Red neon part at (-20, 5, 0)")
print("RightGuard spawn: Blue neon part at (20, 5, 0)")
print("Bandits should now spawn at these two locations")
print("=====================================")
