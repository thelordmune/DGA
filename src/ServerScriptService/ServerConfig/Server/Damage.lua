local DamageService = {}
local Server = require(script.Parent)
DamageService.__index = DamageService
local Replicated = game:GetService("ReplicatedStorage")
local Visuals = require(Replicated.Modules.Visuals)
local Library = require(Replicated.Modules.Library)
local Utilities = require(Replicated.Modules.Utilities)
local Debris = Utilities.Debris
local Voxbreaker = require(Replicated.Modules.Voxel)
local RunService = game:GetService("RunService")
local VFXCleanup = require(Replicated.Modules.Utils.VFXCleanup)
local self = setmetatable({}, DamageService)
local world = require(Replicated.Modules.ECS.jecs_world)
local ref = require(Replicated.Modules.ECS.jecs_ref)
local RefManager = require(Replicated.Modules.ECS.jecs_ref_manager)
local comps = require(Replicated.Modules.ECS.jecs_components)
local tags = require(Replicated.Modules.ECS.jecs_tags)
local jecsRef = require(Replicated.Modules.ECS.jecs_ref)
local Global = require(Replicated.Modules.Shared.Global)
local LimbManager = require(Replicated.Modules.Utils.LimbManager)
local DeathSignals = require(Replicated.Modules.Signals.DeathSignals)
local StunSignals = require(Replicated.Modules.Signals.StunSignals)
local StunRegistry = require(Replicated.Modules.ECS.StunRegistry)
local ActionCancellation = require(Replicated.Modules.ECS.ActionCancellation)
local StateManager = require(Replicated.Modules.ECS.StateManager)
local Players = game:GetService("Players")

-- Helper to set combat animation attribute for Chrono NPC replication
-- Same as Combat.lua - replicates animations to client clones
local NPC_MODEL_CACHE = Replicated:FindFirstChild("NPC_MODEL_CACHE")

local function setNPCCombatAnim(character: Model, weapon: string, animType: string, animName: string, speed: number?)
	-- Only set attribute for NPCs (not players) that have a ChronoId
	if Players:GetPlayerFromCharacter(character) then
		return -- Skip players
	end

	local chronoId = character:GetAttribute("ChronoId")
	if not chronoId then
		return -- Not a Chrono NPC
	end

	local animSpeed = speed or 1
	local timestamp = os.clock()
	local animData = `{weapon}|{animType}|{animName}|{animSpeed}|{timestamp}`

	character:SetAttribute("NPCCombatAnim", animData)

	if not NPC_MODEL_CACHE then
		NPC_MODEL_CACHE = Replicated:FindFirstChild("NPC_MODEL_CACHE")
	end
	if NPC_MODEL_CACHE then
		local cacheModel = NPC_MODEL_CACHE:FindFirstChild(tostring(chronoId))
		if cacheModel then
			cacheModel:SetAttribute("NPCCombatAnim", animData)
		end
	end
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

-- D:\iv\src\ReplicatedStorage\Modules\ECS\jecs_world.luau

