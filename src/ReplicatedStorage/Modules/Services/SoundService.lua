--!strict
--[[
	SoundService

	Centralized sound management for the game.
	Extracted from Library.lua for better code organization.

	Responsibilities:
	- Playing sounds with position or on characters
	- Sound variation (random pitch)
	- Automatic cleanup via Debris
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Import Utilities for Debris
local Utilities = require(ReplicatedStorage.Modules.Utilities)
local Debris = Utilities.Debris

local SoundService = {}

-- Sound part template for positional audio
local SoundPartTemplate: Part?

--[[
	Get or create the sound part template
	@return Part - The sound part template
]]
local function getSoundPartTemplate(): Part
	if not SoundPartTemplate then
		SoundPartTemplate = Instance.new("Part")
		SoundPartTemplate.Name = "SoundPart"
		SoundPartTemplate.Size = Vector3.new(1, 1, 1)
		SoundPartTemplate.Transparency = 1
		SoundPartTemplate.CanCollide = false
		SoundPartTemplate.Anchored = true
		SoundPartTemplate.CanQuery = false
		SoundPartTemplate.CanTouch = false
	end
	return SoundPartTemplate
end

--[[
	Play a sound at a position or on a character
	@param Origin CFrame | Model | BasePart - Where to play the sound
	@param S Sound | Folder - The sound to play (or folder to pick random from)
	@param Overlap boolean? - If true, allows overlapping sounds
	@param Speed number? - Pitch variation amount (default 0.1)
	@return Sound? - The playing sound instance, or nil if failed
]]
function SoundService.PlaySound(Origin: CFrame | Model | BasePart, S: Sound | Folder, Overlap: boolean?, Speed: number?): Sound?
	if not S then return nil end

	local Sound: Sound = S :: Sound
	if S:IsA("Folder") then
		local children = S:GetChildren()
		Sound = children[math.random(1, #children)] :: Sound
	end

	if typeof(Origin) == "CFrame" then
		-- Play at a world position
		local Part = getSoundPartTemplate():Clone()
		Part.CFrame = Origin
		Part.Parent = workspace

		local SoundClone = Sound:Clone()
		SoundClone.Name = "SoundClone"
		SoundClone.PlaybackSpeed *= (1 + (Speed or 0.1) * (math.random() * 2 - 1))

		local Time = 5 + (SoundClone.TimeLength / SoundClone.PlaybackSpeed)
		SoundClone.Parent = Part
		Debris:AddItem(Part, Time)

		task.spawn(function()
			RunService.Stepped:Wait()
			SoundClone:Play()
		end)

		return SoundClone
	else
		-- Play on a character/part
		local targetPart: BasePart?

		if typeof(Origin) == "Instance" then
			if Origin:IsA("Model") then
				targetPart = Origin:FindFirstChild("Torso") :: BasePart?
			elseif Origin:IsA("BasePart") then
				targetPart = Origin
			end
		end

		if not targetPart then
			warn("[SoundService] Invalid origin for PlaySound - no valid part found")
			return nil
		end

		local SoundClone = Sound:Clone()

		if Overlap then
			SoundClone.Name = "Overlap"
		else
			SoundClone.Name = "SoundClone"
		end

		SoundClone.PlaybackSpeed *= (1 + (Speed or 0.1) * (math.random() * 2 - 1))

		SoundClone.Parent = targetPart
		Debris:AddItem(SoundClone, SoundClone.TimeLength)

		task.spawn(function()
			RunService.Stepped:Wait()
			SoundClone:Play()
		end)

		return SoundClone
	end
end

--[[
	Stop a sound by name on a part
	@param Part BasePart - The part containing the sound
	@param SoundName string - The name of the sound to stop
]]
function SoundService.StopSound(Part: BasePart, SoundName: string)
	if not Part then return end

	for _, child in Part:GetChildren() do
		if child:IsA("Sound") and child.Name == SoundName then
			child:Stop()
			child:Destroy()
		end
	end
end

--[[
	Stop all sounds on a part
	@param Part BasePart - The part containing sounds
]]
function SoundService.StopAllSounds(Part: BasePart)
	if not Part then return end

	for _, child in Part:GetChildren() do
		if child:IsA("Sound") then
			child:Stop()
			child:Destroy()
		end
	end
end

return SoundService
