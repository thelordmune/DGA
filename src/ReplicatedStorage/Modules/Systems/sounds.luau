local players = game:GetService("Players")
local replicatedStorage = game:GetService("ReplicatedStorage")
local lighting = game:GetService("Lighting")

local runService = game:GetService("RunService")
local tweenService = game:GetService("TweenService")

local player = players.LocalPlayer

local playing = false
local Debris = game:GetService("Debris")

local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")

local currentSound = nil
local currentThemeType = nil -- Track what type of theme is playing ("day", "night", "combat")

-- Initialize global combat state tracker if it doesn't exist
if not _G.PlayerInCombat then
    _G.PlayerInCombat = false
end

repeat task.wait() until game:IsLoaded()

-- Helper function to check if it's nighttime
local function isNightTime()
    local timeString = lighting.TimeOfDay
    local hours = tonumber(string.match(timeString, "^(%d+):"))

    -- Night is from 18:00 (6 PM) to 6:00 (6 AM)
    return hours >= 18 or hours < 6
end

-- Helper function to stop current sound
local function stopCurrentSound()
    if currentSound and currentSound.IsPlaying then
        currentSound:Stop()
        currentSound:Destroy()
        currentSound = nil
    end
    playing = false
    currentThemeType = nil
end

local function sound()
    -- Determine what theme should be playing based on combat state and time
    local desiredThemeType
    if _G.PlayerInCombat then
        desiredThemeType = "combat"
    elseif isNightTime() then
        desiredThemeType = "night"
    else
        desiredThemeType = "day"
    end

    -- If we're already playing the correct theme type, don't change
    if playing and currentThemeType == desiredThemeType then
        return
    end

    -- If a different theme type should be playing, stop current and start new
    if currentThemeType ~= desiredThemeType then
        stopCurrentSound()
    end

    if not playing then
        if currentSound and currentSound.IsPlaying then return end

        playing = true
        currentThemeType = desiredThemeType

        -- Select the appropriate theme folder
        local themeFolder
        if desiredThemeType == "combat" then
            themeFolder = replicatedStorage.Assets.SFX.Themes.Combat
        elseif desiredThemeType == "night" then
            themeFolder = replicatedStorage.Assets.SFX.Themes.Night
        else
            themeFolder = replicatedStorage.Assets.SFX.Themes.Day
        end

        local sounds = themeFolder:GetChildren()
        if #sounds == 0 then
            playing = false
            currentThemeType = nil
            return
        end

        local ost = sounds[math.random(1, #sounds)]:Clone()
        ost.Parent = workspace.Themes
        ost.Volume = 0.5
        currentSound = ost

        ost:Play()

        ost.Ended:Connect(function()
            ost:Destroy()
            playing = false
            currentSound = nil
            currentThemeType = nil
            -- Don't call sound() here to prevent immediate restart
        end)
    end
end

return {
    run = function()
        sound()
    end,
    settings = {
        phase = "Heartbeat",  -- Connect to PlayerAdded phase
        depends_on = {},
        client_only = true  -- Optional dependencies
}
}