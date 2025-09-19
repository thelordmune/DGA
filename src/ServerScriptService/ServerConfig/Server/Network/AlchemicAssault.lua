local ServerStorage = game:GetService("ServerStorage")
local Replicated = game:GetService("ReplicatedStorage")
local Server
local Utilities = require(Replicated.Modules.Utilities)
local Library = require(Replicated.Modules.Library)
local Packets = require(Replicated.Modules.Packets)
local Visuals = require(Replicated.Modules.Visuals)
local Voxbreaker = require(Replicated.Modules.Voxel)
local SFX = Replicated.Assets.SFX
local WeaponStats = require(ServerStorage.Stats._Weapons)
local Moves = require(ServerStorage.Stats._Moves)
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local RunService = game:GetService("RunService")

local NetworkModule = {}
local Server = require(script.Parent.Parent)
NetworkModule.__index = NetworkModule
local self = setmetatable({}, NetworkModule)

local activeConnections = {}
local activeTweens = {}

local function cleanUp()
	for _, conn in pairs(activeConnections) do
		conn:Disconnect()
	end
	activeConnections = {}

	for _, t in pairs(activeTweens) do
		t:Cancel()
	end
	activeTweens = {}
end

NetworkModule.EndPoint = function(Player, Data)
	local Character = Player.Character

	if not Character or not Character:GetAttribute("Equipped") then
		return
	end

	local PlayerObject = Server.Modules["Players"].Get(Player)
	local Animation = Replicated.Assets.Animations.Misc.AA

	local Hitbox = Server.Modules.Hitbox
	local Entity = Server.Modules["Entities"].Get(Character)
	local Weapon: string = Entity.Weapon
	local Stats: {} = WeaponStats[Weapon]
	local Move: string = script.Name
	local Moves: {} = Moves[Move]

	local root = Character:FindFirstChild("HumanoidRootPart")

	if Server.Library.StateCount(Character.Actions) or Server.Library.StateCount(Character.Stuns) then
		return
	end

	if PlayerObject and PlayerObject.Keys and not Server.Library.CheckCooldown(Character, "AlchemicAssault") then
		cleanUp()
		Server.Library.SetCooldown(Character,"AlchemicAssault",7)
		Server.Library.StopAllAnims(Character)

		local Alchemy = Library.PlayAnimation(Character, Animation)
		Alchemy.Looped = false
		-- Alchemy:AdjustSpeed(1) -- Add mulitplier later
		-- Alchemy:Play()

		Server.Visuals.Ranged(Character.HumanoidRootPart.Position, 300, {
					Module = "Base",
					Function = "AlchemicAssault",
					Arguments = { Character, "Jump" },
				})

		repeat task.wait() until Alchemy.Length > 0 
    	local duration = Alchemy:GetTimeOfKeyframe("Land")
		print(duration)
		Server.Library.TimedState(Character.Actions, "AlchemicAssault", Alchemy.Length)
		
		Server.Library.TimedState(Character.Speeds, "AlcSpeed-0", Alchemy.Length)

		Server.Packets.Bvel.sendTo({Character = Character, Name = "AABvel" }, Player)

				local kfConn
		kfConn = Alchemy.KeyframeReached:Connect(function(key)
			if key == "Land" then
			Server.Library.AddState(Character.Stuns, "NoRotate")
			

			

			local s = Replicated.Assets.SFX.FMAB.Clap:Clone()
					s.Parent = Character.HumanoidRootPart
					s:Play()
					Debris:AddItem(s, s.TimeLength)

			Server.Visuals.Ranged(Character.HumanoidRootPart.Position, 300, {
						Module = "Base", 
						Function = "Clap", 
						Arguments = {Character}
					})
		end

		if key == "Mutate" then
			local s = Replicated.Assets.SFX.FMAB.Transmute:Clone()
					s.Volume = 2
					s.Parent = Character.HumanoidRootPart
					s:Play()
					Debris:AddItem(s, s.TimeLength)

			Server.Visuals.Ranged(Character.HumanoidRootPart.Position, 300, {
						Module = "Base", 
						Function = "Transmute", 
						Arguments = {Character}
					})

				Server.Visuals.FireClient(Player, {
						Module = "Base", 
						Function = "Shake", 
						Arguments = {"Once", { 6, 11, 0, 0.7, Vector3.new(1.1, 2, 1.1), Vector3.new(0.34, 0.25, 0.34) }}
					})
			local wallCount = math.random(3, 6)
            -- Base distance from player
            local baseDistance = 15
            -- Distance increment between walls
            local distanceIncrement = 13
            
            -- Get player's look direction (flattened to XZ plane)
            local playerLookVector = root.CFrame.LookVector
            playerLookVector = Vector3.new(playerLookVector.X, 0, playerLookVector.Z).Unit
            
            -- Spawn walls in sequence
            for i = 1, wallCount do
                task.delay((i-1) * 0.15, function()
					Server.Visuals.FireClient(Player, {
						Module = "Base", 
						Function = "Shake", 
						Arguments = {"Once", { 3, 5, 0, 0.3, Vector3.new(1.1, 2, 1.1), Vector3.new(0.34, 0.25, 0.34) }}
					})
                    local part = Instance.new("Part")
                    part.Name = "AbilityWall_" .. os.time()
                    part.Anchored = true
                    part.CanCollide = true
                    part.Transparency = 0
                    part.Material = Enum.Material.Plastic
                    part.MaterialVariant = "Alchemy"
                    part.Color = Color3.fromRGB(100, 150, 255)
                    part:SetAttribute("Id", HttpService:GenerateGUID(false))

					Server.Visuals.Ranged(Character.HumanoidRootPart.Position, 300, {
						Module = "Base", 
						Function = "WallErupt", 
						Arguments = {part, Character}
					})
                    
                    -- Randomize wall dimensions slightly
                    local baseSize = math.random(6, 10)
                    local variation = math.random() * 0.5 + 0.75
                    local width = baseSize * variation
                    local height = baseSize * 2
                    local depth = baseSize * variation
                    part.Size = Vector3.new(width, height, depth)
                    
                    -- Calculate position (further out for each subsequent wall)
                    local spawnDistance = baseDistance + (distanceIncrement * (i-1))
                    local spawnOffset = Vector3.new(0, -3, 0) -- Height offset
                    local startPos = root.Position + (playerLookVector * spawnDistance) + spawnOffset
                    
                    -- Create wall CFrame (facing same direction as player)
                    local wallCFrame = CFrame.new(startPos)
                        * CFrame.fromEulerAnglesYXZ(0, math.atan2(playerLookVector.Z, playerLookVector.X), 0)
                    
                    -- Start position (below ground)
                    local belowGroundOffset = height + 2
                    part.CFrame = wallCFrame * CFrame.new(0, -belowGroundOffset, 0) * CFrame.Angles(0, math.rad(120), 0)
                    part.Parent = workspace.Transmutables
                    
                    -- Tween the wall up
                    local tweenInfo = TweenInfo.new(
                        0.5, -- Duration
                        Enum.EasingStyle.Circular,
                        Enum.EasingDirection.Out
                    )
                    
                    local tween = TweenService:Create(
                        part,
                        tweenInfo,
                        {CFrame = wallCFrame * CFrame.new(0, -1, 0)} -- Final position (slightly above ground)
                    )
                    
                    tween:Play()
                    
                    -- Add some visual effects
                    -- local particle = Instance.new("ParticleEmitter")
                    -- particle.Texture = "rbxassetid://242932737"
                    -- particle.LightEmission = 1
                    -- particle.Color = ColorSequence.new(part.Color)
                    -- particle.Size = NumberSequence.new(0.5)
                    -- particle.Transparency = NumberSequence.new(0.5)
                    -- particle.Speed = NumberRange.new(1)
                    -- particle.Lifetime = NumberRange.new(0.5)
                    -- particle.Rate = 20
                    -- particle.Rotation = NumberRange.new(0, 360)
                    -- particle.Parent = part
                    
                    -- Clean up after some time
                    if i == wallCount then
                        Alchemy:AdjustSpeed(1)
						Server.Library.RemoveState(Character.Stuns, "NoRotate")
						Server.Library.RemoveState(Character.Speeds, "AlcSpeed-0")
                        -- world:set(pEntity, comps.NoRotate, { value = false, duration = 0 })
                        -- world:set(pEntity, comps.CantMove, { value = false, duration = 0 })
                    end
                    Debris:AddItem(part, 10)
                end)
            end
		end

       if key == "Endframe" then
            Alchemy:AdjustSpeed(0)
            
            -- Number of walls to spawn (random between 5-10)
            task.delay(0.2, function()
				Alchemy:AdjustSpeed(1)
            end)
        end
		end)
		table.insert(activeConnections, kfConn)
	end
end

return NetworkModule
