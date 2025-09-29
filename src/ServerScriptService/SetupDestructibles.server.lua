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
        
        print("Set up destructible part:", part.Name, "in", part.Parent and part.Parent.Name or "unknown parent")
    end
end

local function setupDestructibleModel(model)
    -- Set up all mesh parts within the model
    for _, child in pairs(model:GetDescendants()) do
        setupDestructiblePart(child)
    end
    
    -- Also set up the model itself if it's a part
    setupDestructiblePart(model)
end

local function setupBarrels()
    local destructablesFolder = workspace:FindFirstChild("Map")
    if not destructablesFolder then
        warn("Map folder not found in workspace")
        return
    end
    
    destructablesFolder = destructablesFolder:FindFirstChild("Destructables")
    if not destructablesFolder then
        warn("Destructables folder not found in Map")
        return
    end
    
    -- Find barrel folders
    for _, child in pairs(destructablesFolder:GetChildren()) do
        if child.Name:lower():find("barrel") and child:IsA("Folder") then
            print("Setting up barrels in folder:", child.Name)
            
            -- Go through all models in the barrel folder
            for _, barrelModel in pairs(child:GetChildren()) do
                if barrelModel:IsA("Model") then
                    print("Setting up barrel model:", barrelModel.Name)
                    setupDestructibleModel(barrelModel)
                end
            end
        end
    end
end

local function setupTrees()
    local destructablesFolder = workspace:FindFirstChild("Map")
    if not destructablesFolder then
        warn("Map folder not found in workspace")
        return
    end
    
    destructablesFolder = destructablesFolder:FindFirstChild("Destructables")
    if not destructablesFolder then
        warn("Destructables folder not found in Map")
        return
    end
    
    local treesFolder = destructablesFolder:FindFirstChild("Trees")
    if not treesFolder then
        warn("Trees folder not found in Destructables")
        return
    end
    
    print("Setting up trees in Trees folder")
    
    -- Go through numbered folders (1-5)
    for i = 1, 5 do
        local numberedFolder = treesFolder:FindFirstChild(tostring(i))
        if numberedFolder then
            print("Setting up trees in folder:", numberedFolder.Name)
            
            -- Go through all models in the numbered folder
            for _, treeModel in pairs(numberedFolder:GetChildren()) do
                if treeModel:IsA("Model") then
                    print("Setting up tree model:", treeModel.Name)
                    
                    -- Look for leaves and trunk models within the tree model
                    for _, subModel in pairs(treeModel:GetChildren()) do
                        if subModel:IsA("Model") then
                            print("Setting up tree sub-model:", subModel.Name)
                            setupDestructibleModel(subModel)
                        else
                            -- Also check direct parts
                            setupDestructiblePart(subModel)
                        end
                    end
                end
            end
        else
            warn("Tree folder", i, "not found")
        end
    end
end

-- Wait a moment for the workspace to fully load
task.wait(2)

print("Setting up destructible objects...")

-- Set up barrels
setupBarrels()

-- Set up trees  
setupTrees()

print("Destructible objects setup complete!")
