--[[
    Weapon Skill Hold System
    
    Allows weapon skills (without body movers) to be held before execution:
    - Hold key: Play first 0.1s of animation, freeze
    - Release key: Complete animation and execute skill
    
    Alchemy skills and weapon skills with body movers execute immediately.
    
    Usage:
        local WeaponSkillHold = require(ReplicatedStorage.Modules.Utils.WeaponSkillHold)
        
        local StoneLance = WeaponSkillHold.new({
            name = "Stone Lance",
            animation = animations.StoneLance,
            skillType = "weapon",
            hasBodyMovers = false,
            damage = 50,
            cooldown = 8
        })
        
        function StoneLance:Execute(player, character, holdDuration)
            -- Your skill logic here
        end
]]

local WeaponSkillHold = {}
WeaponSkillHold.__index = WeaponSkillHold

-- Track held weapon skills per player
local heldSkills = {} -- {[player]: {skill, track, startTime, character}}

-- Cooldown tracking
local cooldowns = {} -- {[userId]: {[skillName]: expiryTime}}

-- Input debounce tracking (prevents spam)
local inputDebounce = {} -- {[userId]: {[skillName]: expiryTime}}

-- Set up collision group for ghost clones (no collision with anything)
local PhysicsService = game:GetService("PhysicsService")
local hasGhostGroup = pcall(function()
	PhysicsService:GetCollisionGroupId("GhostClone")
end)

if not hasGhostGroup then
	pcall(function()
		PhysicsService:CreateCollisionGroup("GhostClone")
		-- Set GhostClone to not collide with anything
		PhysicsService:CollisionGroupSetCollidable("GhostClone", "Default", false)
	end)
end

function WeaponSkillHold.new(skillData)
	local self = setmetatable({}, WeaponSkillHold)
	
	self.skillName = skillData.name
	self.animation = skillData.animation
	self.skillType = skillData.skillType or "weapon" -- "weapon" or "alchemy"
	self.hasBodyMovers = skillData.hasBodyMovers or false
	self.damage = skillData.damage or 0
	self.cooldown = skillData.cooldown or 0
	
	return self
end

function WeaponSkillHold:OnInputBegan(player, character)
	-- ALCHEMY SKILLS: Execute immediately, no hold
	if self.skillType == "alchemy" then
		self:ExecuteImmediately(player, character)
		return
	end

	-- WEAPON SKILLS WITH BODY MOVERS: Execute immediately
	if self.hasBodyMovers then
		self:ExecuteImmediately(player, character)
		return
	end

	-- WEAPON SKILLS WITHOUT BODY MOVERS: Can be held

	-- Check input debounce (prevents spam before cooldown is set)
	local userId = player.UserId
	if not inputDebounce[userId] then
		inputDebounce[userId] = {}
	end

	if inputDebounce[userId][self.skillName] and tick() < inputDebounce[userId][self.skillName] then
		print(`[WeaponSkillHold] {self.skillName} input is debounced, ignoring input`)
		return
	end

	-- Check if player is already holding a skill (prevent spam)
	if heldSkills[player] then
		print(`[WeaponSkillHold] {player.Name} is already holding a skill, ignoring input`)
		return
	end

	-- Check cooldown
	if self:IsOnCooldown(player) then
		print(`[WeaponSkillHold] {self.skillName} is on cooldown`)
		return
	end

	-- Check if character is in the middle of executing this skill (Actions state)
	if character:FindFirstChild("Actions") and character.Actions:FindFirstChild(self.skillName) then
		print(`[WeaponSkillHold] {self.skillName} is already executing, ignoring input`)
		return
	end

	-- Set input debounce (skill animation length + cooldown)
	-- This prevents any input for this skill until it's completely done
	local debounceTime = self.cooldown + 5 -- Cooldown + extra buffer
	inputDebounce[userId][self.skillName] = tick() + debounceTime
	print(`[WeaponSkillHold] Set input debounce for {self.skillName} for {debounceTime}s`)

	-- Validate character
	if not character or not character.Parent then
		warn(`[WeaponSkillHold] Invalid character for {player.Name}`)
		-- Clear debounce if validation fails
		inputDebounce[userId][self.skillName] = nil
		return
	end
	
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		warn(`[WeaponSkillHold] No humanoid found for {player.Name}`)
		return
	end
	
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		warn(`[WeaponSkillHold] No animator found for {player.Name}`)
		return
	end
	
	-- Load animation
	local animTrack = animator:LoadAnimation(self.animation)

	-- Play animation very slowly (5% speed)
	animTrack:Play()
	animTrack:AdjustSpeed(0.05) -- Very slowly play animation until release

	-- Store held skill data
	heldSkills[player] = {
		skill = self,
		track = animTrack,
		startTime = tick(),
		character = character,
		isHolding = true, -- Track if still holding
		effectsApplied = false -- Track if visual effects have been applied
	}

	-- Start monitoring for stuns/interruptions
	task.spawn(function()
		self:MonitorForInterruptions(player, character)
	end)

	-- Delay visual effects to avoid showing them on quick taps
	task.delay(0.3, function()
		local heldData = heldSkills[player]
		if heldData and heldData.isHolding and heldData.skill == self then
			-- Still holding after 0.3s, apply visual effects
			self:ApplyHoldEffect(character, true)

			-- Create ghost clone showing the skill preview
			local ghostClone = self:CreateGhostClone(character, animTrack)
			if ghostClone then
				heldData.ghostClone = ghostClone
				print(`[WeaponSkillHold] Ghost clone created`)
			else
				warn(`[WeaponSkillHold] Failed to create ghost clone`)
			end

			heldData.effectsApplied = true
			print(`[WeaponSkillHold] {player.Name} is holding {self.skillName} - effects applied`)
		end
	end)

	print(`[WeaponSkillHold] {player.Name} started holding {self.skillName}`)
