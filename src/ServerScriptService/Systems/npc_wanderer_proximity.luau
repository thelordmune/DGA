--!strict
--[[
    NPC Wanderer Proximity System

    Handles proximity detection for wandering citizen NPCs.
    When a player gets close:
    - Pauses wandering behavior
    - Faces the NPC toward the player
    - Enables head tracking (via attribute)

    Runs at 10 Hz for performance
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local world = require(ReplicatedStorage.Modules.ECS.jecs_world)
local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)
local Jecs = require(ReplicatedStorage.Modules.Imports.jecs)

-- Query wandering NPCs with proximity component
local query = world:query(
    comps.Character,
    comps.Transform,
    comps.NPCProximity,
    comps.Locomotion
):with(comps.WandererNPC):cached()

-- Throttle to 10 Hz
local lastUpdate = 0
local UPDATE_INTERVAL = 0.1

-- Find the closest player within range (using Players service directly instead of ECS query)
local function findClosestPlayer(npcPos: Vector3, detectionRange: number): (Model?, number)
    local closestPlayer: Model? = nil
    local closestDistance = math.huge

    for _, player in Players:GetPlayers() do
        local character = player.Character
        if not character or not character:IsDescendantOf(workspace) then
            continue
        end

        local hrp = character:FindFirstChild("HumanoidRootPart")
        if not hrp then
            continue
        end

        local playerPos = hrp.Position
        local distance = (playerPos - npcPos).Magnitude

        if distance <= detectionRange and distance < closestDistance then
            closestPlayer = character
            closestDistance = distance
        end
    end

    return closestPlayer, closestDistance
end

-- Calculate direction to face the player (Y-axis rotation only)
local function getFacingCFrame(npcPos: Vector3, targetPos: Vector3): CFrame
    local direction = (targetPos - npcPos) * Vector3.new(1, 0, 1) -- Ignore Y
    if direction.Magnitude < 0.01 then
        return CFrame.new(npcPos)
    end
    return CFrame.lookAt(npcPos, npcPos + direction.Unit)
end

-- Main system function
local function updateProximity(dt: number)
    local now = os.clock()
    if now - lastUpdate < UPDATE_INTERVAL then
        return
    end
    lastUpdate = now

    for entity, char, transform, proximity, loco in query do
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then
            continue
        end

        local npcPos = transform.new.Position
        local detectionRange = proximity.detectionRange or 8

        -- Find closest player
        local closestPlayer, distance = findClosestPlayer(npcPos, detectionRange)

        local wasNearPlayer = proximity.nearbyPlayer ~= nil
        local isNearPlayer = closestPlayer ~= nil

        if isNearPlayer and closestPlayer then
            -- Player is nearby - pause wandering and face them
            if not wasNearPlayer or proximity.nearbyPlayer ~= closestPlayer then
                -- Just entered range or switched to new player
                proximity.nearbyPlayer = closestPlayer
                proximity.isWanderPaused = true

                -- Set attribute for head tracking system
                char:SetAttribute("TrackPlayer", true)
            end

            -- Face toward the player (smooth rotation)
            local playerHRP = closestPlayer:FindFirstChild("HumanoidRootPart")
            if playerHRP then
                local targetCFrame = getFacingCFrame(npcPos, playerHRP.Position)

                -- Smoothly interpolate rotation
                local currentCFrame = transform.new
                local newCFrame = currentCFrame:Lerp(
                    CFrame.new(currentCFrame.Position) * targetCFrame.Rotation,
                    0.15 -- Smooth rotation speed
                )

                -- Update transform
                world:set(entity, comps.Transform, {
                    new = newCFrame,
                    old = transform.new
                })

                -- Apply rotation to HumanoidRootPart
                hrp.CFrame = CFrame.new(hrp.Position) * newCFrame.Rotation
            end

            -- Stop movement
            world:set(entity, comps.Locomotion, {
                dir = Vector3.zero,
                speed = 0
            })

        elseif wasNearPlayer and not isNearPlayer then
            -- Player left range - resume wandering
            proximity.nearbyPlayer = nil
            proximity.isWanderPaused = false

            -- Clear head tracking attribute
            char:SetAttribute("TrackPlayer", false)
        end

        -- Update proximity component
        world:set(entity, comps.NPCProximity, proximity)
    end
end

return {
    run = function(world: Jecs.World, dt: number)
        updateProximity(dt)
    end,

    settings = {
        phase = "Heartbeat",
        depends_on = {},
        server_only = true
    }
}
