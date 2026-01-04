--[[
	Jail Escape Quest Module

	Triggered when a jailed player uses Deconstruct:
	1. Plays jail alarm sound (looped, fading in)
	2. Starts "Escape" quest
	3. Constructs walls from JailBlocks (raycast down, build up over 45 seconds)
	4. Spawns guards in front of each wall
	5. Shows "A PRISONER HAS ESCAPED" text with red strobe effect
	6. Quest completes when player's zone changes from "Central Command HQ"
	7. Time limit based on alarm sound length - failure quintuples jail time
]]

local Replicated = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local isServer = RunService:IsServer()

if isServer then
	local Server = require(game:GetService("ServerScriptService").ServerConfig.Server)
	local Bridges = require(Replicated.Modules.Bridges)
	local Seralizer = require(Replicated.Seralizer)

	-- Use QuestGuard data for guard spawning (has appearance config)
	local QuestGuardData = require(Replicated.Regions.Forest.Npcs.QuestGuard)

	-- Track active escape attempts
	local activeEscapes = {}

	-- Constants
	local WALL_BUILD_TIME = 60 -- seconds to fully construct wall (1 minute)
	local ESCAPE_TIME_LIMIT = 60 -- seconds to escape before failure (alarm sound duration)
	local JAIL_TIME_MULTIPLIER = 5 -- Multiplier for jail time on escape failure
	local WALL_MATERIAL = Enum.Material.Concrete
	local WALL_COLOR = Color3.fromRGB(120, 120, 120)

	-- Broadcast wall construction VFX to all nearby players
	local function broadcastWallVFX(groundPosition, wallWidth, wallHeight)
		for _, player in Players:GetPlayers() do
			local character = player.Character
			if character then
				local hrp = character:FindFirstChild("HumanoidRootPart")
				if hrp and (hrp.Position - groundPosition).Magnitude < 300 then
					Server.Visuals.FireClient(player, {
						Module = "Misc",
						Function = "WallConstruct",
						Arguments = { groundPosition, wallWidth, wallHeight, WALL_BUILD_TIME },
					})
				end
			end
		end
	end

	-- Spawn a guard at a position using the proper NPC pipeline
	local function spawnEscapeGuard(position, targetPlayer)
		local npcFileTemplate = Replicated:FindFirstChild("NpcFile")
		if not npcFileTemplate then
			warn("[JailEscape] No NpcFile template found!")
			return
		end

		-- Set up container structure
		local regionName = "EscapeGuards"
		local regionContainer = Workspace.World.Live:FindFirstChild(regionName)
		if not regionContainer then
			regionContainer = Instance.new("Folder")
			regionContainer.Name = regionName
			regionContainer.Parent = Workspace.World.Live
		end

		local npcsContainer = regionContainer:FindFirstChild("NPCs")
		if not npcsContainer then
			npcsContainer = Instance.new("Folder")
			npcsContainer.Name = "NPCs"
			npcsContainer.Parent = regionContainer
		end

		-- Configure QuestGuard spawn
		QuestGuardData.DataToSendOverAndUdpate.Spawning.Locations = { position }
		QuestGuardData.Quantity = 1
		QuestGuardData.AlwaysSpawn = true

		-- Clone NpcFile
		local npcFile = npcFileTemplate:Clone()
		local guardId = "EscapeGuard_" .. targetPlayer.UserId .. "_" .. math.random(1000, 9999)
		npcFile.Name = "QuestGuard" -- Must match behavior tree name
		npcFile:SetAttribute("SetName", guardId)
		npcFile:SetAttribute("DefaultName", "Military Police")
		npcFile:SetAttribute("IsGuard", true)
		npcFile:SetAttribute("IsSpawnedGuard", true)
		npcFile:SetAttribute("SpawnedBySystem", true)
		npcFile:SetAttribute("TargetPlayerId", targetPlayer.UserId)
		npcFile:SetAttribute("IsHostile", true)
		npcFile:SetAttribute("GuardId", guardId)

		-- Create Data folder with QuestGuard configuration
		local dataFolder = Instance.new("Folder")
		dataFolder.Name = "Data"
		Seralizer.LoadTableThroughInstance(dataFolder, QuestGuardData.DataToSendOverAndUdpate)
		dataFolder.Parent = npcFile

		npcFile.Parent = npcsContainer

		-- Wait for guard to spawn and set target
		task.spawn(function()
			local maxWaitTime = 10
			local startTime = os.clock()
			local targetPattern = "EscapeGuard_" .. targetPlayer.UserId

			while (os.clock() - startTime) < maxWaitTime do
				for _, model in Workspace.World.Live:GetDescendants() do
					if model:IsA("Model") and model:FindFirstChild("Humanoid") then
						if model.Name:find(targetPattern) and not model:GetAttribute("GuardSetup") then
							model:SetAttribute("GuardSetup", true)
							CollectionService:AddTag(model, "SpawnedGuard")
							model:SetAttribute("IsSpawnedGuard", true)
							model:SetAttribute("TargetPlayerId", targetPlayer.UserId)

							-- Add player to damage log
							local character = targetPlayer.Character
							if character then
								local damageLog = model:FindFirstChild("Damage_Log")
								if damageLog then
									local attackRecord = Instance.new("ObjectValue")
									attackRecord.Name = "GuardTarget"
									attackRecord.Value = character
									attackRecord.Parent = damageLog
								end
							end

							print("[JailEscape] Spawned escape guard:", model.Name)
							return
						end
					end
				end
				task.wait(0.5)
			end
		end)

		return npcFile
	end

	-- Construct a wall from a JailBlock part
	local function constructWall(jailBlock, targetPlayer, onComplete)
		-- Raycast down to find the ground
		local rayOrigin = jailBlock.Position
		local rayDirection = Vector3.new(0, -500, 0)
		local raycastParams = RaycastParams.new()
		raycastParams.FilterType = Enum.RaycastFilterType.Exclude
		raycastParams.FilterDescendantsInstances = { jailBlock, Workspace.World.Live }

		local rayResult = Workspace:Raycast(rayOrigin, rayDirection, raycastParams)
		if not rayResult then
			warn("[JailEscape] Raycast failed for JailBlock:", jailBlock.Name)
			if onComplete then onComplete() end
			return
		end

		local groundPosition = rayResult.Position
		local wallHeight = jailBlock.Position.Y - groundPosition.Y
		local wallWidth = jailBlock.Size.X
		local wallDepth = 3 -- Wall thickness

		-- Get the rotation from the JailBlock (only Y rotation for vertical wall)
		local _, yRotation, _ = jailBlock.CFrame:ToEulerAnglesYXZ()

		-- Create the wall part (starts at ground level with 0 height)
		local wall = Instance.new("Part")
		wall.Name = "EscapeWall_" .. jailBlock.Name
		wall.Anchored = true
		wall.CanCollide = true
		wall.Material = WALL_MATERIAL
		wall.Color = WALL_COLOR
		wall.Size = Vector3.new(wallWidth, 0.1, wallDepth) -- Start very small
		-- Apply the same Y rotation as the JailBlock
		wall.CFrame = CFrame.new(groundPosition.X, groundPosition.Y + 0.05, groundPosition.Z) * CFrame.Angles(0, yRotation, 0)
		wall.Parent = Workspace.World

		-- Tag for cleanup
		CollectionService:AddTag(wall, "EscapeWall")

		-- Trigger wall construction VFX for all nearby players
		broadcastWallVFX(groundPosition, wallWidth, wallHeight)

		-- Spawn guard in front of the wall
		local guardSpawnPos = groundPosition + (jailBlock.CFrame.LookVector * 5) + Vector3.new(0, 2, 0)
		spawnEscapeGuard(guardSpawnPos, targetPlayer)

		-- Animate wall construction over WALL_BUILD_TIME seconds
		local startTime = os.clock()
		local connection
		connection = RunService.Heartbeat:Connect(function()
			local elapsed = os.clock() - startTime
			local progress = math.min(elapsed / WALL_BUILD_TIME, 1)

			-- Ease out for more dramatic construction
			local easedProgress = 1 - math.pow(1 - progress, 3)

			local currentHeight = wallHeight * easedProgress
			wall.Size = Vector3.new(wallWidth, currentHeight, wallDepth)
			-- Preserve the Y rotation while animating height
			wall.CFrame = CFrame.new(groundPosition.X, groundPosition.Y + currentHeight / 2, groundPosition.Z) * CFrame.Angles(0, yRotation, 0)

			if progress >= 1 then
				connection:Disconnect()
				if onComplete then onComplete() end
			end
		end)

		return wall
	end

	-- Handle escape failure (time ran out)
	local function failEscape(player)
		local escapeData = activeEscapes[player.UserId]
		if not escapeData then return end

		print("[JailEscape] Escape FAILED for:", player.Name, "- Time ran out!")

		-- Get original jail time and multiply it
		local originalJailTime = escapeData.originalJailTime or 60
		local newJailTime = originalJailTime * JAIL_TIME_MULTIPLIER

		-- Notify client of failure
		Bridges.JailEscape:Fire(player, {
			action = "failed",
			newJailTime = newJailTime,
		})

		-- Update jail time in player data
		local Global = require(Replicated.Modules.Shared.Global)
		Global.SetData(player, function(data)
			data.Influence.JailTime = newJailTime
			return data
		end)

		-- Re-jail the player with new time (fire jail event to client)
		Bridges.JailPlayer:Fire(player, {
			duration = newJailTime,
			reason = "Escape attempt failed! Your sentence has been extended.",
		})

		-- Clean up walls immediately on failure
		for _, wall in escapeData.walls do
			if wall and wall.Parent then
				wall:Destroy()
			end
		end
		activeEscapes[player.UserId] = nil
	end

	-- Start the jail escape sequence
	local function startEscape(player)
		if activeEscapes[player.UserId] then
			return -- Already escaping
		end

		local character = player.Character
		if not character then return end

		-- Check if player is jailed
		if not character:GetAttribute("Jailed") then
			return
		end

		-- Get current jail time from player data
		local Global = require(Replicated.Modules.Shared.Global)
		local playerData = Global.GetData(player)
		local originalJailTime = (playerData and playerData.Influence and playerData.Influence.JailTime) or 60

		activeEscapes[player.UserId] = {
			walls = {},
			guards = {},
			startTime = os.clock(),
			originalJailTime = originalJailTime,
			escaped = false, -- Track if player successfully escaped
		}

		print("[JailEscape] Starting escape sequence for:", player.Name, "Original jail time:", originalJailTime)

		-- Fire client event to start alarm and visual effects
		Bridges.JailEscape:Fire(player, {
			action = "start",
			timeLimit = ESCAPE_TIME_LIMIT,
			originalJailTime = originalJailTime,
		})

		-- Broadcast to all players the escape message
		for _, otherPlayer in Players:GetPlayers() do
			Bridges.JailEscape:Fire(otherPlayer, {
				action = "broadcast",
				escapingPlayer = player.Name,
			})
		end

		-- Find JailBlocks and construct walls
		local jailBlocksFolder = Workspace.World:FindFirstChild("JailBlocks")
		if jailBlocksFolder then
			local jailBlocks = jailBlocksFolder:GetChildren()
			local wallsCompleted = 0
			local totalWalls = #jailBlocks

			for _, jailBlock in jailBlocks do
				if jailBlock:IsA("BasePart") then
					local wall = constructWall(jailBlock, player, function()
						wallsCompleted = wallsCompleted + 1
						if wallsCompleted >= totalWalls then
							print("[JailEscape] All walls constructed!")
						end
					end)
					if wall then
						table.insert(activeEscapes[player.UserId].walls, wall)
					end
				end
			end
		else
			warn("[JailEscape] JailBlocks folder not found at workspace.World.JailBlocks")
		end

		-- Zone detection is handled by client (zones.luau runs client-side)
		-- Client will fire "player_escaped" action when zone changes

		-- Start escape timer - fail if time runs out
		task.delay(ESCAPE_TIME_LIMIT, function()
			-- Check if still escaping AND hasn't already escaped
			local escapeData = activeEscapes[player.UserId]
			if escapeData and not escapeData.escaped then
				failEscape(player)
			end
		end)
	end

	-- Handle client notification of successful escape (zone change detected on client)
	local function handlePlayerEscaped(player, data)
		if not activeEscapes[player.UserId] then
			return -- Not escaping
		end

		-- Mark as escaped immediately to prevent failure timer from triggering
		activeEscapes[player.UserId].escaped = true

		local toZone = data.toZone or "Unknown"
		print("[JailEscape] Player escaped to zone:", toZone)

		-- Complete the escape - notify client
		Bridges.JailEscape:Fire(player, {
			action = "escaped",
			zone = toZone,
		})

		-- Clear jailed status
		local char = player.Character
		if char then
			char:SetAttribute("Jailed", false)
		end

		-- Clean up walls after a delay
		task.delay(30, function()
			if activeEscapes[player.UserId] then
				for _, wall in activeEscapes[player.UserId].walls do
					if wall and wall.Parent then
						-- Fade out wall
						local tween = TweenService:Create(wall, TweenInfo.new(3), {
							Transparency = 1
						})
						tween:Play()
						tween.Completed:Connect(function()
							wall:Destroy()
						end)
					end
				end
				activeEscapes[player.UserId] = nil
			end
		end)
	end

	-- Listen for client escape notifications
	Bridges.JailEscape:Connect(function(player, data)
		if data and data.action == "player_escaped" then
			handlePlayerEscaped(player, data)
		end
	end)

	-- Clean up when player leaves
	Players.PlayerRemoving:Connect(function(player)
		if activeEscapes[player.UserId] then
			for _, wall in activeEscapes[player.UserId].walls do
				if wall and wall.Parent then
					wall:Destroy()
				end
			end
			activeEscapes[player.UserId] = nil
		end
	end)

	return {
		-- Called when Deconstruct is used while jailed
		TriggerEscape = function(player)
			startEscape(player)
		end,

		-- Check if player is currently escaping
		IsEscaping = function(player)
			return activeEscapes[player.UserId] ~= nil
		end,
	}
else
	-- Client-side module
	return function()
	end
end
