--[[
    Clock.lua

    Fusion UI component that displays the current time of day.
    Positioned in the top-left corner of the screen.
    Reads time from Lighting.TimeOfDay.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local Fusion = require(ReplicatedStorage.Modules.Fusion)
local Children, scoped, peek = Fusion.Children, Fusion.scoped, Fusion.peek

return function(scope, props)
    local parent = props.Parent

    -- Reactive values for time display
    local timeText = scope:Value("12:00")
    local isDaytime = scope:Value(true)

    -- Update time every 0.5 seconds
    local lastUpdate = 0
    local connection = RunService.Heartbeat:Connect(function()
        local now = os.clock()
        if now - lastUpdate < 0.5 then
            return
        end
        lastUpdate = now

        -- Get time from Lighting
        local timeOfDay = Lighting.TimeOfDay
        local hour, minute = timeOfDay:match("(%d+):(%d+)")

        if hour and minute then
            timeText:set(string.format("%02d:%02d", tonumber(hour), tonumber(minute)))

            local hourNum = tonumber(hour)
            isDaytime:set(hourNum >= 6 and hourNum < 18)
        end
    end)

    -- Register cleanup
    table.insert(scope, function()
        connection:Disconnect()
    end)

    -- Create the clock UI frame
    local clockFrame = scope:New "Frame" {
        Parent = parent,
        Name = "ClockFrame",
        AnchorPoint = Vector2.new(0, 0),
        Position = UDim2.new(0, 15, 0, 15),
        Size = UDim2.fromOffset(90, 35),
        BackgroundColor3 = Color3.fromRGB(20, 20, 25),
        BackgroundTransparency = 0.3,
        BorderSizePixel = 0,

        [Children] = {
            -- Rounded corners
            scope:New "UICorner" {
                CornerRadius = UDim.new(0, 8),
            },

            -- Border stroke
            scope:New "UIStroke" {
                Color = scope:Computed(function(use)
                    return use(isDaytime) and Color3.fromRGB(255, 200, 100) or Color3.fromRGB(100, 150, 255)
                end),
                Thickness = 1.5,
                Transparency = 0.5,
            },

            -- Sun/Moon icon
            scope:New "ImageLabel" {
                Name = "TimeIcon",
                AnchorPoint = Vector2.new(0, 0.5),
                Position = UDim2.new(0, 8, 0.5, 0),
                Size = UDim2.fromOffset(18, 18),
                BackgroundTransparency = 1,
                Image = scope:Computed(function(use)
                    -- Sun icon for day, moon for night
                    return use(isDaytime) and "rbxassetid://6031094678" or "rbxassetid://6031094667"
                end),
                ImageColor3 = scope:Computed(function(use)
                    return use(isDaytime) and Color3.fromRGB(255, 220, 100) or Color3.fromRGB(200, 220, 255)
                end),
            },

            -- Time text
            scope:New "TextLabel" {
                Name = "TimeText",
                AnchorPoint = Vector2.new(0, 0.5),
                Position = UDim2.new(0, 30, 0.5, 0),
                Size = UDim2.new(1, -35, 1, 0),
                BackgroundTransparency = 1,
                Font = Enum.Font.GothamBold,
                Text = timeText,
                TextColor3 = Color3.fromRGB(255, 255, 255),
                TextSize = 16,
                TextXAlignment = Enum.TextXAlignment.Left,
            },
        }
    }

    return clockFrame
end
