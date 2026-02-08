local Combat = {}; local Server = require(script.Parent);
local WeaponStats = require(Server.Service.ServerStorage:WaitForChild("Stats")._Weapons)
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Voxbreaker = require(ReplicatedStorage.Modules.Voxel)
local world = require(ReplicatedStorage.Modules.ECS.jecs_world)
local ref = require(ReplicatedStorage.Modules.ECS.jecs_ref)
local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)
local RefManager = require(ReplicatedStorage.Modules.ECS.jecs_ref_manager)
local StateManager = require(ReplicatedStorage.Modules.ECS.StateManager)
local FocusHandler = require(script.Parent.FocusHandler)

-- Helper to set combat animation attribute for Chrono NPC replication
-- Format: "Weapon|AnimType|AnimName|Speed|Timestamp"
-- Client NpcAnimator.lua listens for this attribute to play animations on the clone
--
-- IMPORTANT: Chrono clones NPCs - the server model and client clone are separate instances.
-- We must set the attribute on the NPC_MODEL_CACHE model (in ReplicatedStorage) for it to replicate.
local NPC_MODEL_CACHE = ReplicatedStorage:FindFirstChild("NPC_MODEL_CACHE")

local function setNPCCombatAnim(character: Model, weapon: string, animType: string, animName: string, speed: number?)
	-- Only set attribute for NPCs (not players) that have a ChronoId
	if Players:GetPlayerFromCharacter(character) then
		return -- Skip players, their animations replicate normally
	end

	local chronoId = character:GetAttribute("ChronoId")
	if not chronoId then
		print(`[Combat] setNPCCombatAnim: {character.Name} has no ChronoId, skipping`)
		return -- Not a Chrono NPC
	end

	-- Format: "Weapon|AnimType|AnimName|Speed|Timestamp"
	local animSpeed = speed or 1
	local timestamp = workspace:GetServerTimeNow()
	local animData = `{weapon}|{animType}|{animName}|{animSpeed}|{timestamp}`

	-- Set on server model (for server-side reference)
	character:SetAttribute("NPCCombatAnim", animData)

	-- CRITICAL: Also set on the NPC_MODEL_CACHE model for client replication
	-- The cache model is in ReplicatedStorage and its attributes replicate to clients
	if not NPC_MODEL_CACHE then
		NPC_MODEL_CACHE = ReplicatedStorage:FindFirstChild("NPC_MODEL_CACHE")
	end
	if NPC_MODEL_CACHE then
		local cacheModel = NPC_MODEL_CACHE:FindFirstChild(tostring(chronoId))
		if cacheModel then
			cacheModel:SetAttribute("NPCCombatAnim", animData)
			print(`[Combat] ✅ Set NPCCombatAnim on cache model {chronoId}: {animData}`)
		else
			print(`[Combat] ⚠️ Cache model not found for ChronoId {chronoId}`)
		end
	else
		print(`[Combat] ⚠️ NPC_MODEL_CACHE folder not found`)
	end
end

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

