local Library = {};
Library.__index = Library;
local self = setmetatable({}, Library);

local Utilities = require(script.Parent.Utilities);
local Debris    = Utilities.Debris;

local Players 	  = game:GetService("Players");
local RunService  = game:GetService("RunService");
local HttpService = game:GetService("HttpService");
local Replicated  = game:GetService("ReplicatedStorage");

-- Import ECS state and cooldown managers
local StateManager = require(Replicated.Modules.ECS.StateManager)
local CooldownManager = require(Replicated.Modules.ECS.CooldownManager)

local Animations = {};
-- Cooldowns are now managed by ECS CooldownManager
-- local Cooldowns  = {};

Library.PlayAnimation = function(Char: Model, Name, Transition: number)
    if not Char then return end;
    -- Use character instance as key instead of name to avoid respawn issues
    if not Animations[Char] then Animations[Char] = {} end

    -- Check if animation is already playing
    if Animations[Char][Name] and Animations[Char][Name].IsPlaying then
        return Animations[Char][Name]
    end

    local Anim = Name;
    if type(Anim) == "string" then
        -- First try to find in Movement folder for run animations
        Anim = Replicated:WaitForChild("Assets").Animations.Movement:FindFirstChild(Name, true)

        -- If not found in Movement, search in all Animations
        if not Anim then
            Anim = Replicated:WaitForChild("Assets").Animations:FindFirstChild(Name, true)
        end
    end

    if not Anim then
        warn(`Animation "{Name}" not found in Assets.Animations`)
        return
    end

    -- Load and play animation only if not already loaded and playing
    if not Animations[Char][Name] then
        Animations[Char][Name] = Char.Humanoid.Animator:LoadAnimation(Anim)
    end

    Animations[Char][Name]:Play(Transition)
    return Animations[Char][Name]
end

Library.StopAnimation = function(Char: Model,Name, Table)
	if not Char then return end;
	-- Use character instance as key instead of name to avoid respawn issues
	if not Animations[Char] then Animations[Char] = {} end

	if Animations[Char][Name] == nil then
		local anim = Name
		if type(anim) == "string" then
			anim = Replicated:WaitForChild("Assets").Animations:FindFirstChild(Name, true)
		end

		-- If animation not found, just return instead of trying to load nil
		if not anim then
			warn(`Animation "{Name}" not found in Assets.Animations (StopAnimation)`)
			return
		end

		Animations[Char][Name] = Char.Humanoid.Animator:LoadAnimation(anim)
	end

	Animations[Char][Name]:Stop(Table)
end

Library.StopAllAnims = function(Char: Model)
	local Weapon
	local Player = Players:GetPlayerFromCharacter(Char)
	if not Char then return end

	if Player then
		Weapon = Player:GetAttribute("Weapon")
	else
		Weapon = "Fist"
	end

	for _, v in next, Char.Humanoid.Animator:GetPlayingAnimationTracks() do
		if tonumber(v.Name) or Replicated.Assets.Animations.Abilities:FindFirstChild(v.Name) or Replicated.Assets.Animations.Weapons[Weapon].Swings:FindFirstChild(v.Name) or Replicated.Assets.Animations.Weapons[Weapon]:FindFirstChild(v.Name) then
			v:Stop(.2)
		end
	end

end

-- Comprehensive cleanup function for character respawn
Library.CleanupCharacter = function(Char: Model)
	if not Char then return end

	-- Clear animation cache for this character
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
		---- print("Cleared animation cache for character:", Char.Name)
	end

	-- Clear cooldowns for this character (ECS-based)
	CooldownManager.ClearAllCooldowns(Char)
	---- print("Cleared cooldowns for character:", Char.Name)

	-- Clear all states for this character (ECS-based)
	for _, category in ipairs({"Actions", "Stuns", "IFrames", "Speeds", "Frames", "Status"}) do
		StateManager.ClearCategory(Char, category)
	end
	---- print("Cleared states for character:", Char.Name)

	-- Stop all playing animation tracks
	if Char:FindFirstChild("Humanoid") and Char.Humanoid:FindFirstChild("Animator") then
		for _, track in pairs(Char.Humanoid.Animator:GetPlayingAnimationTracks()) do
			track:Stop(0)
			track:Destroy()
		end
		---- print("Stopped all animation tracks for character:", Char.Name)
	end

	-- Clean up all body movers to prevent flinging
	Library.RemoveAllBodyMovers(Char)
