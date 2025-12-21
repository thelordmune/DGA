--!strict
--[[
    NPC Wanderer Flee System

    Handles hit detection and flee behavior for wandering citizen NPCs.
    When hit by a player:
    - Reduces relationship with that player
    - Tracks hit count
    - After enough hits, NPC flees from the attacker

    Runs at 10 Hz for performance
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local world = require(ReplicatedStorage.Modules.ECS.jecs_world)
local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)
local OccupationData = require(ReplicatedStorage.Modules.OccupationData)
local Jecs = require(ReplicatedStorage.Modules.Imports.jecs)

-- Query wandering NPCs with flee component
local query = world:query(
    comps.Character,
    comps.Transform,
    comps.NPCFlee,
    comps.NPCRelationship,
    comps.NPCProximity,
    comps.Locomotion
):with(comps.WandererNPC):cached()

-- Throttle to 10 Hz
local lastUpdate = 0
local UPDATE_INTERVAL = 0.1

-- Track last known health per NPC to detect damage
local lastHealthValues: {[number]: number} = {}

-- Get player from character model
local function getPlayerFromCharacter(character: Model): Player?
    return Players:GetPlayerFromCharacter(character)
end

-- Check if NPC was recently hit by checking Damage_Log or health change
local function checkForDamage(char: Model, entity: number): (boolean, Model?)
    -- Check for Damage_Log (created by damage system)
    local damageLog = char:FindFirstChild("Damage_Log")
    if damageLog then
        local children = damageLog:GetChildren()
        if #children > 0 then
            -- Get most recent attacker
            local recentEntry = children[#children]
            if recentEntry:IsA("ObjectValue") and recentEntry.Value then
                return true, recentEntry.Value
            end
        end
    end

    -- Also check health component for damage
    local health = world:get(entity, comps.Health)
    if health then
        local lastHealth = lastHealthValues[entity] or health.max
        if health.current < lastHealth then
            lastHealthValues[entity] = health.current
            return true, nil -- Damaged but unknown attacker
        end
        lastHealthValues[entity] = health.current
    end

    return false, nil
end

-- Main system function
local function updateFlee(dt: number)
    local now = os.clock()
    if now - lastUpdate < UPDATE_INTERVAL then
        return
    end
    lastUpdate = now

    for entity, char, transform, flee, relationship, proximity, loco in query do
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then
            continue
        end

        -- Check if currently fleeing
        if flee.isFleeing then
            -- Check if flee duration is over
            if now >= flee.fleeEndTime then
                -- Stop fleeing
                flee.isFleeing = false
                flee.fleeTarget = nil
                flee.fleeEndTime = 0

                -- Resume normal state
                proximity.isWanderPaused = false

                world:set(entity, comps.NPCFlee, flee)
                world:set(entity, comps.NPCProximity, proximity)

                -- Stop movement briefly
                world:set(entity, comps.Locomotion, {
                    dir = Vector3.zero,
                    speed = 0
                })
            else
                -- Continue fleeing
                if flee.fleeTarget then
                    local targetHRP = flee.fleeTarget:FindFirstChild("HumanoidRootPart")
                    if targetHRP then
                        local npcPos = transform.new.Position
                        local targetPos = targetHRP.Position

                        -- Calculate flee direction (away from target)
                        local fleeDir = (npcPos - targetPos) * Vector3.new(1, 0, 1)
                        if fleeDir.Magnitude > 0.01 then
                            fleeDir = fleeDir.Unit
                        else
                            -- Random direction if directly on top
                            fleeDir = Vector3.new(math.random() - 0.5, 0, math.random() - 0.5).Unit
                        end

                        -- Get run speed from config
                        local config = world:get(entity, comps.NPCConfig)
                        local runSpeed = config and config.runSpeed or 18

                        -- Update locomotion to flee
                        world:set(entity, comps.Locomotion, {
                            dir = fleeDir,
                            speed = runSpeed
                        })

                        -- Update transform to face away
                        local newCFrame = CFrame.lookAt(npcPos, npcPos + fleeDir)
                        world:set(entity, comps.Transform, {
                            new = newCFrame,
                            old = transform.new
                        })
                    end
                end
            end
            continue -- Skip damage check while fleeing
        end

        -- Check for damage
        local wasDamaged, attacker = checkForDamage(char, entity)
        if wasDamaged then
            -- Find attacker player ID
            local attackerId: number? = nil
            if attacker then
                local player = getPlayerFromCharacter(attacker)
                if player then
                    attackerId = player.UserId
                end
            end

            if attackerId then
                -- Update hit count
                local hitCounts = relationship.hitCounts or {}
                hitCounts[attackerId] = (hitCounts[attackerId] or 0) + 1
                relationship.hitCounts = hitCounts

                -- Reduce relationship
                local relationships = relationship.relationships or {}
                local currentRel = relationships[attackerId] or 0
                relationships[attackerId] = math.max(0, currentRel - OccupationData.RELATIONSHIP_LOSS_PER_HIT)
                relationship.relationships = relationships

                world:set(entity, comps.NPCRelationship, relationship)

                -- Check if should flee
                if hitCounts[attackerId] >= OccupationData.HITS_TO_FLEE then
                    -- Start fleeing
                    flee.isFleeing = true
                    flee.fleeTarget = attacker
                    flee.fleeEndTime = now + OccupationData.FLEE_DURATION

                    -- Pause wandering
                    proximity.isWanderPaused = true
                    proximity.nearbyPlayer = nil

                    world:set(entity, comps.NPCFlee, flee)
                    world:set(entity, comps.NPCProximity, proximity)

                    -- Clear head tracking
                    char:SetAttribute("TrackPlayer", false)

                    -- Reset hit count after fleeing starts
                    hitCounts[attackerId] = 0
                    relationship.hitCounts = hitCounts
                    world:set(entity, comps.NPCRelationship, relationship)
                end
            end
        end
    end
end

return {
    run = function(world: Jecs.World, dt: number)
        updateFlee(dt)
    end,

    settings = {
        phase = "Heartbeat",
        depends_on = { "npc_wanderer_proximity" },
        server_only = true
    }
}