end

function WeaponSkillHold:OnInputEnded(player)
	local heldData = heldSkills[player]

	-- Check if this player is holding this specific skill
	if not heldData or heldData.skill ~= self then
		return
	end

	local holdDuration = tick() - heldData.startTime

	-- Minimum hold time to activate hold system (0.3 seconds)
	-- If released too quickly, just execute immediately without hold effects
	if holdDuration < 0.3 then
		print(`[WeaponSkillHold] {player.Name} tapped {self.skillName} (too quick for hold)`)

		-- Mark as no longer holding (prevents effects from being applied)
		heldData.isHolding = false

		-- Stop slow animation
		if heldData.track then
			heldData.track:Stop()
		end

		-- Only remove effects if they were applied
		if heldData.effectsApplied then
			self:ApplyHoldEffect(heldData.character, false)
		end

		-- Execute immediately with 0 hold duration
		self:ExecuteImmediately(player, heldData.character)

		-- Cleanup
		heldSkills[player] = nil
		return
	end

	-- Mark as no longer holding (stops interruption monitoring)
	heldData.isHolding = false

	-- Validate character still exists
	if not heldData.character or not heldData.character.Parent then
		self:CleanupHeldSkill(player)
		return
	end

	print(`[WeaponSkillHold] {player.Name} released {self.skillName} after {holdDuration}s`)

	-- Only remove effects if they were applied
	if heldData.effectsApplied then
		self:ApplyHoldEffect(heldData.character, false)

		-- Fade out and remove ghost clone
		if heldData.ghostClone then
			self:FadeOutGhostClone(heldData.ghostClone)
		end
	end

	-- Stop the slow animation (the skill will play its own animation)
	if heldData.track then
		heldData.track:Stop()
	end

	-- Cleanup held skill data
	heldSkills[player] = nil

	-- Execute skill with hold duration (skill handles its own animation)
	self:Execute(player, heldData.character, holdDuration)
end

function WeaponSkillHold:Execute(player, character, holdDuration)
	-- This should be overridden by each weapon skill
	-- Default implementation just prints
	print(`[WeaponSkillHold] Executing {self.skillName} (holdDuration: {holdDuration}s)`)
	
	-- Start cooldown
	self:StartCooldown(player)
end

function WeaponSkillHold:ExecuteImmediately(player, character)
	-- For alchemy skills or weapon skills with body movers
	print(`[WeaponSkillHold] {self.skillName} executing immediately ({self.skillType})`)
	
	-- Check cooldown
	if self:IsOnCooldown(player) then
		print(`[WeaponSkillHold] {self.skillName} is on cooldown`)
		return
	end
	
	-- Validate character
	if not character or not character.Parent then
		warn(`[WeaponSkillHold] Invalid character for {player.Name}`)
		return
	end
	
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		warn(`[WeaponSkillHold] No humanoid found for {player.Name}`)
		return
	end
	
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		warn(`[WeaponSkillHold] No animator found for {player.Name}`)
		return
	end
	
	-- Play animation normally
	local animTrack = animator:LoadAnimation(self.animation)
	animTrack:Play()
	
	-- Execute with 0 hold duration
	self:Execute(player, character, 0)
