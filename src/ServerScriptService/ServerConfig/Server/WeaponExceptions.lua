local Customs = {}
local Server = require(script.Parent)
local WeaponStats = require(Server.Service.ServerStorage:WaitForChild("Stats")._Weapons)
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Voxbreaker = require(ReplicatedStorage.Modules.Voxel)
local RunService = game:GetService("RunService")
local Moves = require(game:GetService("ServerStorage").Stats._Moves)
local Replicated = game:GetService("ReplicatedStorage")
local Lightning = require(ReplicatedStorage.Lightning)

Customs.__index = Customs
local self = setmetatable({}, Customs)

Customs.Flame = function(Character, Entity, Weapon, Stats)
	local Hitbox = Server.Modules.Hitbox
	if Stats then
		if Entity["SwingConnection"] then
			if Server.Library.StateCheck(Character.Speeds, "M1Speed10") then
				Server.Library.RemoveState(Character.Speeds, "M1Speed10")
			end

			Entity["SwingConnection"]:Disconnect()
			Entity["SwingConnection"] = nil
		end

		Entity.Combo += 1

		local Combo: number = Entity.Combo
		local Cancel = false
		local Max = false

		Entity.LastHit = os.clock()

		if Entity.Combo >= Stats.MaxCombo then
			Max = true
			Entity.Combo = 0
		end

		Server.Library.TimedState(Character.Actions, "M1" .. Combo, Stats["Endlag"][Combo])
		Server.Library.AddState(Character.Speeds, "M1Speed10") -- Changed from 8 to 12 for faster combat

		local Swings = Server.Service.ReplicatedStorage.Assets.Animations.Weapons[Weapon].Swings

		local SwingAnimation = Character.Humanoid.Animator:LoadAnimation(Swings:FindFirstChild(Combo))
		SwingAnimation:Play()
		SwingAnimation.Priority = Enum.AnimationPriority.Action2

		local Sound = Server.Library.PlaySound(
			Character,
			Server.Service.ReplicatedStorage.Assets.SFX.Weapons[Weapon].Swings[Random.new():NextInteger(
				1,
				2
			)]
		)

		if Stats["Trail"] then
			Customs.Trail(Character, true)
		end

		Entity["SwingConnection"] = SwingAnimation.Stopped:Once(function()
			Entity["SwingConnection"] = nil

			-- Remove M1Speed10 (not M1Speed8)
			if Server.Library.StateCheck(Character.Speeds, "M1Speed10") then
				Server.Library.RemoveState(Character.Speeds, "M1Speed10")
			end

			if Stats["Trail"] then
				Customs.Trail(Character, false)
			end
		end)

		local Connection
		Connection = Character.Stuns.Changed:Once(function()
			Connection = nil

			-- Remove M1Speed10 (not M1Speed8)
			if Server.Library.StateCheck(Character.Speeds, "M1Speed10") then
				Server.Library.RemoveState(Character.Speeds, "M1Speed10")
			end

			if Server.Library.StateCheck(Character.Actions, "M1" .. Combo) then
				Server.Library.RemoveState(Character.Actions, "M1" .. Combo)
			end

			Sound:Stop()

			SwingAnimation:Stop(0.2)

			Cancel = true
		end)

		task.wait(Stats["HitTimes"][Combo])

		if Cancel then
			return
		end

		if Stats["Slashes"] then
			Server.Visuals.Ranged(
				Character.HumanoidRootPart.Position,
				300,
				{ Module = "Base", Function = "Slashes", Arguments = { Character, Weapon, Combo } }
			)
		end

		Connection:Disconnect()
		Connection = nil

		self.FlameProj(Character, Entity, Weapon, Stats, Combo)

		--if Player then
		--	Server.Packets.Bvel.sendTo({Character = Character, Name = "M1Bvel"}, Player)
		--end
		Server.Visuals.Ranged(
			Character.HumanoidRootPart.Position,
			300,
			{ Module = "Base", Function = "HandEffect", Arguments = { Character, Weapon, Combo } }
		)

		local HitTargets = Hitbox.SpatialQuery(
			Character,
			Stats["Hitboxes"][Combo]["HitboxSize"],
			Entity:GetCFrame() * Stats["Hitboxes"][Combo]["HitboxOffset"]
		)

		-- for _, Target: Model in pairs(HitTargets) do
		-- 	Server.Modules.Damage.Tag(Character, Target, Stats["M1Table"])
		-- 	--if not Target:GetAttribute("")
		-- end
	end
