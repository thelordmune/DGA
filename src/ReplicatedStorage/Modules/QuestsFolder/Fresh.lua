local Replicated = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local isServer = RunService:IsServer()

if isServer then
	-- Server-side quest module
	local ref = require(Replicated.Modules.ECS.jecs_ref)
	local world = require(Replicated.Modules.ECS.jecs_world)
	local comps = require(Replicated.Modules.ECS.jecs_components)
	local Server = require(game:GetService("ServerScriptService").ServerConfig.Server)

	return {
		-- Called when a quest stage starts
		Teleport = function(player)

            if not player  or not player:IsA("Player") then
                warn("[Fresh Quest] Teleport called without valid player!")
                return
            end

            local playerEntity = ref.get("player", player)
            local char = player.Character
            local root = char:WaitForChild("HumanoidRootPart")

			-- Get the target teleport location
			local targetPart = Workspace.World.AreaSpawns.Library
			if not targetPart then
				warn("[Fresh Quest] Library spawn point not found!")
				return
			end

			-- Lock the player in position for longer duration
			local humanoid = char:FindFirstChild("Humanoid")
			if humanoid then
				-- Disable movement for full duration (increased to 7 seconds)
				Server.Library.TimedState(char.Stuns, "Teleporting", 7)
				Server.Library.TimedState(char.Speeds, "AlcSpeed-0", 7)
			end
			task.wait(1.5)

			-- Play transmute effect below player's feet
			local footPosition = root.Position - Vector3.new(0, 3, 0)
			Server.Visuals.Ranged(footPosition, 300, {
				Module = "Base", -- base
				Function = "Transmute",
				Arguments = { char },
			})

			local startup = Replicated.Assets.SFX.MISC.Startup:Clone()
			startup.PlaybackSpeed = 1
			startup.Parent = root
			startup:Play()
			Debris:AddItem(startup, startup.TimeLength)

			-- Wait longer before starting screen fade
			task.wait(1)

			-- Start screen fade to white
			Server.Visuals.Ranged(root.Position, 300, {
				Module = "Base",
				Function = "ScreenFadeWhiteOut",
				Arguments = {},
			})

			-- Play teleport sound (slowed down)
			local teleportSound = Replicated.Assets.SFX.MISC.Teleport:Clone()
			teleportSound.PlaybackSpeed = 0.75 -- Slow down to 75% speed
			teleportSound.Parent = root
			teleportSound:Play()
			Debris:AddItem(teleportSound, teleportSound.TimeLength / 0.75) -- Adjust cleanup time for slower playback

			-- Wait for screen to fully fade to white
			task.wait(0.4)

			-- Request streaming around destination before teleporting
			local success, err = pcall(function()
				player:RequestStreamAroundAsync(targetPart.Position)
			end)
			if not success then
				warn("[Fresh Quest] Failed to stream around destination:", err)
			end

			-- Teleport the player
            root.CFrame = targetPart.CFrame

			-- Play transmute effect at destination (higher up so it's visible)
			Server.Visuals.Ranged(root.Position, 300, {
				Module = "Base",
				Function = "Transmute",
				Arguments = { char, nil, 5.5 }, -- nil for distance (default), 4.5 for height
			})

			-- Play spawn effect at new location
			Server.Visuals.Ranged(root.Position, 300, {
				Module = "Base",
				Function = "Spawn",
				Arguments = { root.Position },
			})

			-- Fade screen back from white
			Server.Visuals.Ranged(root.Position, 300, {
				Module = "Base",
				Function = "ScreenFadeWhiteIn",
				Arguments = {},
			})
		end,
    }
else
    return function()
    end
end