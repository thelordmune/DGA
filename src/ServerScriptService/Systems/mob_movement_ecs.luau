--[[
    ECS-Based Mob Movement System for Ironveil
    
    This system reads the Locomotion component (movement intent) and
    executes the actual movement with proper physics checks.
    
    Features:
    - Reads Locomotion component set by mob_brain_ecs
    - Performs raycasting for ground detection
    - Handles edge detection to prevent falling
    - Updates Transform component
    - Moves the actual NPC model
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)
local world = require(ReplicatedStorage.Modules.ECS.jecs_world)

-- Component shortcuts
local Character = comps.Character
local Mob = comps.Mob
local Transform = comps.Transform
local Locomotion = comps.Locomotion
local Hitbox = comps.Hitbox
local CombatNPC = comps.CombatNPC

-- Query for moving COMBAT mobs (filters out dialogue NPCs)
local moving_mobs = world
    :query(Character, Transform, Locomotion)
    :with(Mob)
    :with(CombatNPC) -- ONLY combat NPCs
    :cached()

local EPS = 1e-4
local GROUND_CHECK_DIST = 30
local MIN_REPL_DELTA = 0.05

-- Ground root for raycasting
local GROUND_ROOT = workspace:WaitForChild("Map", 10) or workspace

local function makeRayParams(): RaycastParams
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Include
    params.FilterDescendantsInstances = { GROUND_ROOT, workspace.Terrain }
    return params
end

local function mobMoveStep(dt: number)
    for e, char, transform, loco in moving_mobs do
        if not char or not char:IsDescendantOf(workspace) then
            continue
        end

        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then
            continue
        end

        local cf = transform.new
        local pos = cf.Position

        local dir = loco.dir
        local speed = loco.speed or 0

        -- Horizontal movement only
        dir = Vector3.new(dir.X, 0, dir.Z)
        if dir.Magnitude > EPS and speed > 0 then
            dir = dir.Unit
        else
            dir = Vector3.zero
            speed = 0
        end

        local move = dir * speed * dt
        local desiredPos = pos + move

        local params = makeRayParams()

        -- Forward wall check
        if move.Magnitude > EPS then
            local forwardResult = Workspace:Raycast(
                pos + Vector3.new(0, 2, 0),
                move,
                params
            )

            if forwardResult then
                local hitDist = (forwardResult.Position - pos).Magnitude
                if hitDist > 1 then
                    desiredPos = pos + dir * (hitDist - 1)
                else
                    desiredPos = pos -- Blocked immediately
                end
            end
        end

        -- Ground check under desired position
        local groundResult = Workspace:Raycast(
            desiredPos + Vector3.new(0, GROUND_CHECK_DIST * 0.5, 0),
            Vector3.new(0, -GROUND_CHECK_DIST, 0),
            params
        )

        local stepUpLimit = pos.Y + 3

        if groundResult then
            local hitY = groundResult.Position.Y

            if hitY <= stepUpLimit then
                desiredPos = Vector3.new(
                    desiredPos.X,
                    hitY + 2.5, -- Offset for character height
                    desiredPos.Z
                )
            else
                -- Treat as ceiling, keep current Y
                desiredPos = Vector3.new(
                    desiredPos.X,
                    pos.Y,
                    desiredPos.Z
                )
            end
        else
            -- No ground under new step -> edge, don't move
            desiredPos = pos
        end

        pos = desiredPos

        -- Facing direction
        local forward = if dir.Magnitude > EPS
            then dir
            else cf.LookVector

        local newCF = CFrame.new(pos, pos + forward)

        -- Update Transform component
        transform.new = newCF
        world:set(e, Transform, transform)

        -- Move the actual model (only if significant movement)
        if (pos - hrp.Position).Magnitude > MIN_REPL_DELTA then
            hrp.CFrame = newCF
        end
    end
end

-- Throttle movement to 20 Hz for performance
local MOVE_HZ = 20
local MOVE_TICK = 1 / MOVE_HZ
local moveAcc = 0

local function moveWrapper(dt: number)
    moveAcc += dt
    if moveAcc < MOVE_TICK then return end

    local step_dt = moveAcc
    moveAcc = 0
    mobMoveStep(step_dt)
end

return {
    run = function(world)
        local dt = task.wait()
        moveWrapper(dt)
    end,

    settings = {
        phase = "Heartbeat",
        depends_on = {},
        server_only = true
    }
}

