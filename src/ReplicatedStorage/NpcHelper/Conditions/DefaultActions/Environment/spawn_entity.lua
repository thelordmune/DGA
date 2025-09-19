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
	npcModel:SetAttribute("Equipped", true)  -- NPCs should be equipped to use Combat.Light
	npcModel:SetAttribute("IsNPC", true)  -- Mark as NPC for damage system

	print("Spawning NPC:", npcModel.Name, "with IsNPC attribute:", npcModel:GetAttribute("IsNPC"))

    -- Determine spawn location with improved distribution
    local spawn_
    local npcTypeKey = regionName .. "_" .. npcName

    -- Initialize tracking for this NPC type if not exists
    if not usedSpawns[npcTypeKey] then
        usedSpawns[npcTypeKey] = {
            currentIndex = 0,
            occupiedSpawns = {}
        }
    end

    -- Get current spawn index for this NPC type
    local currentSpawnIndex = usedSpawns[npcTypeKey].currentIndex or 0

    -- Always try to distribute NPCs across available spawn points
    if #spawnLocations > 1 then
        -- Find the next available spawn point
        local attempts = 0
        local maxAttempts = #spawnLocations * 2 -- Prevent infinite loops

        repeat
            currentSpawnIndex = (currentSpawnIndex % #spawnLocations) + 1
            attempts = attempts + 1
        until not usedSpawns[npcTypeKey].occupiedSpawns[currentSpawnIndex] or attempts >= maxAttempts

        -- If all spawns are occupied, use round-robin anyway but with larger offset
        local isOccupied = usedSpawns[npcTypeKey].occupiedSpawns[currentSpawnIndex]
        spawn_ = spawnLocations[currentSpawnIndex]
        usedSpawns[npcTypeKey].currentIndex = currentSpawnIndex
        usedSpawns[npcTypeKey].occupiedSpawns[currentSpawnIndex] = true

        print("Spawning", npcName, "at spawn point", currentSpawnIndex, "of", #spawnLocations, "at position:", spawn_, isOccupied and "(was occupied)" or "(free)")
    else
        -- Only one spawn location available
        spawn_ = spawnLocations[1]
        print("Spawning", npcName, "at single spawn point:", spawn_)
    end

    -- Add random offset to prevent exact overlap, larger if spawn was occupied
    local offsetMultiplier = usedSpawns[npcTypeKey].occupiedSpawns and usedSpawns[npcTypeKey].occupiedSpawns[currentSpawnIndex] and 2 or 1
    local offsetX = (math.random() - 0.5) * 4 * offsetMultiplier -- Random offset between -2 and 2 studs (or -4 to 4 if occupied)
    local offsetZ = (math.random() - 0.5) * 4 * offsetMultiplier
    spawn_ = spawn_ + Vector3.new(offsetX, 0, offsetZ)

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

    -- Entity creation will be handled automatically by Startup.lua when NPC is added to workspace.World.Live
    print("Spawned NPC:", npcModel.Name, "- entity creation will be handled by monitoring system")

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
            if spawn_ and usedSpawns[npcTypeKey] then
                -- Find which spawn index this NPC was using and mark it as free
                for i, location in ipairs(spawnLocations) do
                    if (location - spawn_).Magnitude < 10 then -- Within 10 studs of original spawn
                        usedSpawns[npcTypeKey].occupiedSpawns[i] = nil
                        print("Freed spawn point", i, "for", npcName)
                        break
                    end
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