-- Script to set up destructible objects in the workspace
-- This script makes barrels and trees destructible by any attack in the game

local function setupDestructiblePart(part)
    if part:IsA("MeshPart") or part:IsA("Part") then
        -- Set the Destroyable attribute so VoxBreaker can destroy it
        part:SetAttribute("Destroyable", true)

        -- Make sure the part can be hit by attacks
        part.CanCollide = true
        part.CanQuery = true

        -- Store original properties for potential restoration
        part:SetAttribute("OriginalTransparency", part.Transparency)
        part:SetAttribute("OriginalCanCollide", part.CanCollide)
        part:SetAttribute("OriginalCanQuery", part.CanQuery)

        -- print("✓ Set up destructible part:", part.Name, "in", part.Parent and part.Parent.Name or "unknown parent")
        return true
    end
    return false
end

local function debugWorkspaceStructure()
    print("=== WORKSPACE STRUCTURE DEBUG ===")
    print("Workspace children:")
    for _, child in pairs(workspace:GetChildren()) do
        print("  -", child.Name, "(" .. child.ClassName .. ")")
        if child.Name == "Map" or child.Name == "World" then
            print("    Map/World children:")
            for _, subChild in pairs(child:GetChildren()) do
                print("      -", subChild.Name, "(" .. subChild.ClassName .. ")")
                if subChild.Name == "Destructables" then
                    print("        Destructables children:")
                    for _, destructChild in pairs(subChild:GetChildren()) do
                        print("          -", destructChild.Name, "(" .. destructChild.ClassName .. ")")
                    end
                end
            end
        end
    end
    print("=== END WORKSPACE DEBUG ===")
end

local function setupDestructibleModel(model)
    -- Set up all mesh parts within the model
    for _, child in pairs(model:GetDescendants()) do
        setupDestructiblePart(child)
    end
    
    -- Also set up the model itself if it's a part
    setupDestructiblePart(model)
end

local function findDestructablesFolder()
    -- Try multiple possible paths
    local possiblePaths = {
        workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Destructables"),
        workspace:FindFirstChild("World") and workspace.World:FindFirstChild("Map") and workspace.World.Map:FindFirstChild("Destructables"),
        workspace:FindFirstChild("Destructables"),
        workspace:FindFirstChild("Map")
    }

    for _, path in pairs(possiblePaths) do
        if path then
            print("Found destructables folder at:", path:GetFullName())
            return path
        end
    end

    return nil
end

local function setupBarrels()
    print("=== SETTING UP BARRELS ===")
    local destructablesFolder = findDestructablesFolder()
    if not destructablesFolder then
        warn(" No destructables folder found! Trying to find barrels anywhere in workspace...")
        -- Fallback: search entire workspace for barrel-like objects
        for _, descendant in pairs(workspace:GetDescendants()) do
            if descendant:IsA("Model") and descendant.Name:lower():find("barrel") then
                print("Found barrel model in workspace:", descendant:GetFullName())
                setupDestructibleModel(descendant)
            end
        end
        return
    end

    local barrelsFound = 0
    -- Find barrel folders or models
    for _, child in pairs(destructablesFolder:GetDescendants()) do
        if child:IsA("Model") and child.Name:lower():find("barrel") then
            print(" Setting up barrel model:", child.Name, "at", child:GetFullName())
            setupDestructibleModel(child)
            barrelsFound = barrelsFound + 1
        elseif child:IsA("Folder") and child.Name:lower():find("barrel") then
            print(" Found barrel folder:", child.Name)
            for _, barrelModel in pairs(child:GetChildren()) do
                if barrelModel:IsA("Model") then
                    print(" Setting up barrel model:", barrelModel.Name)
                    setupDestructibleModel(barrelModel)
                    barrelsFound = barrelsFound + 1
                end
            end
        end
    end

    print(" Set up", barrelsFound, "barrel models")
end

local function setupTrees()
    print("=== SETTING UP TREES ===")
    local destructablesFolder = findDestructablesFolder()
    if not destructablesFolder then
        warn(" No destructables folder found! Trying to find trees anywhere in workspace...")
        -- Fallback: search entire workspace for tree-like objects
        for _, descendant in pairs(workspace:GetDescendants()) do
            if descendant:IsA("Model") and (descendant.Name:lower():find("tree") or descendant.Name:lower():find("oak") or descendant.Name:lower():find("pine")) then
                print("Found tree model in workspace:", descendant:GetFullName())
                setupDestructibleModel(descendant)
            end
        end
        return
    end

    local treesFound = 0
    -- Look for trees folder or tree models directly
    local treesFolder = destructablesFolder:FindFirstChild("Trees")
    if treesFolder then
        print(" Found Trees folder")

        -- Go through numbered folders (1-5) and any other children
        for _, child in pairs(treesFolder:GetChildren()) do
            if child:IsA("Folder") then
                print(" Checking tree folder:", child.Name)
                for _, treeModel in pairs(child:GetChildren()) do
                    if treeModel:IsA("Model") then
                        print(" Setting up tree model:", treeModel.Name)
                        setupDestructibleModel(treeModel)
                        treesFound = treesFound + 1
                    end
                end
            elseif child:IsA("Model") then
                print(" Setting up tree model:", child.Name)
                setupDestructibleModel(child)
                treesFound = treesFound + 1
            end
        end
    else
        -- Look for tree models directly in destructables folder
        for _, child in pairs(destructablesFolder:GetDescendants()) do
            if child:IsA("Model") and (child.Name:lower():find("tree") or child.Name:lower():find("oak") or child.Name:lower():find("pine")) then
                print(" Setting up tree model:", child.Name, "at", child:GetFullName())
                setupDestructibleModel(child)
                treesFound = treesFound + 1
            end
        end
    end

    print(" Set up", treesFound, "tree models")
end

local function setupGenericDestructibles()
    print("=== SETTING UP GENERIC DESTRUCTIBLES ===")
    local destructablesFolder = findDestructablesFolder()
    if not destructablesFolder then
        print(" No destructables folder found for generic setup")
        return
    end

    local genericFound = 0
    -- Look for any other models that might be destructible
    for _, child in pairs(destructablesFolder:GetDescendants()) do
        if child:IsA("Model") then
            local name = child.Name:lower()
            -- Skip barrels and trees as they're handled separately
            if not name:find("barrel") and not name:find("tree") and not name:find("oak") and not name:find("pine") then
                -- Look for common destructible object names
                if name:find("crate") or name:find("box") or name:find("pot") or name:find("vase") or
                   name:find("rock") or name:find("stone") or name:find("debris") or name:find("destructible") then
                    print(" Setting up generic destructible:", child.Name, "at", child:GetFullName())
                    setupDestructibleModel(child)
                    genericFound = genericFound + 1
                end
            end
        end
    end

    print(" Set up", genericFound, "generic destructible models")
end

-- Wait a moment for the workspace to fully load
task.wait(2)

print(" STARTING DESTRUCTIBLE OBJECTS SETUP...")
print(" Waiting for workspace to fully load...")

-- Debug workspace structure first
debugWorkspaceStructure()

-- Set up barrels
setupBarrels()

-- Set up trees
setupTrees()

-- Set up other destructible objects
setupGenericDestructibles()

print(" DESTRUCTIBLE OBJECTS SETUP COMPLETE!")
print(" All destructible objects should now be attackable and will shatter when hit!")
