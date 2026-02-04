--[[
    Movement State System (ECS-Driven)

    Manages movement state tags with automatic mutual exclusion.
    Instead of scattered boolean flags, uses ECS tags that systems can query.

    Movement States (Mutually Exclusive):
    - Running: Normal walking/running
    - Sprinting: Fast movement (stamina drain)
    - Dashing: Dodge/dash ability
    - Sliding: Slide movement
    - WallRunning: Running on walls
    - Climbing: Climbing surfaces
    - InAir: Airborne (jumping/falling)
    - Grounded: On the ground (compatible with Running/Sprinting)

    Benefits:
    - Single source of truth for movement state
    - Systems can query for specific states efficiently
    - Automatic cleanup of conflicting states
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local world = require(ReplicatedStorage.Modules.ECS.jecs_world)
local tags = require(ReplicatedStorage.Modules.ECS.jecs_tags)

local MovementState = {}

-- Movement states that are mutually exclusive with each other
local EXCLUSIVE_MOVEMENT_STATES = {
    tags.Running,
    tags.Sprinting,
    tags.Dashing,
    tags.Sliding,
    tags.WallRunning,
    tags.Climbing,
}

-- Grounded/InAir are a separate exclusive pair
local GROUND_STATES = {
    tags.Grounded,
    tags.InAir,
}

-- Set a movement state (clears conflicting states automatically)
function MovementState.setState(entity: number, stateTag)
    -- Clear mutually exclusive movement states
    for _, tag in EXCLUSIVE_MOVEMENT_STATES do
        if tag ~= stateTag and world:has(entity, tag) then
            world:remove(entity, tag)
        end
    end

    -- Add the new state
    if not world:has(entity, stateTag) then
        world:add(entity, stateTag)
    end
end

-- Set ground state (Grounded or InAir)
function MovementState.setGroundState(entity: number, stateTag)
    for _, tag in GROUND_STATES do
        if tag ~= stateTag and world:has(entity, tag) then
            world:remove(entity, tag)
        end
    end

    if not world:has(entity, stateTag) then
        world:add(entity, stateTag)
    end
end

-- Clear a specific state
function MovementState.clearState(entity: number, stateTag)
    if world:has(entity, stateTag) then
        world:remove(entity, stateTag)
    end
end

-- Clear all movement states
function MovementState.clearAllStates(entity: number)
    for _, tag in EXCLUSIVE_MOVEMENT_STATES do
        if world:has(entity, tag) then
            world:remove(entity, tag)
        end
    end
    for _, tag in GROUND_STATES do
        if world:has(entity, tag) then
            world:remove(entity, tag)
        end
    end
end

-- Check if entity has a specific state
function MovementState.hasState(entity: number, stateTag): boolean
    return world:has(entity, stateTag)
end

-- Get current movement state (returns the tag or nil)
function MovementState.getCurrentState(entity: number)
    for _, tag in EXCLUSIVE_MOVEMENT_STATES do
        if world:has(entity, tag) then
            return tag
        end
    end
    return nil
end

-- Check if entity is grounded
function MovementState.isGrounded(entity: number): boolean
    return world:has(entity, tags.Grounded)
end

-- Check if entity is in air
function MovementState.isInAir(entity: number): boolean
    return world:has(entity, tags.InAir)
end

-- Check if entity can perform an action (not in a blocking state)
function MovementState.canAct(entity: number): boolean
    -- Can't act while dashing or wall running
    if world:has(entity, tags.Dashing) then return false end
    if world:has(entity, tags.WallRunning) then return false end
    if world:has(entity, tags.Sliding) then return false end
    if world:has(entity, tags.Dead) then return false end
    if world:has(entity, tags.Stunned) then return false end

    return true
end

-- Check if entity can move
function MovementState.canMove(entity: number): boolean
    if world:has(entity, tags.Dead) then return false end
    if world:has(entity, tags.Stunned) then return false end

    return true
end

-- Convenience functions for common state changes
function MovementState.startRunning(entity: number)
    MovementState.setState(entity, tags.Running)
end

function MovementState.startSprinting(entity: number)
    MovementState.setState(entity, tags.Sprinting)
end

function MovementState.startDashing(entity: number)
    MovementState.setState(entity, tags.Dashing)
end

function MovementState.startSliding(entity: number)
    MovementState.setState(entity, tags.Sliding)
end

function MovementState.startWallRunning(entity: number)
    MovementState.setState(entity, tags.WallRunning)
end

function MovementState.startClimbing(entity: number)
    MovementState.setState(entity, tags.Climbing)
end

function MovementState.setGrounded(entity: number)
    MovementState.setGroundState(entity, tags.Grounded)
end

function MovementState.setInAir(entity: number)
    MovementState.setGroundState(entity, tags.InAir)
end

return MovementState
