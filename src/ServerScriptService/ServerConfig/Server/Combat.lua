local Combat = {}; local Server = require(script.Parent);
local WeaponStats = require(Server.Service.ServerStorage:WaitForChild("Stats")._Weapons)
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Voxbreaker = require(ReplicatedStorage.Modules.Voxel)
local world = require(ReplicatedStorage.Modules.ECS.jecs_world)
local ref = require(ReplicatedStorage.Modules.ECS.jecs_ref)
local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)

Combat.__index = Combat;
local self = setmetatable({}, Combat)

Combat.Light = function(Character: Model)
	local Hitbox = Server.Modules.Hitbox
	local Entity = Server.Modules["Entities"].Get(Character)
	if not Entity then return end

	local Player : Player;
	if Entity.Player then Player = Entity.Player end;

	-- Prevent actions during parry knockback for both NPCs and players
	if Server.Library.StateCheck(Character.Stuns, "ParryKnockback") then
		return
	end

	-- Allow NPCs to attack even with states, but block players with certain states
	local isNPC = Character:GetAttribute("IsNPC")
	if not isNPC and (Server.Library.StateCount(Character.Actions) or Server.Library.StateCount(Character.Stuns)) then
		return
	end

	-- CANCEL SPRINT when attacking (for players only)
	if Player then
		Server.Packets.CancelSprint.sendTo({}, Player)
	end

	Server.Library.StopAllAnims(Character)

	if not Entity.Combo then Entity.Combo = 0 end
	if not Entity.LastHit then Entity.LastHit = os.clock() end
	Server.Library.RemoveState(Entity.Character.IFrames, "Dodge");

	if os.clock() - Entity.LastHit > 2 then Entity.Combo = 0 end

	local Weapon: string = Entity.Weapon
	local Stats: {} = WeaponStats[Weapon]

	if Stats["Exception"] then
		-- print('weapon has an exception')
		Server.Modules.WeaponExceptions[Weapon](Character, Entity, Weapon, Stats)
		return
	end

	if Stats then
		
		if Entity["SwingConnection"] then

			if Server.Library.StateCheck(Character.Speeds, "M1Speed13") then
				Server.Library.RemoveState(Character.Speeds,"M1Speed13")
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
		Server.Library.AddState(Character.Speeds,"M1Speed13") -- Reduced walkspeed to 13 (16 + (-3)) for more consistent hitboxes

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

			if Server.Library.StateCheck(Character.Speeds, "M1Speed13") then
				Server.Library.RemoveState(Character.Speeds,"M1Speed13")
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



		task.delay(Stats["HitTimes"][Combo] - (15/60), function()
			if Stats["Slashes"] then
			Server.Visuals.Ranged(Character.HumanoidRootPart.Position,300,{Module = "Base",Function = "Slashes", Arguments = {Character,Weapon,Combo}})
			end
		end)

		task.wait(Stats["HitTimes"][Combo])


		if Cancel then
			return
		end

		-- Clean up connections
		if Connection then
			Connection:Disconnect()
			Connection = nil
		end

		--if Player then
		--	Server.Packets.Bvel.sendTo({Character = Character, Name = "M1Bvel"}, Player)
		--end

		-- Multi-frame hit detection loop for more accurate hits
		-- Check for hits 3 times over 0.1 seconds to catch fast-moving targets
		local HitTargets = {}
		local AlreadyHit = {}

		for i = 1, 3 do
			local FrameHits = Hitbox.SpatialQuery(Character, Stats["Hitboxes"][Combo]["HitboxSize"], Entity:GetCFrame() * Stats["Hitboxes"][Combo]["HitboxOffset"])

			for _, Target: Model in pairs(FrameHits) do
				if not AlreadyHit[Target] then
					table.insert(HitTargets, Target)
					AlreadyHit[Target] = true
				end
			end

			-- Wait a tiny bit between checks (only wait if not the last iteration)
			if i < 3 then
				task.wait(0.033) -- ~2 frames at 60fps
			end
		end

		-- Apply damage to all detected targets
		for _, Target: Model in pairs(HitTargets) do
			Server.Modules.Damage.Tag(Character, Target, Stats["M1Table"])
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

	-- Prevent critical during parry knockback
	if Server.Library.StateCheck(Character.Stuns, "ParryKnockback") then return end

	if Server.Library.StateCount(Character.Actions) or Server.Library.StateCount(Character.Stuns) then return end

	-- CANCEL SPRINT when attacking (for players only)
	if Player then
		Server.Packets.CancelSprint.sendTo({}, Player)
	end

	Server.Library.StopAllAnims(Character)

	-- For NPCs, clear any lingering body movers to prevent stuttering
	if not Player then
		local root = Character:FindFirstChild("HumanoidRootPart")
		if root then
			for _, bodyMover in pairs(root:GetChildren()) do
				if bodyMover:IsA("LinearVelocity") or bodyMover:IsA("BodyVelocity") or bodyMover:IsA("BodyGyro") then
					bodyMover:Destroy()
				end
			end
		end
	end

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

			if Server.Library.StateCheck(Character.Speeds, "M1Speed16") then
				Server.Library.RemoveState(Character.Speeds,"M1Speed16")
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
			print("[Critical] Stats[Critical][DamageTable]:", Stats["Critical"]["DamageTable"])
			-- Check if target is ragdolled and apply additional knockback (similar to Pincer Impact)
			if Target:IsA("Model") and Target:FindFirstChild("HumanoidRootPart") then
				local isRagdolled = Target:FindFirstChild("Ragdoll") or
				                   (Target:GetAttribute("Knocked") and Target:GetAttribute("Knocked") > 0)

				if isRagdolled then
					-- Apply extra knockback using the same method as Pincer Impact
					local direction = Character.HumanoidRootPart.CFrame.LookVector -- Forward from attacker
					local horizontalPower = 60 -- Strong horizontal knockback
					local upwardPower = 50 -- Strong upward arc

					-- Use ServerBvel for consistent knockback
					Server.Modules.ServerBvel.BFKnockback(Target, direction, horizontalPower, upwardPower)

					-- Extend ragdoll duration by 3 seconds
					local Ragdoller = require(game.ReplicatedStorage.Modules.Utils.Ragdoll)
					Ragdoller.Ragdoll(Target, 3)

					-- print(`[Critical] Knocked back ragdolled target: {Target.Name} and extended ragdoll by 3 seconds`)
				end
			end

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
				-- print("sending loop to wall")
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

			if Server.Library.StateCheck(Character.Speeds, "M1Speed13") then
				Server.Library.RemoveState(Character.Speeds,"M1Speed13")
			end

			Entity["SwingConnection"]:Disconnect()
			Entity["SwingConnection"] = nil
		end
		
		Server.Library.TimedState(Character.Actions,"RunningAttack",Stats["RunningAttack"]["Endlag"])
		Server.Library.AddState(Character.Speeds,"RunningAttack-12") -- Changed from 8 to 12 for faster combat
		
		local SwingAnimation = Character.Humanoid.Animator:LoadAnimation(Server.Service.ReplicatedStorage.Assets.Animations.Weapons[Weapon]["Running Attack"])
		SwingAnimation:Play()
		
		-- Send Bvel to the player (they have network ownership of their character)
		if Player then
			if Stats["RunningAttack"]["DelayedBvel"] then
				task.delay(Stats["RunningAttack"]["DelayedBvel"],function()
					if not Cancel then
						Server.Packets.Bvel.sendTo({Character = Character, Name = Weapon.."RunningBvel", Targ = Character}, Player)
					end
				end)
			else
				Server.Packets.Bvel.sendTo({Character = Character, Name = Weapon.."RunningBvel", Targ = Character}, Player)
			end
		end
		
		Entity["SwingConnection"] = SwingAnimation.Stopped:Once(function()
			Entity["SwingConnection"] = nil

			if Server.Library.StateCheck(Character.Speeds, "RunningAttack-12") then
				Server.Library.RemoveState(Character.Speeds,"RunningAttack-12")
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

			if Server.Library.StateCheck(Character.Speeds, "RunningAttack-12") then
				Server.Library.RemoveState(Character.Speeds,"RunningAttack-12")
			end

			if Server.Library.StateCheck(Character.Actions, "RunningAttack") then
				Server.Library.RemoveState(Character.Actions,"RunningAttack")
			end

			if Player then
				Server.Packets.Bvel.sendTo({Character = Character, Name = "RemoveBvel", Targ = Character}, Player)
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
							-- print("ra table")
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

-- Clear block state tracking for a character (used during block break)
Combat.ClearBlockState = function(Character: Model)
	if BlockStates[Character] then
		-- Disconnect any active connections
		if BlockStates[Character].Connection then
			BlockStates[Character].Connection:Disconnect()
		end
		-- Clear the tracking data
		BlockStates[Character] = nil
	end
end

Combat.HandleBlockInput = function(Character: Model, State: boolean)
    local Entity = Server.Modules["Entities"].Get(Character)
    if not Entity then return end

    local Weapon = Entity.Weapon
    local Stats = WeaponStats[Weapon]
    if not Stats then return end

    if State then
        -- PREVENT OVERLAPPING ACTIONS: Cannot START blocking while performing any action
        if Server.Library.StateCount(Character.Actions) then return end

        -- Prevent blocking during parry knockback
        if Server.Library.StateCheck(Character.Stuns, "ParryKnockback") then return end
        -- If already parrying, don't interrupt
        if Server.Library.StateCheck(Character.Frames, "Parry") then return end
        -- Prevent blocking during strategist combo
        if Server.Library.StateCheck(Character.Stuns, "StrategistComboHit") then return end
        -- Prevent blocking while BlockBroken (guard broken)
        if Server.Library.StateCheck(Character.Stuns, "BlockBreakStun") then return end
        -- Prevent blocking for 2 seconds after BlockBreak stun ends
        if Server.Library.StateCheck(Character.Stuns, "BlockBreakCooldown") then return end

        -- Prevent blocking if BlockBroken ECS component is true
        if Entity.Player then
            local playerEntity = ref.get("player", Entity.Player)
            if playerEntity then
                local blockBroken = world:get(playerEntity, comps.BlockBroken)
                if blockBroken then return end
            end
        end
        -- Start block if not already blocking
        if not BlockStates[Character] then
            -- CANCEL SPRINT when starting to block (for players only)
            if Entity.Player then
                Server.Packets.CancelSprint.sendTo({}, Entity.Player)
            end

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

                -- If held long enough, start blocking - decreased from 0.25s to 0.2s
                if BlockStates[Character].HoldTime >= 0.2 and not BlockStates[Character].Blocking then
                    BlockStates[Character].Blocking = true
                    self.StartBlock(Character)
                end

                return false
            end)
        end
    else
        -- Release input
        if BlockStates[Character] then
            -- If released quickly, attempt parry - decreased from 0.25s to 0.2s
            if BlockStates[Character].HoldTime < 0.2 and not BlockStates[Character].Blocking then
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
    print(`[PARRY DEBUG] {Character.Name} attempting to parry`)

    if Server.Library.CheckCooldown(Character, "Parry") then
        print(`[PARRY DEBUG] {Character.Name} - BLOCKED: On cooldown`)
        return
    end

    -- Prevent parrying during parry knockback
    if Server.Library.StateCheck(Character.Stuns, "ParryKnockback") then
        print(`[PARRY DEBUG] {Character.Name} - BLOCKED: ParryKnockback state active`)
        return
    end

    if Server.Library.StateCheck(Character.Stuns, "BlockBreakStun") then
        print(`[PARRY DEBUG] {Character.Name} - BLOCKED: BlockBreakStun state active`)
        return
    end

    -- Prevent parrying during ragdoll
    if Character:FindFirstChild("Ragdoll") then
        print(`[PARRY DEBUG] {Character.Name} - BLOCKED: Ragdoll active`)
        return
    end

    -- Prevent parrying during moves
    if Server.Library.StateCount(Character.Actions) then
        local actions = Server.Library.GetAllStatesFromCharacter(Character).Actions or {}
        print(`[PARRY DEBUG] {Character.Name} - BLOCKED: Actions active: {table.concat(actions, ", ")}`)
        return
    end

    -- Prevent parrying during strategist combo
    if Server.Library.StateCheck(Character.Stuns, "StrategistComboHit") then
        print(`[PARRY DEBUG] {Character.Name} - BLOCKED: StrategistComboHit state active`)
        return
    end

    -- Prevent parrying during M1 stun (true stun system)
    if Server.Library.StateCheck(Character.Stuns, "M1Stun") then
        print(`[PARRY DEBUG] {Character.Name} - BLOCKED: M1Stun state active (true stun)`)
        return
    end

    local Entity = Server.Modules["Entities"].Get(Character)
    if not Entity then
        print(`[PARRY DEBUG] {Character.Name} - BLOCKED: No entity found`)
        return
    end

    local Weapon = Entity.Weapon
    local Stats = WeaponStats[Weapon]
    if not Stats then
        print(`[PARRY DEBUG] {Character.Name} - BLOCKED: No weapon stats for {Weapon}`)
        return
    end

    print(`[PARRY DEBUG] {Character.Name} - ✅ PARRY STARTED - Weapon: {Weapon}`)

    Server.Library.SetCooldown(Character, "Parry", 1.5) -- Increased from 0.5 to 1.5 for longer cooldown
    Server.Library.StopAllAnims(Character)

    -- Play parry animation
    local ParryAnimation = Server.Library.PlayAnimation(Character, Server.Service.ReplicatedStorage.Assets.Animations.Weapons[Weapon].Parry)
    ParryAnimation.Priority = Enum.AnimationPriority.Action2

    -- Add parry frames - increased from 0.3s to 0.5s to make parrying easier
    Server.Library.TimedState(Character.Frames, "Parry", .5)

    print(`[PARRY DEBUG] {Character.Name} - Parry frames active for 0.5s`)

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