end


local function Bezier(t, start, control, endPos)
    return (1 - t)^2 * start + 2 * (1 - t) * t * control + t^2 * endPos
end

Customs.FlameProjEffect = function(Character, Combo)
	if Combo == 1 or Combo == 2 then
		local Hitbox = Server.Modules.Hitbox

		-- Create a dummy part for the end position (5 studs in front)
		local endPart = Instance.new("Part")
		endPart.Anchored = true
		endPart.CanCollide = false
		endPart.Transparency = 1
		endPart.Size = Vector3.new(1, 1, 1)
		endPart.CFrame = Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, -5)
		endPart.Parent = workspace.World.Visuals
		endPart.Name = "LightningTarget_"..Character.Name

		-- Strike settings
		-- local lightning = Lightning.new(
		-- 	"cylinder", -- Shape
		-- 	ColorSequence.new({
		-- 		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 100, 50)), -- Orange
		-- 		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 0)) -- Yellow
		-- 	}),
		-- 	3, -- Color speed
		-- 	true, -- Juggle colors
		-- 	Character.HumanoidRootPart, -- Start
		-- 	endPart, -- End
		-- 	false, -- Not spread
		-- 	math.random(1, 1.5), -- Size
		-- 	12, -- Segments (optimized)
		-- 	2.5, -- Zigzag intensity
		-- 	nil, -- Instant strike
		-- 	0.3, -- Animation speed (faster)
		-- 	.7, -- Fade direction
		-- 	0 -- No sparks
		-- )

	-- 	Server.Visuals.Ranged(
	-- 	Character.HumanoidRootPart.Position,
	-- 	300,
	-- 	{ Module = "Base", Function = "Lightning", Arguments = {{"cylinder", -- Shape
	-- 		ColorSequence.new({
	-- 			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 100, 50)), -- Orange
	-- 			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 0)) -- Yellow
	-- 		}),
	-- 		3, -- Color speed
	-- 		true, -- Juggle colors
	-- 		Character.HumanoidRootPart, -- Start
	-- 		endPart, -- End
	-- 		false, -- Not spread
	-- 		math.random(1, 1.2), -- Size
	-- 		12, -- Segments (optimized)
	-- 		2.5, -- Zigzag intensity
	-- 		nil, -- Instant strike
	-- 		0.3, -- Animation speed (faster)
	-- 		.7, -- Fade direction
	-- 		0 }}} -- No sparks}} }
	-- )

		-- Damage/explosion logic (unchanged from your original)
		task.delay(0.3, function() -- Sync with lightning timing
			Server.Library.PlaySound(
				Character,
				Server.Service.ReplicatedStorage.Assets.SFX.Elemental.Fire[math.random(1, 2)]
			)

			Server.Visuals.Ranged(
				Character.HumanoidRootPart.Position,
				300,
				{ Module = "Base", Function = "FlameProjExplosion", Arguments = { endPart.CFrame } }
			)

			local targets = {}
			local TargetsFound = Hitbox.SpatialQuery(
				Character,
				Vector3.new(5, 5, 5),
				endPart.CFrame,
				false
			)
			for _, target in TargetsFound do
				if target ~= Character and not table.find(targets, target) and target:IsA("Model") then
					table.insert(targets, target)
					Server.Modules.Damage.Tag(Character, target, Moves["Flame"]["ExplosionM1"])
				end
			end
			endPart:Destroy()
		end)
	end