end

Library.StopMovementAnimations = function(Char: Model)
	if not Char then return end;
	local Table = {"Left", "Right", "Forward", "Back", "CancelLeft", "CancelRight"};

	for _, v in next, Char.Humanoid.Animator:GetPlayingAnimationTracks() do
		if table.find(Table, v.Name) then
			v:Stop()
		end
	end
end

-- Remove all body movers from a character to prevent flinging
Library.RemoveAllBodyMovers = function(Char: Model)
	if not Char then return end

	local moversRemoved = 0

	-- Check all descendants for body movers
	for _, descendant in pairs(Char:GetDescendants()) do
		if descendant:IsA("BodyVelocity")
			or descendant:IsA("BodyPosition")
			or descendant:IsA("BodyGyro")
			or descendant:IsA("BodyAngularVelocity")
			or descendant:IsA("LinearVelocity")
			or descendant:IsA("AngularVelocity")
			or descendant:IsA("AlignPosition")
			or descendant:IsA("AlignOrientation") then
			descendant:Destroy()
			moversRemoved = moversRemoved + 1
		end
	end

	-- Clear residual velocity from HumanoidRootPart
	local rootPart = Char:FindFirstChild("HumanoidRootPart")
	if rootPart then
		rootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
		rootPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
	end

	if moversRemoved > 0 then
		---- print(`[Library] Removed {moversRemoved} body movers from {Char.Name}`)
	end
end