end

function WeaponSkillHold:ApplyHoldEffect(character, isHolding)
	-- Visual feedback while holding WEAPON skills
	local TweenService = game:GetService("TweenService")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Library = require(ReplicatedStorage.Modules.Library)

	local primaryPart = character.PrimaryPart or character:FindFirstChild("HumanoidRootPart")
	if not primaryPart then return end

	if isHolding then
		-- Lock position using Library state manager
		if character:FindFirstChild("Actions") then
			Library.TimedState(character.Actions, "WeaponSkillHold", 999) -- Long duration, will be manually removed
		end

		-- Lock movement speeds (SpeedSet0 = set speed to 0)
		if character:FindFirstChild("Speeds") then
			Library.TimedState(character.Speeds, "WeaponSkillHoldSpeedSet0", 999)
		end

		-- Make player invisible (fade out over 0.3s)
		-- Store original transparencies for restoration
		local transparencyStorage = Instance.new("Configuration")
		transparencyStorage.Name = "WeaponSkillHoldTransparencies"
		transparencyStorage.Parent = character

		for _, part in pairs(character:GetDescendants()) do
			if part:IsA("BasePart") then
				-- Store original transparency
				local value = Instance.new("NumberValue")
				value.Name = part:GetFullName()
				value.Value = part.Transparency
				value.Parent = transparencyStorage

				-- Fade to invisible
				local fadeOut = TweenService:Create(
					part,
					TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{Transparency = 1}
				)
				fadeOut:Play()
			elseif part:IsA("Decal") or part:IsA("Texture") then
				-- Store and fade out decals
				local value = Instance.new("NumberValue")
				value.Name = part:GetFullName()
				value.Value = part.Transparency
				value.Parent = transparencyStorage

				local fadeOut = TweenService:Create(
					part,
					TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{Transparency = 1}
				)
				fadeOut:Play()
			end
		end

	else
		-- Remove position lock using Library state manager
		if character:FindFirstChild("Actions") then
			Library.RemoveState(character.Actions, "WeaponSkillHold")
			print("[WeaponSkillHold] Removed Actions state")
		end

		-- Remove speed lock
		if character:FindFirstChild("Speeds") then
			Library.RemoveState(character.Speeds, "WeaponSkillHoldSpeedSet0")
			print("[WeaponSkillHold] Removed Speeds state")
		end

		-- Restore player visibility (fade in over 0.2s)
		local transparencyStorage = character:FindFirstChild("WeaponSkillHoldTransparencies")
		if transparencyStorage then
			-- Create a lookup table for easier access
			local transparencyLookup = {}
			for _, value in pairs(transparencyStorage:GetChildren()) do
				if value:IsA("NumberValue") then
					transparencyLookup[value.Name] = value.Value
				end
			end

			-- Restore all parts and decals
			for _, part in pairs(character:GetDescendants()) do
				local fullName = part:GetFullName()
				local originalTransparency = transparencyLookup[fullName]

				if originalTransparency and (part:IsA("BasePart") or part:IsA("Decal") or part:IsA("Texture")) then
					-- Fade back to original transparency
					local fadeIn = TweenService:Create(
						part,
						TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
						{Transparency = originalTransparency}
					)
					fadeIn:Play()
				end
			end

			-- Remove storage after restoring
			task.delay(0.2, function()
				transparencyStorage:Destroy()
			end)

			print("[WeaponSkillHold] Restoring player visibility")
		end

		print("[WeaponSkillHold] All hold effects removed")
	end
end