if Combo == 3 then
    local Hitbox = Server.Modules.Hitbox
    local direction = Character.HumanoidRootPart.CFrame.LookVector
    local startPosition = Character.HumanoidRootPart.Position
    
    -- Spawn 3 flame effects in sequence
    for i = 1, 3 do
		Server.Library.PlaySound(
			Character,
			Server.Service.ReplicatedStorage.Assets.SFX.Elemental.Fire[Random.new():NextInteger(
				1,
				2
			)]
		)
        -- Calculate position in front of player with spacing
        local offset = direction * (i * 5) -- Each flame is 5 studs further than the last
        local spawnPosition = startPosition + offset
        
        -- Create the effect
        local eff = Replicated.Assets.VFX.Snap3:Clone()
        eff.Name = "Flame" .. Character.Name .. tostring(Combo) .. "_" .. i
        eff.Parent = workspace.World.Visuals
		eff.CFrame = CFrame.new(spawnPosition)
        
-- Server.Visuals.Ranged(
-- 		Character.HumanoidRootPart.Position,
-- 		300,
-- 		{ Module = "Base", Function = "Shake", Arguments = {"Once", { 2, 4, 0.3, 0.1, Vector3.new(1.1, 2, 1.1), Vector3.new(0.11, 0.25, 0.11) }} }
-- 	)

        -- Visual effect
        Server.Visuals.Ranged(
            Character.HumanoidRootPart.Position,
            300,
            { Module = "Base", Function = "Emit", Arguments = {eff} }
        )
        
        -- Damage logic
        local targets = {}
        local TargetsFound = Hitbox.SpatialQuery(
            Character,
            eff.Size * 5,
            eff.CFrame,
            false
        )
        
        for _, target in TargetsFound do
            if target ~= Character and not table.find(targets, target) and target:IsA("Model") then
                table.insert(targets, target)
                Server.Modules.Damage.Tag(Character, target, Moves["Flame"]["ExplosionM1"])
            end
        end
        
        -- Small delay between each spawn (optional)
        task.wait(0.15)
    end
end

if Combo == 4 then
	local endPart = Instance.new("Part")
		endPart.Anchored = true
		endPart.CanCollide = false
		endPart.Transparency = 1
		endPart.Size = Vector3.new(1, 1, 1)
		endPart.CFrame = Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, -10)
		endPart.Parent = workspace.World.Visuals
		endPart.Name = "LightningTarget_"..Character.Name

		-- Strike settings
		-- local lightning = Lightning.new(
		-- 	"cylinder", -- Shape
		-- 	ColorSequence.new({
		-- 		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 64, 50)), -- Orange
		-- 		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 166, 0))
		-- 	}),
		-- 	10, -- Color speed
		-- 	true, -- Juggle colors
		-- 	Character.HumanoidRootPart, -- Start
		-- 	endPart, -- End
		-- 	false, -- Not spread
		-- 	math.random(1, 4), -- Size
		-- 	20, -- Segments (optimized)
		-- 	1, -- Zigzag intensity
		-- 	nil, -- Instant strike
		-- 	0.5, -- Animation speed (faster)
		-- 	1, -- Fade direction
		-- 	5 -- No sparks
		-- )


	local Hitbox = Server.Modules.Hitbox
	local eff = Replicated.Assets.VFX.Final:Clone()
	eff.Name = "Flame" .. Character.Name .. tostring(Combo)
	eff.Parent = workspace.World.Visuals
	eff.CFrame = Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, -10)
	
	-- Server.Visuals.Ranged(
	-- 	Character.HumanoidRootPart.Position,
	-- 	300,
	-- 	{ Module = "Base", Function = "Lightning", Arguments = {{"cylinder", -- Shape
	-- 		ColorSequence.new({
	-- 			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 64, 50)), -- Orange
	-- 			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 166, 0))
	-- 		}),
	-- 		10, -- Color speed
	-- 		true, -- Juggle colors
	-- 		Character.HumanoidRootPart, -- Start
	-- 		endPart, -- End
	-- 		true, -- Not spread
	-- 		math.random(2, 2.5), -- Size
	-- 		20, -- Segments (optimized)
	-- 		1, -- Zigzag intensity
	-- 		nil, -- Instant strike
	-- 		0.3, -- Animation speed (faster)
	-- 		1, -- Fade direction
	-- 		0}}} -- No sparks}} }
	-- )

	Server.Visuals.Ranged(
		Character.HumanoidRootPart.Position,
		300,
		{ Module = "Base", Function = "Emit", Arguments = {eff} }
	)

	Server.Visuals.Ranged(
		Character.HumanoidRootPart.Position,
		300,
		{ Module = "Base", Function = "Shake", Arguments = {"Once", { 10, 14, 0, 0.7, Vector3.new(1.1, 2, 1.1), Vector3.new(0.11, 0.25, 0.11) }} }
	)
	
	local targets = {}
	local TargetsFound = Hitbox.SpatialQuery(
		Character,
		eff.Size,
		eff.CFrame,
		false
	)

	task.spawn(function()
	Server.Library.PlaySound(
			Character,
			Server.Service.ReplicatedStorage.Assets.SFX.Elemental.Fire["Final1"]
		)

	task.delay(.15, function()
	Server.Library.PlaySound(
			Character,
			Server.Service.ReplicatedStorage.Assets.SFX.Elemental.Fire["Final2"]
		)
	endPart:Destroy()
	end)
	end)

	
	
	for _, target in TargetsFound do
		if target ~= Character and not table.find(targets, target) and target:IsA("Model") then
			table.insert(targets, target)
			Server.Modules.Damage.Tag(Character, target, Moves["Flame"]["ExplosionM1"])
		end
	end
