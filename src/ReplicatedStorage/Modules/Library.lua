local Library = {};
Library.__index = Library;
local self = setmetatable({}, Library);

local Utilities = require(script.Parent.Utilities);
local Debris    = Utilities.Debris;

local Players 	  = game:GetService("Players");
local RunService  = game:GetService("RunService");
local HttpService = game:GetService("HttpService");
local Replicated  = game:GetService("ReplicatedStorage");

local Animations = {};
local Cooldowns  = {};

Library.PlayAnimation = function(Char: Model, Name, Transition: number)
    if not Char then return end;
    if not Animations[Char.Name] then Animations[Char.Name] = {} end

    -- Check if animation is already playing
    if Animations[Char.Name][Name] and Animations[Char.Name][Name].IsPlaying then
        return Animations[Char.Name][Name]
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
    if not Animations[Char.Name][Name] then
        Animations[Char.Name][Name] = Char.Humanoid.Animator:LoadAnimation(Anim)
    end
    
    Animations[Char.Name][Name]:Play(Transition)
    return Animations[Char.Name][Name]
end

Library.StopAnimation = function(Char: Model,Name, Table)
	if not Char then return end;
	if not Animations[Char.Name] then Animations[Char.Name] = {} end

	if Animations[Char.Name][Name] == nil then
		local anim = Name
		if type(anim) == "string" then
			anim = Replicated:WaitForChild("Assets").Animations:FindFirstChild(Name, true)
		end
		Animations[Char.Name][Name] = Char.Humanoid.Animator:LoadAnimation(anim)
	end
	
	Animations[Char.Name][Name]:Stop(Table)
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

Library.StopMovementAnimations = function(Char: Model)
	if not Char then return end;
	local Table = {"Left", "Right", "Forward", "Back", "CancelLeft", "CancelRight"};
	
	for _, v in next, Char.Humanoid.Animator:GetPlayingAnimationTracks() do
		if table.find(Table, v.Name) then
			v:Stop()
		end
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

Library.SetCooldown = function(Char: Model, Identifier: string, Time: number)
	if not Cooldowns[Char.Name] then Cooldowns[Char.Name] = {} end;
	Cooldowns[Char.Name][Identifier] = os.clock() + Time
end

Library.CheckCooldown = function(Char: Model, Identifier: string)
	if not Cooldowns[Char.Name] then Cooldowns[Char.Name] = {} end;
	if Cooldowns[Char.Name][Identifier] then 
		if Cooldowns[Char.Name][Identifier] > os.clock()  then
			return true;
		else
			Cooldowns[Char.Name][Identifier] = nil
			return false;
		end
	end;

	return false;
end

Library.ResetCooldown = function(Char: Model, Identifier: string)
	if not Cooldowns[Char.Name] then Cooldowns[Char.Name] = {} end;
	if Cooldowns[Char.Name][Identifier] ~= nil then Cooldowns[Char.Name][Identifier] = 0 end;
end

function ReturnDecodedTable(Table)
	return HttpService:JSONDecode(Table.Value)
end

function ReturnEncodedTable(Table)
	return HttpService:JSONEncode(Table)
end

Library.StateCheck = function(Table, FrameName)
	local Found = false
	local DecodedTable = ReturnDecodedTable(Table)

	return (table.find(DecodedTable, FrameName) and true) or false
end

Library.StateCount = function(Table)
	local Decode = ReturnDecodedTable(Table);
	return (#Decode > 0 and true) or false;
end

Library.MultiStateCheck = function(Table, Query) 
	local Pass = true
	local DecodedTable = ReturnDecodedTable(Table)

	for _, Frame in Query do
		if table.find(DecodedTable, Frame) then
			Pass = false
		end
	end

	return Pass
end

Library.AddState = function(Table, Name)
	local DecodedTable = ReturnDecodedTable(Table)
	table.insert(DecodedTable, Name)
	Table.Value = ReturnEncodedTable(DecodedTable)
end

Library.RemoveState = function(Table, Name)
	local DecodedTable = ReturnDecodedTable(Table)
	local Query = table.find(DecodedTable, Name);
	
	if Query then table.remove(DecodedTable, Query) end;
	Table.Value = ReturnEncodedTable(DecodedTable)
end

Library.TimedState = function(Table, Name, Time)
	self.AddState(Table, Name)
	task.delay(Time, function()
		self.RemoveState(Table, Name)
	end)
end

Library.RemoveAllStates = function(Table, Name)
	local DecodedTable = ReturnDecodedTable(Table)

	for FrameIndex, Frame in DecodedTable do
		if Frame == Name then
			table.remove(DecodedTable, FrameIndex)
		end
	end

	Table.Value = ReturnEncodedTable(DecodedTable)
end

Library.Remove = function(Char) --> For Clean Up
	if Animations[Char.Name] then Animations[Char.Name] = nil end;
	if Cooldowns[Char.Name] then Cooldowns[Char.Name] = nil end;
end

Library.GetAllStates = function(Table)
	local DecodedTable = ReturnDecodedTable(Table)
	return DecodedTable
end

Library.GetAllStatesFromCharacter = function(Char: Model)
	if not Char then return {} end
	local allStates = {}

	for _, child in Char:GetDescendants() do
		if child:IsA("StringValue") and child.Value ~= "" then
			local success, decodedTable = pcall(function()
				return HttpService:JSONDecode(child.Value)
			end)
			
			if success and type(decodedTable) == "table" then
				allStates[child.Name] = decodedTable
			end
		end
	end

	return allStates
end

Library.GetSpecificState = function(Char: Model, DesiredState: string)
    if not Char then return nil end
    
    for _, child in Char:GetDescendants() do
        if child:IsA("StringValue") and child.Value ~= "" then
            local success, decodedTable = pcall(function()
                return HttpService:JSONDecode(child.Value)
            end)
            
            if success and type(decodedTable) == "table" then
                for _, state in decodedTable do
                    if string.match(state, DesiredState) then
                        return child
                    end
                end
            end
        end
    end
    
    return nil
end


return Library