function WeaponSkillHold:CreateGhostClone(character, originalTrack)
	-- Create a transparent clone of the character showing the skill preview

	print("[WeaponSkillHold] CreateGhostClone called")
	print("[WeaponSkillHold] Character:", character)
	print("[WeaponSkillHold] Character.Parent:", character and character.Parent)

	-- Validate character
	if not character or not character.Parent then
		warn("[WeaponSkillHold] Cannot create ghost clone - invalid character")
		return nil
	end

	-- Temporarily enable Archivable to allow cloning
	local originalArchivable = character.Archivable
	character.Archivable = true

	-- Clone the character
	print("[WeaponSkillHold] Attempting to clone character...")
	local success, result = pcall(function()
		return character:Clone()
	end)

	-- Restore original Archivable setting
	character.Archivable = originalArchivable

	print("[WeaponSkillHold] Clone success:", success)
	print("[WeaponSkillHold] Clone result:", result)
	print("[WeaponSkillHold] Clone result type:", type(result))

	if not success then
		warn("[WeaponSkillHold] Failed to clone character:", result)
		return nil
	end

	local clone = result
	if not clone then
		warn("[WeaponSkillHold] Clone is nil - character.Archivable was likely false")
		return nil
	end

	print("[WeaponSkillHold] Clone created successfully, type:", typeof(clone))

	-- Store original transparencies for fade-in effect
	local partTransparencies = {}

	-- Remove scripts and other non-visual components FIRST
	for _, obj in pairs(clone:GetDescendants()) do
		if obj:IsA("Script") or obj:IsA("LocalScript") or obj:IsA("ModuleScript") then
			obj:Destroy()
		elseif obj:IsA("Sound") or obj:IsA("ParticleEmitter") or obj:IsA("Fire") or obj:IsA("Smoke") then
			obj:Destroy()
		end
	end

	-- Make clone look exactly like the player (solid, not transparent)
	for _, part in pairs(clone:GetDescendants()) do
		if part:IsA("BasePart") then
			-- Store original transparency
			partTransparencies[part] = part.Transparency

			-- Start fully transparent for fade-in (will fade to original transparency)
			part.Transparency = 1
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false

			-- Only anchor the root part, leave other parts unanchored for animation
			if part.Name == "HumanoidRootPart" then
				part.Anchored = true
			else
				part.Anchored = false
			end

			-- Set collision group to prevent any collision
			part.CollisionGroup = "GhostClone"

			-- Keep original color and material (looks exactly like player)
			-- Don't change color or material
		elseif part:IsA("Decal") or part:IsA("Texture") then
			-- Store original transparency for decals too
			partTransparencies[part] = part.Transparency
			-- Start invisible for fade-in
			part.Transparency = 1
		end
	end

	-- Configure humanoid for animation playback only
	local cloneHumanoid = clone:FindFirstChildOfClass("Humanoid")
	if cloneHumanoid then
		cloneHumanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		cloneHumanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	end

	-- Position clone slightly in front of the character
	local charRootPart = character:FindFirstChild("HumanoidRootPart")
	if charRootPart and clone.PrimaryPart then
		clone:SetPrimaryPartCFrame(charRootPart.CFrame * CFrame.new(0, 0, -3)) -- 3 studs in front
	end

	-- Parent to workspace
	clone.Parent = workspace

	-- Play the animation using the existing humanoid
	local humanoid = clone:FindFirstChildOfClass("Humanoid")
	print("[WeaponSkillHold] Ghost humanoid found:", humanoid)

	if humanoid then
		local animator = humanoid:FindFirstChildOfClass("Animator")
		print("[WeaponSkillHold] Ghost animator found:", animator)

		if not animator then
			animator = Instance.new("Animator")
			animator.Parent = humanoid
			print("[WeaponSkillHold] Created new animator for ghost")
		end

		print("[WeaponSkillHold] Animation object:", self.animation)
		print("[WeaponSkillHold] Animation type:", typeof(self.animation))

		-- Load and play the same animation at normal speed
		local success, ghostTrack = pcall(function()
			return animator:LoadAnimation(self.animation)
		end)

		if success and ghostTrack then
			print("[WeaponSkillHold] Animation loaded successfully")
			ghostTrack:Play()
			ghostTrack.Looped = true -- Loop the preview
			print("[WeaponSkillHold] Ghost clone animation playing, IsPlaying:", ghostTrack.IsPlaying)
		else
			warn("[WeaponSkillHold] Failed to load animation:", ghostTrack)
		end
	else
		warn("[WeaponSkillHold] No humanoid found for ghost clone animation")
	end

	-- No glow - clone should look exactly like the player

	-- Fade in effect (0.3 seconds) - fade to original transparency (looks exactly like player)
	local TweenService = game:GetService("TweenService")
	local fadeInDuration = 0.3

	for part, originalTransparency in pairs(partTransparencies) do
		if part and (part:IsA("BasePart") or part:IsA("Decal") or part:IsA("Texture")) then
			-- Tween from 1 (invisible) to original transparency (solid)
			local tweenInfo = TweenInfo.new(fadeInDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			local tween = TweenService:Create(part, tweenInfo, {Transparency = originalTransparency})
			tween:Play()
		end
	end

	print(`[WeaponSkillHold] Created ghost clone for preview`)

	return clone
end

function WeaponSkillHold:FadeOutGhostClone(clone)
	-- Fade out the ghost clone smoothly before destroying
	if not clone or not clone.Parent then return end

	local TweenService = game:GetService("TweenService")
	local fadeOutDuration = 0.2

	-- Fade out all parts and decals
	for _, part in pairs(clone:GetDescendants()) do
		if part:IsA("BasePart") then
			local fadeOutTween = TweenService:Create(
				part,
				TweenInfo.new(fadeOutDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{Transparency = 1}
			)
			fadeOutTween:Play()
		elseif part:IsA("Decal") or part:IsA("Texture") then
			local fadeOutTween = TweenService:Create(
				part,
				TweenInfo.new(fadeOutDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{Transparency = 1}
			)
			fadeOutTween:Play()
		end
	end

	-- Destroy after fade out completes
	task.delay(fadeOutDuration, function()
		if clone and clone.Parent then
			clone:Destroy()
		end
	end)

	print("[WeaponSkillHold] Fading out ghost clone")
end

function WeaponSkillHold:MonitorForInterruptions(player, character)
	-- Monitor for stuns or other interruptions during charge
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Library = require(ReplicatedStorage.Modules.Library)

	local heldData = heldSkills[player]
	if not heldData then return end

	while heldData and heldData.isHolding do
		-- Check if character still exists
		if not character or not character.Parent then
			print(`[WeaponSkillHold] Character destroyed, interrupting {self.skillName}`)
			self:CleanupHeldSkill(player)
			return
		end

		-- Check for stuns
		if character:FindFirstChild("Stuns") then
			if Library.StateCount(character.Stuns) then
				print(`[WeaponSkillHold] Stunned, interrupting {self.skillName}`)
				self:CleanupHeldSkill(player)
				return
			end
		end

		-- Check if player still exists
		if not player or not player.Parent then
			print(`[WeaponSkillHold] Player disconnected, interrupting {self.skillName}`)
			self:CleanupHeldSkill(player)
			return
		end

		task.wait(0.1) -- Check every 0.1 seconds
	end
end

function WeaponSkillHold:CleanupHeldSkill(player)
	local heldData = heldSkills[player]
	if not heldData then return end

	-- Mark as no longer holding
	heldData.isHolding = false

	-- Stop animation
	if heldData.track then
		heldData.track:Stop()
	end

	-- Remove effects
	if heldData.character then
		self:ApplyHoldEffect(heldData.character, false)
	end

	-- Fade out and remove ghost clone
	if heldData.ghostClone then
		self:FadeOutGhostClone(heldData.ghostClone)
	end

	-- Remove from tracking
	heldSkills[player] = nil

	print(`[WeaponSkillHold] Cleaned up held skill for {player.Name}`)
end

-- Cooldown Management

function WeaponSkillHold:IsOnCooldown(player)
	local cooldownData = cooldowns[player.UserId]
	if not cooldownData then return false end
	
	local expiryTime = cooldownData[self.skillName]
	if not expiryTime then return false end
	
	return tick() < expiryTime
end

function WeaponSkillHold:StartCooldown(player)
	if not cooldowns[player.UserId] then
		cooldowns[player.UserId] = {}
	end
	
	cooldowns[player.UserId][self.skillName] = tick() + self.cooldown
	print(`[WeaponSkillHold] {self.skillName} on cooldown for {self.cooldown}s`)
end

function WeaponSkillHold:GetRemainingCooldown(player)
	local cooldownData = cooldowns[player.UserId]
	if not cooldownData then return 0 end
	
	local expiryTime = cooldownData[self.skillName]
	if not expiryTime then return 0 end
	
	return math.max(0, expiryTime - tick())
end

-- Cleanup when player leaves
game:GetService("Players").PlayerRemoving:Connect(function(player)
	-- Cleanup held skills
	if heldSkills[player] then
		local heldData = heldSkills[player]
		if heldData.track then
			heldData.track:Stop()
		end
		heldSkills[player] = nil
	end
	
	-- Cleanup cooldowns
	cooldowns[player.UserId] = nil
end)

return WeaponSkillHold

