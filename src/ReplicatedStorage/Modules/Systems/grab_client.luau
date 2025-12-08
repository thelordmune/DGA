--!strict
--[[
	grab_client.luau - Client-side grab system

	Handles players grabbing other players.
	When a player has the Grab component, this system:
	- Welds the grabbed target at a fixed distance from the grabber
	- Maintains the grab for the duration specified in the component
	- Automatically cleans up welds when grab is released

	Usage:
		To make a player grab another player:

		local grabberEntity = RefManager.entity.find(grabberCharacter)
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

	-- Create AlignPosition to hold target in place
	local alignPos = Instance.new("AlignPosition")
	alignPos.Name = "GrabAlign"
	alignPos.Attachment0 = targetAttachment
	alignPos.Attachment1 = grabberAttachment
	alignPos.MaxForce = 100000
	alignPos.MaxVelocity = math.huge
	alignPos.Responsiveness = 200
	alignPos.RigidityEnabled = true
	alignPos.Parent = targetRoot

	-- Create AlignOrientation to match grabber's facing direction
	local alignOri = Instance.new("AlignOrientation")
	alignOri.Name = "GrabOrient"
	alignOri.Attachment0 = targetAttachment
	alignOri.Attachment1 = grabberAttachment
	alignOri.MaxTorque = 100000
	alignOri.MaxAngularVelocity = math.huge
	alignOri.Responsiveness = 200
	alignOri.RigidityEnabled = true
	alignOri.Parent = targetRoot

	return {alignPos = alignPos, alignOri = alignOri}
end

-- Helper function to remove grab weld
local function removeGrabWeld(grabber: Model, target: Model?)
	local grabberRoot = grabber:FindFirstChild("HumanoidRootPart") :: BasePart?

	if grabberRoot then
		-- Remove attachment
		local attachment = grabberRoot:FindFirstChild("GrabberAttachment")
		if attachment then
			attachment:Destroy()
		end
	end

	-- Clean up target's constraints and attachment
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
	end

	-- Clear from active welds
	activeWelds[grabber] = nil
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
		phase = "RenderStepped", -- Run on RenderStepped for smooth client-side updates
		depends_on = {},
		client_only = true, -- Only run on client
	}
}


