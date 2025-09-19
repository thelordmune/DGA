local VISUALIZE_SPAWN_PART = false

local SPAWN_EFFECT: boolean = false
local DESPAWN_EFFECT: boolean = false

-- Global table to track used spawn locations per NPC type
local usedSpawns = {}

local EquipModule = require(game:GetService("ServerScriptService").ServerConfig.Server.Network.Equip)

-- local AnimateScript = game.ReplicatedStorage.NpcHelper.Animations:Clone()

return function(actor: Actor, mainConfig: table)

    -- More thorough check for existing NPC
    if actor:FindFirstChildWhichIsA("Model") then
        return false
    end

    -- Enforce cooldown more strictly
    local currentTime = os.clock()
    if currentTime - mainConfig.Spawning.LastSpawned < mainConfig.Spawning.Cooldown then
        return
    end

    local npcName = actor.Parent.Name
    local regionName = actor.Parent.Parent.Parent.Name

    --print(npcName,regionName)
    local dataModel = game.ReplicatedStorage.Regions[regionName].NpcContents.DataModels[npcName]
    if not dataModel then
        warn(`Failed to find data model for {npcName} in {regionName}`)
        return false
    end

    print(math.random(1, 2))

    mainConfig.cleanup()

    local spawnLocations = {}
    for _, location in mainConfig.Spawning.Locations do
        table.insert(spawnLocations, location)
    end

    local npcModel = dataModel:Clone()
    npcModel.Name = actor.Parent:GetAttribute("SetName") .. tostring(math.random(1, 1000))

	local weapons = {"Fist", "Guns"}
    local randomWeapon = weapons[math.random(1, #weapons)]
    npcModel:SetAttribute("Weapon", randomWeapon)
	npcModel:SetAttribute("Equipped", false)

    -- Determine spawn location
    local spawn_
    local npcTypeKey = regionName .. "_" .. npcName
    
    -- Initialize tracking for this NPC type if not exists
    if not usedSpawns[npcTypeKey] then
        usedSpawns[npcTypeKey] = {}
    end
    
    -- If quantity equals number of spawns, ensure unique spawn assignment
    local quantity = mainConfig.Spawning.Quantity or 1
    if quantity == #spawnLocations then
        -- Find first unused spawn location
        for i, location in ipairs(spawnLocations) do
            local locationKey = tostring(location)
            if not usedSpawns[npcTypeKey][locationKey] then
                spawn_ = location
                usedSpawns[npcTypeKey][locationKey] = true
                break
            end
        end
        
        -- If all spawns are used, reset and use first one
        if not spawn_ then
            usedSpawns[npcTypeKey] = {}
            spawn_ = spawnLocations[1]
            usedSpawns[npcTypeKey][tostring(spawn_)] = true
        end
    else
        -- Original random selection for other cases
        spawn_ = spawnLocations[math.random(1, #spawnLocations)]
    end

    mainConfig.Spawning.SpawnedAt = spawn_

    npcModel:SetPrimaryPartCFrame(CFrame.new(spawn_) * CFrame.Angles(0, math.rad(90), 0))
    npcModel:MoveTo(spawn_)

    if VISUALIZE_SPAWN_PART then
        local visualziedPart = Instance.new("Part")
        visualziedPart.Anchored = true
        visualziedPart.CanCollide = false
        visualziedPart.Material = "Neon"
        visualziedPart.Color = Color3.fromRGB(255, 0, 0)
        visualziedPart.CFrame = CFrame.new(spawn_)
        visualziedPart.Parent = workspace
    end

    local function findExistingNPC(actor)
        -- Check under actor first
        local npc = actor:FindFirstChildWhichIsA("Model")
        if npc then
            return npc
        end

        -- Check in world live as fallback
        for _, child in ipairs(workspace.World.Live:GetChildren()) do
            if child:IsA("Model") and child.Name == actor.Parent:GetAttribute("SetName") then
                return child
            end
        end
        return nil
    end

    local existingNPC = findExistingNPC(actor)
    if existingNPC then
        return false
    end
    for _, specificTag in mainConfig.Spawning.Tags do
        game.CollectionService:AddTag(npcModel, specificTag)
    end

    npcModel.Parent = actor
    npcModel.AncestryChanged:Connect(function(_, parent)
        if parent.Name ~= "DataModels" then
            npcModel:FindFirstChild("hi").Enabled = true
        end
    end)

    mainConfig.LoadAppearance()

    -- skillSystem:setUp(npcModel)

    for _, basepart: BasePart in npcModel:GetChildren() do
        if basepart:IsA("BasePart") or basepart:IsA("MeshPart") then
            basepart:SetNetworkOwner(nil)
        end
    end

    local _ = SPAWN_EFFECT and mainConfig.SpawnEffect(mainConfig.Spawning.SpawnedAt)

    local damageLog = Instance.new("Folder")
    damageLog.Name = "Damage_Log"
    damageLog.Parent = npcModel

    mainConfig.Spawning.LastSpawned = os.clock()

    -- connectors (adjust to game framework)
    local statesFolder = game.ReplicatedStorage.PlayerStates:WaitForChild(npcModel.Name)
    do
        local root, humanoid = npcModel.HumanoidRootPart, npcModel.Humanoid

        local function cleanSweep()
            -- Clear the used spawn when NPC is cleaned up
            if spawn_ then
                local locationKey = tostring(spawn_)
                if usedSpawns[npcTypeKey] then
                    usedSpawns[npcTypeKey][locationKey] = nil
                end
            end
            
            if npcModel then
                npcModel:Destroy()
                npcModel = nil
            end

            local _ = npcModel ~= nil and mainConfig.getState(npcModel):Destroy()

            mainConfig.Spawning.LastSpawned = os.clock()

            mainConfig.Idle.PauseDuration.Current = nil
            mainConfig.Idle.NextPause.Current = nil

            mainConfig.EnemyDetection.Current = nil

            for _, specificTag in mainConfig.Spawning.Tags do
                game.CollectionService:RemoveTag(npcModel, specificTag)
            end
            mainConfig.cleanup()

            for _, connection in mainConfig.SpawnConnections do
                connection:Disconnect()
            end
            table.clear(mainConfig.SpawnConnections)
        end

        table.insert(
            mainConfig.SpawnConnections,
            statesFolder.ChildRemoved:Connect(function(Child)
                if Child.Name == "Stunned" then
                    root:SetNetworkOwner(nil)
                end
            end)
        )

        table.insert(
            mainConfig.SpawnConnections,
            humanoid.Died:Connect(function()
                local diedAt: CFrame = mainConfig.getNpcCFrame()

                mainConfig.getState(npcModel):Destroy()

                task.wait(mainConfig.Spawning.DespawnTime)

                local _ = DESPAWN_EFFECT and mainConfig.DespawnEffect(diedAt)
                cleanSweep()
            end)
        )
    end

	EquipModule.EquipWeapon(npcModel, randomWeapon)
	task.delay(5, function()
    local AnimateScript = game.ReplicatedStorage.NpcHelper.Animations:Clone()
    AnimateScript.Parent = npcModel
    AnimateScript.Enabled = true
	end)


    return true
end