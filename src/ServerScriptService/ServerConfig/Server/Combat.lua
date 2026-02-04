local Combat = {}; local Server = require(script.Parent);
local WeaponStats = require(Server.Service.ServerStorage:WaitForChild("Stats")._Weapons)
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Voxbreaker = require(ReplicatedStorage.Modules.Voxel)
local world = require(ReplicatedStorage.Modules.ECS.jecs_world)
local ref = require(ReplicatedStorage.Modules.ECS.jecs_ref)
local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)
local RefManager = require(ReplicatedStorage.Modules.ECS.jecs_ref_manager)
local StateManager = require(ReplicatedStorage.Modules.ECS.StateManager)

-- ============================================
-- ECS COMBAT STATE HELPERS
-- Replaces Entity.Combo, Entity.LastHit, Entity.SwingConnection
-- with ECS CombatState component
-- ============================================

local function getEntityECS(character: Model): number?
	local Players = game:GetService("Players")
	local player = Players:GetPlayerFromCharacter(character)
	if player then
		return ref.get("player", player)
	end
	return RefManager.entity.find(character)
end

local function getCombatState(character: Model): {combo: number, lastHitTime: number, swingConnection: RBXScriptConnection?}
	local entity = getEntityECS(character)
	if not entity then
		return { combo = 0, lastHitTime = 0, swingConnection = nil }
	end

	if world:has(entity, comps.CombatState) then
		return world:get(entity, comps.CombatState)
	end

	-- Initialize default combat state
	local defaultState = { combo = 0, lastHitTime = 0, swingConnection = nil }
	world:set(entity, comps.CombatState, defaultState)
	return defaultState
end

local function setCombatState(character: Model, state: {combo: number?, lastHitTime: number?, swingConnection: RBXScriptConnection?})
	local entity = getEntityECS(character)
	if not entity then return end

	local current = getCombatState(character)

	-- Merge provided state with current
	if state.combo ~= nil then current.combo = state.combo end
	if state.lastHitTime ~= nil then current.lastHitTime = state.lastHitTime end
	if state.swingConnection ~= nil then current.swingConnection = state.swingConnection end

	world:set(entity, comps.CombatState, current)
end

local function getCombo(character: Model): number
	return getCombatState(character).combo
end

local function setCombo(character: Model, value: number)
	setCombatState(character, { combo = value })
end

local function getLastHitTime(character: Model): number
	return getCombatState(character).lastHitTime
end

local function setLastHitTime(character: Model, value: number)
	setCombatState(character, { lastHitTime = value })
end

local function getSwingConnection(character: Model): RBXScriptConnection?
	return getCombatState(character).swingConnection
end

local function setSwingConnection(character: Model, connection: RBXScriptConnection?)
	setCombatState(character, { swingConnection = connection })
end

-- BvelRemove Effect enum for optimized packet (matches client-side decoder)
local BvelRemoveEffect = {
	All = 0,        -- Remove all body movers
	M1 = 1,
	M2 = 2,
	Knockback = 3,
	Dash = 4,
	Pincer = 5,
	Lunge = 6,
	IS = 7,
}

Combat.__index = Combat;
local self = setmetatable({}, Combat)

