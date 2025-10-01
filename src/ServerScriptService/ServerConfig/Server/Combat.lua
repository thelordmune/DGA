local Combat = {}; local Server = require(script.Parent);
local WeaponStats = require(Server.Service.ServerStorage:WaitForChild("Stats")._Weapons)
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Voxbreaker = require(ReplicatedStorage.Modules.Voxel)

Combat.__index = Combat;
local self = setmetatable({}, Combat)

Combat.Light = function(Character: Model)
	local Hitbox = Server.Modules.Hitbox
	local Entity = Server.Modules["Entities"].Get(Character)
	if not Entity then return end

	local Player : Player;
	if Entity.Player then Player = Entity.Player end;

	-- Allow NPCs to attack even with states, but block players with certain states
	local isNPC = Character:GetAttribute("IsNPC")
	if not isNPC and (Server.Library.StateCount(Character.Actions) or Server.Library.StateCount(Character.Stuns)) then
		return
	end

	-- For NPCs, clear any problematic feint states that might cause loops
	if isNPC and Character:GetAttribute("Feint") then
		Character:SetAttribute("Feint", nil)
	end

	Server.Library.StopAllAnims(Character)

	if not Entity.Combo then Entity.Combo = 0 end
	if not Entity.LastHit then Entity.LastHit = os.clock() end
	Server.Library.RemoveState(Entity.Character.IFrames, "Dodge");

	if os.clock() - Entity.LastHit > 2 then Entity.Combo = 0 end

	local Weapon: string = Entity.Weapon
	local Stats: {} = WeaponStats[Weapon]

	if Stats["Exception"] then
		print('weapon has an exception')
		Server.Modules.WeaponExceptions[Weapon](Character, Entity, Weapon, Stats)
		return
	end

	if Stats then
		
		if Entity["SwingConnection"] then
			
			if Server.Library.StateCheck(Character.Speeds, "M1Speed8") then
				Server.Library.RemoveState(Character.Speeds,"M1Speed8")
			end
			
			Entity["SwingConnection"]:Disconnect()
			Entity["SwingConnection"] = nil
		end
		
		Entity.Combo += 1

		local Combo: number = Entity.Combo;
		local Cancel = false
		local Max = false

		Entity.LastHit = os.clock()

		if Entity.Combo >= Stats.MaxCombo then
			Max = true
			Entity.Combo = 0
		end
		
		Server.Library.TimedState(Character.Actions,"M1"..Combo,Stats["Endlag"][Combo])
		Server.Library.AddState(Character.Speeds,"M1Speed8")

		local Swings = Server.Service.ReplicatedStorage.Assets.Animations.Weapons[Weapon].Swings

		local SwingAnimation = Character.Humanoid.Animator:LoadAnimation(Swings:FindFirstChild(Combo))
		SwingAnimation:Play()
		SwingAnimation.Priority = Enum.AnimationPriority.Action2
		
		local Sound = Server.Library.PlaySound(Character,Server.Service.ReplicatedStorage.Assets.SFX.Weapons[Weapon].Swings[Random.new():NextInteger(1,#Server.Service.ReplicatedStorage.Assets.SFX.Weapons[Weapon].Swings:GetChildren())])
		
		if Stats["Trail"] then
			Combat.Trail(Character, true)
		end

		Entity["SwingConnection"] = SwingAnimation.Stopped:Once(function()
			Entity["SwingConnection"] = nil
			
			if Server.Library.StateCheck(Character.Speeds, "M1Speed8") then
				Server.Library.RemoveState(Character.Speeds,"M1Speed8")
			end
						
			if Stats["Trail"] then
				Combat.Trail(Character, false)
			end
		end)
		
	
		local Connection Connection = Character.Stuns.Changed:Once(function()
			-- Connection = nil
			
			if Server.Library.StateCheck(Character.Speeds, "M1Speed8") then
				Server.Library.RemoveState(Character.Speeds,"M1Speed8")
			end
			
			if Server.Library.StateCheck(Character.Actions, "M1"..Combo) then
				Server.Library.RemoveState(Character.Actions,"M1"..Combo)	
			end

			Sound:Stop()
			
			SwingAnimation:Stop(.2)
			
			-- Character:SetAttribute("Feint",nil)

			Cancel = true
		end)

		Character:SetAttribute("Feint", true)

		local Feint = Character:GetAttributeChangedSignal("Feint"):Once(function()
			Server.Visuals.Ranged(Character.HumanoidRootPart.Position, 300, {Module = "Base", Function = "Feint", Arguments = {Character}})
			Cancel = true
			-- Reset combo when feinting to skip M1 count
			Entity.Combo = math.max(0, Entity.Combo - 1)
			print("Feint triggered - combo reset to:", Entity.Combo)

			-- Clean up M1 states when feinting
			if Server.Library.StateCheck(Character.Actions, "M1" .. Combo) then
				Server.Library.RemoveState(Character.Actions, "M1" .. Combo)
			end
			if Server.Library.StateCheck(Character.Speeds, "M1Speed8") then
				Server.Library.RemoveState(Character.Speeds, "M1Speed8")
			end

			-- Stop animation and sound
			SwingAnimation:Stop(0.2)
			Sound:Stop()

			-- Clean up connections when feinting
			if Connection then
				Connection:Disconnect()
				Connection = nil
			end

			Server.Library.TimedState(Character.Stuns,"Feint",0)
		end)

		task.delay(Stats["HitTimes"][Combo] - (15/60), function()
			if Stats["Slashes"] then
			Server.Visuals.Ranged(Character.HumanoidRootPart.Position,300,{Module = "Base",Function = "Slashes", Arguments = {Character,Weapon,Combo}})
			end
		end)

		task.wait(Stats["HitTimes"][Combo])


		if Cancel then
			-- Ensure feint attribute is cleared when cancelled
			Character:SetAttribute("Feint", nil)
			return
		end

		-- Clean up connections and reset feint attribute
		if Feint then
			Feint:Disconnect()
			Feint = nil
		end
		if Connection then
			Connection:Disconnect()
			Connection = nil
		end

		Character:SetAttribute("Feint", nil)

		--if Player then
		--	Server.Packets.Bvel.sendTo({Character = Character, Name = "M1Bvel"}, Player)
		--end

		local HitTargets = Hitbox.SpatialQuery(Character, Stats["Hitboxes"][Combo]["HitboxSize"], Entity:GetCFrame() * Stats["Hitboxes"][Combo]["HitboxOffset"])
		
		for _, Target: Model in pairs(HitTargets) do
			Server.Modules.Damage.Tag(Character, Target, Stats["M1Table"])
			--if not Target:GetAttribute("")
		end
		
		end
end

Combat.Critical = function(Character: Model)
	local Hitbox = Server.Modules.Hitbox
	local Entity = Server.Modules["Entities"].Get(Character)

	if not Entity then return end

	if Server.Library.CheckCooldown(Character, "Critical") then return end

	local Player : Player;
	if Entity.Player then Player = Entity.Player end;

	if Server.Library.StateCount(Character.Actions) or Server.Library.StateCount(Character.Stuns) then return end

	Server.Library.StopAllAnims(Character)

	local Weapon: string = Entity.Weapon
	local Stats: {} = WeaponStats[Weapon]

	Server.Library.SetCooldown(Character,"Critical",5)	

	Server.Visuals.Ranged(Character.HumanoidRootPart.Position,300, {Module = "Base", Function = "CriticalIndicator", Arguments = {Character}})		


	if Stats then

		if Entity["SwingConnection"] then

			if Server.Library.StateCheck(Character.Speeds, "M1Speed8") then
				Server.Library.RemoveState(Character.Speeds,"M1Speed8")
			end

			Entity["SwingConnection"]:Disconnect()
			Entity["SwingConnection"] = nil
		end

		if Stats["Critical"]["CustomFunction"] then
			Stats["Critical"]["CustomFunction"](Character,Entity)
			return
		end

		local Cancel = false

		Server.Library.TimedState(Character.Actions,"M2",Stats["Critical"]["Endlag"])
		Server.Library.AddState(Character.Speeds,"M1Speed8")

		local Swings = Server.Service.ReplicatedStorage.Assets.Animations.Weapons[Weapon]

		local SwingAnimation = Character.Humanoid.Animator:LoadAnimation(Swings:FindFirstChild("Critical"))
		SwingAnimation:Play()
		SwingAnimation.Priority = Enum.AnimationPriority.Action2

		--local Sound = Server.Library.PlaySound(Character,Server.Service.ReplicatedStorage.Assets.SFX.Weapons[Weapon].Swings[Random.new():NextInteger(1,#Server.Service.ReplicatedStorage.Assets.SFX.Weapons[Weapon].Swings:GetChildren())])

		if Stats["Trail"] then
			Combat.Trail(Character, true)
		end

		Entity["SwingConnection"] = SwingAnimation.Stopped:Once(function()
			Entity["SwingConnection"] = nil

			if Server.Library.StateCheck(Character.Speeds, "M1Speed8") then
				Server.Library.RemoveState(Character.Speeds,"M1Speed8")
			end

			if Stats["Trail"] then
				Combat.Trail(Character, false)
			end
		end)


		Entity["M1StunConnection"] = Character.Stuns.Changed:Once(function()
			Entity["M1StunConnection"] = nil

			if Server.Library.StateCheck(Character.Speeds, "M1Speed8") then
				Server.Library.RemoveState(Character.Speeds,"M1Speed8")
			end

			--Sound:Stop()

			SwingAnimation:Stop(.2)
			Cancel = true
		end)

		task.wait(Stats["Critical"].WaitTime)

		if Cancel then return end

		Entity["M1StunConnection"]:Disconnect()
		Entity["M1StunConnection"] = nil

		local soundEffects = {}

		--if Player and Stats["Critical"]["Velocity"] then
		--	Server.Packets.Bvel.sendTo({Character = Character, Name = "M2Bvel"}, Player)
		--end

		if WeaponStats[Weapon].SpecialCrit == true then
			Server.Visuals.Ranged(Character.HumanoidRootPart.Position,300, {Module = "Base", Function = "SpecialCrit"..Weapon, Arguments = {Character}})
			if WeaponStats[Weapon].SpecialCritSound then
				Server.Library.PlaySound(Character,WeaponStats[Weapon].Critical.Sfx[1])
				Server.Library.PlaySound(Character,WeaponStats[Weapon].Critical.Sfx[2])
				Server.Library.PlaySound(Character,WeaponStats[Weapon].Critical.Sfx[3])
			end
		end

		local HitTargets = Hitbox.SpatialQuery(Character, Stats["Hitboxes"][1]["HitboxSize"], Entity:GetCFrame() * Stats["Hitboxes"][1]["HitboxOffset"])

		for _, Target: Model in pairs(HitTargets) do
			Server.Modules.Damage.Tag(Character, Target, Stats["Critical"]["DamageTable"])
			if Target:IsDescendantOf(workspace.Transmutables) then
				local wall = Target
				local root = Character.HumanoidRootPart
				local playerForward = root.CFrame.LookVector
						playerForward = Vector3.new(playerForward.X, 0, playerForward.Z).Unit

						-- Store original position
						local originalCFrame = wall.CFrame
						local originalColor = wall.Color
						local startTime = os.clock()
						local duration = 1.0
						local maxDistance = 35
				task.spawn(function()

							local movingTargets = {}
							local hitboxSize = wall.Size + Vector3.new(3, 3, 3)

							-- Create dust particles on the wall as it slides
							Server.Visuals.Ranged(wall.Position, 300, {
								Module = "Base",
								Function = "WallSlideDust",
								Arguments = {wall, duration}
							})

							while os.clock() - startTime < duration do
								local elapsed = os.clock() - startTime
								local progress = elapsed / duration
								local distanceEase = 1 - (1 - progress) ^ 2
								local offset = playerForward * (maxDistance * distanceEase)
								local newCFrame = CFrame.new(originalCFrame.Position + offset)
									* (originalCFrame - originalCFrame.Position)

								wall.CFrame = wall.CFrame:Lerp(newCFrame, 0.3 + (0.2 * (1 - progress)))

								-- Collision detection
								local newHitTargets = Hitbox.SpatialQuery(Character, wall.Size, wall.CFrame)

								for _, hitTarget in pairs(newHitTargets) do
									if
										hitTarget ~= wall
										and hitTarget:IsA("Model")
										and not movingTargets[hitTarget]
									then
										movingTargets[hitTarget] = true
										local parts = Voxbreaker:VoxelizePart(wall, 10, 15)

										-- if soundEffects[wall].drag then
										-- 	soundEffects[wall].drag.Looped = false
										-- 	soundEffects[wall].drag:Stop()
										-- end

										-- Debris handling
										for _, v in pairs(parts) do
											if v:IsA("BasePart") then
												v.Anchored = false
												v.CanCollide = true
												local debrisVelocity = Instance.new("BodyVelocity")
												debrisVelocity.Velocity = (
													playerForward
													+ Vector3.new(
														(math.random() - 0.25) * 0.3,
														math.random() * 0.7,
														(math.random() - 0.25) * 10
													)
												) * 9
												debrisVelocity.MaxForce = Vector3.new(math.huge, 0, math.huge)
												debrisVelocity.Parent = v
												Debris:AddItem(debrisVelocity, 0.5)
												Debris:AddItem(v, 8 + math.random() * 4)
											end
										end

										Server.Modules.Damage.Tag(Character, hitTarget, Stats["Critical"]["DamageTable"])
									end
								end
								task.wait()
							end
						end)
				print("sending loop to wall")
			end
			--if not Target:GetAttribute("")
		end

	end
end

Combat.RunningAttack = function(Character)
	local Hitbox = Server.Modules.Hitbox
	local Entity = Server.Modules["Entities"].Get(Character)

	if not Entity then return end

	if Server.Library.CheckCooldown(Character, "RunningAttack") then return end

	local Player : Player;
	if Entity.Player then Player = Entity.Player end;

	Server.Visuals.Ranged(Character.HumanoidRootPart.Position, 300, {
					Module = "Base",
					Function = "AlchemicAssault",
					Arguments = { Character, "Jump" },
				})

	if Server.Library.StateCount(Character.Actions) or Server.Library.StateCount(Character.Stuns) then return end

	Server.Library.StopAllAnims(Character)
	
	Server.Library.SetCooldown(Character,"RunningAttack",5)	

	local Weapon: string = Entity.Weapon
	local Stats: {} = WeaponStats[Weapon]
	
	local Cancel = false
	
	if Stats then

		if Entity["SwingConnection"] then

			if Server.Library.StateCheck(Character.Speeds, "M1Speed8") then
				Server.Library.RemoveState(Character.Speeds,"M1Speed8")
			end

			Entity["SwingConnection"]:Disconnect()
			Entity["SwingConnection"] = nil
		end
		
		Server.Library.TimedState(Character.Actions,"RunningAttack",Stats["RunningAttack"]["Endlag"])
		Server.Library.AddState(Character.Speeds,"RunningAttack-8")
		
		local SwingAnimation = Character.Humanoid.Animator:LoadAnimation(Server.Service.ReplicatedStorage.Assets.Animations.Weapons[Weapon]["Running Attack"])
		SwingAnimation:Play()
		
		if Player then
			
			if Stats["RunningAttack"]["DelayedBvel"] then
				task.delay(Stats["RunningAttack"]["DelayedBvel"],function()
					if not Cancel then
						Server.Packets.Bvel.sendTo({Character = Character, Name = Weapon.."RunningBvel"}, Player)
					end
				end)
			else
				Server.Packets.Bvel.sendTo({Character = Character, Name = Weapon.."RunningBvel"}, Player)
			end
			
		end
		
		Entity["SwingConnection"] = SwingAnimation.Stopped:Once(function()
			Entity["SwingConnection"] = nil

			if Server.Library.StateCheck(Character.Speeds, "RunningAttack-8") then
				Server.Library.RemoveState(Character.Speeds,"RunningAttack-8")
			end

			if Stats["Trail"] then
				Combat.Trail(Character, false)
			end
		end)
		
		if Stats["Trail"] then
			Combat.Trail(Character, true)
		end

		local Connection Connection = Character.Stuns.Changed:Once(function()
			Connection = nil

			if Server.Library.StateCheck(Character.Speeds, "RunningAttack-8") then
				Server.Library.RemoveState(Character.Speeds,"RunningAttack-8")
			end

			if Server.Library.StateCheck(Character.Actions, "RunningAttack") then
				Server.Library.RemoveState(Character.Actions,"RunningAttack")	
			end
			
			if Player then
				Server.Packets.Bvel.sendTo({Character = Character, Name = "RemoveBvel"},Player)
			end
			
			--Sound:Stop()

			SwingAnimation:Stop(.2)

			

			Cancel = true
		end)

		task.wait(Stats["RunningAttack"]["HitTime"])

		if Cancel then return end		

		Connection:Disconnect()
		Connection = nil
		
		if Stats["RunningAttack"]["Linger"] then
			local Tagged = {};
			local Start = os.clock();
			
			Server.Utilities:AddToTempLoop(function(DeltaTime)
				if Entity then
					local HitTargets = Hitbox.SpatialQuery(Character, Stats["Hitboxes"][1]["HitboxSize"], Entity:GetCFrame() * Stats["Hitboxes"][1]["HitboxOffset"])

					for _, Target in pairs(HitTargets) do
						if not Tagged[Target] then
							Tagged[Target] = true;
							Server.Modules.Damage.Tag(Character, Target, Stats["RATable"])
							print("ra table")
						end
					end
					
				else return true end
				
				if os.clock() - Start >= Stats["RunningAttack"]["Linger"] then return true end;
			end, true);

		else
			
			local HitTargets = Hitbox.SpatialQuery(Character, Stats["Hitboxes"][1]["HitboxSize"], Entity:GetCFrame() * Stats["Hitboxes"][1]["HitboxOffset"])

			for _, Target in pairs(HitTargets) do
				Server.Modules.Damage.Tag(Character, Target, Stats["RATable"])
			end
		end
	end
	
end

local BlockStates = {}

Combat.HandleBlockInput = function(Character: Model, State: boolean)
    local Entity = Server.Modules["Entities"].Get(Character)
    if not Entity then return end
    
    local Weapon = Entity.Weapon
    local Stats = WeaponStats[Weapon]
    if not Stats then return end
    
    -- If already parrying, don't interrupt
    if Server.Library.StateCheck(Character.Frames, "Parry") then return end
    
    if State then
        -- Start block if not already blocking
        if not BlockStates[Character] then
            BlockStates[Character] = {
                Blocking = false,
                ParryWindow = false,
                HoldTime = 0
            }
            
            -- Start tracking hold time
            BlockStates[Character].HoldTime = 0
            BlockStates[Character].Connection = Server.Utilities:AddToTempLoop(function(dt)
                if not BlockStates[Character] then return true end
                
                BlockStates[Character].HoldTime = BlockStates[Character].HoldTime + dt
                
                -- If held long enough, start blocking
                if BlockStates[Character].HoldTime >= 0.15 and not BlockStates[Character].Blocking then
                    BlockStates[Character].Blocking = true
                    self.StartBlock(Character)
                end
                
                return false
            end)
        end
    else
        -- Release input
        if BlockStates[Character] then
            -- If released quickly, attempt parry
            if BlockStates[Character].HoldTime < 0.15 and not BlockStates[Character].Blocking then
                self.AttemptParry(Character)
            end
            
            -- Clean up block if active
            if BlockStates[Character].Blocking then
                self.EndBlock(Character)
            end
            
            -- Clean up tracking
            if BlockStates[Character].Connection then
                BlockStates[Character].Connection:Disconnect()
            end
            BlockStates[Character] = nil
        end
    end
end

Combat.AttemptParry = function(Character: Model)
    if Server.Library.CheckCooldown(Character, "Parry") then return end
    if Server.Library.StateCheck(Character.Stuns, "BlockBreakStun") then return end

    local Entity = Server.Modules["Entities"].Get(Character)
    if not Entity then return end
    
    local Weapon = Entity.Weapon
    local Stats = WeaponStats[Weapon]
    if not Stats then return end
    
    Server.Library.SetCooldown(Character, "Parry", 0.5)
    Server.Library.StopAllAnims(Character)
    
    -- Play parry animation
    local ParryAnimation = Server.Library.PlayAnimation(Character, Server.Service.ReplicatedStorage.Assets.Animations.Weapons[Weapon].Parry)
    ParryAnimation.Priority = Enum.AnimationPriority.Action2
    
    -- Add parry frames
    Server.Library.TimedState(Character.Frames, "Parry", .3)
    
    -- Visual effect
    -- Server.Visuals.Ranged(Character.HumanoidRootPart.Position, 300, {
    --     Module = "Base", 
    --     Function = "Parry", 
    --     Arguments = {Character}
    -- })
end

Combat.StartBlock = function(Character: Model)
    local Entity = Server.Modules["Entities"].Get(Character)
    if not Entity then return end
    
    local Weapon = Entity.Weapon
    local Stats = WeaponStats[Weapon]
    if not Stats then return end
    
    Server.Library.AddState(Character.Frames, "Blocking")
    Server.Library.AddState(Character.Speeds, "BlockSpeed8")
    Server.Library.AddState(Character.Actions, "Blocking")
    
    local BlockAnimation = Server.Library.PlayAnimation(Character, Server.Service.ReplicatedStorage.Assets.Animations.Weapons[Weapon].Block)
    BlockAnimation.Priority = Enum.AnimationPriority.Action2
end

Combat.EndBlock = function(Character: Model)
    local Entity = Server.Modules["Entities"].Get(Character)
    if not Entity then return end
    
    local Weapon = Entity.Weapon
    if not Weapon then return end
    
    Server.Library.StopAnimation(Character, Server.Service.ReplicatedStorage.Assets.Animations.Weapons[Weapon].Block)
    
    Server.Library.RemoveState(Character.Actions, "Blocking")
    Server.Library.RemoveState(Character.Speeds, "BlockSpeed8")
    Server.Library.RemoveState(Character.Frames, "Blocking")
end

Combat.Trail = function(Character: Model, State: boolean)
	if State then
		for _,v in pairs(Character:GetDescendants()) do
			if v:GetAttribute("WeaponTrail") then
				v.Enabled = true
			end
		end
	else
		for _,v in pairs(Character:GetDescendants()) do
			if v:GetAttribute("WeaponTrail") then
				v.Enabled = false
			end
		end
	end
end

return Combat
