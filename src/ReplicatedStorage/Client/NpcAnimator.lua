--[[
	NPC Animator - Client-side animation for Chrono NPCs

	Since Chrono bypasses default Roblox replication, animations don't replicate.
	This module plays walk/idle animations locally based on NPC velocity.

	Combat animations are triggered via the NPCCombatAnim attribute set by the server.
	Format: "Weapon|AnimType|AnimName|Speed|Timestamp"
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Only run on client
if RunService:IsServer() then
	return {}
end

local NpcAnimator = {}

-- Animation IDs (same as player animations from Animate/Cache.lua)
local ANIMATION_IDS = {
	Idle = 180435571,
	Walk = 180426354, -- Standard R6 walk animation
}

-- Track NPC animation state
local npcAnimations = {} -- [model] = { animator, walkTrack, idleTrack, lastState, combatConnection, lastCombatTimestamp, cacheModel }

-- Map NPC ID to client clone for cache model attribute listening
local npcIdToClone = {} -- [npcId] = clientCloneModel

-- Minimum velocity to be considered walking
local WALK_VELOCITY_THRESHOLD = 0.5

-- Get the NPC_MODEL_CACHE folder (attributes on these models replicate from server)
local NPC_MODEL_CACHE = ReplicatedStorage:WaitForChild("NPC_MODEL_CACHE", 10)

local function getOrCreateAnimator(model: Model): Animator?
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return nil
	end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	return animator
end

local function loadAnimation(animator: Animator, animationId: number): AnimationTrack?
	local animation = Instance.new("Animation")
	animation.AnimationId = `rbxassetid://{animationId}`

	local success, track = pcall(function()
		return animator:LoadAnimation(animation)
	end)

	if success then
		return track
	else
		warn(`[NpcAnimator] Failed to load animation {animationId}`)
		return nil
	end
end

-- Handle combat animation attribute changes from server
local function onCombatAnimChanged(model: Model, animData: string?)
	print(`[NpcAnimator] onCombatAnimChanged called for {model.Name}: {animData or "nil"}`)

	if not animData or animData == "" then
		return
	end

	local data = npcAnimations[model]
	if not data or not data.animator then
		print(`[NpcAnimator] ❌ No animation data for {model.Name}`)
		return
	end

	-- Parse format: "Weapon|AnimType|AnimName|Speed|Timestamp"
	local parts = string.split(animData, "|")
	if #parts < 5 then
		print(`[NpcAnimator] ❌ Invalid animData format: {animData}`)
		return
	end

	local weapon = parts[1]
	local animType = parts[2]
	local animName = parts[3]
	local speed = tonumber(parts[4]) or 1
	local timestamp = tonumber(parts[5]) or 0

	-- Avoid replaying the same animation
	if data.lastCombatTimestamp and data.lastCombatTimestamp >= timestamp then
		print(`[NpcAnimator] ⏭️ Skipping duplicate animation (timestamp already processed)`)
		return
	end
	data.lastCombatTimestamp = timestamp

	print(`[NpcAnimator] 🔍 Looking for animation: {weapon}/{animType}/{animName}`)

	-- Find the animation in ReplicatedStorage
	local animationsFolder = ReplicatedStorage:FindFirstChild("Assets")
	if not animationsFolder then
		print(`[NpcAnimator] ❌ Assets folder not found`)
		return
	end
	animationsFolder = animationsFolder:FindFirstChild("Animations")
	if not animationsFolder then
		print(`[NpcAnimator] ❌ Animations folder not found`)
		return
	end

	-- Find the specific animation
	local animInstance

	-- Handle Hit stun animations (they're in Assets.Animations.Hit, not Weapons)
	if weapon == "Hit" and animType == "Stun" then
		local hitFolder = animationsFolder:FindFirstChild("Hit")
		if hitFolder then
			animInstance = hitFolder:FindFirstChild(animName)
		end
		if not animInstance then
			warn(`[NpcAnimator] Hit animation not found: {animName}`)
			return
		end
	elseif weapon == "Misc" then
		-- Misc animations (KnockbackStun, etc.) are in Assets.Animations.Misc
		local miscFolder = animationsFolder:FindFirstChild("Misc")
		if miscFolder then
			animInstance = miscFolder:FindFirstChild(animName)
		end
		if not animInstance then
			warn(`[NpcAnimator] Misc animation not found: {animName}`)
			return
		end
	elseif weapon == "Parried" then
		-- Parried reaction animations are in Assets.Animations.Parried
		local parriedFolder = animationsFolder:FindFirstChild("Parried")
		if parriedFolder then
			animInstance = parriedFolder:FindFirstChild(animName)
		end
		if not animInstance then
			warn(`[NpcAnimator] Parried animation not found: {animName}`)
			return
		end
	else
		-- Weapon animations are in Assets.Animations.Weapons
		local weaponsFolder = animationsFolder:FindFirstChild("Weapons")
		if not weaponsFolder then
			print(`[NpcAnimator] ❌ Weapons folder not found`)
			return
		end

		local weaponFolder = weaponsFolder:FindFirstChild(weapon)
		if not weaponFolder then
			warn(`[NpcAnimator] Weapon folder not found: {weapon}`)
			return
		end

		if animType == "Swings" then
			local swingsFolder = weaponFolder:FindFirstChild("Swings")
			if swingsFolder then
				animInstance = swingsFolder:FindFirstChild(animName)
			end
		else
			-- For Critical, Block, Parry, etc. - direct child of weapon folder
			animInstance = weaponFolder:FindFirstChild(animName)
		end
	end

	if not animInstance then
		warn(`[NpcAnimator] Animation not found: {weapon}/{animType}/{animName}`)
		return
	end

	print(`[NpcAnimator] ✅ Found animation: {animInstance:GetFullName()}`)

	-- Load and play the animation
	local success, track = pcall(function()
		return data.animator:LoadAnimation(animInstance)
	end)

	if success and track then
		track.Priority = Enum.AnimationPriority.Action2
		track:Play(0.1)
		if speed ~= 1 then
			track:AdjustSpeed(speed)
		end
		print(`[NpcAnimator] ✅ Playing animation on {model.Name}`)

		-- Clean up track when done
		track.Stopped:Once(function()
			track:Destroy()
		end)
	end
end

-- Fix and equip weapon parts on client clone
-- The server loads weapon parts onto the NPC model BEFORE Chrono clones it.
-- The clone has the parts, but welds may need reconnecting and switching to equipped position.
-- The server's EquipWeapon runs 2s after spawn (after the clone was already made), so the
-- client clone is stuck with Unequip welds. We fix that here by equipping on the client.
local function fixAndEquipWeapons(model: Model)
	local weaponsFound = 0

	for _, child in model:GetChildren() do
		if not (child:IsA("BasePart") or child:IsA("MeshPart")) then
			continue
		end

		local equipWeld = child:FindFirstChild("Equip")
		local unequipWeld = child:FindFirstChild("Unequip")
		local torsoWeld = child:FindFirstChild("TorsoWeld")

		-- Skip body parts that aren't weapon parts
		if not equipWeld and not unequipWeld and not torsoWeld then
			continue
		end

		weaponsFound += 1

		-- Equip the weapon: connect the Equip weld and disconnect Unequip weld
		-- This mirrors what the server's EquipWeapon does
		if equipWeld and (equipWeld:IsA("Weld") or equipWeld:IsA("Motor6D")) then
			local part0Attr = equipWeld:GetAttribute("Part0")
			local part1Attr = equipWeld:GetAttribute("Part1")

			if part0Attr then
				local targetPart = model:FindFirstChild(part0Attr)
				if targetPart then
					equipWeld.Part0 = targetPart
				end
			end
			if part1Attr then
				local targetPart = model:FindFirstChild(part1Attr)
				if targetPart then
					equipWeld.Part1 = targetPart
				end
			end

			-- Disconnect the Unequip weld (holstered position)
			if unequipWeld and (unequipWeld:IsA("Weld") or unequipWeld:IsA("Motor6D")) then
				if unequipWeld:GetAttribute("Part0") then
					unequipWeld.Part0 = nil
				else
					unequipWeld.Part1 = nil
				end
			end
		elseif unequipWeld and (unequipWeld:IsA("Weld") or unequipWeld:IsA("Motor6D")) then
			-- No Equip weld, just fix the Unequip weld (holstered position)
			local part0Attr = unequipWeld:GetAttribute("Part0")
			local part1Attr = unequipWeld:GetAttribute("Part1")

			if part0Attr then
				local targetPart = model:FindFirstChild(part0Attr)
				if targetPart then
					unequipWeld.Part0 = targetPart
				end
			end
			if part1Attr then
				local targetPart = model:FindFirstChild(part1Attr)
				if targetPart then
					unequipWeld.Part1 = targetPart
				end
			end
		elseif torsoWeld and (torsoWeld:IsA("Weld") or torsoWeld:IsA("Motor6D")) then
			-- TorsoWeld variant
			local part0Attr = torsoWeld:GetAttribute("Part0")
			local part1Attr = torsoWeld:GetAttribute("Part1")

			if part0Attr then
				local targetPart = model:FindFirstChild(part0Attr)
				if targetPart then
					torsoWeld.Part0 = targetPart
				end
			end
			if part1Attr then
				local targetPart = model:FindFirstChild(part1Attr)
				if targetPart then
					torsoWeld.Part1 = targetPart
				end
			end
		end

		print(`[NpcAnimator] Fixed weapon part: {child.Name} on {model.Name}`)
	end

	if weaponsFound > 0 then
		print(`[NpcAnimator] Equipped {weaponsFound} weapon parts for NPC {model.Name}`)
	else
		print(`[NpcAnimator] No weapon parts found on NPC {model.Name}`)
		-- Debug: list all children to see what's on the clone
		for _, child in model:GetChildren() do
			print(`[NpcAnimator]   child: {child.Name} ({child.ClassName})`)
		end
	end
end

local function setupNpcAnimations(model: Model)
	if npcAnimations[model] then
		return -- Already set up
	end

	local animator = getOrCreateAnimator(model)
	if not animator then
		return
	end

	local walkTrack = loadAnimation(animator, ANIMATION_IDS.Walk)
	local idleTrack = loadAnimation(animator, ANIMATION_IDS.Idle)

	if not walkTrack or not idleTrack then
		return
	end

	-- Configure tracks
	walkTrack.Priority = Enum.AnimationPriority.Core
	walkTrack.Looped = true

	idleTrack.Priority = Enum.AnimationPriority.Core
	idleTrack.Looped = true

	-- Get the NPC ID from the model name (Chrono names clones by their ID)
	local npcId = tonumber(model.Name)

	npcAnimations[model] = {
		animator = animator,
		walkTrack = walkTrack,
		idleTrack = idleTrack,
		lastState = "none", -- "idle", "walk", or "none"
		lastPosition = model.PrimaryPart and model.PrimaryPart.Position or Vector3.zero,
		lastTime = os.clock(),
		combatConnection = nil,
		stateConnections = {}, -- Connections for state attribute changes
		lastCombatTimestamp = 0,
		npcId = npcId,
		-- Track NPC states from server
		currentStuns = {},
		currentActions = {},
		isStunned = false,
		isBlocking = false,
	}

	-- Track the clone by NPC ID for cache model lookups
	if npcId then
		npcIdToClone[npcId] = model
	end

	-- Listen for combat animation attribute changes on the CACHE model (in ReplicatedStorage)
	-- The cache model's attributes replicate from the server, unlike the local clone
	if npcId and NPC_MODEL_CACHE then
		local cacheModel = NPC_MODEL_CACHE:FindFirstChild(tostring(npcId))
		if cacheModel then
			print(`[NpcAnimator] 🔗 Connecting to cache model for NPC {npcId}`)

			-- Fix weapon welds and equip weapons on the client clone
			fixAndEquipWeapons(model)

			-- Combat animation changes
			npcAnimations[model].combatConnection = cacheModel:GetAttributeChangedSignal("NPCCombatAnim"):Connect(function()
				local animData = cacheModel:GetAttribute("NPCCombatAnim")
				print(`[NpcAnimator] 📨 Received attribute change from cache model: {animData or "nil"}`)
				onCombatAnimChanged(model, animData)
			end)

			-- Check if there's already a combat animation set (in case we connected late)
			local existingAnim = cacheModel:GetAttribute("NPCCombatAnim")
			if existingAnim then
				print(`[NpcAnimator] 📨 Found existing animation on cache model: {existingAnim}`)
				onCombatAnimChanged(model, existingAnim)
			end

			-- Helper to parse state string (comma-separated)
			local function parseStates(stateStr: string?): {string}
				if not stateStr or stateStr == "" then return {} end
				return string.split(stateStr, ",")
			end

			-- Helper to check if any state in list matches pattern
			local function hasStateMatching(states: {string}, pattern: string): boolean
				for _, state in ipairs(states) do
					if string.find(state, pattern) then
						return true
					end
				end
				return false
			end

			-- State change handler - updates NPC behavior based on server states
			local function onStateChanged(category: string)
				local data = npcAnimations[model]
				if not data then return end

				local stateStr = cacheModel:GetAttribute("NPC" .. category) or ""
				local states = parseStates(stateStr)

				if category == "Stuns" then
					data.currentStuns = states
					local wasStunned = data.isStunned
					data.isStunned = #states > 0

					-- If just got stunned, you might want to stop attack animations
					if data.isStunned and not wasStunned then
						-- Stun started - hit stun animation is handled separately via NPCCombatAnim
					end
				elseif category == "Actions" then
					data.currentActions = states
					-- Check for blocking state
					data.isBlocking = hasStateMatching(states, "Blocking")
				end
			end

			-- Connect to state attribute changes
			local stateCategories = {"Stuns", "Actions", "Speeds", "Frames"}
			for _, category in ipairs(stateCategories) do
				local conn = cacheModel:GetAttributeChangedSignal("NPC" .. category):Connect(function()
					onStateChanged(category)
				end)
				table.insert(npcAnimations[model].stateConnections, conn)

				-- Initialize with current state
				onStateChanged(category)
			end
		else
			print(`[NpcAnimator] ⚠️ Cache model not found for NPC {npcId}`)
		end
	else
		print(`[NpcAnimator] ⚠️ Cannot connect to cache - npcId: {npcId}, cache exists: {NPC_MODEL_CACHE ~= nil}`)
	end

	-- Start with idle
	idleTrack:Play(0.2)
	npcAnimations[model].lastState = "idle"
end

local function cleanupNpcAnimations(model: Model)
	local data = npcAnimations[model]
	if not data then
		return
	end

	if data.walkTrack then
		data.walkTrack:Stop(0)
		data.walkTrack:Destroy()
	end

	if data.idleTrack then
		data.idleTrack:Stop(0)
		data.idleTrack:Destroy()
	end

	if data.combatConnection then
		data.combatConnection:Disconnect()
	end

	-- Disconnect state connections
	if data.stateConnections then
		for _, conn in ipairs(data.stateConnections) do
			conn:Disconnect()
		end
	end

	-- Remove from ID mapping
	if data.npcId then
		npcIdToClone[data.npcId] = nil
	end

	npcAnimations[model] = nil
end

local function updateNpcAnimation(model: Model)
	local data = npcAnimations[model]
	if not data then
		return
	end

	local primaryPart = model.PrimaryPart
	if not primaryPart then
		return
	end

	-- Calculate velocity from position change
	local currentPosition = primaryPart.Position
	local timeDelta = os.clock() - data.lastTime

	if timeDelta < 0.016 then -- Don't calculate too frequently
		return
	end

	local velocity = (currentPosition - data.lastPosition) / timeDelta
	local horizontalSpeed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude

	data.lastPosition = currentPosition
	data.lastTime = os.clock()

	-- Determine if walking or idle
	local shouldWalk = horizontalSpeed > WALK_VELOCITY_THRESHOLD

	if shouldWalk and data.lastState ~= "walk" then
		-- Transition to walk
		data.idleTrack:Stop(0.2)
		data.walkTrack:Play(0.2)
		data.lastState = "walk"
	elseif not shouldWalk and data.lastState ~= "idle" then
		-- Transition to idle
		data.walkTrack:Stop(0.2)
		data.idleTrack:Play(0.2)
		data.lastState = "idle"
	end
end

-- Initialize Chrono connection
local function initializeChrono()
	local success, Chrono = pcall(function()
		return require(ReplicatedStorage.Modules.Chrono)
	end)

	if not success or not Chrono then
		warn("[NpcAnimator] Failed to require Chrono module")
		return false
	end

	if not Chrono.NpcRegistry then
		warn("[NpcAnimator] Chrono.NpcRegistry not available")
		return false
	end

	-- Listen for new NPCs
	Chrono.NpcRegistry.NpcAdded:Connect(function(_npcId, model, _initData)
		task.defer(function()
			setupNpcAnimations(model)
		end)
	end)

	-- Listen for NPC removal
	Chrono.NpcRegistry.NpcRemoved:Connect(function(_npcId, model)
		if model then
			cleanupNpcAnimations(model)
		end
	end)

	-- Set up existing NPCs by scanning the Camera folder where Chrono stores them
	local camera = workspace.CurrentCamera
	if camera then
		for _, child in camera:GetChildren() do
			if child:IsA("Model") and child:FindFirstChildOfClass("Humanoid") then
				task.defer(function()
					setupNpcAnimations(child)
				end)
			end
		end
	end

	return true
end

-- Update loop
RunService.Heartbeat:Connect(function()
	for model in npcAnimations do
		if not model or not model.Parent then
			npcAnimations[model] = nil
			continue
		end
		updateNpcAnimation(model)
	end
end)

-- Initialize immediately since this module is required after Chrono is ready
initializeChrono()

return NpcAnimator
