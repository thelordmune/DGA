--!strict
--[[
	grab_server.luau - Server-side grab system

	Handles NPCs grabbing players/other NPCs.
	When an NPC has the Grab component, this system:
	- Welds the grabbed target at a fixed distance from the grabber
	- Maintains the grab for the duration specified in the component
	- Automatically cleans up welds when grab is released

	Usage:
		To make an NPC grab a player/NPC:

		local grabberEntity = RefManager.entity.find(npcCharacter)
		world:set(grabberEntity, comps.Grab, {
			target = targetCharacter,
			value = true,
			duration = 5, -- Hold for 5 seconds (0 = infinite)
			startTime = tick(),
			distance = 3 -- Optional: Distance in studs (defaults to 3)
		})

		To release the grab early:
		world:remove(grabberEntity, comps.Grab)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)
local world = require(ReplicatedStorage.Modules.ECS.jecs_world)
local RefManager = require(ReplicatedStorage.Modules.ECS.jecs_ref_manager)
local StateManager = require(ReplicatedStorage.Modules.ECS.StateManager)

-- Constants
local GRAB_DISTANCE = 3 -- Distance in studs to hold the target

-- Query for entities with Grab component
local grabQuery = world:query(comps.Character, comps.Grab):cached()

-- Track active welds by grabber character
local activeWelds = {}

-- Helper function to create a weld between grabber and target
local function createGrabWeld(grabber: Model, target: Model, distance: number)
	local grabberRoot = grabber:FindFirstChild("HumanoidRootPart") :: BasePart?
	local targetRoot = target:FindFirstChild("HumanoidRootPart") :: BasePart?

	if not grabberRoot or not targetRoot then
		return nil
	end

	-- Set network ownership of target to server so we have full control
	local targetParts = target:GetDescendants()
	for _, part in targetParts do
		if part:IsA("BasePart") then
			pcall(function()
				part:SetNetworkOwner(nil) -- nil = server ownership
			end)
		end
	end

	-- Create attachment on grabber (in front at specified distance)
	local grabberAttachment = Instance.new("Attachment")
	grabberAttachment.Name = "GrabberAttachment"
	grabberAttachment.Position = Vector3.new(0, 0, -distance)
	grabberAttachment.Parent = grabberRoot

	-- Create attachment on target (at center)
	local targetAttachment = Instance.new("Attachment")
	targetAttachment.Name = "TargetAttachment"
	targetAttachment.Position = Vector3.new(0, 0, 0)
	targetAttachment.Parent = targetRoot

	-- Disable collisions on target so they don't collide with grabber/others
	for _, part in targetParts do
		if part:IsA("BasePart") then
			part.CanCollide = false
		end
	end

	-- Use AlignPosition to pull target toward grabber (allows movement)
	local alignPos = Instance.new("AlignPosition")
	alignPos.Name = "GrabAlign"
	alignPos.Attachment0 = targetAttachment
	alignPos.Attachment1 = grabberAttachment
	alignPos.MaxForce = 500000
	alignPos.MaxVelocity = math.huge
	alignPos.Responsiveness = 200
	alignPos.RigidityEnabled = false -- Allow some flexibility for movement
	alignPos.Parent = targetRoot

	-- Use AlignOrientation to face target toward grabber
	local alignOri = Instance.new("AlignOrientation")
	alignOri.Name = "GrabOrient"
	alignOri.Attachment0 = targetAttachment
	alignOri.Attachment1 = grabberAttachment
	alignOri.MaxTorque = 500000
	alignOri.MaxAngularVelocity = math.huge
	alignOri.Responsiveness = 200
	alignOri.RigidityEnabled = false
	alignOri.Parent = targetRoot

	-- Disable target's humanoid controls
	local targetHumanoid = target:FindFirstChildOfClass("Humanoid")
	if targetHumanoid then
		targetHumanoid.PlatformStand = true
		targetHumanoid.AutoRotate = false
	end

	-- Apply Grabbed state to target
	pcall(function()
		StateManager.AddState(target, "Stuns", "Grabbed")
	end)

	return {alignPos = alignPos, alignOri = alignOri, grabberAttachment = grabberAttachment, targetAttachment = targetAttachment}
end

-- Helper function to remove grab weld
local function removeGrabWeld(grabber: Model, target: Model)
	local grabberRoot = grabber:FindFirstChild("HumanoidRootPart") :: BasePart?

	if grabberRoot then
		-- Remove attachment
		local attachment = grabberRoot:FindFirstChild("GrabberAttachment")
		if attachment then
			attachment:Destroy()
		end
	end

	if target and target.Parent then
		local targetRoot = target:FindFirstChild("HumanoidRootPart") :: BasePart?
		if targetRoot then
			-- Remove align constraints
			local alignPos = targetRoot:FindFirstChild("GrabAlign")
			if alignPos then
				alignPos:Destroy()
			end

			local alignOri = targetRoot:FindFirstChild("GrabOrient")
			if alignOri then
				alignOri:Destroy()
			end

			-- Remove attachment
			local attachment = targetRoot:FindFirstChild("TargetAttachment")
			if attachment then
				attachment:Destroy()
			end
		end

		-- Re-enable target's humanoid controls
		local targetHumanoid = target:FindFirstChildOfClass("Humanoid")
		if targetHumanoid then
			targetHumanoid.PlatformStand = false
			targetHumanoid.AutoRotate = true
		end

		-- Re-enable collisions on target
		local targetParts = target:GetDescendants()
		for _, part in targetParts do
			if part:IsA("BasePart") then
				part.CanCollide = true
			end
		end

		-- Restore network ownership to the target player (if it's a player)
		local Players = game:GetService("Players")
		local targetPlayer = Players:GetPlayerFromCharacter(target)
		if targetPlayer then
			local targetParts = target:GetDescendants()
			for _, part in targetParts do
				if part:IsA("BasePart") then
					pcall(function()
						part:SetNetworkOwner(targetPlayer)
					end)
				end
			end
		end

		-- Remove Grabbed state
		pcall(function()
			StateManager.RemoveState(target, "Stuns", "Grabbed")
		end)
	end

	-- Clear from active welds
	activeWelds[grabber] = nil
end

-- Helper function to check if character can act
local function canAct(character: Model): boolean
	if not character or not character.Parent then
		return false
	end

	-- Check if character is stunned or in an action that prevents grabbing
	local success1, isStunned = pcall(function()
		return StateManager.StateCheck(character, "Stuns", "Stunned")
	end)
	if success1 and isStunned then
		return false
	end

	local success2, isRagdoll = pcall(function()
		return StateManager.StateCheck(character, "Actions", "Ragdoll")
	end)
	if success2 and isRagdoll then
		return false
	end

	return true
end

-- Main update function
local function updateGrabs(_dt: number)
	local now = tick()

	for entity, character, grab in grabQuery do
		if not character or not character.Parent then
			-- Clean up if character is gone
			if activeWelds[character] then
				removeGrabWeld(character, activeWelds[character].target)
			end
			continue
		end

		-- Check if grabber can still act
		if not canAct(character) then
			-- Grabber is stunned/ragdolled, release grab
			if activeWelds[character] then
				removeGrabWeld(character, activeWelds[character].target)
			end
			world:remove(entity, comps.Grab)
			continue
		end

		-- Check if grab is active
		if not grab.value then
			if activeWelds[character] then
				removeGrabWeld(character, activeWelds[character].target)
			end
			continue
		end

		-- Check if grab duration has expired
		if grab.duration and grab.duration > 0 then
			local elapsed = now - (grab.startTime or now)
			if elapsed >= grab.duration then
				-- Remove grab component (duration expired)
				if activeWelds[character] then
					removeGrabWeld(character, activeWelds[character].target)
				end
				world:remove(entity, comps.Grab)
				continue
			end
		end

		-- Get target
		local target = grab.target
		if not target or not target.Parent then
			-- Target no longer exists, remove grab
			if activeWelds[character] then
				removeGrabWeld(character, activeWelds[character].target)
			end
			world:remove(entity, comps.Grab)
			continue
		end

		-- Create weld if it doesn't exist yet
		if not activeWelds[character] then
			local grabDistance = grab.distance or GRAB_DISTANCE
			local weld = createGrabWeld(character, target, grabDistance)
			if weld then
				activeWelds[character] = {
					weld = weld,
					target = target
				}
			end
		end
	end

	-- Clean up welds for entities that no longer have Grab component
	for character, weldData in pairs(activeWelds) do
		local entity = RefManager.entity.find(character)
		if not entity or not world:has(entity, comps.Grab) then
			removeGrabWeld(character, weldData.target)
		end
	end
end

return {
	run = function(_, dt: number)
		updateGrabs(dt)
	end,

	settings = {
		phase = "Heartbeat",
		depends_on = {},
		server_only = true, -- Only run on server
	}
}