Combat.Light = function(Character: Model, Air: boolean?)
	print(`[Combat.Light] Called for {Character.Name}`)
	local Hitbox = Server.Modules.Hitbox
	local Entity = Server.Modules["Entities"].Get(Character)
	if not Entity then
		print(`[Combat.Light] ❌ No Entity for {Character.Name}`)
		return
	end
	print(`[Combat.Light] Entity found, Weapon: {Entity.Weapon or "nil"}, ChronoId: {Character:GetAttribute("ChronoId") or "nil"}`)

	-- Check for aerial attack: player is airborne and weapon has Aerial stats
	-- Server-side validation: verify humanoid is actually airborne (don't trust client alone)
	if Air then
		local humanoid = Character:FindFirstChild("Humanoid")
		local actuallyAirborne = humanoid and humanoid.FloorMaterial == Enum.Material.Air
		if actuallyAirborne then
			local Weapon = Entity.Weapon
			local Stats = WeaponStats[Weapon]
			if Stats and Stats["Aerial"] then
				Combat.AerialAttack(Character)
				return
			end
		end
	end

	local Player : Player;
	if Entity.Player then Player = Entity.Player end;

	-- Prevent actions during parry knockback for both NPCs and players
	if StateManager.StateCheck(Character, "Stuns", "ParryKnockback") then
		return
	end

	-- Check stuns — applies to BOTH players and NPCs
	if StateManager.StateCount(Character, "Stuns") then
		return
	end

	-- Check if M1 attack can cancel current action (priority-based)
	local isNPC = Character:GetAttribute("IsNPC")
	if not isNPC then
		-- Use ActionPriority to check if M1 can start (cancels lower priority actions)
		if not Server.Library.CanStartAction(Character, "M1Attack") then
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
					StateManager.TimedState(Character, "Actions", "ComboRecovery", 0.6)
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
		local animSpeed = Stats["Speed"] or 1
		if Stats["Speed"] then
			SwingAnimation:AdjustSpeed(Stats["Speed"])
		end

		-- Replicate animation to clients for Chrono NPCs
		setNPCCombatAnim(Character, Weapon, "Swings", tostring(Combo), animSpeed)

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
		-- Last hit of combo uses LastTable (full knockback) instead of M1Table (light knockback)
		local isLastHit = (Combo >= Stats.MaxCombo)
		local damageTable = isLastHit and Stats["LastTable"] or Stats["M1Table"]

		if #HitTargets > 0 then
			-- Focus: reward landing hits
			FocusHandler.AddFocus(Character, FocusHandler.Amounts.M1_HIT, "m1_hit")
			if Combo >= 3 then
				FocusHandler.AddFocus(Character, FocusHandler.Amounts.COMBO_BONUS, "combo_bonus")
			end
		else
			-- Focus: punish whiffing
			FocusHandler.RemoveFocus(Character, FocusHandler.Amounts.WHIFF_ATTACK, "whiff_attack")
		end

		for _, Target: Model in pairs(HitTargets) do
			Server.Modules.Damage.Tag(Character, Target, damageTable)
		end

		end
end

-- CriticalStart: Begin charged M2. Pauses animation at attack frame, waits for release.
-- Players hold M2 to charge (up to 1s). NPCs use instant Critical() wrapper below.
Combat.CriticalStart = function(Character: Model)
	local Entity = Server.Modules["Entities"].Get(Character)
	if not Entity then return end

	if Server.Library.CheckCooldown(Character, "Critical") then return end

	local Player: Player?
	if Entity.Player then Player = Entity.Player end

	if StateManager.StateCheck(Character, "Stuns", "ParryKnockback") then return end
	if not Server.Library.CanStartAction(Character, "M2Attack") then return end
	if StateManager.StateCount(Character, "Stuns") then return end

	-- Already charging? Ignore duplicate start
	if Character:GetAttribute("CriticalChargeStart") then return end

	-- Clear stale early release flag from a previous failed attempt
	Character:SetAttribute("CriticalEarlyRelease", nil)

	if Player then
		Server.Packets.CancelSprint.sendTo({}, Player)
	end

	Server.Library.StopAllAnims(Character)

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
	if not Stats then return end

	if Stats["Critical"]["CustomFunction"] then
		Stats["Critical"]["CustomFunction"](Character, Entity)
		return
	end

	Server.Library.SetCooldown(Character, "Critical", 5)
	Server.Visuals.Ranged(Character.HumanoidRootPart.Position, 300, {Module = "Base", Function = "CriticalIndicator", Arguments = {Character}})

	local combatState = getCombatState(Character)
	if combatState.swingConnection then
		if StateManager.StateCheck(Character, "Speeds", "M1Speed8") then
			StateManager.RemoveState(Character, "Speeds", "M1Speed8")
		end
		combatState.swingConnection:Disconnect()
		combatState.swingConnection = nil
	end

	-- Max charge duration + buffer for action state
	local MAX_CHARGE = 1.0
	local actionDuration = Stats["Critical"]["Endlag"] + MAX_CHARGE + 0.5

	Server.Library.StartAction(Character, "M2Attack", actionDuration)
	StateManager.TimedState(Character, "Actions", "CriticalCharge", actionDuration)
	StateManager.AddState(Character, "Speeds", "M1Speed8")

	local Swings = Server.Service.ReplicatedStorage.Assets.Animations.Weapons[Weapon]
	local SwingAnimation = Character.Humanoid.Animator:LoadAnimation(Swings:FindFirstChild("Critical"))
	SwingAnimation:Play(0.1)
	SwingAnimation.Priority = Enum.AnimationPriority.Action2

	setNPCCombatAnim(Character, Weapon, "Critical", "Critical", 1)

	if Weapon == "Scythe" then
		Server.Visuals.Ranged(Character.HumanoidRootPart.Position, 300, {Module = "Weapons", Function = "ScytheCritLoad", Arguments = {Character}})
	end

	if Stats["Trail"] then
		Combat.Trail(Character, true)
	end

	-- Stun listener: cancel if hit during wind-up or charge
	local Cancel = false
	local chargeStunDisconnect
	chargeStunDisconnect = StateManager.OnStunAdded(Character, function()
		if chargeStunDisconnect then
			chargeStunDisconnect()
			chargeStunDisconnect = nil
		end
		Cancel = true
		Character:SetAttribute("CriticalChargeStart", nil)
		Character:SetAttribute("CriticalEarlyRelease", nil)
		SwingAnimation:Stop(0.2)
		if StateManager.StateCheck(Character, "Speeds", "M1Speed8") then
			StateManager.RemoveState(Character, "Speeds", "M1Speed8")
		end
		if Stats["Trail"] then
			Combat.Trail(Character, false)
		end
		-- Clear combat state refs so stale CriticalRelease calls don't find old animation
		local cs = getCombatState(Character)
		cs.criticalAnimation = nil
		cs.criticalWeapon = nil
		cs.criticalStunDisconnect = nil
		setCombatState(Character, cs)
		if Player then
			Server.Packets.Bvel.sendTo({Character = Character, Name = "CriticalChargeRelease"}, Player)
		end
	end)

	-- Wait until just before attack frame, then pause
	task.wait(Stats["Critical"].WaitTime)

	if Cancel then return end

	-- Check if player already released during wind-up (quick tap)
	if Character:GetAttribute("CriticalEarlyRelease") then
		Character:SetAttribute("CriticalEarlyRelease", nil)
		-- Clean up stun listener
		if chargeStunDisconnect then
			chargeStunDisconnect()
			chargeStunDisconnect = nil
		end
		-- Don't pause — let animation continue, set charge start to NOW so release fires instantly
		Character:SetAttribute("CriticalChargeStart", os.clock())
		combatState = getCombatState(Character)
		combatState.criticalAnimation = SwingAnimation
		combatState.criticalWeapon = Weapon
		setCombatState(Character, combatState)
		-- Immediately release at stage 1
		Combat.CriticalRelease(Character)
		return
	end

	SwingAnimation:AdjustSpeed(0) -- Pause at attack frame

	-- Record charge start time
	Character:SetAttribute("CriticalChargeStart", os.clock())

	-- Store animation reference and stun disconnect for CriticalRelease
	combatState = getCombatState(Character)
	combatState.criticalAnimation = SwingAnimation
	combatState.criticalWeapon = Weapon
	combatState.criticalStunDisconnect = chargeStunDisconnect
	setCombatState(Character, combatState)

	-- Send charge VFX to player
	if Player then
		Server.Packets.Bvel.sendTo({Character = Character, Name = "CriticalChargeStart"}, Player)
	end

	-- Auto-release after max charge time
	task.delay(MAX_CHARGE, function()
		if Character:GetAttribute("CriticalChargeStart") then
			Combat.CriticalRelease(Character)
		end
	end)
end

-- CriticalRelease: Execute the charged M2 attack based on hold duration.
Combat.CriticalRelease = function(Character: Model)
	local chargeStart = Character:GetAttribute("CriticalChargeStart")
	if not chargeStart then
		-- Player released during wind-up (before charge started).
		-- Flag so CriticalStart skips the charge phase and fires immediately.
		Character:SetAttribute("CriticalEarlyRelease", true)
		return
	end

	local Entity = Server.Modules["Entities"].Get(Character)
	if not Entity then return end

	local Hitbox = Server.Modules.Hitbox
	local Player: Player?
	if Entity.Player then Player = Entity.Player end

	-- Calculate charge time and stage
	local chargeTime = math.clamp(os.clock() - chargeStart, 0, 1.0)
	local stage, damageMultiplier
	if chargeTime >= 0.66 then
		stage = 3
		damageMultiplier = 1.5
	elseif chargeTime >= 0.33 then
		stage = 2
		damageMultiplier = 1.25
	else
		stage = 1
		damageMultiplier = 1.0
	end

	-- Clear charge state
	Character:SetAttribute("CriticalChargeStart", nil)

	-- Clean up stun listener
	local combatState = getCombatState(Character)
	if combatState.criticalStunDisconnect then
		combatState.criticalStunDisconnect()
		combatState.criticalStunDisconnect = nil
	end

	local SwingAnimation = combatState.criticalAnimation
	local Weapon = combatState.criticalWeapon or Entity.Weapon
	combatState.criticalAnimation = nil
	combatState.criticalWeapon = nil
	setCombatState(Character, combatState)

	if not SwingAnimation then return end

	local Stats: {} = WeaponStats[Weapon]
	if not Stats then return end

	-- Stage 3: Uninterruptible (super armor) for the attack duration
	if stage == 3 then
		StateManager.TimedState(Character, "IFrames", "CriticalArmor", Stats["Critical"]["Endlag"])
	end

	-- Resume animation
	SwingAnimation:AdjustSpeed(1)

	-- Update action duration to proper endlag now
	Server.Library.StartAction(Character, "M2Attack", Stats["Critical"]["Endlag"])
	StateManager.TimedState(Character, "Actions", "M2", Stats["Critical"]["Endlag"])

	-- Send release VFX
	if Player then
		Server.Packets.Bvel.sendTo({Character = Character, Name = "CriticalChargeRelease"}, Player)
	end

	-- Store swing connection
	combatState = getCombatState(Character)
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

	-- Brief wait for attack frame to play out
	task.wait(0.1)

	if WeaponStats[Weapon].SpecialCrit == true then
		Server.Visuals.Ranged(Character.HumanoidRootPart.Position, 300, {Module = "Weapons", Function = "SpecialCrit"..Weapon, Arguments = {Character}})
		if WeaponStats[Weapon].SpecialCritSound then
			Server.Library.PlaySound(Character, WeaponStats[Weapon].Critical.Sfx[1])
			Server.Library.PlaySound(Character, WeaponStats[Weapon].Critical.Sfx[2])
			Server.Library.PlaySound(Character, WeaponStats[Weapon].Critical.Sfx[3])
		end
	end

	-- Hitbox check with damage multiplier (use CritHitbox if defined, else fall back to Hitboxes[1])
	local critHB = Stats["Critical"]["CritHitbox"]
	local hitboxSize = critHB and critHB["HitboxSize"] or Stats["Hitboxes"][1]["HitboxSize"]
	local hitboxOffset = critHB and critHB["HitboxOffset"] or Stats["Hitboxes"][1]["HitboxOffset"]
	local HitTargets = Hitbox.SpatialQuery(Character, hitboxSize, Entity:GetCFrame() * hitboxOffset)

	-- Focus: reward or punish M2
	if #HitTargets > 0 then
		FocusHandler.AddFocus(Character, FocusHandler.Amounts.SKILL_HIT, "critical_hit")
	else
		FocusHandler.RemoveFocus(Character, FocusHandler.Amounts.WHIFF_ATTACK, "whiff_critical")
	end

	for _, Target: Model in pairs(HitTargets) do
		-- Apply damage with charge multiplier
		local scaledDamageTable = {}
		for k, v in pairs(Stats["Critical"]["DamageTable"]) do
			scaledDamageTable[k] = v
		end
		scaledDamageTable.Damage = math.floor(scaledDamageTable.Damage * damageMultiplier)
		if scaledDamageTable.PostureDamage then
			scaledDamageTable.PostureDamage = math.floor(scaledDamageTable.PostureDamage * damageMultiplier)
		end

		Server.Modules.Damage.Tag(Character, Target, scaledDamageTable)

		if Target:IsA("Model") and Target:FindFirstChild("HumanoidRootPart") then
			local isRagdolled = Target:FindFirstChild("Ragdoll") or
			                   (Target:GetAttribute("Knocked") and Target:GetAttribute("Knocked") > 0)

			if isRagdolled then
				local direction = Character.HumanoidRootPart.CFrame.LookVector
				local horizontalPower = 60
				local upwardPower = 50

				Server.Modules.ServerBvel.BFKnockback(Target, direction, horizontalPower, upwardPower)

				local Ragdoller = require(game.ReplicatedStorage.Modules.Utils.Ragdoll)
				Ragdoller.Ragdoll(Target, 3)
			end
		end

		if Target:IsDescendantOf(workspace.Transmutables) then
			local wall = Target
			local root = Character.HumanoidRootPart
			local playerForward = root.CFrame.LookVector
					playerForward = Vector3.new(playerForward.X, 0, playerForward.Z).Unit

					local originalCFrame = wall.CFrame
					local originalColor = wall.Color
					local startTime = os.clock()
					local duration = 1.0
					local maxDistance = 35
			task.spawn(function()
						local movingTargets = {}
						local hitboxSize = wall.Size + Vector3.new(3, 3, 3)

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

							local newHitTargets = Hitbox.SpatialQuery(Character, wall.Size, wall.CFrame)

							for _, hitTarget in pairs(newHitTargets) do
								if
									hitTarget ~= wall
									and hitTarget:IsA("Model")
									and not movingTargets[hitTarget]
								then
									movingTargets[hitTarget] = true
									local parts = Voxbreaker:VoxelizePart(wall, 10, 15)

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

									Server.Modules.Damage.Tag(Character, hitTarget, scaledDamageTable)
								end
							end
							task.wait()
						end
					end)
		end
	end

	-- Remove CriticalArmor after attack completes (stage 3)
	if stage == 3 then
		task.delay(0.3, function()
			if StateManager.StateCheck(Character, "IFrames", "CriticalArmor") then
				StateManager.RemoveState(Character, "IFrames", "CriticalArmor")
			end
		end)
	end
end

-- Instant Critical for NPCs (no charging). Also used as backwards-compatible wrapper.
Combat.Critical = function(Character: Model)
	Combat.CriticalStart(Character)
	-- For NPCs, immediately release (0 charge time = stage 1 damage)
	task.wait(0.05)
	Combat.CriticalRelease(Character)
end

-- Aerial Attack: Jump + M1 with Scythe (or any weapon with Aerial stats)
-- Launches upward+forward, animation plays through, hit on ground contact
-- On landing: crater VFX + expanded hitbox
Combat.AerialAttack = function(Character: Model)
	local Hitbox = Server.Modules.Hitbox
	local Entity = Server.Modules["Entities"].Get(Character)
	if not Entity then return end

	local Player: Player?
	if Entity.Player then Player = Entity.Player end

	if StateManager.StateCheck(Character, "Stuns", "ParryKnockback") then return end
	if not Server.Library.CanStartAction(Character, "M1Attack") then return end
	if StateManager.StateCount(Character, "Stuns") then return end

	local Weapon: string = Entity.Weapon
	local Stats: {} = WeaponStats[Weapon]
	if not Stats or not Stats["Aerial"] then return end

	local aerialStats = Stats["Aerial"]
	local animFolder = Server.Service.ReplicatedStorage.Assets.Animations.Weapons[Weapon]
	local aerialAnim = animFolder and animFolder:FindFirstChild("Aerial")
	if not aerialAnim then return end

	if Player then
		Server.Packets.CancelSprint.sendTo({}, Player)
	end

	Server.Library.StopAllAnims(Character)

	-- Generous action duration — will be refreshed on landing
	local maxAirTime = 2.0
	Server.Library.StartAction(Character, "M1Attack", maxAirTime)
	StateManager.TimedState(Character, "Actions", "AerialAttack", maxAirTime)
	StateManager.AddState(Character, "Speeds", "M1Speed8")

	-- Play aerial animation (plays straight through, no pause)
	local SwingAnimation = Character.Humanoid.Animator:LoadAnimation(aerialAnim)
	SwingAnimation:Play(0.1)
	SwingAnimation.Priority = Enum.AnimationPriority.Action2

	setNPCCombatAnim(Character, Weapon, "Aerial", "Aerial", 1)

	if Stats["Trail"] then
		Combat.Trail(Character, true)
	end

	-- Apply smooth forward dive velocity
	if Player then
		Server.Packets.Bvel.sendTo({Character = Character, Name = "AerialAttackBvel"}, Player)
	else
		Server.Modules.ServerBvel.AerialAttackLaunch(Character)
	end

	-- Stun cancellation listener
	local Cancel = false
	local stunDisconnect
	stunDisconnect = StateManager.OnStunAdded(Character, function()
		if stunDisconnect then stunDisconnect(); stunDisconnect = nil end
		Cancel = true
		SwingAnimation:Stop(0.2)
		if StateManager.StateCheck(Character, "Speeds", "M1Speed8") then
			StateManager.RemoveState(Character, "Speeds", "M1Speed8")
		end
		if Stats["Trail"] then Combat.Trail(Character, false) end
	end)

	-- Wait for the Bvel arc to finish before checking ground contact
	task.wait(0.45)
	if Cancel then return end

	-- Now poll for ground contact (character is descending)
	local humanoid = Character:FindFirstChild("Humanoid")
	local landed = false
	local groundCheckStart = os.clock()

	while not landed and not Cancel do
		task.wait()
		if Cancel then return end
		if not Character or not Character.Parent then return end

		if humanoid and humanoid.FloorMaterial ~= Enum.Material.Air then
			landed = true
		end

		-- Safety timeout (1.5s after Bvel ends)
		if os.clock() - groundCheckStart > 1.5 then
			landed = true
		end
	end

	if Cancel then return end
	if stunDisconnect then stunDisconnect(); stunDisconnect = nil end

	-- LANDED — hitbox check immediately
	local landingHitboxSize = aerialStats["LandingHitboxSize"] or Vector3.new(12, 8, 12)
	local landingHitboxOffset = aerialStats["LandingHitboxOffset"] or CFrame.new(0, -2, -3)

	local HitTargets = Hitbox.SpatialQuery(Character, landingHitboxSize, Entity:GetCFrame() * landingHitboxOffset)

	-- Focus: reward landing aerial attack
	if #HitTargets > 0 then
		FocusHandler.AddFocus(Character, FocusHandler.Amounts.SKILL_HIT, "aerial_hit")
	else
		FocusHandler.RemoveFocus(Character, FocusHandler.Amounts.WHIFF_ATTACK, "whiff_aerial")
	end

	for _, Target: Model in pairs(HitTargets) do
		Server.Modules.Damage.Tag(Character, Target, aerialStats["DamageTable"])
	end

	-- Send crater VFX to all nearby clients
	local hrp = Character:FindFirstChild("HumanoidRootPart")
	if hrp then
		Server.Visuals.Ranged(hrp.Position, 300, {Module = "Weapons", Function = "AerialCrater", Arguments = {Character}})
	end

	-- Camera shake for the player
	if Player then
		Server.Visuals.FireClient(Player, {Module = "Misc", Function = "CameraShake", Arguments = {"Medium"}})
	end

	-- Endlag
	local endlag = aerialStats["Endlag"]
	Server.Library.StartAction(Character, "M1Attack", endlag)
	StateManager.TimedState(Character, "Actions", "AerialAttack", endlag)

	-- Cleanup on animation stop
	SwingAnimation.Stopped:Once(function()
		if StateManager.StateCheck(Character, "Speeds", "M1Speed8") then
			StateManager.RemoveState(Character, "Speeds", "M1Speed8")
		end
		if Stats["Trail"] then
			Combat.Trail(Character, false)
		end
	end)

	-- Safety cleanup
	task.delay(endlag + 0.5, function()
		if StateManager.StateCheck(Character, "Speeds", "M1Speed8") then
			StateManager.RemoveState(Character, "Speeds", "M1Speed8")
		end
		if Stats["Trail"] then
			Combat.Trail(Character, false)
		end
	end)
end

-- Running attack removed (animation reused for KnockbackFollowUp)
Combat.RunningAttack = function(_Character)
	return
end

-- Knockback Follow-Up: attacker chases knocked-back target with bezier curve
Combat.KnockbackFollowUp = function(Character: Model)
	local Hitbox = Server.Modules.Hitbox
	local Entity = Server.Modules["Entities"].Get(Character)
	if not Entity then return end

	local Player: Player? = Entity.Player

	-- Validation: not stunned, can act, not on Critical cooldown (shared CD)
	if StateManager.StateCount(Character, "Stuns") then return end
	if not Server.Library.CanStartAction(Character, "KnockbackFollowUp") then return end
	if Server.Library.CheckCooldown(Character, "Critical") then return end

	-- Find knockback target: look for models with matching attacker attributes AND KnockbackStun active
	local Target: Model? = nil
	local searchLocations = { workspace.World.Live }

	-- Also search NpcRegistryCamera for Chrono NPCs
	-- NPCs are nested inside type folders (e.g. NpcRegistryCamera > DEFAULT > [NPC models])
	local npcCamera = workspace:FindFirstChild("NpcRegistryCamera")
	if npcCamera then
		for _, child in ipairs(npcCamera:GetChildren()) do
			if child:IsA("Folder") then
				table.insert(searchLocations, child)
			elseif child:IsA("Model") then
				-- In case NPCs are direct children
				table.insert(searchLocations, npcCamera)
				break
			end
		end
	end

	for _, location in ipairs(searchLocations) do
		for _, model in ipairs(location:GetChildren()) do
			if model:IsA("Model") and model ~= Character then
				local attackerName = model:GetAttribute("KnockbackAttacker")
				if attackerName == Character.Name then
					local hasStun = StateManager.StateCheck(model, "Stuns", "KnockbackStun")
					if hasStun then
						Target = model
						break
					end
				end
			end
		end
		if Target then break end
	end

	if not Target then return end

	local targetRoot = Target:FindFirstChild("HumanoidRootPart")
	local attackerRoot = Character:FindFirstChild("HumanoidRootPart")
	if not targetRoot or not attackerRoot then return end

	-- Calculate distance and travel time
	local distance = (targetRoot.Position - attackerRoot.Position).Magnitude
	local travelTime = math.clamp(distance / 40, 0.3, 1.2)

	-- Set Critical cooldown (shared with M2)
	Server.Library.SetCooldown(Character, "Critical", 5)

	-- CANCEL SPRINT when following up (for players only)
	if Player then
		Server.Packets.CancelSprint.sendTo({}, Player)
	end

	Server.Library.StopAllAnims(Character)

	-- Start follow-up action
	Server.Library.StartAction(Character, "KnockbackFollowUp", travelTime + 0.3)
	StateManager.TimedState(Character, "Actions", "KnockbackFollowUp", travelTime + 0.3)

	local Weapon: string = Entity.Weapon
	local Stats: {} = WeaponStats[Weapon]

	-- Play Running Attack animation with speed adjusted to match travel time
	local animFolder = Server.Service.ReplicatedStorage.Assets.Animations.Weapons[Weapon]
	local runningAtkAnim = animFolder and animFolder:FindFirstChild("Running Attack")
	if not runningAtkAnim then return end

	local SwingAnimation = Character.Humanoid.Animator:LoadAnimation(runningAtkAnim)
	SwingAnimation:Play(0.1)
	SwingAnimation.Priority = Enum.AnimationPriority.Action2

	-- Adjust animation speed to match travel time (cap at 1.5x to avoid looking too fast)
	local animLength = SwingAnimation.Length
	local adjustedSpeed = 1
	if animLength > 0 then
		adjustedSpeed = math.min(animLength / travelTime, 1.5)
		SwingAnimation:AdjustSpeed(adjustedSpeed)
	end

	-- Replicate animation to clients for Chrono NPCs
	setNPCCombatAnim(Character, Weapon, "RunningAttack", "Running Attack", adjustedSpeed)

	-- Apply bezier velocity
	if Player then
		-- For Chrono NPCs, Target is in the server Camera and can't be sent as Instance ref.
		-- Send ChronoId so the client can resolve to its local clone.
		local targetChronoId = Target:GetAttribute("ChronoId")
		if targetChronoId then
			Server.Packets.Bvel.sendTo({
				Character = Character,
				Name = "KnockbackFollowUpBvel",
				ChronoId = targetChronoId,
				duration = travelTime,
			}, Player)
		else
			-- Non-Chrono target (player in workspace.World.Live) — safe to send Instance ref
			Server.Packets.Bvel.sendTo({
				Character = Character,
				Name = "KnockbackFollowUpBvel",
				Targ = Target,
				duration = travelTime,
			}, Player)
		end
	else
		-- NPC attacker: apply server-side bezier chase
		Server.Modules.ServerBvel.BezierChase(Character, Target, travelTime)
	end

	-- Cancel tracking
	local Cancel = false
	local stunDisconnect = StateManager.OnStunAdded(Character, function()
		if stunDisconnect then
			stunDisconnect()
			stunDisconnect = nil
		end
		SwingAnimation:Stop(0.2)
		Cancel = true
	end)

	-- Wait for travel time then do hitbox check
	task.wait(travelTime)

	if Cancel then return end

	-- Disconnect stun listener
	if stunDisconnect then
		stunDisconnect()
		stunDisconnect = nil
	end

	-- Stop knockback on the target: remove velocity and stun, then apply follow-up hit
	if Target and Target.Parent then
		-- Remove knockback velocity from target
		local tRoot = Target:FindFirstChild("HumanoidRootPart")
		if tRoot then
			for _, child in ipairs(tRoot:GetChildren()) do
				if child:IsA("LinearVelocity") or child:IsA("BodyVelocity") then
					child:Destroy()
				end
			end
			tRoot.AssemblyLinearVelocity = Vector3.zero
		end

		-- Stop knockback animation on target
		Server.Library.StopAllAnims(Target)

		-- Remove KnockbackStun so the follow-up stun can apply cleanly
		if StateManager.StateCheck(Target, "Stuns", "KnockbackStun") then
			StateManager.RemoveState(Target, "Stuns", "KnockbackStun")
		end

		-- Clear knockback tracking attributes
		Target:SetAttribute("KnockbackAttacker", nil)
		Target:SetAttribute("KnockbackTime", nil)
		Target:SetAttribute("KnockbackAttackerUserId", nil)
		Target:SetAttribute("KnockbackAttackerChronoId", nil)
	end

	-- Follow-up damage table: normal M1 hit with longer stun
	-- No LightKnockback — custom directional knockback applied below
	local followUpTable = {
		Damage = Stats["M1Table"].Damage,
		PostureDamage = Stats["M1Table"].PostureDamage,
		M1 = true,
		FX = Stats["M1Table"].FX,
		Stun = 1.2, -- Longer stun than normal M1
	}

	-- Attacker's forward direction for knockback (flattened to horizontal)
	local attackerLook = attackerRoot.CFrame.LookVector
	local knockbackDir = Vector3.new(attackerLook.X, 0, attackerLook.Z).Unit

	-- Helper: apply directional knockback and rotate target to face attacker
	local function applyFollowUpKnockback(hitTarget)
		local hitRoot = hitTarget:FindFirstChild("HumanoidRootPart")
		if not hitRoot then return end

		-- Rotate target to face the attacker
		local targetPos = hitRoot.Position
		local attackerPos = attackerRoot.Position
		local lookAtAttacker = CFrame.lookAt(
			targetPos,
			Vector3.new(attackerPos.X, targetPos.Y, attackerPos.Z)
		)
		hitRoot.CFrame = CFrame.new(targetPos) * lookAtAttacker.Rotation

		-- Knockback in attacker's facing direction
		local hitPlayer = game:GetService("Players"):GetPlayerFromCharacter(hitTarget)
		if hitPlayer then
			Server.Packets.BvelKnockback.sendTo({
				Character = hitTarget,
				Direction = knockbackDir,
				HorizontalPower = 30,
				UpwardPower = 0,
			}, hitPlayer)
		else
			-- NPC: apply server-side directional knockback
			for _, child in ipairs(hitRoot:GetChildren()) do
				if child:IsA("LinearVelocity") or child:IsA("BodyVelocity") then
					child:Destroy()
				end
			end

			local attachment = hitRoot:FindFirstChild("RootAttachment")
			if not attachment then return end

			local lv = Instance.new("LinearVelocity")
			lv.Name = "FollowUpKnockback"
			lv.MaxForce = 50000
			lv.VectorVelocity = knockbackDir * 30
			lv.Attachment0 = attachment
			lv.RelativeTo = Enum.ActuatorRelativeTo.World
			lv.Parent = hitRoot

			local TweenService = game:GetService("TweenService")
			TweenService:Create(lv, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				VectorVelocity = Vector3.new(0, 0, 0)
			}):Play()

			task.delay(0.15, function()
				if lv and lv.Parent then lv:Destroy() end
			end)
		end
	end

	-- Directly tag the known target (don't rely on spatial query — target may have drifted from knockback)
	if Target and Target.Parent then
		local targetHumanoid = Target:FindFirstChild("Humanoid")
		if targetHumanoid and targetHumanoid.Health > 0 then
			Server.Modules.Damage.Tag(Character, Target, followUpTable)
			applyFollowUpKnockback(Target)
		end
	end

	-- Also check for any other targets caught in the hitbox
	local hitboxSize = Stats["Hitboxes"][1]["HitboxSize"]
	local hitboxOffset = Stats["Hitboxes"][1]["HitboxOffset"]
	local HitTargets = Hitbox.SpatialQuery(Character, hitboxSize, Entity:GetCFrame() * hitboxOffset)

	for _, HitTarget: Model in pairs(HitTargets) do
		if HitTarget ~= Target then -- Don't double-hit the main target
			Server.Modules.Damage.Tag(Character, HitTarget, followUpTable)
			applyFollowUpKnockback(HitTarget)
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

    -- Replicate animation to clients for Chrono NPCs
    setNPCCombatAnim(Character, Weapon, "Parry", "Parry", 1)

    -- Add parry frames - increased from 0.3s to 0.5s to make parrying easier
    StateManager.TimedState(Character, "Frames", "Parry", 0.5)

   -- print(`[PARRY DEBUG] {Character.Name} - Parry frames active for 0.5s`)

    -- Add recovery endlag after parry window expires (prevents instant action after parry attempt)
    task.delay(0.5, function()
        if Character then
            StateManager.TimedState(Character, "Actions", "ParryRecovery", 0.15)

            -- Focus: punish whiffed parry (if parry frame expired without landing)
            if not Character:GetAttribute("ParryLanded") then
                FocusHandler.RemoveFocus(Character, FocusHandler.Amounts.WHIFF_PARRY, "whiff_parry")
            end
            Character:SetAttribute("ParryLanded", nil)
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

    -- Replicate animation to clients for Chrono NPCs
    setNPCCombatAnim(Character, Weapon, "Block", "Block", 1)
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
