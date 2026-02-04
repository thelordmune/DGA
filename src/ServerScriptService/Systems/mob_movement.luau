
--[[
	mob_movement_ecs.luau - HEAVILY OPTIMIZED FOR NETWORK

	Executes NPC movement based on Locomotion component.

	OPTIMIZATIONS:
	- Replaced StateManager calls with direct ECS component checks
	- Cached component lookups
	- Reduced redundant Vector3 allocations
	- Optimized state checking using ECS queries
	- NETWORK: Only update Humanoid properties when they actually change
	- NETWORK: Cache last movement state to avoid redundant replication
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)
local world = require(ReplicatedStorage.Modules.ECS.jecs_world)


local Character = comps.Character
local Mob = comps.Mob
local Transform = comps.Transform
local Locomotion = comps.Locomotion
local Hitbox = comps.Hitbox
local CombatNPC = comps.CombatNPC
local WandererNPC = comps.WandererNPC

-- OPTIMIZATION: Cache state components for direct access
local StateStuns = comps.StateStuns
local StateActions = comps.StateActions

-- Query combat NPCs
local moving_mobs = world
    :query(Character, Transform, Locomotion)
    :with(Mob)
    :with(CombatNPC)
    :cached()

-- Query wanderer NPCs (non-combat citizens)
local moving_wanderers = world
    :query(Character, Transform, Locomotion)
    :with(Mob)
    :with(WandererNPC)
    :cached()

local EPS = 1e-4
local GROUND_CHECK_DIST = 30
local MIN_REPL_DELTA = 0.05

-- NETWORK OPTIMIZATION: Cache last movement state per NPC to avoid redundant updates
-- This prevents sending the same movement data every frame (reduces network recv!)
local lastMovementState = {} -- [character] = {dir: Vector3, speed: number}

local GROUND_ROOT = workspace:WaitForChild("Map", 10) or workspace

local function makeRayParams(): RaycastParams
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Include
    params.FilterDescendantsInstances = { GROUND_ROOT, workspace.Terrain }
    return params
end

local hasLoggedMovement = false

-- OPTIMIZATION: Reusable Vector3 constants to avoid allocations
local VECTOR3_ZERO = Vector3.zero
local VECTOR3_UP = Vector3.new(0, 1, 0)

-- NETWORK OPTIMIZATION: Threshold for considering movement "changed"
-- Only update Humanoid if movement changed by more than this amount
local MOVEMENT_CHANGE_THRESHOLD = 0.1 -- studs/second
local DIRECTION_CHANGE_THRESHOLD = 0.05 -- dot product threshold

local function mobMoveStep(_dt: number)
    for e, char, transform, loco in moving_mobs do
        if not char or not char:IsDescendantOf(workspace) then
            -- NETWORK OPTIMIZATION: Clean up cache for removed NPCs
            if lastMovementState[char] then
                lastMovementState[char] = nil
            end
            continue
        end

        local hrp = char:FindFirstChild("HumanoidRootPart")
        local humanoid = char:FindFirstChild("Humanoid")
        if not hrp or not humanoid then
            continue
        end

        -- Ensure proper platform standing to prevent sinking
        if humanoid.PlatformStand then
            humanoid.PlatformStand = false
        end

        -- OPTIMIZATION: Check stuns using direct ECS component access instead of StateManager
        -- This avoids entity lookup overhead (70 NPCs × 15 Hz = 1050 lookups/sec saved!)
        local hasStuns = false
        if world:has(e, StateStuns) then
            local stuns = world:get(e, StateStuns)
            hasStuns = stuns and #stuns > 0
        end

        if hasStuns then
            continue
        end

        -- OPTIMIZATION: Check actions using direct ECS component access
        local actions = nil
        if world:has(e, StateActions) then
            actions = world:get(e, StateActions)
        end

        -- Check if NPC is performing actions that prevent movement
        if actions and table.find(actions, "BlockBreak") then
            continue
        end

        -- FIXED: Prevent movement while blocking
        if actions and table.find(actions, "Block") then
            humanoid:Move(VECTOR3_ZERO)
            humanoid.WalkSpeed = 0
            continue
        end

        local dir = loco.dir
        local speed = loco.speed or 0

        if not hasLoggedMovement then
            ---- print(`[mob_movement_ecs] System active - processing NPCs (HEAVILY OPTIMIZED FOR NETWORK)`)
            hasLoggedMovement = true
        end

        -- OPTIMIZATION: Lock Y-axis to prevent vertical movement/clipping
        -- Reuse calculation instead of creating multiple Vector3s
        local dirX, dirZ = dir.X, dir.Z
        local dirMagnitude2D = math.sqrt(dirX * dirX + dirZ * dirZ)

        -- NETWORK OPTIMIZATION: Get last movement state for this NPC
        local lastState = lastMovementState[char]
        local shouldUpdateMovement = false
        local newMoveDir = VECTOR3_ZERO
        local newSpeed = 0

        if dirMagnitude2D > EPS and speed > 0 then
            -- Normalize direction (only XZ plane)
            local invMag = 1 / dirMagnitude2D
            dirX = dirX * invMag
            dirZ = dirZ * invMag
            newMoveDir = Vector3.new(dirX, 0, dirZ)
            newSpeed = speed

            -- Check if movement changed significantly
            if not lastState then
                shouldUpdateMovement = true
            else
                -- Check if direction changed (using dot product)
                local dirDot = newMoveDir:Dot(lastState.dir)
                local speedDiff = math.abs(newSpeed - lastState.speed)

                -- Update if direction changed significantly OR speed changed significantly
                if dirDot < (1 - DIRECTION_CHANGE_THRESHOLD) or speedDiff > MOVEMENT_CHANGE_THRESHOLD then
                    shouldUpdateMovement = true
                end
            end
        else
            -- Stopping movement
            newMoveDir = VECTOR3_ZERO
            newSpeed = 0

            -- Only update if we were previously moving
            if lastState and (lastState.speed > 0 or lastState.dir.Magnitude > 0) then
                shouldUpdateMovement = true
            end
        end

        -- NETWORK OPTIMIZATION: Only update Humanoid if movement actually changed
        -- This prevents redundant network replication (70 NPCs × 15 Hz = 1050 updates/sec!)
        if shouldUpdateMovement then
            humanoid:Move(newMoveDir)
            humanoid.WalkSpeed = newSpeed

            -- Cache the new state
            lastMovementState[char] = {
                dir = newMoveDir,
                speed = newSpeed
            }
        end

        -- OPTIMIZATION: Only update Transform if CFrame actually changed
        local currentCF = hrp.CFrame
        if transform.new ~= currentCF then
            transform.new = currentCF
            world:set(e, Transform, transform)
        end
    end

    -- Process wanderer NPCs (non-combat citizens)
    for e, char, transform, loco in moving_wanderers do
        if not char or not char:IsDescendantOf(workspace) then
            if lastMovementState[char] then
                lastMovementState[char] = nil
            end
            continue
        end

        local hrp = char:FindFirstChild("HumanoidRootPart")
        local humanoid = char:FindFirstChild("Humanoid")
        if not hrp or not humanoid then
            continue
        end

        -- Ensure proper platform standing
        if humanoid.PlatformStand then
            humanoid.PlatformStand = false
        end

        -- Check stuns for wanderers too
        local hasStuns = false
        if world:has(e, StateStuns) then
            local stuns = world:get(e, StateStuns)
            hasStuns = stuns and #stuns > 0
        end

        if hasStuns then
            continue
        end

        local dir = loco.dir
        local speed = loco.speed or 0

        -- Lock Y-axis to prevent vertical movement
        local dirX, dirZ = dir.X, dir.Z
        local dirMagnitude2D = math.sqrt(dirX * dirX + dirZ * dirZ)

        local lastState = lastMovementState[char]
        local shouldUpdateMovement = false
        local newMoveDir = VECTOR3_ZERO
        local newSpeed = 0

        if dirMagnitude2D > EPS and speed > 0 then
            local invMag = 1 / dirMagnitude2D
            dirX = dirX * invMag
            dirZ = dirZ * invMag
            newMoveDir = Vector3.new(dirX, 0, dirZ)
            newSpeed = speed

            if not lastState then
                shouldUpdateMovement = true
            else
                local dirDot = newMoveDir:Dot(lastState.dir)
                local speedDiff = math.abs(newSpeed - lastState.speed)
                if dirDot < (1 - DIRECTION_CHANGE_THRESHOLD) or speedDiff > MOVEMENT_CHANGE_THRESHOLD then
                    shouldUpdateMovement = true
                end
            end
        else
            newMoveDir = VECTOR3_ZERO
            newSpeed = 0
            if lastState and (lastState.speed > 0 or lastState.dir.Magnitude > 0) then
                shouldUpdateMovement = true
            end
        end

        if shouldUpdateMovement then
            humanoid:Move(newMoveDir)
            humanoid.WalkSpeed = newSpeed
            lastMovementState[char] = {
                dir = newMoveDir,
                speed = newSpeed
            }
        end

        -- Update Transform
        local currentCF = hrp.CFrame
        if transform.new ~= currentCF then
            transform.new = currentCF
            world:set(e, Transform, transform)
        end
    end
end


local MOVE_HZ = 15
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
    run = function(_world, dt)
        moveWrapper(dt)
    end,

    settings = {
        phase = "Heartbeat",
        depends_on = {},
        server_only = true
    }
}

