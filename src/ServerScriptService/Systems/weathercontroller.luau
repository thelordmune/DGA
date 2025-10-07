local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ref = require(ReplicatedStorage.Modules.ECS.jecs_ref)
local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)
local world = require(ReplicatedStorage.Modules.ECS.jecs_world)
-- local global = require(ReplicatedStorage.Global)

local types = {"Snow", "Rain", "Sandstorm"}
local weather_check_interval = 30 * 60
local weather_duration = 5 * 30
local weather_chance = .3

local weatheractive = false
local weatherendtime = 0
local currentweather = "Clear"
local nextcheck = os.clock() + weather_check_interval

workspace:SetAttribute("Weather", currentweather) 

local function startweather(weathertype)
    currentweather = weathertype
    weatheractive = true
    weatherendtime = os.clock() + weather_duration
    workspace:SetAttribute("Weather", weathertype)
end

local function endweathe()
    currentweather = "Clear"
    weatheractive = false
    workspace:SetAttribute("Weather", currentweather)   
end


local function updateweather()
local currenttime = os.clock()

if weatheractive and currenttime >= weatherendtime then
    endweathe()
end

if currenttime >= nextcheck then
    nextcheck = currenttime + weather_check_interval
    if not weatheractive and math.random() <= weather_chance then
        local randomweather = types(math.random(#types))
        startweather(randomweather)
    end
end
end

return {
    run = function()
        updateweather()
    end,
    settings = {
        phase = "Heartbeat",
        depends_on = {},  -- Optional dependencies
        server_only = true
    }
}