--[[
	Modernized NPC System using jecs-utils ref

	This system now uses the new ref system to track NPCs.
	Observers handle spawn/despawn events automatically.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)
local world = require(ReplicatedStorage.Modules.ECS.jecs_world)
local RefManager = require(ReplicatedStorage.Modules.ECS.jecs_ref_manager)
local Players = game:GetService("Players")

-- Helper function to check if NPC is a combat NPC
local function isCombatNPC(npcModel: Model): boolean
	-- Check if NPC is in Dialogue folder (dialogue NPCs are never combat NPCs)
	local ancestor = npcModel
	while ancestor do
		if ancestor.Name == "Dialogue" and ancestor.Parent and ancestor.Parent.Name == "World" then
			-- print(`[Mobs] {npcModel.Name} is in World.Dialogue - DIALOGUE NPC`)
			return false -- Dialogue NPC
		end
		ancestor = ancestor.Parent
	end

	-- Check if NPC name contains "Dummy" or "Training" - these are NOT combat NPCs
	local npcName = npcModel.Name:lower()
	if npcName:find("dummy") or npcName:find("training") then
		-- print(`[Mobs] {npcModel.Name} is a training dummy - DIALOGUE NPC`)
		return false
	end

	-- OPTIMIZATION: Don't wait for Actor parent - just check immediately
	-- If Actor doesn't exist yet, the NPC will be reinitialized when it's fully loaded
	local actor = npcModel.Parent
	if not actor or not actor:IsA("Actor") then
		-- print(`[Mobs] {npcModel.Name} - No Actor parent found, assuming DIALOGUE NPC (safer default)`)
		return false -- Default to dialogue NPC if no Actor (safer for dummies/static NPCs)
	end

	local dataFolder = actor:FindFirstChild("Data")
	if not dataFolder then
		-- print(`[Mobs] {npcModel.Name} - No Data folder found, assuming DIALOGUE NPC (safer default)`)
		return false -- Default to dialogue NPC if no Data folder
	end

	-- Check Combat settings
	local combatFolder = dataFolder:FindFirstChild("Combat")
	if combatFolder then
		local lightValue = combatFolder:FindFirstChild("Light")
		if lightValue then
			-- print(`[Mobs] {npcModel.Name} - Combat.Light = {lightValue.Value}`)
			if lightValue.Value == true then
				return true
			end
		end
	end

	-- Check if has weapons enabled
	local weaponsFolder = dataFolder:FindFirstChild("Weapons")
	if weaponsFolder then
		local enabledValue = weaponsFolder:FindFirstChild("Enabled")
		if enabledValue then
			-- print(`[Mobs] {npcModel.Name} - Weapons.Enabled = {enabledValue.Value}`)
			if enabledValue.Value == true then
				return true
			end
		end
	end

	-- Check if has enemy detection
	local enemyDetectionFolder = dataFolder:FindFirstChild("EnemyDetection")
	if enemyDetectionFolder then
		local captureDistValue = enemyDetectionFolder:FindFirstChild("CaptureDistance")
		if captureDistValue then
			-- print(`[Mobs] {npcModel.Name} - EnemyDetection.CaptureDistance = {captureDistValue.Value}`)
			if captureDistValue.Value > 0 then
				return true
			end
		end
	end

	-- print(`[Mobs] {npcModel.Name} - No combat indicators found, defaulting to DIALOGUE NPC`)
	return false
end

-- Function to initialize NPC entity with all components
local function initializeNPCEntity(npcModel: Model): number
	-- Use new ref system with initializer function
	local entity = RefManager.entity(npcModel, function(e)
		-- Set all NPC components
		world:set(e, comps.Character, npcModel)
		world:set(e, comps.Mob, true)

		-- Determine if this is a combat NPC
		local isCombat = isCombatNPC(npcModel)
		if isCombat then
			world:set(e, comps.CombatNPC, true)
		end
		world:set(e, comps.Health, {current = 175, max = 175, tick = 0.5, tickspeed = 0.1})
		world:set(e, comps.Energy, {current = 100, tick = 0.5, tickspeed = 0.1})
		world:set(e, comps.Combat, { weapon = "Fist", equipped = true, animation = "Fist" })
		world:set(e, comps.Attacking, {duration = 0, value = false})
		world:set(e, comps.Stun, {duration = 0, value = false})
		world:set(e, comps.NoRotate, {duration = 0, value = false})
		world:set(e, comps.Dashing, false)
		world:set(e, comps.Blocking, {duration = 0, value = false})
		world:set(e, comps.Carrying, {target = nil, value = false})
		world:set(e, comps.BeingGripped, false)
		world:set(e, comps.BeingCarried, false)
		world:set(e, comps.DeathLocation, CFrame.new(0,0,0))
		world:set(e, comps.Knocked, {duration = 0, value = false})
		world:set(e, comps.IFrame, {duration = 0, value = false})
		world:set(e, comps.Sprinting, false)
		world:set(e, comps.Ragdoll, {duration = 0, value = false})
		world:set(e, comps.CantMove, {duration = 0, value = false})
		world:set(e, comps.Dead, false)
		world:set(e, comps.Weapon, {name = "Fist", type = "Fist"})
		world:set(e, comps.Swing, 1)
		world:set(e, comps.WallRunning, false)
		world:set(e, comps.Sliding, false)
		world:set(e, comps.NoJump, {duration = 0, value = false})
		world:set(e, comps.ToSpeed, 0)
		world:set(e, comps.KeysLogged, 1)
		world:set(e, comps.Light, {duration = 0, value = false})
		world:set(e, comps.NoDash, {duration = 0, value = false})
		world:set(e, comps.LastHit, 0)
		world:set(e, comps.CritCD, {duration = 0, value = false})
		world:set(e, comps.Heavy, {duration = 0, value = false})
		world:set(e, comps.IgnoreParry, {duration = 0, value = false})
		world:set(e, comps.NoHurt, {duration = 0, value = false})
		world:set(e, comps.Damage, 0)
		world:set(e, comps.ParryTick, {duration = 0, value = false})
		world:set(e, comps.ParryStun, {duration = 0, value = false})
		world:set(e, comps.InAir, false)
		world:set(e, comps.Utility, {duration = 0, value = false})
		world:set(e, comps.Victim, nil)
		world:set(e, comps.Action, {duration = 0, value = false})
		world:set(e, comps.BlockBar, {Value = 0, MaxValue = 100})  -- Start at 0, increases to 100 when blocking hits
		world:set(e, comps.BBRegen, {duration = 0, value = false})
		world:set(e, comps.BlockBroken, false)
		world:set(e, comps.Armor, {duration = 0, armortype = "None", value = false})
		world:set(e, comps.QDC, {duration = 0, value = false})
		world:set(e, comps.NoRagdoll, false)
		world:set(e, comps.Locked, {duration = 0, value = false})

		-- ECS AI Components (only for combat NPCs)
		if isCombat then
			local hrp = npcModel:FindFirstChild("HumanoidRootPart")
			local spawnPos = hrp and hrp.Position or Vector3.new(0, 0, 0)
			local spawnCF = hrp and hrp.CFrame or CFrame.new(0, 0, 0)

			-- Transform component (required for AI)
			world:set(e, comps.Transform, {
				new = spawnCF,
				old = spawnCF
			})

			-- Locomotion component (movement intent)
			world:set(e, comps.Locomotion, {
				dir = Vector3.zero,
				speed = 0
			})

			-- AI State component
			local function randRange(min: number, max: number): number
				return min + (max - min) * math.random()
			end

			world:set(e, comps.AIState, {
				state = "wander",
				t = randRange(0, 2), -- Random starting time to desync NPCs
				dur = randRange(2, 5),
				circleSign = (math.random(0, 1) == 0) and -1 or 1,
			})

			-- Traits component (AI personality)
			local chaseWeight = randRange(0.3, 0.8)
			local fleeWeight = randRange(0.1, 0.4)
			local circleWeight = randRange(0.2, 0.5)
			local detectRange = randRange(25, 45)

			world:set(e, comps.Traits, {
				baseSpeedMul = randRange(0.8, 1.2),
				chaseWeight = chaseWeight,
				fleeWeight = fleeWeight,
				circleWeight = circleWeight,
				jumpWeight = randRange(0, 0.3),
				fleeDistance = randRange(8, 15),
				preferDistance = randRange(2, 5),
				detectRange = detectRange,
				loseSightRange = detectRange + randRange(10, 20),
			})

			-- Wander component
			world:set(e, comps.Wander, {
				center = spawnPos,
				radius = 30,
				nextMove = math.random() * 2, -- Random starting time to desync NPCs
			})

			-- Hitbox component (for debugging/attributes)
			if hrp then
				world:set(e, comps.Hitbox, hrp)
				hrp:SetAttribute("DetectRange", detectRange)
				hrp:SetAttribute("IsCombatNPC", true)

				-- Size component (for mob avoidance)
				-- Calculate size from HumanoidRootPart or use default
				local hitboxSize = hrp.Size
				world:set(e, comps.Size, hitboxSize.Magnitude)
			end

			-- NEW: NPC Combat AI Components
			-- Get config from Actor Data folder
			local actor = npcModel.Parent
			local captureDistance = 40
			local letGoDistance = 60
			local runAwayHP = 0.2
			local canStrafe = true
			local canWander = false -- Default to false - NPCs must explicitly opt-in to wandering
			local maxStrafeRadius = 12 -- REDUCED: Was 20, now 12 for tighter circle strafe
			local maxAlignmentDot = 0.5
			local walkSpeed = 16
			local runSpeed = 24
			local jumpPower = 50
			local smoothingAlpha = 0.3
			local maxWanderDistance = 30

			if actor and actor:IsA("Actor") then
				local dataFolder = actor:FindFirstChild("Data")
				if dataFolder then
					local enemyDetection = dataFolder:FindFirstChild("EnemyDetection")
					if enemyDetection then
						local captureDist = enemyDetection:FindFirstChild("CaptureDistance")
						if captureDist then captureDistance = captureDist.Value end
						local letGoDist = enemyDetection:FindFirstChild("LetGoDistance")
						if letGoDist then letGoDistance = letGoDist.Value end
					end

					local combatFolder = dataFolder:FindFirstChild("Combat")
					if combatFolder then
						local runAwayHPValue = combatFolder:FindFirstChild("RunAwayHP")
						if runAwayHPValue then runAwayHP = runAwayHPValue.Value end
					end

					local settingFolder = dataFolder:FindFirstChild("Setting")
					if settingFolder then
						local canStrafeValue = settingFolder:FindFirstChild("CanStrafe")
						if canStrafeValue then canStrafe = canStrafeValue.Value end
						local canWanderValue = settingFolder:FindFirstChild("CanWander")
						if canWanderValue then canWander = canWanderValue.Value end
					end

					local movementFolder = dataFolder:FindFirstChild("Movement")
					if movementFolder then
						local maxStrafeRadiusValue = movementFolder:FindFirstChild("MaxStrafeRadius")
						if maxStrafeRadiusValue then maxStrafeRadius = maxStrafeRadiusValue.Value end
						local maxAlignmentDotValue = movementFolder:FindFirstChild("MaxAlignmentDot")
						if maxAlignmentDotValue then maxAlignmentDot = maxAlignmentDotValue.Value end
						local smoothingAlphaValue = movementFolder:FindFirstChild("SmoothingAlpha")
						if smoothingAlphaValue then smoothingAlpha = smoothingAlphaValue.Value end
					end

					local humanoidDefaults = dataFolder:FindFirstChild("HumanoidDefaults")
					if humanoidDefaults then
						local walkSpeedValue = humanoidDefaults:FindFirstChild("WalkSpeed")
						if walkSpeedValue then walkSpeed = walkSpeedValue.Value end
						local runSpeedValue = humanoidDefaults:FindFirstChild("RunSpeed")
						if runSpeedValue then runSpeed = runSpeedValue.Value end
						local jumpPowerValue = humanoidDefaults:FindFirstChild("JumpPower")
						if jumpPowerValue then jumpPower = jumpPowerValue.Value end
					end

					local idleFolder = dataFolder:FindFirstChild("Idle")
					if idleFolder then
						local maxDistanceValue = idleFolder:FindFirstChild("MaxDistance")
						if maxDistanceValue then maxWanderDistance = maxDistanceValue.Value end
					end
				end
			end

			-- NPCCombatState (FIXED: Only start aggressive if they have capture range > 0)
			-- This prevents wandering NPCs from aggroing without being attacked
			local shouldStartAggressive = captureDistance > 0
			world:set(e, comps.NPCCombatState, {
				isPassive = not shouldStartAggressive, -- FIXED: Passive by default unless capture range set
				isAggressive = shouldStartAggressive,  -- FIXED: Only aggressive if they hunt players
				hasBeenAttacked = false,
				lastAttackTime = 0,
				lastDefenseTime = 0,
				lastActionTime = 0,
				justParried = false,
				parryTime = 0,
				lastM1Time = 0,
				lastSkillUsed = nil,
				hitsTaken = 0,
			})

			-- NPCSkillScoring
			world:set(e, comps.NPCSkillScoring, {
				bestSkill = nil,
				bestScore = 0,
				lastScoringTime = 0,
			})

			-- NPCGuardPattern (only for guards)
			local isGuard = string.find(npcModel.Name, "Guard") ~= nil
			world:set(e, comps.NPCGuardPattern, {
				enabled = isGuard,
				currentState = "Defensive",
				stateStartTime = os.clock(),
				comboCount = 0,
			})

			-- NPCPathfinding
			world:set(e, comps.NPCPathfinding, {
				isActive = false,
				pathState = "Direct",
				stateId = 0,
				waypoints = nil,
				currentWaypointIndex = 0,
				lastRecomputeTime = 0,
			})

			-- NPCMovementPattern
			world:set(e, comps.NPCMovementPattern, {
				current = "Direct",
				lastChanged = math.random() * 2, -- Random start to desync
				duration = math.random() * 1 + 2, -- 2-3 seconds
				strafeDirection = nil,
				sideDirection = nil,
				circleDirection = (math.random() > 0.5) and 1 or -1, -- Random circle direction
				zigzagDirection = (math.random() > 0.5) and 1 or -1, -- Random zigzag direction
				zigzagTimer = math.random(), -- Random zigzag phase
			})

			-- NPCWander (only add if NPC can wander)
			-- Guards should NOT wander, so they won't have this component
			if canWander then
				world:set(e, comps.NPCWander, {
					center = spawnPos, -- spawnPos is already the NPC's current position (from hrp.Position)
					radius = maxWanderDistance or 30,
					nextMove = math.random() * 3, -- Random starting time to desync
					swayX = 0,
					swayY = 0,
					noiseOffset = math.random() * 1000, -- Already randomized, good!
					currentDirection = Vector3.zero,
					isPaused = false, -- Initialize pause state
					pauseEndTime = 0,
					moveEndTime = 0,
				})
			end

			-- NPCConfig
			world:set(e, comps.NPCConfig, {
				captureDistance = captureDistance,
				letGoDistance = letGoDistance,
				runAwayHP = runAwayHP,
				safeRange = 15,
				canStrafe = canStrafe,
				canWander = canWander,
				maxStrafeRadius = maxStrafeRadius,
				maxAlignmentDot = maxAlignmentDot,
				walkSpeed = walkSpeed,
				runSpeed = runSpeed,
				jumpPower = jumpPower,
				smoothingAlpha = smoothingAlpha,
			})

			-- NPCSpawnData
			world:set(e, comps.NPCSpawnData, {
				spawnPosition = spawnPos,
				maxWanderDistance = maxWanderDistance,
			})

			-- Debug logging for initialization
		local combatState = world:get(e, comps.NPCCombatState)
		-- print("[Mobs] ⚔️ Initialized COMBAT NPC:", npcModel.Name, "Entity:", e, "with ECS AI")
		-- print(`[Mobs]    - isPassive: {combatState.isPassive}, canWander: {canWander}`)
		-- print(`[Mobs]    - Components: NPCCombatState, NPCMovementPattern, NPCConfig, Transform, Locomotion`)
		if canWander then
			-- print(`[Mobs]    - Added NPCWander (radius: {maxWanderDistance or 30})`)
		else
			-- print(`[Mobs]    - NPCWander NOT added (guard mode)`)
		end
		else
			-- print("[Mobs] 💬 Initialized DIALOGUE NPC:", npcModel.Name, "Entity:", e, "(no ECS AI)")
		end
	end)

	return entity
end

-- Track NPCs that have been initialized to avoid rescanning
local initializedNPCs = {}

-- OPTIMIZATION: Cache Live folder children instead of using GetDescendants
local liveFolder = workspace.World.Live
local cachedNPCs = {}

-- Helper to scan a folder for NPCs (non-recursive, more efficient)
local function scanFolderForNPCs(folder)
	for _, child in folder:GetChildren() do
		if child:IsA("Model") and not Players:GetPlayerFromCharacter(child) then
			if not initializedNPCs[child] and not cachedNPCs[child] then
				local existingEntity = RefManager.entity.find(child)
				if not existingEntity then
					-- FIXED: Initialize immediately instead of deferring to prevent NPCs from not loading
					initializeNPCEntity(child)
					initializedNPCs[child] = true
					cachedNPCs[child] = true
				else
					cachedNPCs[child] = true
				end
			end
		end
	end
end

-- Set up DescendantAdded listener for immediate NPC detection (more efficient than polling)
workspace.World.Live.DescendantAdded:Connect(function(descendant)
	if descendant:IsA("Model") and not Players:GetPlayerFromCharacter(descendant) then
		-- FIXED: Initialize immediately to ensure NPCs load properly
		-- Small delay to ensure model is fully loaded
		task.wait(0.1)
		if not initializedNPCs[descendant] then
			local existingEntity = RefManager.entity.find(descendant)
			if not existingEntity then
				initializeNPCEntity(descendant)
				initializedNPCs[descendant] = true
				cachedNPCs[descendant] = true
			end
		end
	end
end)

-- Clean up tracking when NPCs are removed
workspace.World.Live.DescendantRemoving:Connect(function(descendant)
	if initializedNPCs[descendant] then
		initializedNPCs[descendant] = nil
	end
	if cachedNPCs[descendant] then
		cachedNPCs[descendant] = nil
	end
end)

-- OPTIMIZATION: Do initial scan once on startup, then rely on DescendantAdded
local hasScannedOnce = false

return {
	run = function()
		-- Skip if more than 1 player (temporary restriction)
		if #Players:GetPlayers() > 1 then return end

		-- OPTIMIZATION: Only scan once on startup, then rely on DescendantAdded listener
		-- This eliminates the expensive GetDescendants() call every 2 seconds
		if not hasScannedOnce then
			hasScannedOnce = true
			-- Scan Live folder (non-recursive, much faster than GetDescendants)
			scanFolderForNPCs(liveFolder)
		end

		-- No periodic scanning needed - DescendantAdded handles everything
	end,

	settings = {
		phase = "Heartbeat",
		depends_on = {},
		server_only = true
	}
}