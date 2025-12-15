--!strict
--[[
    Day/Night Cycle System - OPTIMIZED

    Updates the Lighting.TimeOfDay based on elapsed time.

    OPTIMIZATIONS:
    - Removed unnecessary component updates (only modify ClockTime, not read/write it every frame)
    - Removed debug logging
    - Simplified initialization logic
    - Only updates Lighting.TimeOfDay (as per ECS best practices)
]]

local Lighting = game:GetService("Lighting")

-- Day/Night cycle configuration
local DAY_LENGTH = 20 * 60 -- 20 minutes in seconds for a full day/night cycle
local START_TIME = 6 -- Start at 6 AM

-- Calculate start time offset so that the cycle begins at START_TIME
local startTimeOffset = (START_TIME / 24) * DAY_LENGTH
local startTime = os.clock() - startTimeOffset

-- Set initial lighting
Lighting.TimeOfDay = string.format("%02d:%02d:%02d", START_TIME, 0, 0)

local function updateDayNightCycle()
    local currentTime = os.clock()
    local elapsedTime = currentTime - startTime

    -- Calculate the current time of day (0-1 range) based purely on elapsed time
    local cycleProgress = (elapsedTime % DAY_LENGTH) / DAY_LENGTH

    -- Convert to hours for Roblox TimeOfDay (0-24 hours)
    local hours = cycleProgress * 24
    local hoursPart = math.floor(hours)
    local minutesPart = math.floor((hours - hoursPart) * 60)
    local secondsPart = math.floor(((hours - hoursPart) * 60 - minutesPart) * 60)

    -- Update Roblox lighting (only thing that needs to change)
    Lighting.TimeOfDay = string.format("%02d:%02d:%02d", hoursPart, minutesPart, secondsPart)
end

return {
    run = updateDayNightCycle,
    settings = {
        phase = "Heartbeat",
        server_only = true
    }
}