Library.PlaySound = function(Origin, S,Overlap: boolean,Speed: number)
	local Sound = S
	if not Sound then return end;

	if Sound:IsA("Folder") then
		Sound = Sound:GetChildren()[math.random(1,#Sound:GetChildren())]
	end

	if typeof(Origin) == "CFrame" then
		local Part = script.SoundPart:Clone()
		Part.CFrame = Origin
		Part.Parent = workspace

		local SoundClone = Sound:Clone()
		SoundClone.Name = "SoundClone"
		SoundClone.PlaybackSpeed *= (1+(0.1)*(math.random()*2-1))

		local Time = 5 + (SoundClone.TimeLength / SoundClone.PlaybackSpeed)
		SoundClone.Parent = Part
		Debris:AddItem(Part,Time)


		coroutine.wrap(function()
			RunService.Stepped:Wait()
			SoundClone:Play()
		end)()

		return SoundClone
	else
		if Sound and Origin:FindFirstChild("Torso") then
			local SoundClone = Sound:Clone()

			if Overlap then
				SoundClone.Name = "Overlap"
			else
				SoundClone.Name = "SoundClone"
			end

			SoundClone.PlaybackSpeed *= (1+(Speed or 0.1)*(math.random()*2-1))

			local Time = 5+(SoundClone.TimeLength / SoundClone.PlaybackSpeed)
			SoundClone.Parent = Origin.Torso
			Debris:AddItem(SoundClone,SoundClone.TimeLength)

			coroutine.wrap(function()
				RunService.Stepped:Wait()
				SoundClone:Play()
			end)()

			return SoundClone
		elseif Sound and Origin:IsA("Part") then
			local SoundClone = Sound:Clone()

			if Overlap then
				SoundClone.Name = "Overlap"
			else
				SoundClone.Name = "SoundClone"
			end

			SoundClone.PlaybackSpeed *= (1+(Speed or 0.1)*(math.random()*2-1))

			local Time = 5+(SoundClone.TimeLength / SoundClone.PlaybackSpeed)
			SoundClone.Parent = Origin
			Debris:AddItem(SoundClone,SoundClone.TimeLength)

			coroutine.wrap(function()
				RunService.Stepped:Wait()
				SoundClone:Play()
			end)()

			return SoundClone
		end
	end
end

-- ECS-based cooldown functions
Library.SetCooldown = function(Char: Model, Identifier: string, Time: number)
	CooldownManager.SetCooldown(Char, Identifier, Time)
end

Library.CheckCooldown = function(Char: Model, Identifier: string)
	return CooldownManager.CheckCooldown(Char, Identifier)
end

Library.ResetCooldown = function(Char: Model, Identifier: string)
	CooldownManager.ResetCooldown(Char, Identifier)
end

Library.GetCooldowns = function(Char: Model)
	return CooldownManager.GetCooldowns(Char)
end

Library.GetCooldownTime = function(Char: Model, Identifier: string)
	return CooldownManager.GetCooldownTime(Char, Identifier)
end

function ReturnDecodedTable(Table)
	return HttpService:JSONDecode(Table.Value)
end

function ReturnEncodedTable(Table)
	return HttpService:JSONEncode(Table)
end

-- Helper to extract category from StringValue name
local function getCategoryFromStringValue(stringValue)
	local name = stringValue.Name
	-- Map old StringValue names to new categories
	local categoryMap = {
		Actions = "Actions",
		Stuns = "Stuns",
		IFrames = "IFrames",
		Speeds = "Speeds",
		Frames = "Frames",
		Status = "Status",
	}
	return categoryMap[name] or "Actions"
end

-- Helper to get character from StringValue
local function getCharacterFromStringValue(stringValue)
	-- Validate input
	if not stringValue or typeof(stringValue) ~= "Instance" then
		-- Silent fail for nil - this is expected when character is respawning
		return nil
	end

	if not stringValue:IsA("StringValue") then
		warn(`[Library] Expected StringValue, got {stringValue.ClassName} named "{stringValue.Name}"`)
		return nil
	end

	local parent = stringValue.Parent
	if not parent then
		-- Silent fail for no parent - StringValue might be destroyed
		return nil
	end

	if not parent:IsA("Model") then
		warn(`[Library] StringValue "{stringValue.Name}" parent is not a Model: {parent.ClassName} named "{parent.Name}"`)
		return nil
	end

	return parent
end

-- ECS-based state functions
Library.StateCheck = function(Table, FrameName)
	local character = getCharacterFromStringValue(Table)
	if not character then return false end

	local category = getCategoryFromStringValue(Table)
	return StateManager.StateCheck(character, category, FrameName)
end

Library.StateCount = function(Table)
	local character = getCharacterFromStringValue(Table)
	if not character then return false end

	local category = getCategoryFromStringValue(Table)
	return StateManager.StateCount(character, category)
end

Library.MultiStateCheck = function(Table, Query)
	local character = getCharacterFromStringValue(Table)
	if not character then return true end

	local category = getCategoryFromStringValue(Table)
	return StateManager.MultiStateCheck(character, category, Query)
end

Library.AddState = function(Table, Name)
	local character = getCharacterFromStringValue(Table)
	if not character then return end

	local category = getCategoryFromStringValue(Table)
	StateManager.AddState(character, category, Name)
end

Library.RemoveState = function(Table, Name)
	local character = getCharacterFromStringValue(Table)
	if not character then return end

	local category = getCategoryFromStringValue(Table)
	StateManager.RemoveState(character, category, Name)
end

Library.TimedState = function(Table, Name, Time)
	local character = getCharacterFromStringValue(Table)
	if not character then return end

	local category = getCategoryFromStringValue(Table)
	StateManager.TimedState(character, category, Name, Time)
end

Library.RemoveAllStates = function(Table, Name)
	local character = getCharacterFromStringValue(Table)
	if not character then return end

	local category = getCategoryFromStringValue(Table)
	StateManager.RemoveAllStates(character, category, Name)
end

Library.Remove = function(Char) --> For Clean Up
	if Animations[Char.Name] then Animations[Char.Name] = nil end;
	-- Cooldowns are now managed by ECS
	CooldownManager.ClearAllCooldowns(Char)
end

Library.GetAllStates = function(Table)
	local character = getCharacterFromStringValue(Table)
	if not character then return {} end

	local category = getCategoryFromStringValue(Table)
	return StateManager.GetAllStates(character, category)
end

Library.GetAllStatesFromCharacter = function(Char: Model)
	return StateManager.GetAllStatesFromCharacter(Char)
end

Library.GetSpecificState = function(Char: Model, DesiredState: string)
	if not Char then return nil end

	-- Check all state categories for the desired state
	local allStates = StateManager.GetAllStatesFromCharacter(Char)

	for category, states in pairs(allStates) do
		for _, state in ipairs(states) do
			if string.match(state, DesiredState) then
				-- Return a mock StringValue for backwards compatibility
				local mockStringValue = Instance.new("StringValue")
				mockStringValue.Name = category
				mockStringValue.Parent = Char
				return mockStringValue
			end
		end
	end

	return nil
end


return Library
