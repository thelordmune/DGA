local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local ref = require(ReplicatedStorage.Modules.ECS.jecs_ref)
local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)
local world = require(ReplicatedStorage.Modules.ECS.jecs_world)

-- Day/Night cycle configuration
local DAY_LENGTH = 20 * 60 -- 20 minutes in seconds for a full day/night cycle
local START_TIME = 6 -- Start at 6 AM

-- Create a singleton entity for the clock if it doesn't exist
local clockEntity = nil
local lastDebugTime = 0

local function initializeClock()
    -- Check if clock entity already exists
    for entity in world:query(comps.ClockTime) do
        clockEntity = entity
        return
    end

    -- Create new clock entity if none exists
    clockEntity = world:entity()

    -- Calculate start time offset so that the cycle begins at START_TIME
    local startTimeOffset = (START_TIME / 24) * DAY_LENGTH
    local adjustedStartTime = os.clock() - startTimeOffset

    world:set(clockEntity, comps.ClockTime, {
        timeOfDay = START_TIME / 24, -- Convert to Roblox time format (0-1)
        dayLength = DAY_LENGTH,
        startTime = adjustedStartTime
    })

    -- Set initial lighting
    Lighting.TimeOfDay = string.format("%02d:%02d:%02d", START_TIME, 0, 0)
    print("Day/Night cycle initialized - Starting at", START_TIME, ":00, Cycle length:", DAY_LENGTH, "seconds")
end

local function updateDayNightCycle()
    if not clockEntity then
        initializeClock()
        return
    end

    local clockData = world:get(clockEntity, comps.ClockTime)
    if not clockData then
        initializeClock()
        return
    end

    local currentTime = os.clock()
    local elapsedTime = currentTime - clockData.startTime

    -- Calculate the current time of day (0-1 range) based purely on elapsed time
    local cycleProgress = (elapsedTime % clockData.dayLength) / clockData.dayLength
    local newTimeOfDay = cycleProgress -- This gives us 0-1 over the full day cycle

    -- Convert to hours for Roblox TimeOfDay (0-24 hours)
    local hours = newTimeOfDay * 24
    local hoursPart = math.floor(hours)
    local minutesPart = math.floor((hours - hoursPart) * 60)
    local secondsPart = math.floor(((hours - hoursPart) * 60 - minutesPart) * 60)

    -- Update Roblox lighting
    Lighting.TimeOfDay = string.format("%02d:%02d:%02d", hoursPart, minutesPart, secondsPart)

    -- Debug output every 30 seconds
    if currentTime - lastDebugTime >= 30 then
        lastDebugTime = currentTime
        print(string.format("Day/Night Cycle - Time: %02d:%02d:%02d (%.1f%% through day)",
            hoursPart, minutesPart, secondsPart, cycleProgress * 100))
    end

    -- Update the component with new time (keep startTime unchanged)
    world:set(clockEntity, comps.ClockTime, {
        timeOfDay = newTimeOfDay,
        dayLength = clockData.dayLength,
        startTime = clockData.startTime
    })
end

return {
    run = function()
        updateDayNightCycle()
    end,
    settings = {
        phase = "Heartbeat",
        depends_on = {},  -- No dependencies needed
        server_only = true
    }
}
