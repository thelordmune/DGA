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
local self = setmetatable({}, DamageService)
local world = require(Replicated.Modules.ECS.jecs_world)
local ref = require(Replicated.Modules.ECS.jecs_ref)
local RefManager = require(Replicated.Modules.ECS.jecs_ref_manager)
local comps = require(Replicated.Modules.ECS.jecs_components)
local Global = require(Replicated.Modules.Shared.Global)
-- Adrenaline system (lazy load to avoid circular dependencies)
local AdrenalineSystem = nil
local function getAdrenalineSystem()
	if not AdrenalineSystem then
		local success, module = pcall(function()
			return require(Replicated.Modules.Systems.adrenaline)
		end)
		if success then
			AdrenalineSystem = module
		end
	end
	return AdrenalineSystem
end

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
	-- 	-- -- print("in combat for " .. Target.Name)
	-- 	Visuals.FireClient(TargetPlayer, {
	-- 		Module = "Base",
	-- 		Function = "InCombat",
	-- 		Arguments = { Target },
	-- 	})
	-- end

	local function CancelAllActions()
		-- COMPREHENSIVE ACTION CANCELLATION SYSTEM
		-- When hit, cancel ALL ongoing actions to prevent overlapping states

		print(`[HIT INTERRUPT] 🛑 {Target.Name} was hit - cancelling all actions`)

		-- 1. Stop all animations immediately
		Library.StopAllAnims(Target)

		-- 2. Clear ALL action states (skills, M1s, M2s, etc.)
		local actions = Target:FindFirstChild("Actions")
		if actions then
			local allStates = Library.GetAllStates(actions)
			for _, stateName in ipairs(allStates) do
				Library.RemoveState(actions, stateName)
				print(`[HIT INTERRUPT] - Removed action state: {stateName}`)
			end
		end

		-- 3. Cancel dash if active (clear Dashing ECS component)
		-- Only for players (NPCs don't have ECS Dashing component)
		if TargetEntity and TargetEntity.Player then
			local targetPlayer = TargetEntity.Player
			local playerEntity = ref.get("player", targetPlayer)
			if playerEntity and world:has(playerEntity, comps.Dashing) then
				local isDashing = world:get(playerEntity, comps.Dashing)
				if isDashing then
					world:set(playerEntity, comps.Dashing, false)
					print(`[HIT INTERRUPT] - Cancelled dash for {Target.Name}`)
				end
			end
		end

		-- 4. Remove ALL velocities and body movers (dash, skill velocities, etc.)
		local rootPart = Target:FindFirstChild("HumanoidRootPart")
		if rootPart then
			for _, child in ipairs(rootPart:GetChildren()) do
				if child:IsA("LinearVelocity") or child:IsA("BodyVelocity") or
				   child:IsA("BodyPosition") or child:IsA("BodyGyro") then
					child:Destroy()
					print(`[HIT INTERRUPT] - Removed {child.ClassName} from {Target.Name}`)
				end
			end
		end

		-- 5. Clear speed modifiers from actions (keep only damage stun speed)
		local speeds = Target:FindFirstChild("Speeds")
		if speeds then
			local allSpeeds = Library.GetAllStates(speeds)
			for _, speedName in ipairs(allSpeeds) do
				-- Remove action-related speed states (M1Speed, AlcSpeed, RunSpeed, etc.)
				if speedName:match("M1Speed") or speedName:match("AlcSpeed") or
				   speedName:match("RunSpeed") or speedName:match("DashSpeed") then
					Library.RemoveState(speeds, speedName)
					print(`[HIT INTERRUPT] - Removed speed state: {speedName}`)
				end
			end
		end

		print(`[HIT INTERRUPT] ✅ All actions cancelled for {Target.Name}`)
	end

	local function DealStun()
		-- Check if target is victim of Strategist Combination - if so, skip all stun logic
		local actions = Target:FindFirstChild("Actions")
		if actions and Library.StateCheck(actions, "StrategistVictim") then
			-- Target is locked in Strategist Combination - don't apply any stun or animations
			return
		end

		-- Check for hyperarmor moves (Pincer Impact, Needle Thrust)
		if actions then
			local currentAction = nil
			local allStates = Library.GetAllStates(actions)

			-- Find the current action
			for stateName, _ in pairs(allStates) do
				if stateName == "Pincer Impact" or stateName == "Needle Thrust" then
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
				local threshold = 15 -- Damage threshold before hyperarmor breaks

				-- Update hyperarmor visual indicator (white → red based on damage)
				local damagePercent = math.clamp(accumulatedDamage / threshold, 0, 1)
				Visuals.Ranged(Target.HumanoidRootPart.Position, 300, {
					Module = "Misc",
					Function = "UpdateHyperarmor",
					Arguments = { Target, damagePercent }
				})

				if accumulatedDamage >= threshold then
					-- Break hyperarmor - cancel the move
					-- -- print("Hyperarmor broken for", Target.Name, "- took", accumulatedDamage, "damage during", currentAction)
					Library.RemoveState(actions, currentAction)
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

					-- Apply stun normally
					if not Table.NoStunAnim then
						Library.PlayAnimation(
							Target,
							Replicated.Assets.Animations.Hit:GetChildren()[Random.new():NextInteger(
								1,
								#Replicated.Assets.Animations.Hit:GetChildren()
							)]
						)
					end

					local stunDuration = Table.Stun
					Library.TimedState(Target.Stuns, "DamageStun", stunDuration)
					Library.TimedState(Target.Speeds, "DamageSpeedSet4", stunDuration)
				else
					-- Hyperarmor holds - don't apply stun, just play hit animation
					-- -- print("Hyperarmor active for", Target.Name, "-", accumulatedDamage, "/", threshold, "damage taken during", currentAction)
					if not Table.NoStunAnim then
						Library.PlayAnimation(
							Target,
							Replicated.Assets.Animations.Hit:GetChildren()[Random.new():NextInteger(
								1,
								#Replicated.Assets.Animations.Hit:GetChildren()
							)]
						)
					end
					-- Don't apply DamageStun - hyperarmor prevents cancellation
				end
				return
			end
		end

		-- CANCEL ALL ACTIONS WHEN HIT (no hyperarmor)
		CancelAllActions()

		-- Normal stun (no hyperarmor)
		if not Table.NoStunAnim then
			Library.PlayAnimation(
				Target,
				Replicated.Assets.Animations.Hit:GetChildren()[Random.new():NextInteger(
					1,
					#Replicated.Assets.Animations.Hit:GetChildren()
				)]
			)
		end

		-- NPCs and players get the same stun duration now
		local stunDuration = Table.Stun

		Library.TimedState(Target.Stuns, "DamageStun", stunDuration)
		Library.TimedState(Target.Speeds, "DamageSpeedSet4", stunDuration)

		-- M1 True Stun System: Apply M1Stun state that prevents parrying
		-- Only allow parrying on 3rd M1 hit
		if Table.M1 then
			-- Get the invoker's combo count to determine which M1 hit this is
			local InvokerEntity = Server.Modules["Entities"].Get(Invoker)
			local comboCount = InvokerEntity and InvokerEntity.Combo or 1

			-- Apply M1Stun state for all M1 hits except the 3rd
			if comboCount ~= 3 then
				Library.TimedState(Target.Stuns, "M1Stun", stunDuration)
				print(`[M1 STUN] Applied M1Stun to {Target.Name} - Combo: {comboCount}, Duration: {stunDuration}s`)
			else
				print(`[M1 STUN] Skipped M1Stun for {Target.Name} - Combo 3 allows parrying`)
			end
		end
	end

	local function Parried()
		print(`[PARRY DEBUG] ⚔️ PARRY EXECUTED - Invoker: {Invoker.Name}, Target (Parrier): {Target.Name}`)

		-- Apply stun IMMEDIATELY when parry is detected
		Library.StopAllAnims(Invoker)
		Library.StopAllAnims(Target) -- Also stop target animations to ensure clean parry reaction
		Library.TimedState(Invoker.Speeds, "ParrySpeedSet4", 1.5)
		Library.TimedState(Invoker.Stuns, "ParryStun", 1.5)

		print(`[PARRY DEBUG] - Applied ParryStun to {Invoker.Name} for 1.5s`)

		-- Add knockback state and iframes for both characters
		local knockbackDuration = 0.4
		Library.TimedState(Invoker.Stuns, "ParryKnockback", knockbackDuration)
		Library.TimedState(Target.Stuns, "ParryKnockback", knockbackDuration)
		Library.TimedState(Invoker.IFrames, "ParryIFrame", knockbackDuration)
		Library.TimedState(Target.IFrames, "ParryIFrame", knockbackDuration)

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
					-- -- print("found passive for" .. v.Name)
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
				Server.Packets.Bvel.sendTo({ Character = Invoker, Name = "RemoveBvel" }, Player)
			end
		end
	end

	local function BlockBreak()
		-- CLEAR ALL ACTIONS IMMEDIATELY (not just blocking)
		-- Stop all blocking animations and states
		Server.Library.StopAllAnims(Target)

		-- Clear ALL action states (not just blocking)
		if Target:FindFirstChild("Actions") then
			local allActions = Server.Library.GetAllStates(Target.Actions)
			for _, actionName in ipairs(allActions) do
				Server.Library.RemoveState(Target.Actions, actionName)
			end
		end

		-- Clear blocking states (Frames, Speeds)
		if Target:FindFirstChild("Frames") then
			Server.Library.RemoveState(Target.Frames, "Blocking")
		end
		if Target:FindFirstChild("Speeds") then
			Server.Library.RemoveState(Target.Speeds, "BlockSpeed8")
		end

		-- For NPCs: Clear the state folder's "Blocking" state (used by MainConfig.InitiateBlock)
		local isNPC = Target:GetAttribute("IsNPC")
		if isNPC then
			local npcStateFolder = Target:FindFirstChild("State")
			if npcStateFolder and npcStateFolder:IsA("StringValue") then
				-- Remove "Blocking" state from NPC state folder
				Server.Library.RemoveState(npcStateFolder, "Blocking")
			end
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
			world:set(targetEntity, comps.BlockBroken, true)

			-- Schedule BlockBroken reset after 3 seconds
			task.delay(3, function()
				if world:contains(targetEntity) then
					world:set(targetEntity, comps.BlockBroken, false)
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

		-- Apply stun and other effects
		Server.Library.TimedState(Target.Stuns, "BlockBreakStun", 3)
		Server.Library.TimedState(Target.Actions, "BlockBreak", 3)
		Server.Library.TimedState(Target.Speeds, "BlockBreakSpeedSet3", 3)
		-- Stun in place - unable to do anything during guardbreak
		Server.Library.TimedState(Target.Stuns, "GuardbreakStun", 3)

		-- BlockBreakCooldown lasts same duration as stun (3 seconds)
		-- Blocking is allowed again once the stun ends
		Server.Library.TimedState(Target.Stuns, "BlockBreakCooldown", 3)

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

		-- Apply adrenaline damage buff to BASE damage only (before any other multipliers)
		local adrenalineBonusDamage = 0
		if Player then
			local invokerEntity = ref.get("player", Player)
			if invokerEntity then
				local adrenalineData = world:get(invokerEntity, comps.Adrenaline)
				if adrenalineData then
					-- Clamp adrenaline value to 0-100 range (safety check)
					local clampedAdrenaline = math.clamp(adrenalineData.value, 0, 100)

					-- Calculate damage bonus: 0% at 0 adrenaline, 50% at 100 adrenaline
					-- This is ADDITIVE bonus damage, not multiplicative
					local adrenalineBonus = (clampedAdrenaline / 100) * 0.5
					adrenalineBonusDamage = originalBaseDamage * adrenalineBonus
					finalDamage = finalDamage + adrenalineBonusDamage
					print(`[Damage] Adrenaline buff applied: {math.floor(clampedAdrenaline)} adrenaline = +{string.format("%.1f", adrenalineBonusDamage)} damage ({string.format("%.1f", originalBaseDamage)} -> {string.format("%.1f", finalDamage)})`)
				end
			end
		end

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

		-- Apply damage resistance for defender (based on ORIGINAL BASE damage, not modified damage)
		if TargetPlayer then
			local targetEntity = ref.get("player", TargetPlayer)
			if targetEntity then
				local adrenalineData = world:get(targetEntity, comps.Adrenaline)
				if adrenalineData then
					-- Clamp adrenaline value to 0-100 range (safety check)
					local clampedAdrenaline = math.clamp(adrenalineData.value, 0, 100)

					-- Calculate damage reduction: 0% at 0 adrenaline, 30% at 100 adrenaline
					-- This is based on ORIGINAL BASE damage, not current damage
					local damageReductionPercent = (clampedAdrenaline / 100) * 0.3
					local damageReduction = originalBaseDamage * damageReductionPercent
					local beforeResistance = finalDamage
					finalDamage = finalDamage - damageReduction
					print(`[Damage] Damage resistance applied: {math.floor(clampedAdrenaline)} adrenaline = -{string.format("%.1f", damageReduction)} damage ({string.format("%.1f", beforeResistance)} -> {string.format("%.1f", finalDamage)})`)
				end
			end
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

		-- -- print("Damage.Tag called - Target:", Target.Name, "IsNPC:", Target:GetAttribute("IsNPC"))

		if Target:GetAttribute("IsNPC") then
        -- Log the attack for NPC aggression system
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

        -- Set recently attacked state using the character's IFrames (which is a StringValue)
        -- local iFrames = Target:FindFirstChild("IFrames")
        -- if iFrames and iFrames:IsA("StringValue") then
        --     Library.TimedState(iFrames, "RecentlyAttacked", 2) -- Short window just for aggression trigger
        --     Library.TimedState(iFrames, "Damaged", 1) -- Very short immediate reaction
        --     -- -- print("Set RecentlyAttacked and Damaged states for NPC:", Target.Name)
        -- else
        --     -- -- print("Warning: Could not find IFrames StringValue for NPC:", Target.Name)
        -- end

        -- -- -- print("NPC", Target.Name, "was attacked by", Invoker.Name, "- logging for aggression system")

        -- Note: Original NPC damage handling removed as Server.Modules.NPC doesn't exist
        -- The aggression system will handle NPC behavior through the behavior trees
    end

		-- Apply the FINAL calculated damage (not Table.Damage which is the original base)
		if pData then
			Target.Humanoid.Health -= finalDamage + pData.Stats.Damage
			--[[-- -- print(
				"Total damage dealt:",
				finalDamage + pData.Stats.Damage,
				"(Base:",
				originalBaseDamage,
				"+ Player Stats:",
				pData.Stats.Damage,
				"+ Adrenaline:",
				adrenalineBonusDamage,
				"+ Kinetic:",
				bonusDamage,
				")"
			)]]
		else
			Target.Humanoid.Health -= finalDamage
			-- -- print("Total damage dealt:", finalDamage, "(Base:", originalBaseDamage, "+ Adrenaline:", adrenalineBonusDamage, "+ Kinetic:", bonusDamage, ")")
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

				if data.dura % proctick < dtx then
					Target.Humanoid.Health -= procdmg
				end
			end)
		end
		if randomnumber <= proc_chance then
			applyStatus()
		end
	end

	local function LightKnockback()
		if TargetPlayer then
			-- -- print("light kb")
			Server.Packets.Bvel.sendTo({ Character = Target, Name = "BaseBvel" }, TargetPlayer)
		else
		end
	end

	local function handleWallbang()
		-- -- print("handling wallbang")
		local raycastParams = RaycastParams.new()
		raycastParams.FilterType = Enum.RaycastFilterType.Exclude
		raycastParams.FilterDescendantsInstances = { Target, workspace.World.Live }
		local eroot = Target.HumanoidRootPart
		local root = Invoker.HumanoidRootPart
		local direction = (eroot.Position - root.Position).Unit
		local connection
		local cooldown = false
		local triggerDistance = 5

		connection = RunService.Heartbeat:Connect(function(dt)
			if not Target.Parent then
				-- -- print("table parent is nil")
				connection:Disconnect()
				return
			end

			local result =
				workspace:Raycast(Target.HumanoidRootPart.Position, direction * triggerDistance, raycastParams)

			if result and result.Instance and not cooldown then
				local part = result.Instance
				if part.Parent == workspace.Transmutables then
					local sound = Replicated.Assets.SFX.Hits.Wallbang:Clone()
					sound.Parent = Target.HumanoidRootPart
					sound:Play()
					Debris:AddItem(sound, sound.TimeLength)
					cooldown = true
					Table.Damage = Table.Damage * 1.2
					local Position = result.Position
					Visuals.Ranged(
						Target.HumanoidRootPart.Position,
						300,
						{ Module = "Base", Function = "Wallbang", Arguments = { Position } }
					)

					local parts = Voxbreaker:VoxelizePart(part, 10, 15)
					for _, v in ipairs(parts) do
						if v:IsA("BasePart") then
							v.Anchored = false
							v.CanCollide = true

							local debrisDir = (v.Position - result.Position).Unit
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

					task.delay(0.2, function()
						cooldown = false
					end)
				end
			end
		end)

		Debris:AddItem(connection, 0.25)
	end

	local function Knockback()
		if Target then
			print("[Knockback] Applying knockback to", Target.Name, "from", Invoker.Name)
			Library.StopAllAnims(Target)
			local Animation = Library.PlayAnimation(Target, Replicated.Assets.Animations.Misc.KnockbackStun)
			Animation.Priority = Enum.AnimationPriority.Action3

			-- Lock rotation and disable controls during knockback
			Library.TimedState(Target.Stuns, "NoRotate", 0.65) -- Match knockback duration
			Library.TimedState(Target.Stuns, "KnockbackStun", 0.65) -- Prevent all actions during knockback

			Server.Packets.Bvel.sendToAll({ Character = Invoker, Name = "KnockbackBvel", Targ = Target })
			print("[Knockback] Sent KnockbackBvel packet")
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

		-- Use ECS BlockBar component instead of Posture.Value
		local targetEntity = nil
		if TargetPlayer then
			targetEntity = ref.get("player", TargetPlayer)
		else
			-- For NPCs, use RefManager to find entity
			targetEntity = RefManager.entity.find(Target)
		end

		if targetEntity then
			local blockBar = world:get(targetEntity, comps.BlockBar)
			if blockBar then
				-- Increase block damage
				blockBar.Value = blockBar.Value + (Table.Damage / 3)
				world:set(targetEntity, comps.BlockBar, blockBar)

				-- Set BBRegen to start regenerating after 2 seconds of not being hit
				world:set(targetEntity, comps.BBRegen, {value = true, duration = 2})

				-- Check if block is broken
				if blockBar.Value >= blockBar.MaxValue then
					BlockBreak()
					return
				end
			end
		end

		-- Also update old Posture.Value for backwards compatibility
		if Target:FindFirstChild("Posture") then
			Target.Posture.Value = Target.Posture.Value + (Table.Damage / 3)

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

	--if Table.BlockBreak

	-- Check for specific immunity states, but don't block all damage for NPCs with minor states
	if Library.StateCheck(Target.IFrames, "Dodge") then
		Library.RemoveState(Target.IFrames, "Dodge")
		-- -- print("Dodge")

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
		if Library.StateCheck(Target.IFrames, "IFrame") or Library.StateCheck(Target.IFrames, "ForceField") then
			return
		end
		-- Allow damage through for states like "RecentlyAttacked", "Damaged", etc.
	else
		-- For players, check IFrames but allow damage through for combo victims
		if Library.StateCheck(Target.IFrames, "StrategistComboVictim") then
			-- Allow damage through - victim is locked in combo and should take damage
		elseif Library.StateCount(Target.IFrames) then
			-- Block damage for all other IFrame states
			return
		end
	end

	--if Library.StateCheck(Target.Actions, "M2") and Library.StateCheck(Invoker.Actions,"M2") and not Library.CheckCooldown(Invoker,"Clash") and not Library.CheckCooldown(Target,"Clash") then
	--	Clash()
	--	return
	--end

	-- Parry detection
	local hasParryFrame = Library.StateCheck(Target.Frames, "Parry")
	local isParryable = not Table.NoParry
	print(`[PARRY DEBUG] Damage check - Target: {Target.Name}, Invoker: {Invoker.Name}`)
	print(`[PARRY DEBUG] - Has Parry Frame: {hasParryFrame}, Is Parryable: {isParryable}`)

	if hasParryFrame then
		local targetFrames = Library.GetAllStatesFromCharacter(Target).Frames or {}
		print(`[PARRY DEBUG] - Target Frames: {table.concat(targetFrames, ", ")}`)
	end

	if hasParryFrame and isParryable then
		print(`[PARRY DEBUG] - ✅ PARRY DETECTED! Calling Parried()`)
		Parried()
		return
	end

	if
		Library.StateCheck(Target.Frames, "Blocking")
		and not Table.NoBlock -- Check if attack is unblockable
		and not Library.StateCheck(Target.Frames, "Parry")
		and not ((Target.HumanoidRootPart.CFrame:Inverse() * Invoker.HumanoidRootPart.CFrame).Z > 1)
	then
		HandleBlock(Target, Invoker)

		if Library.StateCheck(Target.Frames, "Blocking") then
			return
		end
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
		print("[Damage] Table.Knockback is true, calling Knockback()")
		Knockback()
	end

	if Table.LightKnockback then
		print("[Damage] Table.LightKnockback is true, calling LightKnockback()")
		LightKnockback()
	end

	if Table.Damage then
		DealDamage()

		-- Give NPCs brief immunity after taking damage to prevent spam
		-- Reduced from 0.2 to 0.05 to allow faster combos with increased stun duration
		if Target:GetAttribute("IsNPC") then
			Library.TimedState(Target.IFrames, "IFrame", 0.05)
		end
	end

	if Table.Status then
		Status()
	end

	if Table then
		-- -- print(Table)
	end

	-- Adrenaline System Integration
	local adrenalineSys = getAdrenalineSystem()

	-- Increase adrenaline for attacker when landing a hit
	if adrenalineSys and Player then
		local invokerEntity = ref.get("player", Player)
		if invokerEntity then
			adrenalineSys.increaseAdrenaline(invokerEntity)
		end
	end

	-- Reset adrenaline for target when getting hit (only if they had combo hits)
	if adrenalineSys and TargetPlayer then
		local targetEntity = ref.get("player", TargetPlayer)
		if targetEntity then
			local adrenalineData = world:get(targetEntity, comps.Adrenaline)
			if adrenalineData and adrenalineData.comboHits > 0 then
				adrenalineSys.resetAdrenaline(targetEntity)
			end
		end
	end
end

-- Handle destruction of destructible objects (barrels, trees, etc.)
DamageService.HandleDestructibleObject = function(Invoker: Model, Target: BasePart, Table: {})
	-- -- print("Destroying destructible object:", Target.Name)

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
		-- -- print("Destroying entire model:", targetModel.Name)
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

	-- -- print("Found", #partsToDestroy, "parts to destroy")

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
		-- -- print("VoxelizePart returned", #shatteredParts, "parts for", part.Name)

		-- If VoxelizePart didn't work, create manual debris
		if #shatteredParts == 0 or (#shatteredParts == 1 and shatteredParts[1] == partClone) then
			-- -- print("VoxelizePart failed for", part.Name, ", creating manual debris")
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

				-- -- print("Respawned destructible model:", respawnedModel.Name)
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

				-- -- print("Respawned destructible part:", respawnedPart.Name)
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
	-- -- print("Destructible object destroyed:", targetName, "- Created", #allShatteredParts, "total debris pieces")
	-- -- print("Destroyed", #partsToDestroy, "parts from", targetName)
end

return DamageService
