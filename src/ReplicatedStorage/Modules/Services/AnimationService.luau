--!strict
--[[
	AnimationService

	Centralized animation management for characters.
	Extracted from Library.lua for better code organization.

	Responsibilities:
	- Playing and stopping animations
	- Animation caching per character
	- Clearing animation cache on character removal
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimationService = {}

-- Animation cache: Character -> AnimationName -> AnimationTrack
local Animations: {[Model]: {[string]: AnimationTrack}} = {}

--[[
	Play an animation on a character
	@param Char Model - The character model
	@param Name string | Animation - Animation name or Animation instance
	@param Transition number? - Fade transition time (default 0.1)
	@return AnimationTrack? - The playing animation track, or nil if failed
]]
function AnimationService.PlayAnimation(Char: Model, Name: string | Animation, Transition: number?): AnimationTrack?
	if not Char then return nil end

	-- Use character instance as key instead of name to avoid respawn issues
	if not Animations[Char] then
		Animations[Char] = {}
	end

	local animName = if typeof(Name) == "string" then Name else Name.Name

	-- Check if animation is already playing
	if Animations[Char][animName] and Animations[Char][animName].IsPlaying then
		return Animations[Char][animName]
	end

	local Anim: Animation? = nil
	if typeof(Name) == "string" then
		-- First try to find in Movement folder for run animations
		Anim = ReplicatedStorage:WaitForChild("Assets").Animations.Movement:FindFirstChild(Name, true)

		-- If not found in Movement, search in all Animations
		if not Anim then
			Anim = ReplicatedStorage:WaitForChild("Assets").Animations:FindFirstChild(Name, true)
		end
	else
		Anim = Name
	end

	if not Anim then
		warn(`Animation "{animName}" not found in Assets.Animations`)
		return nil
	end

	local humanoid = Char:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		warn(`No Humanoid found for {Char.Name}`)
		return nil
	end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		warn(`No Animator found for {Char.Name}`)
		return nil
	end

	-- Load and play animation only if not already loaded and playing
	if not Animations[Char][animName] then
		Animations[Char][animName] = animator:LoadAnimation(Anim)
	end

	Animations[Char][animName]:Play(Transition or 0.1)
	return Animations[Char][animName]
end

--[[
	Stop an animation on a character
	@param Char Model - The character model
	@param Name string | Animation - Animation name or Animation instance
	@param FadeTime number? - Fade out time
]]
function AnimationService.StopAnimation(Char: Model, Name: string | Animation, FadeTime: number?)
	if not Char then return end

	-- Use character instance as key instead of name to avoid respawn issues
	if not Animations[Char] then
		Animations[Char] = {}
	end

	local animName = if typeof(Name) == "string" then Name else Name.Name

	if Animations[Char][animName] == nil then
		local anim: Animation? = nil
		if typeof(Name) == "string" then
			anim = ReplicatedStorage:WaitForChild("Assets").Animations:FindFirstChild(Name, true)
		else
			anim = Name
		end

		-- If animation not found, just return instead of trying to load nil
		if not anim then
			warn(`Animation "{animName}" not found in Assets.Animations (StopAnimation)`)
			return
		end

		local humanoid = Char:FindFirstChildOfClass("Humanoid")
		if not humanoid then return end

		local animator = humanoid:FindFirstChildOfClass("Animator")
		if not animator then return end

		Animations[Char][animName] = animator:LoadAnimation(anim)
	end

	Animations[Char][animName]:Stop(FadeTime)
end

--[[
	Stop all weapon/ability animations on a character
	@param Char Model - The character model
]]
function AnimationService.StopAllAnims(Char: Model)
	if not Char then return end

	local Player = Players:GetPlayerFromCharacter(Char)
	local Weapon = if Player then Player:GetAttribute("Weapon") else "Fist"

	local humanoid = Char:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then return end

	local miscFolder = ReplicatedStorage.Assets.Animations:FindFirstChild("Misc")
	local weaponFolder = ReplicatedStorage.Assets.Animations.Weapons:FindFirstChild(Weapon)

	for _, v in animator:GetPlayingAnimationTracks() do
		local shouldStop = false

		-- Check if it's a numbered animation (combat)
		if tonumber(v.Name) then
			shouldStop = true
		-- Check abilities folder
		elseif ReplicatedStorage.Assets.Animations.Abilities:FindFirstChild(v.Name) then
			shouldStop = true
		-- Check weapon swings and general weapon animations
		elseif weaponFolder then
			if weaponFolder.Swings:FindFirstChild(v.Name) or weaponFolder:FindFirstChild(v.Name) then
				shouldStop = true
			end
		end
		-- Check misc folder
		if miscFolder and miscFolder:FindFirstChild(v.Name) then
			shouldStop = true
		end

		if shouldStop then
			v:Stop(0.2)
		end
	end
end

--[[
	Stop movement animations on a character
	@param Char Model - The character model
]]
function AnimationService.StopMovementAnimations(Char: Model)
	if not Char then return end

	local humanoid = Char:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then return end

	local movementAnims = {"Left", "Right", "Forward", "Back", "CancelLeft", "CancelRight"}

	for _, v in animator:GetPlayingAnimationTracks() do
		if table.find(movementAnims, v.Name) then
			v:Stop()
		end
	end
end

--[[
	Clear animation cache for a character
	@param Char Model - The character model
]]
function AnimationService.ClearAnimationCache(Char: Model)
	if not Char then return end

	if Animations[Char] then
		for _, animTrack in pairs(Animations[Char]) do
			if animTrack and animTrack.IsPlaying then
				animTrack:Stop(0)
			end
			if animTrack then
				animTrack:Destroy()
			end
		end
		Animations[Char] = nil
	end
end

--[[
	Stop all playing animation tracks and destroy them
	@param Char Model - The character model
]]
function AnimationService.StopAndDestroyAllTracks(Char: Model)
	if not Char then return end

	local humanoid = Char:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then return end

	for _, track in pairs(animator:GetPlayingAnimationTracks()) do
		track:Stop(0)
		track:Destroy()
	end
end

--[[
	Get cached animation track for a character
	@param Char Model - The character model
	@param AnimName string - The animation name
	@return AnimationTrack? - The cached animation track, or nil
]]
function AnimationService.GetCachedAnimation(Char: Model, AnimName: string): AnimationTrack?
	if not Char or not Animations[Char] then return nil end
	return Animations[Char][AnimName]
end

return AnimationService
