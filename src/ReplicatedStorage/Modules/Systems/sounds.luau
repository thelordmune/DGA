local players = game:GetService("Players")
local replicatedStorage = game:GetService("ReplicatedStorage")

local runService = game:GetService("RunService")
local tweenService = game:GetService("TweenService")

local player = players.LocalPlayer
-- local global = require(game:GetService("ReplicatedStorage").Global)

local ref = require(replicatedStorage.Modules.ECS.jecs_ref)
local comps = require(replicatedStorage.Modules.ECS.jecs_components)
local world = require(replicatedStorage.Modules.ECS.jecs_world)
local playing = false
local Debris = game:GetService("Debris")

local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")

repeat task.wait() until game:IsLoaded()

local function sound()
    -- local pentity = ref.get("player", player)

        if not playing then
          if currentSound and currentSound.IsPlaying then return end
        
        playing = true
        local sounds = replicatedStorage.Assets.SFX.Themes.Day:GetChildren()
        local ost = sounds[math.random(1, #sounds)]:Clone()
        ost.Parent = workspace.Themes
        ost.Volume = 0.5
        currentSound = ost
        
        ost:Play()
        
        ost.Ended:Connect(function()
            ost:Destroy()
            playing = false
            currentSound = nil
            -- Don't call sound() here to prevent immediate restart
        end)
    end
end

return {
    run = function(world, deltaTime, player)
        sound()
    end,
    settings = {
        phase = "Heartbeat",  -- Connect to PlayerAdded phase
        depends_on = {"PlayerAdded"},
        client_only = true  -- Optional dependencies
}
}