DamageService.Tag = function(Invoker: Model, Target: Model, Table: {})
	local Entity, TargetEntity = Server.Modules.Entities.Get(Invoker), Server.Modules.Entities.Get(Target)

	-- Handle destructible objects (they don't have entities)
	if not Entity then
		return -- Invoker must have an entity
	end

	-- Check if target is a destructible object
	if not TargetEntity and Target:IsA("BasePart") and Target:GetAttribute("Destroyable") == true then
		-- SAFETY CHECK: Only destroy if part is in Map or Transmutables folder
		-- This prevents character accessories (hair, hats, etc.) from being destroyed
		local isInMap = workspace:FindFirstChild("Map") and Target:IsDescendantOf(workspace.Map)
		local isInTransmutables = workspace:FindFirstChild("Transmutables") and Target:IsDescendantOf(workspace.Transmutables)

		if isInMap or isInTransmutables then
			-- Handle destructible object destruction
			DamageService.HandleDestructibleObject(Invoker, Target, Table)
			return
		else
			-- Part has Destroyable attribute but is not in Map/Transmutables
			-- This is likely a character accessory - do NOT destroy it
			warn("Attempted to destroy part with Destroyable attribute that is not in Map/Transmutables:", Target:GetFullName())
			return
		end
	end

	if not TargetEntity then
		return -- Non-destructible targets must have entities
	end

	local Player, TargetPlayer
	local InvokerWeapon, TargetWeapon
	local pData
	local tData

	if Entity.Player then
		Player = Entity.Player
		pData = Global.GetData(Player)
	end
	if TargetEntity.Player then
		TargetPlayer = TargetEntity.Player
		tData = Global.GetData(TargetPlayer)
	end

	if Player then
		InvokerWeapon = Player:GetAttribute("Weapon")
	else
		InvokerWeapon = Invoker:GetAttribute("Weapon")
	end

	if TargetPlayer then
		TargetWeapon = TargetPlayer:GetAttribute("Weapon")

		-- Only set InCombat ECS component for players (not NPCs)
		local tentity = ref.get("player", TargetPlayer)
		if tentity then -- Check if entity exists before using it
			local currentInCombat = world:get(tentity, comps.InCombat)
			-- Reset duration to 40 seconds every time player gets hit
			world:set(tentity, comps.InCombat, { value = true, duration = 40 })

			-- Only fire client event if this is the first time entering combat
			if not currentInCombat or not currentInCombat.value then
				Visuals.FireClient(TargetPlayer, {
					Module = "Base",
					Function = "InCombat",
					Arguments = { TargetPlayer, true },
				})
			end
		end
	else
		TargetWeapon = Target:GetAttribute("Weapon")
	end

	-- if TargetPlayer and not world:get then
	-- 	world:set
	-- 	-- -- ---- print("in combat for " .. Target.Name)
	-- 	Visuals.FireClient(TargetPlayer, {
	-- 		Module = "Base",
	-- 		Function = "InCombat",
	-- 		Arguments = { Target },
	-- 	})
	-- end

	local function CancelAllActions()
		-- COMPREHENSIVE ACTION CANCELLATION SYSTEM
		-- When hit, cancel ALL ongoing actions to prevent overlapping states
		-- Use ActionCancellation for centralized cleanup
		ActionCancellation.Cancel(Target, {
			stopAnimations = true,
			animationFadeTime = 0,  -- Stop immediately
			destroyVelocities = true,
			cleanupVFX = true,
		})

		-- Also cleanup via VFXCleanup for backwards compatibility
		VFXCleanup.CleanupCharacter(Target)
		VFXCleanup.DisableCharacterParticles(Target)

		-- Clear ALL action states (skills, M1s, M2s, etc.) using ECS StateManager
		local allActionStates = StateManager.GetAllStates(Target, "Actions")
		for _, stateName in ipairs(allActionStates) do
			StateManager.RemoveState(Target, "Actions", stateName)
		end

		-- Cancel dash if active (clear Dashing ECS component)
		if TargetEntity and TargetEntity.Player then
			local targetPlayer = TargetEntity.Player
			local playerEntity = ref.get("player", targetPlayer)
			if playerEntity and world:has(playerEntity, comps.Dashing) then
				world:remove(playerEntity, comps.Dashing)
			end
		end

		-- Clear speed modifiers from actions (keep only damage stun speed) using ECS StateManager
		local allSpeedStates = StateManager.GetAllStates(Target, "Speeds")
		for _, speedName in ipairs(allSpeedStates) do
			if speedName:match("M1Speed") or speedName:match("AlcSpeed") or
			   speedName:match("RunSpeed") or speedName:match("DashSpeed") then
				StateManager.RemoveState(Target, "Speeds", speedName)
			end
		end

		-- Release any active grabs (if target is grabbing someone)
		local targetEntity = RefManager.entity.find(Target)
		if targetEntity and world:has(targetEntity, comps.Grab) then
			world:remove(targetEntity, comps.Grab)
		end
	end

	local function DealStun()
		-- Check if target has CounterArmor (super armor from landing a counter hit)
		-- CounterArmor absorbs stun but NOT damage - target still takes damage
		if StateManager.StateCheck(Target, "IFrames", "CounterArmor") then
			-- Has counter armor - skip stun application but still allow damage
			-- Play armor absorb VFX
			Visuals.Ranged(Target.HumanoidRootPart.Position, 100, {
				Module = "Base",
				Function = "ArmorAbsorb",
				Arguments = { Target }
			})
			return
		end

		-- Check if target is victim of Strategist Combination - if so, skip all stun logic
		-- StrategistComboHit has priority 8, so regular stuns won't interrupt it
		if StateManager.StateCheck(Target, "Actions", "StrategistVictim") then
			-- Target is locked in Strategist Combination - don't apply any stun or animations
			return
		end

		-- Check priority - if target has higher priority stun, don't apply lower priority
		local incomingStunName = Table.M1 and "M1Stun" or "DamageStun"

		-- Check if we can apply this stun (priority check)
		if not Library.CanApplyStun(Target, incomingStunName) then
			-- Target has higher priority stun active, skip
			return
		end

		-- Check for hyperarmor moves (Pincer Impact, Needle Thrust, Tapdance)
		local allTargetActions = StateManager.GetAllStates(Target, "Actions")
		if #allTargetActions > 0 then
			local currentAction = nil

			-- Find the current action (GetAllStates returns an array, not a dictionary)
			for _, stateName in ipairs(allTargetActions) do
				if stateName == "Pincer Impact" or stateName == "Needle Thrust" or stateName == "Tapdance" then
					currentAction = stateName
					break
				end
			end

			if currentAction then
				-- Hyperarmor move is active - track damage instead of cancelling
				-- Accumulate damage
				local currentDamage = Target:GetAttribute("HyperarmorDamage") or 0
				local newDamage = currentDamage + (Table.Damage or 0)
				Target:SetAttribute("HyperarmorDamage", newDamage)

				-- Check if damage exceeds threshold
				local accumulatedDamage = newDamage
				local threshold = 50 -- Damage threshold before hyperarmor breaks

				-- Update hyperarmor visual indicator (white → red based on damage)
				local damagePercent = math.clamp(accumulatedDamage / threshold, 0, 1)
				Visuals.Ranged(Target.HumanoidRootPart.Position, 300, {
					Module = "Misc",
					Function = "UpdateHyperarmor",
					Arguments = { Target, damagePercent }
				})

				if accumulatedDamage >= threshold then
					-- Break hyperarmor - cancel the move
					StateManager.RemoveState(Target, "Actions", currentAction)
					Library.StopAllAnims(Target)
					Target:SetAttribute("HyperarmorDamage", nil)
					Target:SetAttribute("HyperarmorMove", nil)

					-- Remove hyperarmor visual
					Visuals.Ranged(Target.HumanoidRootPart.Position, 300, {
						Module = "Misc",
						Function = "RemoveHyperarmor",
						Arguments = { Target }
					})

					-- Cancel all actions before applying stun
					CancelAllActions()

					-- Apply stun using new priority system
					if not Table.NoStunAnim then
						local hitAnims = Replicated.Assets.Animations.Hit:GetChildren()
						local hitAnimIndex = Random.new():NextInteger(1, #hitAnims)
						local hitAnim = hitAnims[hitAnimIndex]
						Library.PlayAnimation(Target, hitAnim)

						-- Replicate hit stun animation to clients for Chrono NPCs
						setNPCCombatAnim(Target, "Hit", "Stun", hitAnim.Name, 1)
					end

					local stunDuration = Table.Stun
					Library.ApplyStun(Target, "DamageStun", stunDuration, Invoker)
				else
					-- Hyperarmor holds - NO stun animation, NO damage stun
					-- Hyperarmor prevents ALL interruption including visual stun animations
				end
				return
			end
		end

		-- ============================================
		-- COUNTER HIT DETECTION
		-- Counter hit triggers when:
		-- 1. Target was performing an attack (mid-attack counter)
		-- 2. Invoker has PerfectDodgeWindow AND target is in any action state (dodge counter)
		-- Counter hits grant 50% longer stun duration + armor for follow-up
		-- ============================================
		local isCounterHit = false

		-- Check 1: Target is actively attacking (existing logic)
		local targetActionStates = StateManager.GetAllStates(Target, "Actions")
		if #targetActionStates > 0 then
			-- Check if target was attacking (M1, M2, or skill)
			-- Note: targetActionStates is an array, use ipairs not pairs
			for _, stateName in ipairs(targetActionStates) do
				-- Check for M1 combo states (M11, M12, M13, M14, M15)
				if stateName:match("^M1%d$") then
					isCounterHit = true
					break
				end
				-- Check for M2 state
				if stateName == "M2" then
					isCounterHit = true
					break
				end
				-- Check for common skill patterns (skills often have spaces or specific names)
				-- Exclude defensive actions like Blocking, Parry, etc.
				if stateName ~= "Blocking" and stateName ~= "Running" and stateName ~= "Equipped"
				   and stateName ~= "BlockBreak" and stateName ~= "PostureBreak" and stateName ~= "Dashing"
				   and stateName ~= "DodgeRecovery" then
					-- Likely a skill - check if it's an attack skill
					local actionPriority = Library.GetActionPriority and Library.GetActionPriority(stateName)
					if actionPriority and actionPriority >= 2 then
						isCounterHit = true
						break
					end
				end
			end
		end

		-- Check 2: Perfect Dodge Counter - Invoker dodged and target is in any action/recovery
		if not isCounterHit and Invoker then
			local hasPerfectDodge = StateManager.StateCheck(Invoker, "Frames", "PerfectDodgeWindow")

			if hasPerfectDodge and #targetActionStates > 0 then
				-- Check if target is in any action state (including recovery/endlag)
				for _, stateName in ipairs(targetActionStates) do
					-- Any attack-related state counts (M1, M2, skills, recovery states)
					if stateName:match("^M1%d$") or stateName == "M2" or
					   stateName:match("Recovery$") or stateName == "DodgeRecovery" then
						isCounterHit = true
						-- Clear the window after use (one counter per dodge)
						StateManager.RemoveState(Invoker, "Frames", "PerfectDodgeWindow")
						break
					end
				end
			end
		end

		-- CANCEL ALL ACTIONS WHEN HIT (no hyperarmor)
		CancelAllActions()

		-- Normal stun (no hyperarmor) - use new priority system
		if not Table.NoStunAnim then
			local hitAnims = Replicated.Assets.Animations.Hit:GetChildren()
			local hitAnimIndex = Random.new():NextInteger(1, #hitAnims)
			local hitAnim = hitAnims[hitAnimIndex]
			Library.PlayAnimation(Target, hitAnim)

			-- Replicate hit stun animation to clients for Chrono NPCs
			setNPCCombatAnim(Target, "Hit", "Stun", hitAnim.Name, 1)
		end

		-- NPCs and players get the same stun duration now
		local stunDuration = Table.Stun

		-- Apply stun - use CounterHitStun for counter hits, otherwise normal stun
		if isCounterHit and not Table.M1 then
			-- Counter hit: 50% longer stun, higher priority
			Library.ApplyStun(Target, "CounterHitStun", stunDuration, Invoker)

			-- Grant CounterArmor to the invoker (prevents being interrupted during follow-up)
			-- This gives brief super armor to complete the counter punish
			if Invoker then
				StateManager.TimedState(Invoker, "IFrames", "CounterArmor", 0.3)
			end

			-- Fire counter hit signal for VFX
			StunSignals.OnCounterHit:fire(Target, Invoker)

			-- Counter hit visual effect
			Visuals.Ranged(Target.HumanoidRootPart.Position, 300, {
				Module = "Base",
				Function = "CounterHit",
				Arguments = { Target, Invoker }
			})

			-- Apply bonus posture damage on counter hit
			local targetEntity = nil
			if TargetPlayer then
				targetEntity = ref.get("player", TargetPlayer)
			else
				targetEntity = RefManager.entity.find(Target)
			end

			if targetEntity then
				local postureBar = world:get(targetEntity, comps.PostureBar)
				if postureBar then
					local bonusPostureDamage = 15 -- Counter hit bonus
					postureBar.current = math.min(postureBar.current + bonusPostureDamage, postureBar.max)
					postureBar.lastDamageTime = os.clock()
					world:set(targetEntity, comps.PostureBar, postureBar)

					-- Fire posture changed signal
					StunSignals.OnPostureChanged:fire(Target, postureBar.current, postureBar.max, bonusPostureDamage)

					-- Send posture update to client for UI
					if TargetPlayer then
						Server.Packets.PostureSync.sendTo({
							Current = math.floor(postureBar.current),
							Max = math.floor(postureBar.max),
						}, TargetPlayer)
					end
				end
			end
		else
			-- Normal stun
			Library.ApplyStun(Target, "DamageStun", stunDuration, Invoker)
		end

		-- M1 True Stun System: Apply M1Stun state that prevents parrying
		-- Only allow parrying on 3rd M1 hit
		if Table.M1 then
			-- Get the invoker's combo count to determine which M1 hit this is
			local InvokerEntity = Server.Modules["Entities"].Get(Invoker)
			local comboCount = InvokerEntity and InvokerEntity.Combo or 1

			-- Apply M1Stun state for all M1 hits except the 3rd
			if comboCount ~= 3 then
				Library.ApplyStun(Target, "M1Stun", stunDuration, Invoker)
			end
		end
	end

	local function Parried()
		---- print(`[PARRY DEBUG] ⚔️ PARRY EXECUTED - Invoker: {Invoker.Name}, Target (Parrier): {Target.Name}`)

		-- Check if invoker is in a multi-part skill (check Actions for skill states)
		local isInMultiPartSkill = false
		local allInvokerActions = StateManager.GetAllStates(Invoker, "Actions")
		if #allInvokerActions > 0 then
			for _, stateName in ipairs(allInvokerActions) do
				-- Check for M1 combo states (M11-M15) or known multi-part skills
				if stateName:match("^M1%d$") or stateName == "Pincer Impact" or
				   stateName == "PincerImpact" or stateName == "Triple Kick" or
				   stateName == "Strategist Combination" or stateName == "Dempsey Roll" or
				   stateName == "Needle Thrust" or stateName == "Rapid Thrust" then
					isInMultiPartSkill = true
					break
				end
			end
		end

		-- For multi-part skills: Only stop the CURRENT animation, not future scheduled parts
		-- The skill's task.delay callbacks will continue after parry stun ends
		if isInMultiPartSkill then
			-- Stop current animation but don't cancel the entire skill
			-- The ParryStun will prevent further actions until it expires
			local humanoid = Invoker:FindFirstChild("Humanoid")
			if humanoid then
				local animator = humanoid:FindFirstChild("Animator")
				if animator then
					-- Stop all currently playing animations on the invoker
					for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
						track:Stop(0.1)
					end
				end
			end
		else
			-- For single-hit attacks: Full cancellation as before
			Library.StopAllAnims(Invoker)
		end

		-- Always stop target animations for clean parry reaction
		Library.StopAllAnims(Target)

		-- ParryStun has priority 5, will override lower priority stuns
		Library.ApplyStun(Invoker, "ParryStun", 1.0, Target)

		---- print(`[PARRY DEBUG] - Applied ParryStun to {Invoker.Name} for 1.0s, isMultiPart: {isInMultiPartSkill}`)

		-- Add knockback state and iframes for both characters using priority system
		-- ParryKnockback has priority 4 with built-in iframes
		-- Invoker (attacker who got parried) gets longer knockback, Target (parrier) gets shorter
		Library.ApplyStun(Invoker, "ParryKnockback", 0.4, Target)
		Library.ApplyStun(Target, "ParryKnockback", 0.15, Invoker)

		-- Cancel run animation for both characters if they're running
		-- Try to stop run animation (works for both players and NPCs)
		local runAnimations = Replicated.Assets.Animations:FindFirstChild("Run")
		if runAnimations then
			for _, anim in runAnimations:GetChildren() do
				Library.StopAnimation(Invoker, anim, 0)
				Library.StopAnimation(Target, anim, 0)
			end
		end

		-- Force walk speed for both characters during knockback (default walkspeed is 16)
		if Invoker:FindFirstChild("Humanoid") then
			Invoker.Humanoid.WalkSpeed = 16
		end
		if Target:FindFirstChild("Humanoid") then
			Target.Humanoid.WalkSpeed = 16
		end

		-- Execute parry callbacks for passives
		if not Table.NoParryAnimation then
			for _, v in script.Parent.Callbacks.Parry:GetChildren() do
				if v:IsA("ModuleScript") and tData and table.find(tData.Passives, v.Name) then
					-- -- ---- print("found passive for" .. v.Name)
					local func = require(v)
					func(world, Player, TargetPlayer, Table)
				end
			end
		end

		-- Always execute core parry effects (VFX, knockback, animations, sounds)
		Library.ResetCooldown(Target, "Parry")
		Library.PlaySound(
			Target,
			Replicated.Assets.SFX.Parries:GetChildren()[Random.new():NextInteger(
				1,
				#Replicated.Assets.SFX.Parries:GetChildren()
			)]
		)

		Invoker.Posture.Value += Table.Damage and Table.Damage / 5 or 1
		Target.Posture.Value -= Table.Damage and Table.Damage / 4 or 1

		local Distance = (Target.HumanoidRootPart.Position - Invoker.HumanoidRootPart.Position).Magnitude

		local ParriedAnims = Replicated.Assets.Animations:FindFirstChild("Parried"):GetChildren()

		local ParriedAnimation =
			Library.PlayAnimation(Invoker, ParriedAnims[Random.new():NextInteger(1, #ParriedAnims)])

		ParriedAnimation.Priority = Enum.AnimationPriority.Action2

		local ParriedAnimation2 =
			Library.PlayAnimation(Target, ParriedAnims[Random.new():NextInteger(1, #ParriedAnims)])

		ParriedAnimation2.Priority = Enum.AnimationPriority.Action3

		Visuals.Ranged(
			Target.HumanoidRootPart.Position,
			300,
			{ Module = "Base", Function = "Parry", Arguments = { Target, Invoker, Distance } }
		)

		-- Apply knockback to both characters (nudge them backwards with snappy easing)
		local knockbackPower = 30 -- Moderate knockback for a "nudge" (increased from 25 for more impact)

		-- Knockback for invoker (person who got parried) - push them away from target
		local invokerDirection = (Invoker.HumanoidRootPart.Position - Target.HumanoidRootPart.Position).Unit
		Server.Modules.ServerBvel.ParryKnockback(Invoker, invokerDirection, knockbackPower)

		-- Knockback for target (person who parried) - push them away from invoker
		local targetDirection = (Target.HumanoidRootPart.Position - Invoker.HumanoidRootPart.Position).Unit
		Server.Modules.ServerBvel.ParryKnockback(Target, targetDirection, knockbackPower)

		-- Screen shake for the invoker (person who got parried)
		if Player then
			Server.Packets.Bvel.sendTo({ Character = Invoker, Name = "ParryShakeInvoker" }, Player)
		end

		-- Screen shake for the target (person who parried)
		if TargetPlayer then
			Server.Packets.Bvel.sendTo({ Character = Target, Name = "ParryShakeTarget" }, TargetPlayer)
		end

		if Table.M1 or Table.M2 then
			if Player then
				-- Optimized: Use BvelRemove packet (2 bytes vs ~20+ bytes)
				Server.Packets.BvelRemove.sendTo({ Character = Invoker, Effect = BvelRemoveEffect.All }, Player)
			end
		end
	end

	local function BlockBreak()
		-- CLEAR ALL ACTIONS IMMEDIATELY (not just blocking)
		-- Stop all blocking animations and states
		Server.Library.StopAllAnims(Target)

		-- Clear ALL action states (not just blocking)
		local allActions = StateManager.GetAllStates(Target, "Actions")
		for _, actionName in ipairs(allActions) do
			StateManager.RemoveState(Target, "Actions", actionName)
		end

		-- Clear blocking states (Frames, Speeds)
		StateManager.RemoveState(Target, "Frames", "Blocking")
		StateManager.RemoveState(Target, "Speeds", "BlockSpeed8")

		-- For NPCs: Clear the "Blocking" state (used by MainConfig.InitiateBlock)
		local isNPC = Target:GetAttribute("IsNPC")
		if isNPC then
			-- Remove "Blocking" state from NPC using ECS StateManager
			StateManager.RemoveState(Target, "Frames", "Blocking")
		end

		-- Clear BlockStates tracking for players (used by HandleBlockInput)
		local Combat = Server.Modules.Combat
		if Combat and Combat.ClearBlockState then
			Combat.ClearBlockState(Target)
		end

		-- Use ECS BlockBar component instead of Posture.Value
		local targetEntity = nil
		if TargetPlayer then
			targetEntity = ref.get("player", TargetPlayer)
		else
			-- For NPCs, use RefManager to find entity
			targetEntity = RefManager.entity.find(Target)
		end

		if targetEntity then
			-- Reset BlockBar to 0 and set BlockBroken to true
			world:set(targetEntity, comps.BlockBar, {Value = 0, MaxValue = 100})
			world:add(targetEntity, comps.BlockBroken)

			-- Also reset PostureBar to 0 immediately (prevents repeated breaks)
			local postureBar = world:get(targetEntity, comps.PostureBar)
			if postureBar then
				postureBar.current = 0
				postureBar.lastDamageTime = os.clock()
				world:set(targetEntity, comps.PostureBar, postureBar)
			end
			-- Remove PostureBroken tag if present
			if world:has(targetEntity, tags.PostureBroken) then
				world:remove(targetEntity, tags.PostureBroken)
			end

			-- Schedule BlockBroken reset after 3 seconds (when stun ends)
			task.delay(3, function()
				if world:contains(targetEntity) then
					world:remove(targetEntity, comps.BlockBroken)
					-- Fire posture reset signal for UI update
					StunSignals.OnPostureReset:fire(Target)
				end
			end)
		end

		-- Also update old Posture.Value for backwards compatibility
		if Target:FindFirstChild("Posture") then
			Target.Posture.Value = 0
		end

		local Animation = Library.PlayAnimation(
			Target,
			Replicated.Assets.Animations.Guardbreak:GetChildren()[Random.new():NextInteger(
				1,
				#Replicated.Assets.Animations.Guardbreak:GetChildren()
			)]
		)
		Animation.Priority = Enum.AnimationPriority.Action3

		-- Apply stun using priority system - BlockBreakStun has priority 6
		Library.ApplyStun(Target, "BlockBreakStun", 2, Invoker)
		StateManager.TimedState(Target, "Actions", "BlockBreak", 2)

		-- BlockBreakCooldown lasts same duration as stun (2 seconds)
		-- Blocking is allowed again once the stun ends
		StateManager.TimedState(Target, "Stuns", "BlockBreakCooldown", 2)

		-- Play sound effect
		local sound = Replicated.Assets.SFX.Extra.Guardbreak:Clone()
		sound.Parent = Target.HumanoidRootPart
		sound:Play()
		Debris:AddItem(sound, sound.TimeLength)

		-- Visual effects
		Visuals.Ranged(
			Target.HumanoidRootPart.Position,
			300,
			{ Module = "Base", Function = "Guardbreak", Arguments = { Target } }
		)
	end

	local function DealDamage()
		-- CRITICAL: Store the ORIGINAL base damage from Table.Damage
		-- DO NOT modify Table.Damage directly to prevent stacking across multiple hits
		local originalBaseDamage = Table.Damage
		local finalDamage = originalBaseDamage

		local kineticEnergy = Invoker:GetAttribute("KineticEnergy")
		local kineticExpiry = Invoker:GetAttribute("KineticExpiry")
		local bonusDamage = 0

		if kineticEnergy and kineticExpiry then
			if os.clock() < kineticExpiry then
				bonusDamage = kineticEnergy * 0.5
				finalDamage = finalDamage + bonusDamage
				if not Table.Stun then
					Table.Stun = 2
				end

				Invoker:SetAttribute("KineticEnergy", nil)
				Invoker:SetAttribute("KineticExpiry", nil)
			elseif os.clock() >= kineticExpiry then
				Invoker:SetAttribute("KineticEnergy", nil)
				Invoker:SetAttribute("KineticExpiry", nil)
			end
		else
		end

		if Table.M1 and not Table.SFX then
			Library.PlaySound(
				Target,
				Replicated.Assets.SFX.Hits.Blood:GetChildren()[Random.new():NextInteger(
					1,
					#Replicated.Assets.SFX.Hits.Blood:GetChildren()
				)]
			)
		elseif Table.SFX then
			Library.PlaySound(
				Target,
				Replicated.Assets.SFX.Hits[Table.SFX]:GetChildren()[Random.new():NextInteger(
					1,
					#Replicated.Assets.SFX.Hits[Table.SFX]:GetChildren()
				)]
			)
		end

		-- -- ---- print("Damage.Tag called - Target:", Target.Name, "IsNPC:", Target:GetAttribute("IsNPC"))

		-- Log the attack for aggression/death tracking
		local damageLog = Target:FindFirstChild("Damage_Log")
		if not damageLog then
			damageLog = Instance.new("Folder")
			damageLog.Name = "Damage_Log"
			damageLog.Parent = Target
		end

		-- Create attack record
		local attackRecord = Instance.new("ObjectValue")
		attackRecord.Name = "Attack_" .. os.clock()
		attackRecord.Value = Invoker
		attackRecord.Parent = damageLog

		-- Clean up old attack records (keep only last 5)
		local records = damageLog:GetChildren()
		if #records > 5 then
			for i = 1, #records - 5 do
				records[i]:Destroy()
			end
		end

		-- Note: NPC aggression is now handled through behavior trees using the Damage_Log above

		-- Apply the FINAL calculated damage (not Table.Damage which is the original base)
		-- DEATH THRESHOLD: Clamp health at 1 HP instead of 0 to prevent Roblox's death system from interfering
		local totalDamage = pData and (finalDamage + pData.Stats.Damage) or finalDamage
		local newHealth = Target.Humanoid.Health - totalDamage

		-- Check if this damage would kill the target (bring to 1 or below)
		if newHealth <= 1 then
			-- Skip if already dead
			if Target:GetAttribute("IsDead") then
				return
			end

			-- Set health to exactly 1 (death threshold)
			Target.Humanoid.Health = 1

			-- Mark as dead via attribute so other systems can detect it
			Target:SetAttribute("IsDead", true)
			Target:SetAttribute("DeathTime", os.clock())

			-- ADD DEAD TAG VIA ECS
			local player = game.Players:GetPlayerFromCharacter(Target)
			local entity = player and jecsRef.get("player", player) or jecsRef.get("npc", Target)

			if entity and not world:has(entity, tags.Dead) then
				world:add(entity, tags.Dead)
				world:set(entity, comps.DeathInfo, {
					killer = Data and Data.Parent or nil,
					damageType = Type,
					timestamp = os.clock()
				})
			end

			-- Fire death signal for backward compatibility during transition
			DeathSignals.OnDeath:fire(Target)
		else
			Target.Humanoid.Health = newHealth
		end
	end

	local function Status()
		local proc_chance = Table.Status.ProcChance
		local procdmg = Table.Status.ProcDmg
		local proctick = Table.Status.Tick
		local duration = Table.Status.Duration

		local burningentities = {}

		math.randomseed(os.clock())

		local randomnumber = math.random()

		local function applyStatus()
			if burningentities[Target] then
				return
			end
			Visuals.Ranged(Target.HumanoidRootPart.Position, 300, {
				Module = "Misc",
				Function = "EnableStatus",
				Arguments = { Target, Table.Status.Name, Table.Status.Duration },
			})
			burningentities[Target] = {
				dura = duration,
				connection = nil,
			}

			burningentities[Target].connection = game:GetService("RunService").PostSimulation:Connect(function(dt)
				local data = burningentities[Target]
				if not data then
					return
				end

				data.dura = data.dura - dt

				if data.dura % proctick < dt then
					-- DEATH THRESHOLD: Clamp health at 1 HP instead of 0
					local newHealth = Target.Humanoid.Health - procdmg
					if newHealth <= 1 then
						-- Skip if already dead
						if Target:GetAttribute("IsDead") then
							return
						end
						-- Set health to exactly 1 (death threshold)
						Target.Humanoid.Health = 1
						-- Mark as dead and fire death signal
						Target:SetAttribute("IsDead", true)
						Target:SetAttribute("DeathTime", os.clock())

						-- ADD DEAD TAG VIA ECS
						local statusPlayer = game.Players:GetPlayerFromCharacter(Target)
						local statusEntity = statusPlayer and jecsRef.get("player", statusPlayer) or jecsRef.get("npc", Target)

						if statusEntity and not world:has(statusEntity, tags.Dead) then
							world:add(statusEntity, tags.Dead)
							world:set(statusEntity, comps.DeathInfo, {
								killer = nil,
								damageType = Table.Status.Name,
								timestamp = os.clock()
							})
						end

						DeathSignals.OnDeath:fire(Target)
					else
						Target.Humanoid.Health = newHealth
					end
				end
			end)
		end
		if randomnumber <= proc_chance then
			applyStatus()
		end
	end

	local function LightKnockback()
		if TargetPlayer then
			-- -- ---- print("light kb")
			Server.Packets.Bvel.sendTo({ Character = Target, Name = "BaseBvel" }, TargetPlayer)
		else
		end
	end

	local function handleWallbang()
		-- NEW WALLBANG SYSTEM: Stick player to wall, play wallbang animation, allow wall break on next hit
		local raycastParams = RaycastParams.new()
		raycastParams.FilterType = Enum.RaycastFilterType.Exclude
		raycastParams.FilterDescendantsInstances = { Target, workspace.World.Live }
		local eroot = Target.HumanoidRootPart
		local root = Invoker.HumanoidRootPart
		local direction = (eroot.Position - root.Position).Unit
		local connection
		local wallbangTriggered = false
		local triggerDistance = 5

		connection = RunService.Heartbeat:Connect(function(dt)
			if not Target.Parent then
				connection:Disconnect()
				return
			end

			-- Only check for wall if not already wallbanged
			if wallbangTriggered then
				return
			end

			local result =
				workspace:Raycast(Target.HumanoidRootPart.Position, direction * triggerDistance, raycastParams)

			if result and result.Instance then
				local part = result.Instance
				if part.Parent == workspace.Transmutables then
					wallbangTriggered = true

					-- Play wallbang sound
					local sound = Replicated.Assets.SFX.Hits.Wallbang:Clone()
					sound.Parent = Target.HumanoidRootPart
					sound:Play()
					Debris:AddItem(sound, sound.TimeLength)

					-- Increase damage
					Table.Damage = Table.Damage * 1.2
					local wallPosition = result.Position

					-- Visual effect
					Visuals.Ranged(
						Target.HumanoidRootPart.Position,
						300,
						{ Module = "Base", Function = "Wallbang", Arguments = { wallPosition } }
					)

					-- STOP KNOCKBACK ANIMATION AND PLAY WALLBANG ANIMATION
					Library.StopAllAnims(Target)
					local WallbangAnim = Library.PlayAnimation(Target, Replicated.Assets.Animations.Misc.Wallbang)
					WallbangAnim.Priority = Enum.AnimationPriority.Action4

					-- STICK PLAYER TO WALL FOR 1.5 SECONDS
					-- Remove all existing velocities
					for _, child in ipairs(eroot:GetChildren()) do
						if child:IsA("LinearVelocity") or child:IsA("BodyVelocity") or child:IsA("BodyPosition") or child:IsA("BodyGyro") then
							child:Destroy()
						end
					end

					-- Create BodyPosition to stick to wall
					local attachment = eroot:FindFirstChild("WallbangAttachment")
					if not attachment then
						attachment = Instance.new("Attachment")
						attachment.Name = "WallbangAttachment"
						attachment.Parent = eroot
					end

					-- Position slightly away from wall
					local stickPosition = wallPosition - (direction * 2)

					local bodyPos = Instance.new("BodyPosition")
					bodyPos.Name = "WallbangStick"
					bodyPos.Position = stickPosition
					bodyPos.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
					bodyPos.P = 10000
					bodyPos.D = 500
					bodyPos.Parent = eroot

					-- Apply wallbang stun using priority system - WallbangStun has priority 5 with iframes and lockRotation
					Library.ApplyStun(Target, "WallbangStun", 1.5, Invoker)

					-- Mark that this character is wallbanged (for wall break detection)
					Target:SetAttribute("Wallbanged", true)
					Target:SetAttribute("WallbangWall", part:GetFullName())

					-- Clean up after 1.5 seconds
					task.delay(1.5, function()
						if bodyPos and bodyPos.Parent then
							bodyPos:Destroy()
						end
						if Target then
							Target:SetAttribute("Wallbanged", false)
							Target:SetAttribute("WallbangWall", nil)
						end
					end)

					-- Disconnect the connection since wallbang is triggered
					connection:Disconnect()
				end
			end
		end)

		Debris:AddItem(connection, 0.65) -- Match knockback duration
	end

	local function Knockback()
		if Target then
			-- CHECK IF TARGET IS ALREADY WALLBANGED - IF SO, BREAK THE WALL
			if Target:GetAttribute("Wallbanged") then
				local wallPath = Target:GetAttribute("WallbangWall")
				if wallPath then
					local wall = game
					for _, name in ipairs(string.split(wallPath, ".")) do
						wall = wall:FindFirstChild(name)
						if not wall then break end
					end

					if wall and wall:IsA("BasePart") then
						-- BREAK THE WALL
						local sound = Replicated.Assets.SFX.Hits.Wallbang:Clone()
						sound.Parent = Target.HumanoidRootPart
						sound:Play()
						Debris:AddItem(sound, sound.TimeLength)

						-- Visual effect at wall position
						Visuals.Ranged(
							wall.Position,
							300,
							{ Module = "Base", Function = "Wallbang", Arguments = { wall.Position } }
						)

						-- Voxelize the wall (break it into pieces)
						local Voxbreaker = require(Replicated.Modules.Voxel)
						local parts = Voxbreaker:VoxelizePart(wall, 10, 15)
						for _, v in ipairs(parts) do
							if v:IsA("BasePart") then
								v.Anchored = false
								v.CanCollide = true

								local debrisDir = (v.Position - wall.Position).Unit
								local debrisVel = Instance.new("BodyVelocity")
								debrisVel.Velocity = (
									debrisDir
									+ Vector3.new(
										(math.random() - 0.5) * 0.3,
										math.random() * 1.5,
										(math.random() - 0.5) * 10
									)
								)
									* 60
									* 0.3

								debrisVel.MaxForce = Vector3.new(math.huge, 0, math.huge)
								debrisVel.Parent = v
								Debris:AddItem(debrisVel, 0.5)
								Debris:AddItem(v, 8 + math.random() * 4)
							end
						end
					end
				end

				-- RAGDOLL THE TARGET WITH BACKWARDS AND UPWARDS VELOCITY
				Library.StopAllAnims(Target)

				-- Remove wallbang stick
				local eroot = Target.HumanoidRootPart
				for _, child in ipairs(eroot:GetChildren()) do
					if child.Name == "WallbangStick" then
						child:Destroy()
					end
				end

				-- Clear wallbang attributes
				Target:SetAttribute("Wallbanged", false)
				Target:SetAttribute("WallbangWall", nil)

				-- Apply ragdoll
				local Ragdoll = require(Replicated.Modules.Utils.Ragdoll)
				Ragdoll.Ragdoll(Target, 2)

				-- Apply backwards and upwards velocity
				local direction = (eroot.Position - Invoker.HumanoidRootPart.Position).Unit
				local horizontalPower = 40
				local upwardPower = 30

				local velocity = Vector3.new(
					direction.X * horizontalPower,
					upwardPower,
					direction.Z * horizontalPower
				)

				-- Send velocity to client
				local TargetPlayer = game.Players:GetPlayerFromCharacter(Target)
				if TargetPlayer then
					Server.Packets.Bvel.sendTo({
						Character = Target,
						Name = "WallBreakVelocity",
						Targ = Target,
						Velocity = velocity
					}, TargetPlayer)
				else
					-- For NPCs: Create on server
					local attachment = eroot:FindFirstChild("WallBreakAttachment")
					if not attachment then
						attachment = Instance.new("Attachment")
						attachment.Name = "WallBreakAttachment"
						attachment.Parent = eroot
					end

					local lv = Instance.new("LinearVelocity")
					lv.Name = "WallBreakVelocity"
					lv.MaxForce = math.huge
					lv.VectorVelocity = velocity
					lv.Attachment0 = attachment
					lv.RelativeTo = Enum.ActuatorRelativeTo.World
					lv.Parent = eroot

					task.delay(0.8, function()
						if lv and lv.Parent then
							lv:Destroy()
						end
					end)
				end

				return -- Don't do normal knockback
			end

			-- NORMAL KNOCKBACK (not wallbanged)
			---- print("[Knockback] Applying knockback to", Target.Name, "from", Invoker.Name)
			Library.StopAllAnims(Target)
			local Animation = Library.PlayAnimation(Target, Replicated.Assets.Animations.Misc.KnockbackStun)
			Animation.Priority = Enum.AnimationPriority.Action3

			-- Apply knockback stun using priority system - KnockbackStun has priority 4 with lockRotation
			Library.ApplyStun(Target, "KnockbackStun", 0.65, Invoker)

			Server.Packets.Bvel.sendToAll({ Character = Invoker, Name = "KnockbackBvel", Targ = Target })
			---- print("[Knockback] Sent KnockbackBvel packet")
			handleWallbang()
		end
	end

	local function HandleBlock()
		local Blocks = Server.Service.ReplicatedStorage.Assets.Animations.Weapons[TargetWeapon]
			:FindFirstChild("Blocks")
			:GetChildren()

		local Animation = Library.PlayAnimation(Target, Blocks[Random.new():NextInteger(1, #Blocks)])
		Animation.Priority = Enum.AnimationPriority.Action3
		--CombatUtility.SwingCancel(Character,BlockJanitor,Animation)

		local BlockedSounds =
			Server.Service.ReplicatedStorage.Assets.SFX.Weapons[TargetWeapon]:FindFirstChild("Blocked"):GetChildren()

		Library.PlaySound(Target, BlockedSounds[Random.new():NextInteger(1, #BlockedSounds)])

		-- Get target entity for ECS components
		local targetEntity = nil
		if TargetPlayer then
			targetEntity = ref.get("player", TargetPlayer)
		else
			-- For NPCs, use RefManager to find entity
			targetEntity = RefManager.entity.find(Target)
		end

		-- ============================================
		-- POSTURE SYSTEM (Deepwoken-style)
		-- ============================================
		if targetEntity then
			-- Calculate posture damage based on attack type
			-- M1: 1.0x, M2: 1.5x, Skills: configurable via Table.PostureDamage
			local baseDamage = Table.Damage or 10
			local postureDamageMultiplier = 1.0
			if Table.M2 then
				postureDamageMultiplier = 1.5
			elseif Table.PostureDamage then
				postureDamageMultiplier = Table.PostureDamage
			end

			-- Blocking reduces incoming posture damage by 50%
			local postureDamage = (baseDamage * postureDamageMultiplier) * 0.5

			-- Get or initialize posture bar
			local postureBar = world:get(targetEntity, comps.PostureBar)
			if not postureBar then
				postureBar = {
					current = 0,
					max = 100,
					regenRate = 10,
					regenDelay = 2,
					lastDamageTime = 0,
				}
			end

			-- Apply posture damage
			postureBar.current = math.min(postureBar.current + postureDamage, postureBar.max)
			postureBar.lastDamageTime = os.clock()
			world:set(targetEntity, comps.PostureBar, postureBar)

			-- Fire posture changed signal for UI updates
			StunSignals.OnPostureChanged:fire(Target, postureBar.current, postureBar.max, postureDamage)

			-- Send posture update to client for UI
			if TargetPlayer then
				Server.Packets.PostureSync.sendTo({
					Current = math.floor(postureBar.current),
					Max = math.floor(postureBar.max),
				}, TargetPlayer)
			end

			-- Check for posture break
			if postureBar.current >= postureBar.max then
				-- Add PostureBroken tag
				world:add(targetEntity, tags.PostureBroken)

				-- Fire posture broken signal for VFX
				StunSignals.OnPostureBroken:fire(Target, Invoker)

				-- Trigger posture break stun (uses BlockBreak logic but with PostureBreakStun)
				-- CLEAR ALL ACTIONS IMMEDIATELY
				Server.Library.StopAllAnims(Target)

				local allActions = StateManager.GetAllStates(Target, "Actions")
				for _, actionName in ipairs(allActions) do
					StateManager.RemoveState(Target, "Actions", actionName)
				end

				StateManager.RemoveState(Target, "Frames", "Blocking")
				StateManager.RemoveState(Target, "Speeds", "BlockSpeed8")

				-- Play guard break animation
				local GuardbreakAnims = Replicated.Assets.Animations.Guardbreak:GetChildren()
				local gbAnimation = Library.PlayAnimation(
					Target,
					GuardbreakAnims[Random.new():NextInteger(1, #GuardbreakAnims)]
				)
				gbAnimation.Priority = Enum.AnimationPriority.Action3

				-- Apply PostureBreakStun (2.5s, priority 6) instead of regular BlockBreakStun
				Library.ApplyStun(Target, "PostureBreakStun", 2.5, Invoker)
				StateManager.TimedState(Target, "Actions", "PostureBreak", 2.5)

				-- Play sound effect
				local sound = Replicated.Assets.SFX.Extra.Guardbreak:Clone()
				sound.Parent = Target.HumanoidRootPart
				sound:Play()
				Debris:AddItem(sound, sound.TimeLength)

				-- Visual effects - PostureBreak VFX
				Visuals.Ranged(
					Target.HumanoidRootPart.Position,
					300,
					{ Module = "Base", Function = "PostureBreak", Arguments = { Target, Invoker } }
				)

				-- Reset posture after stun ends
				task.delay(2.5, function()
					if targetEntity and world:contains(targetEntity) then
						local pb = world:get(targetEntity, comps.PostureBar)
						if pb then
							pb.current = 0
							pb.lastDamageTime = os.clock()
							world:set(targetEntity, comps.PostureBar, pb)
						end
						if world:has(targetEntity, tags.PostureBroken) then
							world:remove(targetEntity, tags.PostureBroken)
						end
						StunSignals.OnPostureReset:fire(Target)
					end
				end)

				return
			end
		end

		-- ============================================
		-- LEGACY BLOCK BAR (for backwards compatibility)
		-- ============================================
		if targetEntity then
			local blockBar = world:get(targetEntity, comps.BlockBar)
			if blockBar then
				-- Increase block damage (reduced since posture handles main mechanic)
				blockBar.Value = blockBar.Value + (Table.Damage / 6) -- Halved from /3
				world:set(targetEntity, comps.BlockBar, blockBar)

				-- Set BBRegen to start regenerating after 2 seconds of not being hit
				world:set(targetEntity, comps.BBRegen, {value = true, duration = 2})

				-- Check if block is broken (legacy fallback)
				if blockBar.Value >= blockBar.MaxValue then
					BlockBreak()
					return
				end
			end
		end

		-- Also update old Posture.Value for backwards compatibility
		if Target:FindFirstChild("Posture") then
			Target.Posture.Value = Target.Posture.Value + (Table.Damage / 6) -- Halved

			if Target.Posture.Value >= Target.Posture.MaxValue then
				BlockBreak()
				return
			end
		end

		if TargetPlayer then
			Server.Packets.Bvel.sendTo({ Character = Target, Name = "BaseBvel" }, TargetPlayer)
		end

		Visuals.Ranged(
			Target.HumanoidRootPart.Position,
			300,
			{ Module = "Base", Function = "Block", Arguments = { Target } }
		)
	end

	-- Check for specific immunity states, but don't block all damage for NPCs with minor states
	if StateManager.StateCheck(Target, "IFrames", "Dodge") then
		StateManager.RemoveState(Target, "IFrames", "Dodge")
		-- -- ---- print("Dodge")

		Visuals.Ranged(
			Target.HumanoidRootPart.Position,
			300,
			{ Module = "Base", Function = "PerfectDodge", Arguments = { Target } }
		)
		return
	end

	-- Check immunity frames - different logic for NPCs vs Players
	local isNPC = Target:GetAttribute("IsNPC")
	if isNPC then
		-- For NPCs, only block damage if they have actual immunity states, not minor states like "RecentlyAttacked"
		-- MULTI-HIT FIX: Allow damage through if victim is in a multi-hit combo
		if StateManager.StateCheck(Target, "IFrames", "MultiHitVictim") then
			-- Allow damage through - victim is being hit by multi-hit combo
		elseif StateManager.StateCheck(Target, "IFrames", "IFrame") or StateManager.StateCheck(Target, "IFrames", "ForceField") then
			return
		end
		-- Allow damage through for states like "RecentlyAttacked", "Damaged", etc.
	else
		-- For players, check IFrames but allow damage through for combo victims
		if StateManager.StateCheck(Target, "IFrames", "StrategistComboVictim") or StateManager.StateCheck(Target, "IFrames", "MultiHitVictim") then
			-- Allow damage through - victim is locked in combo and should take damage
		elseif StateManager.StateCount(Target, "IFrames") then
			-- Block damage for all other IFrame states
			return
		end
	end

	--if Library.StateCheck(Target.Actions, "M2") and Library.StateCheck(Invoker.Actions,"M2") and not Library.CheckCooldown(Invoker,"Clash") and not Library.CheckCooldown(Target,"Clash") then
	--	Clash()
	--	return
	--end

	-- Parry detection
	local hasParryFrame = StateManager.StateCheck(Target, "Frames", "Parry")
	local isParryable = not Table.NoParry
	---- print(`[PARRY DEBUG] Damage check - Target: {Target.Name}, Invoker: {Invoker.Name}`)
	---- print(`[PARRY DEBUG] - Has Parry Frame: {hasParryFrame}, Is Parryable: {isParryable}`)

	if hasParryFrame then
		local targetFrames = Library.GetAllStatesFromCharacter(Target).Frames or {}
		---- print(`[PARRY DEBUG] - Target Frames: {table.concat(targetFrames, ", ")}`)
	end

	if hasParryFrame and isParryable then
		---- print(`[PARRY DEBUG] - ✅ PARRY DETECTED! Calling Parried()`)
		Parried()
		return
	end

	-- Check for recent block attempt (parry window) - even if not currently blocking
	local Combat = Server.Modules.Combat
	local hasRecentBlockAttempt = Combat.HasRecentBlockAttempt and Combat.HasRecentBlockAttempt(Target)

	-- If player tapped block recently (within 0.23s), treat as parry
	if hasRecentBlockAttempt and isParryable and not Table.NoBlock then
		-- Quick tap parry - player pressed block within parry window
		Parried()
		return
	end

	-- Check for blocking with parry window (first 0.23s of block counts as parry)
	-- IMPORTANT: Skip if already block broken to prevent multiple breaks
	if
		StateManager.StateCheck(Target, "Frames", "Blocking")
		and not Table.NoBlock -- Check if attack is unblockable
		and not StateManager.StateCheck(Target, "Frames", "Parry")
		and not StateManager.StateCheck(Target, "Stuns", "BlockBreakStun") -- Already broken
		and not StateManager.StateCheck(Target, "Stuns", "PostureBreakStun") -- Already broken
		and not StateManager.StateCheck(Target, "Stuns", "BlockBreakCooldown") -- In cooldown
		and not ((Target.HumanoidRootPart.CFrame:Inverse() * Invoker.HumanoidRootPart.CFrame).Z > 1)
	then
		-- Check if target is in parry window (first 0.23s of blocking)
		local BlockStates = Combat.GetBlockStates and Combat.GetBlockStates() or {}
		local blockState = BlockStates[Target]

		if blockState and blockState.ParryWindow and isParryable then
			-- Within first 0.23s of blocking - treat as parry
			Parried()
			return
		end

		-- FIXED: Check if this attack should guard break (only when target is blocking)
		if Table.BlockBreak == true or Table.GuardBreak == true then
			BlockBreak()
			return
		end

		HandleBlock(Target, Invoker)

		if StateManager.StateCheck(Target, "Frames", "Blocking") then
			return
		end
	end

	-- ALWAYS cancel all actions when taking damage (even without stun)
	-- This ensures M1s, skills, and other moves are interrupted on hit
	if not Table.Stun then
		-- If there's no stun, we still need to cancel actions
		CancelAllActions()
	end

	if Table.Stun then
		DealStun()

		-- Removed NPC IFrames after stun - was preventing NPCs from being stunned properly
		-- NPCs should be able to be stunned like players
	end

	if Table.FX then
		-- if Table.FX.Parent.Name == "Flame" then
		-- 	Visuals.Ranged(
		-- 		Target.HumanoidRootPart.Position,
		-- 		300,
		-- 		{ Module = "Misc", Function = "EnableEffect", Arguments = { Target, Table.FX } }
		-- 	)
		-- end
		Visuals.Ranged(
			Target.HumanoidRootPart.Position,
			300,
			{ Module = "Misc", Function = "DoEffect", Arguments = { Target, Table.FX } }
		)
	end

	if Table.Knockback then
		---- print("[Damage] Table.Knockback is true, calling Knockback()")
		Knockback()
	end

	if Table.LightKnockback then
		---- print("[Damage] Table.LightKnockback is true, calling LightKnockback()")
		LightKnockback()
	end

	if Table.Damage then
		DealDamage()

		-- MULTI-HIT FIX: Removed NPC IFrame after damage to allow multi-hit combos
		-- NPCs no longer get brief immunity after taking damage - allows rapid consecutive hits
		-- Multi-hit moves will mark their victims with "MultiHitVictim" state instead

		-- JUNCTION SYSTEM: Roll for limb loss after damage
		if Table.Junction and Table.JunctionChance then
			-- Get target's current limb state
			local targetEntity = nil
			if TargetPlayer then
				targetEntity = ref.get("player", TargetPlayer)
			else
				targetEntity = RefManager.entity.find(Target)
			end

			if targetEntity then
				local limbState = world:get(targetEntity, comps.LimbState)
				if not limbState then
					-- Initialize limb state if not present
					limbState = LimbManager.GetDefaultLimbState()
					world:set(targetEntity, comps.LimbState, limbState)
				end

				-- Calculate junction chance (increases at low HP)
				local humanoid = Target:FindFirstChild("Humanoid")
				local healthPercent = humanoid and (humanoid.Health / humanoid.MaxHealth) or 1
				local finalChance = LimbManager.calculateJunctionChance(Table.JunctionChance, healthPercent)

				-- Roll for limb loss
				if math.random() <= finalChance or Table.JunctionGuaranteed then
					local limbToSever = LimbManager.GetRandomLimb(Table.Junction, limbState)

					if limbToSever then
						-- Sever the limb
						local success = LimbManager.SeverLimb(Target, limbToSever)

						if success then
							-- Update ECS component
							if limbToSever == "LeftArm" then limbState.leftArm = false
							elseif limbToSever == "RightArm" then limbState.rightArm = false
							elseif limbToSever == "LeftLeg" then limbState.leftLeg = false
							elseif limbToSever == "RightLeg" then limbState.rightLeg = false
							end
							limbState.bleedingStacks = limbState.bleedingStacks + 1
							world:set(targetEntity, comps.LimbState, limbState)

							-- Fire visual effects for limb detachment
							Visuals.Ranged(Target.HumanoidRootPart.Position, 300, {
								Module = "LimbDetach",
								Function = "SeverLimb",
								Arguments = { Target, limbToSever, Invoker },
							})

							-- Apply bleeding status (permanent until healed)
							Visuals.Ranged(Target.HumanoidRootPart.Position, 300, {
								Module = "Misc",
								Function = "EnableStatus",
								Arguments = { Target, "Bleeding", -1 }, -- -1 = permanent
							})

							-- Save limb state to player data (persistence)
							if TargetPlayer then
								Global.SetData(TargetPlayer, function(data)
									data.LimbState = limbState
									return data
								end)
							end

							print(`[Junction] {Invoker.Name} severed {Target.Name}'s {limbToSever}!`)
						end
					end
				end
			end
		end
	end

	if Table.Status then
		Status()
	end

	if Table then
		-- -- ---- print(Table)
	end
end

-- Handle destruction of destructible objects (barrels, trees, etc.)
DamageService.HandleDestructibleObject = function(Invoker: Model, Target: BasePart, Table: {})
	-- -- ---- print("Destroying destructible object:", Target.Name)

	-- Get VoxBreaker module
	local VoxBreaker = require(Server.Service.ReplicatedStorage.Modules.Voxel)
	local TweenService = game:GetService("TweenService")
	local Debris = game:GetService("Debris")

	-- Determine if we should destroy the whole model or just the part
	local targetModel = Target.Parent
	local shouldDestroyWholeModel = false

	-- Check if the target is part of a destructible model (like a barrel group)
	if targetModel and targetModel:IsA("Model") and targetModel.Name:lower():find("barrel") or
	   targetModel and targetModel:IsA("Model") and targetModel.Name:lower():find("crate") or
	   targetModel and targetModel:IsA("Model") and targetModel.Name:lower():find("tree") then
		shouldDestroyWholeModel = true
		-- -- ---- print("Destroying entire model:", targetModel.Name)
	end

	-- Get all parts to destroy
	local partsToDestroy = {}
	local mainCFrame = Target.CFrame

	if shouldDestroyWholeModel then
		-- Collect all destructible parts from the model
		for _, part in pairs(targetModel:GetDescendants()) do
			if part:IsA("BasePart") and part:GetAttribute("Destroyable") == true then
				table.insert(partsToDestroy, part)
			end
		end
		-- Use the model's center as the main position
		if targetModel.PrimaryPart then
			mainCFrame = targetModel.PrimaryPart.CFrame
		elseif #partsToDestroy > 0 then
			mainCFrame = partsToDestroy[1].CFrame
		end
	else
		-- Just destroy the single part
		table.insert(partsToDestroy, Target)
	end

	-- -- ---- print("Found", #partsToDestroy, "parts to destroy")

	-- Store original properties for respawning
	local originalCFrame = mainCFrame
	local originalParent = shouldDestroyWholeModel and targetModel.Parent or Target.Parent
	-- Store original properties for respawning (either single part or whole model)
	local originalData = {}
	if shouldDestroyWholeModel then
		-- Store the entire model structure
		originalData.isModel = true
		originalData.modelName = targetModel.Name
		originalData.modelClone = targetModel:Clone()
	else
		-- Store single part by cloning it (preserves all properties including MeshId)
		originalData.isModel = false
		originalData.originalPart = Target:Clone()
	end

	-- Create debris from all parts
	local allShatteredParts = {}

	for _, part in pairs(partsToDestroy) do
		-- Calculate number of parts based on object size
		local volume = part.Size.X * part.Size.Y * part.Size.Z
		local desiredParts = math.clamp(math.floor(volume / 12) + 3, 4, 15) -- Fewer pieces per part for performance

		-- Create a clone of the part to work with
		local partClone = part:Clone()
		partClone.Parent = workspace
		partClone:SetAttribute("Destroyable", true) -- Ensure it has the attribute

		-- Use VoxBreaker to shatter the part into pieces
		local shatteredParts = VoxBreaker:VoxelizePart(partClone, desiredParts, -1) -- -1 means don't auto-destroy
		-- -- ---- print("VoxelizePart returned", #shatteredParts, "parts for", part.Name)

		-- If VoxelizePart didn't work, create manual debris
		if #shatteredParts == 0 or (#shatteredParts == 1 and shatteredParts[1] == partClone) then
			-- -- ---- print("VoxelizePart failed for", part.Name, ", creating manual debris")
			shatteredParts = {}

			-- Create manual debris pieces
			local pieceSize = math.min(part.Size.X, part.Size.Y, part.Size.Z) / 2
			local piecesPerAxis = math.ceil(math.max(part.Size.X, part.Size.Y, part.Size.Z) / pieceSize)
			piecesPerAxis = math.min(piecesPerAxis, 3) -- Limit to 3x3x3 max

			for x = 1, piecesPerAxis do
				for y = 1, piecesPerAxis do
					for z = 1, piecesPerAxis do
						if #shatteredParts < desiredParts then
							local piece = Instance.new("Part")
							piece.Size = Vector3.new(pieceSize, pieceSize, pieceSize)
							piece.Material = part.Material
							piece.Color = Color3.fromRGB(92, 51, 23) -- Dark brown color for debris
							piece.CFrame = part.CFrame * CFrame.new(
								(x - piecesPerAxis/2 - 0.5) * pieceSize,
								(y - piecesPerAxis/2 - 0.5) * pieceSize,
								(z - piecesPerAxis/2 - 0.5) * pieceSize
							)
							piece.Parent = workspace
							table.insert(shatteredParts, piece)
						end
					end
				end
			end

			-- Clean up the clone
			partClone:Destroy()
		end

		-- Add all pieces from this part to the total collection
		for _, piece in pairs(shatteredParts) do
			table.insert(allShatteredParts, piece)
		end

		-- Hide the original part immediately
		part.Transparency = 1
		part.CanCollide = false
		part.CanQuery = false
	end

	-- Apply physics and visual effects to each piece
	for _, piece in ipairs(allShatteredParts) do
		if piece:IsA("BasePart") then
			-- Make piece physical
			piece.Anchored = false
			piece.CanCollide = true
			piece.CanQuery = true
			piece.CanTouch = true

		-- Set dark brown color for debris
		piece.Color = Color3.fromRGB(92, 51, 23) -- Dark brown color

			-- Calculate debris direction from impact point
			local impactDirection = (piece.Position - originalCFrame.Position).Unit
			if impactDirection.Magnitude == 0 then
				impactDirection = Vector3.new(math.random(-1, 1), 1, math.random(-1, 1)).Unit
			end

			-- Add upward bias and random scatter (reduced)
			local scatterDirection = impactDirection + Vector3.new(
				(math.random() - 0.5) * 0.6, -- Reduced horizontal scatter
				math.random() * 0.4 + 0.3,   -- Reduced upward bias (0.3 to 0.7)
				(math.random() - 0.5) * 0.6  -- Reduced horizontal scatter
			)
			scatterDirection = scatterDirection.Unit

			-- Apply much lower velocity based on piece size
			local sizeMultiplier = math.max(0.3, 2 / math.max(piece.Size.X, piece.Size.Y, piece.Size.Z))
			local velocity = scatterDirection * (15 + math.random() * 10) * sizeMultiplier -- Heavily reduced from 50+30

			-- Create BodyVelocity for initial impulse (reduced force)
			local bodyVelocity = Instance.new("BodyVelocity")
			bodyVelocity.Velocity = velocity
			bodyVelocity.MaxForce = Vector3.new(2000, 2000, 2000) -- Further reduced from 3000 to prevent flinging
			bodyVelocity.Parent = piece

			-- Remove velocity after a short time to let gravity take over
			Debris:AddItem(bodyVelocity, 0.3 + math.random() * 0.2) -- Slightly shorter duration

			-- Add some angular velocity for realistic tumbling (reduced)
			local bodyAngularVelocity = Instance.new("BodyAngularVelocity")
			bodyAngularVelocity.AngularVelocity = Vector3.new(
				(math.random() - 0.5) * 8,  -- Reduced from 20
				(math.random() - 0.5) * 8,  -- Reduced from 20
				(math.random() - 0.5) * 8   -- Reduced from 20
			)
			bodyAngularVelocity.MaxTorque = Vector3.new(800, 800, 800) -- Reduced from 2000
			bodyAngularVelocity.Parent = piece
			Debris:AddItem(bodyAngularVelocity, 0.8 + math.random() * 0.4) -- Shorter duration

			-- Start fading the piece after 3 seconds
			task.delay(3 + math.random() * 2, function()
				if piece and piece.Parent then
					local fadeInfo = TweenInfo.new(
						4, -- 4 second fade
						Enum.EasingStyle.Quad,
						Enum.EasingDirection.InOut
					)
					local fadeTween = TweenService:Create(piece, fadeInfo, {
						Transparency = 1,
						CanCollide = false
					})
					fadeTween:Play()

					-- Destroy piece after fade completes
					fadeTween.Completed:Connect(function()
						if piece and piece.Parent then
							piece:Destroy()
						end
					end)
				end
			end)
		end
	end

	-- Schedule respawn after 30 seconds
	task.delay(30, function()
		if originalParent and originalParent.Parent then
			if originalData.isModel then
				-- Respawn the entire model
				local respawnedModel = originalData.modelClone:Clone()
				respawnedModel.Parent = originalParent

				-- Destroy the old model if it still exists
				if shouldDestroyWholeModel and targetModel and targetModel.Parent then
					targetModel:Destroy()
				end

				-- -- ---- print("Respawned destructible model:", respawnedModel.Name)
			else
				-- Respawn single part by cloning the stored original
				-- This preserves all properties including MeshId without permission issues
				local respawnedPart = originalData.originalPart:Clone()
				respawnedPart.CFrame = originalCFrame
				respawnedPart.Parent = originalParent

				-- Ensure it's set up as destructible
				respawnedPart:SetAttribute("Destroyable", true)
				respawnedPart:SetAttribute("OriginalTransparency", respawnedPart.Transparency)
				respawnedPart:SetAttribute("OriginalCanCollide", respawnedPart.CanCollide)
				respawnedPart:SetAttribute("OriginalCanQuery", respawnedPart.CanQuery)

				-- Destroy the old part
				if Target and Target.Parent then
					Target:Destroy()
				end

				-- -- ---- print("Respawned destructible part:", respawnedPart.Name)
			end
		end
	end)

	-- Play destruction sound effect
	if Table.SFX then
		Server.Library.PlaySound(
			Target,
			Server.Service.ReplicatedStorage.Assets.SFX.Hits[Table.SFX]:GetChildren()[math.random(1, #Server.Service.ReplicatedStorage.Assets.SFX.Hits[Table.SFX]:GetChildren())]
		)
	else
		-- Default destruction sound - use Wood sounds as fallback
		local hitSounds = Server.Service.ReplicatedStorage.Assets.SFX.Hits:FindFirstChild("Wood") or Server.Service.ReplicatedStorage.Assets.SFX.Hits.Blood
		Server.Library.PlaySound(
			Target,
			hitSounds:GetChildren()[math.random(1, #hitSounds:GetChildren())]
		)
	end

	local targetName = shouldDestroyWholeModel and targetModel.Name or Target.Name
	-- -- ---- print("Destructible object destroyed:", targetName, "- Created", #allShatteredParts, "total debris pieces")
	-- -- ---- print("Destroyed", #partsToDestroy, "parts from", targetName)
end

return DamageService