Combat.Light = function(Character: Model)
	local Hitbox = Server.Modules.Hitbox
	local Entity = Server.Modules["Entities"].Get(Character)
	if not Entity then return end

	local Player : Player;
	if Entity.Player then Player = Entity.Player end;

	-- Prevent actions during parry knockback for both NPCs and players
	if StateManager.StateCheck(Character, "Stuns", "ParryKnockback") then
		return
	end

	-- Check if M1 attack can cancel current action (priority-based)
	local isNPC = Character:GetAttribute("IsNPC")
	if not isNPC then
		-- Use ActionPriority to check if M1 can start (cancels lower priority actions)
		if not Server.Library.CanStartAction(Character, "M1Attack") then
			return
		end
		-- Also check stuns (stuns always block actions)
		if StateManager.StateCount(Character, "Stuns") then
			return
		end
	end

	-- CANCEL SPRINT when attacking (for players only)
	if Player then
		Server.Packets.CancelSprint.sendTo({}, Player)
	end

	Server.Library.StopAllAnims(Character)

	-- ECS-based combat state (replaces Entity.Combo, Entity.LastHit)
	local combatState = getCombatState(Character)
	StateManager.RemoveState(Entity.Character, "IFrames", "Dodge");

	-- Reset combo if more than 2 seconds since last hit
	if os.clock() - combatState.lastHitTime > 2 then
		combatState.combo = 0
	end

	local Weapon: string = Entity.Weapon
	local Stats: {} = WeaponStats[Weapon]

	if Stats["Exception"] then
		---- print('weapon has an exception')
		Server.Modules.WeaponExceptions[Weapon](Character, Entity, Weapon, Stats)
		return
	end

	if Stats then

		-- Clean up existing swing connection (ECS-based)
		if combatState.swingConnection then
			if StateManager.StateCheck(Character, "Speeds", "M1Speed13") then
				StateManager.RemoveState(Character, "Speeds", "M1Speed13")
			end

			combatState.swingConnection:Disconnect()
			combatState.swingConnection = nil
		end

		combatState.combo = combatState.combo + 1

		local Combo: number = combatState.combo
		local Cancel = false

		combatState.lastHitTime = os.clock()

		if combatState.combo >= Stats.MaxCombo then
			combatState.combo = 0

			-- Add combo reset cooldown after finishing the full combo chain
			-- This prevents immediately starting another M1 chain after the final hit
			task.delay(Stats["Endlag"][Combo], function()
				if Character then
					StateManager.TimedState(Character, "Actions", "ComboRecovery", 0.4)
				end
			end)
		end

		-- Start the M1 action with priority system (cancels lower priority actions like walking/sprinting)
		Server.Library.StartAction(Character, "M1Attack", Stats["Endlag"][Combo])

		StateManager.TimedState(Character, "Actions", "M1"..Combo, Stats["Endlag"][Combo])
		StateManager.AddState(Character, "Speeds", "M1Speed13") -- Reduced walkspeed to 13 (16 + (-3)) for more consistent hitboxes

		local Swings = Server.Service.ReplicatedStorage.Assets.Animations.Weapons[Weapon].Swings

		local SwingAnimation = Character.Humanoid.Animator:LoadAnimation(Swings:FindFirstChild(Combo))
		SwingAnimation:Play(0.1) -- Smooth fade transition
		SwingAnimation.Priority = Enum.AnimationPriority.Action2

		-- Apply animation speed if specified in weapon stats (slower = more readable combat)
		if Stats["Speed"] then
			SwingAnimation:AdjustSpeed(Stats["Speed"])
		end

		local Sound = Server.Library.PlaySound(Character,Server.Service.ReplicatedStorage.Assets.SFX.Weapons[Weapon].Swings[Random.new():NextInteger(1,#Server.Service.ReplicatedStorage.Assets.SFX.Weapons[Weapon].Swings:GetChildren())])

		if Stats["Trail"] then
			Combat.Trail(Character, true)
		end

		-- Store swing connection in ECS CombatState
		local swingConn
		swingConn = SwingAnimation.Stopped:Once(function()
			-- Clear connection from ECS state
			local currentState = getCombatState(Character)
			if currentState.swingConnection == swingConn then
				currentState.swingConnection = nil
				setCombatState(Character, currentState)
			end

			if StateManager.StateCheck(Character, "Speeds", "M1Speed13") then
				StateManager.RemoveState(Character, "Speeds", "M1Speed13")
			end

			if Stats["Trail"] then
				Combat.Trail(Character, false)
			end
		end)
		combatState.swingConnection = swingConn
		setCombatState(Character, combatState)


		-- ECS-based stun detection (replaces Character.Stuns.Changed)
		-- Use OnStunAdded to get a disconnect function so we can clean up when attack completes
		local m1StunDisconnect
		m1StunDisconnect = StateManager.OnStunAdded(Character, function(stunName)
			-- Disconnect immediately to prevent multiple fires
			if m1StunDisconnect then
				m1StunDisconnect()
				m1StunDisconnect = nil
			end

			if StateManager.StateCheck(Character, "Speeds", "M1Speed13") then
				StateManager.RemoveState(Character, "Speeds", "M1Speed13")
			end

			if StateManager.StateCheck(Character, "Actions", "M1"..Combo) then
				StateManager.RemoveState(Character, "Actions", "M1"..Combo)
			end

			Sound:Stop()

			SwingAnimation:Stop(.2)

			Cancel = true
		end)

		-- Calculate adjusted hit time based on animation speed
		local animSpeed = Stats["Speed"] or 1
		local adjustedHitTime = Stats["HitTimes"][Combo] / animSpeed

		task.delay(adjustedHitTime - (15/60), function()
			if Stats["Slashes"] then
				Server.Visuals.Ranged(Character.HumanoidRootPart.Position,300,{Module = "Base",Function = "Slashes", Arguments = {Character,Weapon,Combo}})
			end
		end)

		-- Wait for the adjusted hit time before checking hitbox (aligned with animation)
		task.wait(adjustedHitTime)

		if Cancel then
			return
		end

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

		if Cancel then
			return
		end

		-- Clean up stun listener since attack completed successfully
		if m1StunDisconnect then
			m1StunDisconnect()
			m1StunDisconnect = nil
		end

		--if Player then
		--	Server.Packets.Bvel.sendTo({Character = Character, Name = "M1Bvel"}, Player)
		--end

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
	if StateManager.StateCheck(Character, "Stuns", "ParryKnockback") then return end

	-- Use ActionPriority to check if Critical (M2) can start
	if not Server.Library.CanStartAction(Character, "M2Attack") then return end
	if StateManager.StateCount(Character, "Stuns") then return end

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

		-- ECS-based combat state for swing connection
		local combatState = getCombatState(Character)

		if combatState.swingConnection then
			if StateManager.StateCheck(Character, "Speeds", "M1Speed8") then
				StateManager.RemoveState(Character, "Speeds", "M1Speed8")
			end

			combatState.swingConnection:Disconnect()
			combatState.swingConnection = nil
		end

		if Stats["Critical"]["CustomFunction"] then
			Stats["Critical"]["CustomFunction"](Character,Entity)
			return
		end

		local Cancel = false

		-- Start the M2 action with priority system
		Server.Library.StartAction(Character, "M2Attack", Stats["Critical"]["Endlag"])

		StateManager.TimedState(Character, "Actions", "M2", Stats["Critical"]["Endlag"])
		StateManager.AddState(Character, "Speeds", "M1Speed8")

		local Swings = Server.Service.ReplicatedStorage.Assets.Animations.Weapons[Weapon]

		local SwingAnimation = Character.Humanoid.Animator:LoadAnimation(Swings:FindFirstChild("Critical"))
		SwingAnimation:Play(0.1) -- Smooth fade transition
		SwingAnimation.Priority = Enum.AnimationPriority.Action2

		--local Sound = Server.Library.PlaySound(Character,Server.Service.ReplicatedStorage.Assets.SFX.Weapons[Weapon].Swings[Random.new():NextInteger(1,#Server.Service.ReplicatedStorage.Assets.SFX.Weapons[Weapon].Swings:GetChildren())])

		-- Trigger Scythe Load VFX at animation start (ground charging effect)
		if Weapon == "Scythe" then
			Server.Visuals.Ranged(Character.HumanoidRootPart.Position, 300, {Module = "Base", Function = "ScytheCritLoad", Arguments = {Character}})
		end

		if Stats["Trail"] then
			Combat.Trail(Character, true)
		end

		-- Store swing connection in ECS CombatState
		local critSwingConn
		critSwingConn = SwingAnimation.Stopped:Once(function()
			local currentState = getCombatState(Character)
			if currentState.swingConnection == critSwingConn then
				currentState.swingConnection = nil
				setCombatState(Character, currentState)
			end

			if StateManager.StateCheck(Character, "Speeds", "M1Speed8") then
				StateManager.RemoveState(Character, "Speeds", "M1Speed8")
			end

			if Stats["Trail"] then
				Combat.Trail(Character, false)
			end
		end)
		combatState.swingConnection = critSwingConn
		setCombatState(Character, combatState)


		-- ECS-based stun detection (replaces Character.Stuns.Changed)
		-- Use OnStunAdded to get a disconnect function so we can clean up when attack completes
		local m2StunDisconnect
		m2StunDisconnect = StateManager.OnStunAdded(Character, function(stunName)
			-- Disconnect immediately to prevent multiple fires
			if m2StunDisconnect then
				m2StunDisconnect()
				m2StunDisconnect = nil
			end

			if StateManager.StateCheck(Character, "Speeds", "M1Speed8") then
				StateManager.RemoveState(Character, "Speeds", "M1Speed8")
			end

			SwingAnimation:Stop(.2)
			Cancel = true
		end)

		task.wait(Stats["Critical"].WaitTime)

		if Cancel then return end

		-- Clean up stun listener since attack completed successfully
		if m2StunDisconnect then
			m2StunDisconnect()
			m2StunDisconnect = nil
		end

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

					---- print(`[Critical] Knocked back ragdolled target: {Target.Name} and extended ragdoll by 3 seconds`)
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
				---- print("sending loop to wall")
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

	-- RunningAttack is priority 1 (same as sprint) - M1 can cancel it
	-- Check stuns separately as they always block actions
	if StateManager.StateCount(Character, "Stuns") then return end
	if not Server.Library.CanStartAction(Character, "RunningAttack") then return end

	Server.Library.StopAllAnims(Character)
	
	Server.Library.SetCooldown(Character,"RunningAttack",5)	

	local Weapon: string = Entity.Weapon
	local Stats: {} = WeaponStats[Weapon]
	
	local Cancel = false
	
	if Stats then

		-- ECS-based combat state for swing connection
		local combatState = getCombatState(Character)

		if combatState.swingConnection then
			if StateManager.StateCheck(Character, "Speeds", "M1Speed13") then
				StateManager.RemoveState(Character, "Speeds", "M1Speed13")
			end

			combatState.swingConnection:Disconnect()
			combatState.swingConnection = nil
		end

		-- Start the RunningAttack action with priority system (low priority, can be cancelled by M1)
		Server.Library.StartAction(Character, "RunningAttack", Stats["RunningAttack"]["Endlag"])

		StateManager.TimedState(Character, "Actions", "RunningAttack", Stats["RunningAttack"]["Endlag"])
		StateManager.AddState(Character, "Speeds", "RunningAttack-12") -- Changed from 8 to 12 for faster combat

		local SwingAnimation = Character.Humanoid.Animator:LoadAnimation(Server.Service.ReplicatedStorage.Assets.Animations.Weapons[Weapon]["Running Attack"])
		SwingAnimation:Play(0.1)

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

		-- Store swing connection in ECS CombatState
		local runSwingConn
		runSwingConn = SwingAnimation.Stopped:Once(function()
			local currentState = getCombatState(Character)
			if currentState.swingConnection == runSwingConn then
				currentState.swingConnection = nil
				setCombatState(Character, currentState)
			end

			if StateManager.StateCheck(Character, "Speeds", "RunningAttack-12") then
				StateManager.RemoveState(Character, "Speeds", "RunningAttack-12")
			end

			if Stats["Trail"] then
				Combat.Trail(Character, false)
			end
		end)
		combatState.swingConnection = runSwingConn
		setCombatState(Character, combatState)

		if Stats["Trail"] then
			Combat.Trail(Character, true)
		end

		-- ECS-based stun detection (replaces Character.Stuns.Changed)
		local runningAtkStunDisconnect = StateManager.OnStunAdded(Character, function(stunName)
			if StateManager.StateCheck(Character, "Speeds", "RunningAttack-12") then
				StateManager.RemoveState(Character, "Speeds", "RunningAttack-12")
			end

			if StateManager.StateCheck(Character, "Actions", "RunningAttack") then
				StateManager.RemoveState(Character, "Actions", "RunningAttack")
			end

			if Player and Player.Parent then
				-- Optimized: Use BvelRemove packet (2 bytes vs ~20+ bytes)
				Server.Packets.BvelRemove.sendTo({Character = Character, Effect = BvelRemoveEffect.All}, Player)
			end

			SwingAnimation:Stop(.2)

			Cancel = true
		end)

		task.wait(Stats["RunningAttack"]["HitTime"])

		if Cancel then return end

		-- Disconnect stun listener after hit time
		if runningAtkStunDisconnect then
			runningAtkStunDisconnect()
		end
		
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
							---- print("ra table")
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
local RecentBlockAttempts = {} -- Track recent block attempts for parry window

-- Get BlockStates table (used by Damage.lua to check parry window)
Combat.GetBlockStates = function()
	return BlockStates
end

-- Check if character has a recent block attempt (within parry window)
Combat.HasRecentBlockAttempt = function(Character: Model)
	local attempt = RecentBlockAttempts[Character]
	if not attempt then return false end

	local timeSinceAttempt = os.clock() - attempt.StartTime
	return timeSinceAttempt <= 0.23 -- Within 0.23s parry window
end

-- Clear block state tracking for a character (used during block break and character death)
Combat.ClearBlockState = function(Character: Model)
	if BlockStates[Character] then
		-- Disconnect any active connections
		if BlockStates[Character].Connection then
			BlockStates[Character].Connection:Disconnect()
		end
		-- Clear the tracking data
		BlockStates[Character] = nil
	end

	-- Also clear recent block attempts
	RecentBlockAttempts[Character] = nil
end

Combat.HandleBlockInput = function(Character: Model, State: boolean)
    local Entity = Server.Modules["Entities"].Get(Character)
    if not Entity then return end

    local Weapon = Entity.Weapon
    local Stats = WeaponStats[Weapon]
    if not Stats then return end

    if State then
        -- PREVENT OVERLAPPING ACTIONS: Cannot START blocking while performing certain actions
        -- Allow blocking during recovery states (DodgeRecovery, ComboRecovery, etc.)
        local allStates = StateManager.GetAllStates(Character, "Actions")
        local allowedForBlock = {
            "DodgeRecovery", "ComboRecovery", "BlockRecovery", "ParryRecovery",
            "Dashing", "Running", "Equipped",
        }
        for _, state in ipairs(allStates) do
            local isAllowed = false
            for _, allowed in ipairs(allowedForBlock) do
                if state == allowed or string.find(state, allowed) then
                    isAllowed = true
                    break
                end
            end
            if not isAllowed then
                return -- Block is prevented by this action
            end
        end

        -- Prevent blocking during parry knockback
        if StateManager.StateCheck(Character, "Stuns", "ParryKnockback") then return end
        -- If already parrying, don't interrupt
        if StateManager.StateCheck(Character, "Frames", "Parry") then return end
        -- Prevent blocking during strategist combo
        if StateManager.StateCheck(Character, "Stuns", "StrategistComboHit") then return end
        -- Prevent blocking while BlockBroken (guard broken)
        if StateManager.StateCheck(Character, "Stuns", "BlockBreakStun") then return end
        -- Prevent blocking for 2 seconds after BlockBreak stun ends
        if StateManager.StateCheck(Character, "Stuns", "BlockBreakCooldown") then return end
        -- Prevent blocking while ragdolled
        if StateManager.StateCheck(Character, "Stuns", "Ragdolled") then return end
        -- Prevent blocking while knocked back (from parry, attacks, etc.)
        if StateManager.StateCheck(Character, "Stuns", "Knockback") then return end
        if StateManager.StateCheck(Character, "Stuns", "KnockbackRoll") then return end

        -- Prevent blocking if BlockBroken tag is present
        if Entity.Player then
            local playerEntity = ref.get("player", Entity.Player)
            if playerEntity and world:has(playerEntity, comps.BlockBroken) then
                return
            end
        end
        -- Start block if not already blocking
        if not BlockStates[Character] then
            -- CANCEL SPRINT when starting to block (for players only)
            if Entity.Player then
                Server.Packets.CancelSprint.sendTo({}, Entity.Player)
            end

            local startTime = os.clock()
            BlockStates[Character] = {
                Blocking = true, -- Start blocking immediately
                ParryWindow = true, -- First 0.23s is parry window
                HoldTime = 0,
                StartTime = startTime
            }

            -- Track this block attempt for parry window (even if released quickly)
            RecentBlockAttempts[Character] = {
                StartTime = startTime
            }

            -- Start blocking immediately (no delay)
            self.StartBlock(Character)

            -- Start tracking hold time
            BlockStates[Character].Connection = Server.Utilities:AddToTempLoop(function(dt)
                if not BlockStates[Character] then return true end

                BlockStates[Character].HoldTime = BlockStates[Character].HoldTime + dt

                -- After 0.23s, parry window expires
                if BlockStates[Character].HoldTime >= 0.23 and BlockStates[Character].ParryWindow then
                    BlockStates[Character].ParryWindow = false
                end

                return false
            end)
        end
    else
        -- Release input
        if BlockStates[Character] then
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
   -- print(`[PARRY DEBUG] {Character.Name} attempting to parry`)

    if Server.Library.CheckCooldown(Character, "Parry") then
       -- print(`[PARRY DEBUG] {Character.Name} - BLOCKED: On cooldown`)
        return
    end

    -- Prevent parrying during parry knockback
    if StateManager.StateCheck(Character, "Stuns", "ParryKnockback") then
       -- print(`[PARRY DEBUG] {Character.Name} - BLOCKED: ParryKnockback state active`)
        return
    end

    if StateManager.StateCheck(Character, "Stuns", "BlockBreakStun") then
       -- print(`[PARRY DEBUG] {Character.Name} - BLOCKED: BlockBreakStun state active`)
        return
    end

    -- Prevent parrying during ragdoll
    if Character:FindFirstChild("Ragdoll") then
       -- print(`[PARRY DEBUG] {Character.Name} - BLOCKED: Ragdoll active`)
        return
    end

    -- Prevent parrying during moves
    if StateManager.StateCount(Character, "Actions") then
        local _actions = StateManager.GetAllStates(Character, "Actions")
       -- print(`[PARRY DEBUG] {Character.Name} - BLOCKED: Actions active: {table.concat(actions, ", ")}`)
        return
    end

    -- Prevent parrying during strategist combo
    if StateManager.StateCheck(Character, "Stuns", "StrategistComboHit") then
       -- print(`[PARRY DEBUG] {Character.Name} - BLOCKED: StrategistComboHit state active`)
        return
    end

    -- Prevent parrying during M1 stun (true stun system)
    if StateManager.StateCheck(Character, "Stuns", "M1Stun") then
       -- print(`[PARRY DEBUG] {Character.Name} - BLOCKED: M1Stun state active (true stun)`)
        return
    end

    local Entity = Server.Modules["Entities"].Get(Character)
    if not Entity then
       -- print(`[PARRY DEBUG] {Character.Name} - BLOCKED: No entity found`)
        return
    end

    local Weapon = Entity.Weapon
    local Stats = WeaponStats[Weapon]
    if not Stats then
       -- print(`[PARRY DEBUG] {Character.Name} - BLOCKED: No weapon stats for {Weapon}`)
        return
    end

   -- print(`[PARRY DEBUG] {Character.Name} - ✅ PARRY STARTED - Weapon: {Weapon}`)

    Server.Library.SetCooldown(Character, "Parry", 1.5) -- Increased from 0.5 to 1.5 for longer cooldown

    -- Start Parry action with priority system (priority 4, same as skills)
    Server.Library.StartAction(Character, "Parry", 0.5)

    Server.Library.StopAllAnims(Character)

    -- Play parry animation
    local ParryAnimation = Server.Library.PlayAnimation(Character, Server.Service.ReplicatedStorage.Assets.Animations.Weapons[Weapon].Parry)
    ParryAnimation.Priority = Enum.AnimationPriority.Action2

    -- Add parry frames - increased from 0.3s to 0.5s to make parrying easier
    StateManager.TimedState(Character, "Frames", "Parry", 0.5)

   -- print(`[PARRY DEBUG] {Character.Name} - Parry frames active for 0.5s`)

    -- Add recovery endlag after parry window expires (prevents instant action after parry attempt)
    task.delay(0.5, function()
        if Character then
            StateManager.TimedState(Character, "Actions", "ParryRecovery", 0.15)
        end
    end)

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

    -- Start Block action with priority system (priority 4, same as skills)
    Server.Library.StartAction(Character, "Block")

    StateManager.AddState(Character, "Frames", "Blocking")
    StateManager.AddState(Character, "Speeds", "BlockSpeed8")
    StateManager.AddState(Character, "Actions", "Blocking")

    local BlockAnimation = Server.Library.PlayAnimation(Character, Server.Service.ReplicatedStorage.Assets.Animations.Weapons[Weapon].Block)
    BlockAnimation.Priority = Enum.AnimationPriority.Action2
end

Combat.EndBlock = function(Character: Model)
    local Entity = Server.Modules["Entities"].Get(Character)
    if not Entity then return end

    local Weapon = Entity.Weapon
    if not Weapon then return end

    -- End the Block action in priority system
    Server.Library.EndAction(Character, "Block")

    Server.Library.StopAnimation(Character, Server.Service.ReplicatedStorage.Assets.Animations.Weapons[Weapon].Block)

    StateManager.RemoveState(Character, "Actions", "Blocking")
    StateManager.RemoveState(Character, "Speeds", "BlockSpeed8")
    StateManager.RemoveState(Character, "Frames", "Blocking")

    -- Add recovery endlag after releasing block (prevents instant attack after block)
    StateManager.TimedState(Character, "Actions", "BlockRecovery", 0.1)
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
