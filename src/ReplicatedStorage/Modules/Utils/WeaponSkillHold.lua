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
	
	-- Load animation
	local animTrack = animator:LoadAnimation(self.animation)
	
	-- Play animation
	animTrack:Play()
	
	-- Immediately pause at 0.1 seconds (10% of animation)
	task.wait(0.1)
	
	-- Check if player still exists and is holding
	if not player or not player.Parent then
		animTrack:Stop()
		return
	end
	
	animTrack:AdjustSpeed(0) -- Freeze animation
	
	-- Store held skill data
	heldSkills[player] = {
		skill = self,
		track = animTrack,
		startTime = tick(),
		character = character
	}
	
	-- Visual feedback: Glow effect while holding
	self:ApplyHoldEffect(character, true)
	
	print(`[WeaponSkillHold] {player.Name} is holding {self.skillName}`)
end

function WeaponSkillHold:OnInputEnded(player)
	local heldData = heldSkills[player]
	
	-- Check if this player is holding this specific skill
	if not heldData or heldData.skill ~= self then
		return
	end
	
	local holdDuration = tick() - heldData.startTime
	
	-- Validate character still exists
	if not heldData.character or not heldData.character.Parent then
		self:CleanupHeldSkill(player)
		return
	end
	
	-- Resume animation
	heldData.track:AdjustSpeed(1)
	
	-- Remove hold effect
	self:ApplyHoldEffect(heldData.character, false)
	
	-- Execute skill
	self:Execute(player, heldData.character, holdDuration)
	
	-- Cleanup
	heldSkills[player] = nil
	
	print(`[WeaponSkillHold] {player.Name} released {self.skillName} after {holdDuration}s`)
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
	local primaryPart = character.PrimaryPart or character:FindFirstChild("HumanoidRootPart")
	if not primaryPart then return end
	
	if isHolding then
		-- Create glow effect (weapon-themed)
		local glow = Instance.new("PointLight")
		glow.Name = "WeaponSkillHoldGlow"
		glow.Brightness = 2
		glow.Range = 10
		glow.Color = Color3.fromRGB(200, 200, 255) -- Blue-ish for weapons
		glow.Parent = primaryPart
		
		-- Particle effect
		local particles = Instance.new("ParticleEmitter")
		particles.Name = "WeaponSkillHoldParticles"
		particles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		particles.Rate = 20
		particles.Lifetime = NumberRange.new(0.5, 1)
		particles.Speed = NumberRange.new(2, 4)
		particles.Color = ColorSequence.new(Color3.fromRGB(200, 200, 255))
		particles.Parent = primaryPart
	else
		-- Remove effects
		local glow = primaryPart:FindFirstChild("WeaponSkillHoldGlow")
		if glow then glow:Destroy() end
		
		local particles = primaryPart:FindFirstChild("WeaponSkillHoldParticles")
		if particles then particles:Destroy() end
	end
end

function WeaponSkillHold:CleanupHeldSkill(player)
	local heldData = heldSkills[player]
	if not heldData then return end
	
	-- Stop animation
	if heldData.track then
		heldData.track:Stop()
	end
	
	-- Remove effects
	if heldData.character then
		self:ApplyHoldEffect(heldData.character, false)
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