end
end

Customs.FlameProj = function(Character, Entity, Weapon, Stats, Combo)
	local Hitbox = Server.Modules.Hitbox
	-- Server.Visuals.Ranged(
	-- 	Character.HumanoidRootPart.Position,
	-- 	300,
	-- 	{ Module = "Base", Function = "FlameProj", Arguments = { Character, Combo } }
	-- )

	self.FlameProjEffect(Character, Combo)
end

Customs.Trail = function(Character: Model, State: boolean)
	if State then
		for _, v in pairs(Character:GetDescendants()) do
			if v:GetAttribute("WeaponTrail") then
				v.Enabled = true
			end
		end
	else
		for _, v in pairs(Character:GetDescendants()) do
			if v:GetAttribute("WeaponTrail") then
				v.Enabled = false
			end
		end
	end
end

Customs.Guns = function(Character, Entity, Weapon, Stats)
    local Hitbox = Server.Modules.Hitbox
    if Stats then
        if Entity["SwingConnection"] then
            if Server.Library.StateCheck(Character.Speeds, "M1Speed10") then
                Server.Library.RemoveState(Character.Speeds, "M1Speed10")
            end
            Entity["SwingConnection"]:Disconnect()
            Entity["SwingConnection"] = nil
        end

        Entity.Combo += 1
        local Combo: number = Entity.Combo
        local Cancel = false
        local Max = false
        Entity.LastHit = os.clock()

        -- Check if this is the last hit (combo 4)
        local IsDoubleHit = Combo == 4

        if IsDoubleHit then
            Entity.Combo = 0  -- Reset combo after the double hit
            Max = true
        elseif Entity.Combo >= Stats.MaxCombo then
            Entity.Combo = 0
            Max = true
        end

        -- Use different endlag for double hit
        local endlagIndex = IsDoubleHit and 4 or Combo
        Server.Library.TimedState(Character.Actions, "M1" .. Combo, Stats["Endlag"][endlagIndex])
        Server.Library.AddState(Character.Speeds, "M1Speed10") -- Changed from 8 to 12 for faster combat

        local Swings = Server.Service.ReplicatedStorage.Assets.Animations.Weapons[Weapon].Swings
        local SwingAnimation = Character.Humanoid.Animator:LoadAnimation(Swings:FindFirstChild(Combo))
        SwingAnimation:Play()
		SwingAnimation:AdjustSpeed(Stats["Speed"])
        SwingAnimation.Priority = Enum.AnimationPriority.Action2

        local Sound = Server.Library.PlaySound(
            Character,
            Server.Service.ReplicatedStorage.Assets.SFX.Weapons[Weapon].Swings[Random.new():NextInteger(1, 3)]
        )

		Server.Library.PlaySound(
			Character,
			Server.Service.ReplicatedStorage.Assets.SFX.Weapons[Weapon].Shells[Random.new():NextInteger(1, 2)]
		)

        if Stats["Trail"] then
            Customs.Trail(Character, true)
        end

        Entity["SwingConnection"] = SwingAnimation.Stopped:Once(function()
            Entity["SwingConnection"] = nil
            -- Remove M1Speed10 (not M1Speed8)
            if Server.Library.StateCheck(Character.Speeds, "M1Speed10") then
                Server.Library.RemoveState(Character.Speeds, "M1Speed10")
            end
            if Stats["Trail"] then
                Customs.Trail(Character, false)
            end
        end)

        local Connection
        Connection = Character.Stuns.Changed:Once(function()
            Connection = nil
            -- Remove M1Speed10 (not M1Speed8)
            if Server.Library.StateCheck(Character.Speeds, "M1Speed10") then
                Server.Library.RemoveState(Character.Speeds, "M1Speed10")
            end
            if Server.Library.StateCheck(Character.Actions, "M1" .. Combo) then
                Server.Library.RemoveState(Character.Actions, "M1" .. Combo)
            end
            Sound:Stop()
            SwingAnimation:Stop(0.2)
            Cancel = true
        end)

        -- Wait for the first hit time
        task.wait(Stats["HitTimes"][Combo])
        if Cancel then return end

        if Stats["Slashes"] then
            Server.Visuals.Ranged(
                Character.HumanoidRootPart.Position,
                300,
                { Module = "Base", Function = "Slashes", Arguments = { Character, Weapon, Combo } }
            )
        end

        -- First hit (or only hit for non-double hits)
        local LeftGun = Character:FindFirstChild("LeftGun")
        local RightGun = Character:FindFirstChild("RightGun")
        Server.Visuals.Ranged(
            Character.HumanoidRootPart.Position,
            300,
            { Module = "Base", Function = "Shot", Arguments = { Character, Combo, LeftGun, RightGun } }
        )

        local HitTargets = Hitbox.SpatialQuery(
            Character,
            Stats["Hitboxes"][Combo]["HitboxSize"],
            Entity:GetCFrame() * Stats["Hitboxes"][Combo]["HitboxOffset"]
        )

        for _, Target: Model in pairs(HitTargets) do
            if IsDoubleHit then
                -- Use LastTable for the double hit
                Server.Modules.Damage.Tag(Character, Target, Stats["LastTable"])
            else
                Server.Modules.Damage.Tag(Character, Target, Stats["M1Table"])
            end
        end

        -- If this is the double hit, do the second hit after a small delay
        if IsDoubleHit and not Cancel then
            task.wait(0.1)  -- Small delay between the two hits
            
            -- Second hit of the double hit
            Server.Visuals.Ranged(
                Character.HumanoidRootPart.Position,
                300,
                { Module = "Base", Function = "Shot", Arguments = { Character, 2, LeftGun, RightGun } }
            )

            local SecondHitTargets = Hitbox.SpatialQuery(
                Character,
                Stats["Hitboxes"][5]["HitboxSize"],  -- Use the 5th hitbox for second hit
                Entity:GetCFrame() * Stats["Hitboxes"][5]["HitboxOffset"]
            )

            for _, Target: Model in pairs(SecondHitTargets) do
                Server.Modules.Damage.Tag(Character, Target, Stats["LastTable"])
            end
        end

        Connection:Disconnect()
    end
end

return Customs
