--[[
	En Detection System (Server ECS)

	Detects entities inside active En spheres and applies slowdown effects.
	Runs at ~5Hz on server Heartbeat for performance.

	When entities enter an En sphere:
	- WalkSpeed reduced to 4 via ECS StateSpeeds component
	- EnSlowed attribute set for client-side animation slowdown (40% speed)

	Client handles its own detection visuals locally (no network needed).

	Queries workspace.World.Live (players) via spatial query AND
	workspace.NpcRegistryCamera (Chrono NPCs) via distance check.

	For NPCs: Uses direct ECS component access (bypasses StateManager entity lookup
	which can silently fail for Chrono NPCs in Camera).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local StateManager = require(ReplicatedStorage.Modules.ECS.StateManager)
local world = require(ReplicatedStorage.Modules.ECS.jecs_world)
local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)
local RefManager = require(ReplicatedStorage.Modules.ECS.jecs_ref_manager)

-- En speed state: "EnSpeed4" = WalkSpeed 4 while inside En
local EN_SPEED_STATE = "EnSpeed4"

-- Track which entities are currently slowed by each player's En
-- player -> { [affectedCharacter] = true }
local enSlowedEntities: {[Player]: {[Model]: boolean}} = {}

-- Throttle: run detection at ~5Hz
local accumulator = 0
local DETECTION_INTERVAL = 0.2

-- Direct ECS add/remove for NPCs (bypasses StateManager entity lookup)
local function addSpeedStateDirect(npcModel: Model, stateName: string)
	local entity = RefManager.entity.find(npcModel)
	if not entity then return false end

	local StateSpeeds = comps.StateSpeeds
	local states
	if world:has(entity, StateSpeeds) then
		states = world:get(entity, StateSpeeds)
		if not states then
			states = {}
		end
	else
		states = {}
	end

	-- Don't add duplicate
	if table.find(states, stateName) then
		return true
	end

	table.insert(states, stateName)
	world:set(entity, StateSpeeds, states)
	return true
end

local function removeSpeedStateDirect(npcModel: Model, stateName: string)
	local entity = RefManager.entity.find(npcModel)
	if not entity then return end

	local StateSpeeds = comps.StateSpeeds
	if not world:has(entity, StateSpeeds) then return end

	local states = world:get(entity, StateSpeeds)
	if not states then return end

	local index = table.find(states, stateName)
	if index then
		table.remove(states, index)
		world:set(entity, StateSpeeds, states)
	end
end

-- Apply slowdown: uses StateManager for players, direct ECS for NPCs
local function applySlowdown(targetChar: Model)
	local isPlayer = Players:GetPlayerFromCharacter(targetChar) ~= nil

	if isPlayer then
		StateManager.AddState(targetChar, "Speeds", EN_SPEED_STATE)
	else
		-- Direct ECS for NPCs
		if not addSpeedStateDirect(targetChar, EN_SPEED_STATE) then
			-- Fallback to StateManager if direct method fails
			StateManager.AddState(targetChar, "Speeds", EN_SPEED_STATE)
		end
	end

	targetChar:SetAttribute("EnSlowed", true)
end

-- Remove slowdown: uses StateManager for players, direct ECS for NPCs
local function removeSlowdown(targetChar: Model)
	local isPlayer = Players:GetPlayerFromCharacter(targetChar) ~= nil

	if isPlayer then
		StateManager.RemoveState(targetChar, "Speeds", EN_SPEED_STATE)
	else
		removeSpeedStateDirect(targetChar, EN_SPEED_STATE)
		-- Fallback to StateManager as well (harmless if entity not found)
		StateManager.RemoveState(targetChar, "Speeds", EN_SPEED_STATE)
	end

	targetChar:SetAttribute("EnSlowed", nil)
end

local function run(_world, dt)
	if RunService:IsClient() then return end

	accumulator = accumulator + dt
	if accumulator < DETECTION_INTERVAL then return end
	accumulator = accumulator - DETECTION_INTERVAL

	-- Iterate all players with active En
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if not character then continue end

		local enRadius = character:GetAttribute("EnRadius")
		local enActive = character:GetAttribute("EnActive")

		if not enActive or not enRadius or enRadius <= 0 then
			-- Player's En is not active; clean up any entities they were slowing
			local slowed = enSlowedEntities[player]
			if slowed then
				for affectedChar, _ in pairs(slowed) do
					if affectedChar and affectedChar.Parent then
						local stillAffected = false
						for otherPlayer, otherSet in pairs(enSlowedEntities) do
							if otherPlayer ~= player and otherSet[affectedChar] then
								stillAffected = true
								break
							end
						end
						if not stillAffected then
							removeSlowdown(affectedChar)
						end
					end
				end
				enSlowedEntities[player] = nil
			end
			continue
		end

		local hrp = character:FindFirstChild("HumanoidRootPart")
		if not hrp then continue end

		local enPosition = hrp.Position

		if not enSlowedEntities[player] then
			enSlowedEntities[player] = {}
		end

		-- Collect unique characters inside the sphere
		local charactersInside: {[Model]: boolean} = {}

		-- 1) Spatial query for workspace.World.Live (players/non-Chrono entities)
		local worldLive = workspace:FindFirstChild("World")
		worldLive = worldLive and worldLive:FindFirstChild("Live")

		if worldLive then
			local overlapParams = OverlapParams.new()
			overlapParams.FilterDescendantsInstances = { worldLive }
			overlapParams.FilterType = Enum.RaycastFilterType.Include
			local parts = workspace:GetPartBoundsInRadius(enPosition, enRadius, overlapParams)
			for _, part in parts do
				if part.Parent and part.Parent:FindFirstChild("Humanoid") then
					local targetChar = part.Parent
					if targetChar ~= character then
						charactersInside[targetChar] = true
					end
				end
			end
		end

		-- 2) Distance-based check for Chrono NPCs (spatial query unreliable in Camera)
		local npcCamera = workspace:FindFirstChild("NpcRegistryCamera")
		if npcCamera then
			for _, typeFolder in npcCamera:GetChildren() do
				local children = typeFolder:IsA("Folder") and typeFolder:GetChildren() or { typeFolder }
				for _, npcModel in children do
					if not npcModel:IsA("Model") then continue end
					if not npcModel:FindFirstChild("Humanoid") then continue end

					local npcHrp = npcModel:FindFirstChild("HumanoidRootPart") or npcModel.PrimaryPart
					if not npcHrp then continue end

					local distance = (npcHrp.Position - enPosition).Magnitude
					if distance <= enRadius then
						charactersInside[npcModel] = true
					end
				end
			end
		end

		-- Apply slowdown to characters that entered the sphere
		for targetChar, _ in pairs(charactersInside) do
			if not enSlowedEntities[player][targetChar] then
				enSlowedEntities[player][targetChar] = true
				applySlowdown(targetChar)
			end
		end

		-- Remove slowdown from characters that left the sphere
		for prevChar, _ in pairs(enSlowedEntities[player]) do
			if not charactersInside[prevChar] then
				enSlowedEntities[player][prevChar] = nil

				local stillAffected = false
				for otherPlayer, otherSet in pairs(enSlowedEntities) do
					if otherPlayer ~= player and otherSet[prevChar] then
						stillAffected = true
						break
					end
				end

				if not stillAffected then
					if prevChar and prevChar.Parent then
						removeSlowdown(prevChar)
					end
				end
			end
		end
	end
end

-- Clean up when player leaves
Players.PlayerRemoving:Connect(function(player)
	local slowed = enSlowedEntities[player]
	if slowed then
		for affectedChar, _ in pairs(slowed) do
			if affectedChar and affectedChar.Parent then
				local stillAffected = false
				for otherPlayer, otherSet in pairs(enSlowedEntities) do
					if otherPlayer ~= player and otherSet[affectedChar] then
						stillAffected = true
						break
					end
				end
				if not stillAffected then
					removeSlowdown(affectedChar)
				end
			end
		end
		enSlowedEntities[player] = nil
	end
end)

return {
	run = run,
	settings = {
		server_only = true,
		phase = "Heartbeat",
	},
}
