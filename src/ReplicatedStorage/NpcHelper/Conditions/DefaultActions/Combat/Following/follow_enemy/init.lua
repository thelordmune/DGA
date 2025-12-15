local getPathState = require(script.GetPathState)
local pathfinding = require(script.Pathfinding)

local raycastParams: RaycastParams do
	raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = {workspace.World.Visuals,workspace.World.Live}
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
end

-- ECS Bridge for combat NPCs
local ECSBridge = require(game.ReplicatedStorage.NpcHelper.ECSBridge)

local function updateMovementPattern(mainConfig)
	------ print(mainConfig.Setting.CanStrafe)
	if not mainConfig.Setting.CanStrafe then
		return "Direct"
	end

	local npc,target = mainConfig.getNpc(),mainConfig.getTarget()

	local distanceToTarget = (mainConfig.getTargetCFrame().Position - mainConfig.getNpcCFrame().Position).Magnitude
	if distanceToTarget > mainConfig.Movement.MaxStrafeRadius then
		return "Direct"
	end

	local toNpc = (mainConfig.getNpcCFrame().Position - mainConfig.getTargetCFrame().Position).Unit
	local targetLook = mainConfig.getTargetCFrame().LookVector
	local alignment = toNpc:Dot(targetLook)

	if alignment < mainConfig.Movement.MaxAlignmentDot then
		return "Direct"
	end


	if not mainConfig.Movement.Patterns.Current or 
		os.clock() - mainConfig.Movement.Patterns.LastChanged > 
		(mainConfig.Movement.Patterns.Duration.Current or math.random(
			mainConfig.Movement.Patterns.Duration.Min,
			mainConfig.Movement.Patterns.Duration.Max
			)) 
	then


		--[[ adds up all current weight in table and stores cumulative weight as denominator/max weight.
			While numerator being specific weight for that pattern]]

		local patterns = {
			{name = "Direct",weight = 1}, -- 1/30 -> 3% (rarely run straight)
			{name = "Strafe",weight = 8}, -- 8/30 -> 27% (strafe often)
			{name = "SideApproach",weight = 4}, -- 4/30 -> 13%
			{name = "CircleStrafe", weight = 15}, -- 15/30 -> 50% (circle strafe most of the time!)
			{name = "ZigZag", weight = 2}, -- 2/30 -> 7%
		}


		local totalWeight = 0;
		for _,pattern in patterns do
			totalWeight += pattern.weight
		end

		local random = math.random()*totalWeight;
		local currenmtWeight = 0;

		for _,pattern in patterns do
			currenmtWeight += pattern.weight
			if random <= currenmtWeight then
				------ print(`Selected {pattern.name} as new pattern`)
				mainConfig.Movement.Patterns.Current = pattern.name
				break
			end
		end


		mainConfig.Movement.Patterns.LastChanged = os.clock()
		mainConfig.Movement.Patterns.Duration.Current = math.random(
			mainConfig.Movement.Patterns.Duration.Min,
			mainConfig.Movement.Patterns.Duration.Max
		)

		if mainConfig.Movement.Patterns.Current == "SideApproach" then
			mainConfig.Movement.Patterns.Types.SideApproach.Direction = 
				math.random() > 0.5 and "Left" or "Right"
		end

		--reset
		mainConfig.States.PatternState = {
			CircleDirection = math.random() > 0.5 and 1 or -1,
			ZigZagDirection = math.random() > 0.5 and 1 or -1,
			ZigZagTimer = 0
		}
	end

	return mainConfig.Movement.Patterns.Current
end

local function createAlignment(npc: Model, victim: Model, mainConfig: table)
	-- Don't create AlignOrientation during attacks to prevent choppy movement
	local Server = require(game:GetService("ServerScriptService").ServerConfig.Server)
	if Server.Library.StateCheck(npc.Actions, "Attacking") then
		return nil
	end

	--task.synchronize()
	local primaryPart = npc.PrimaryPart or npc:FindFirstChild("HumanoidRootPart")
	if not primaryPart then
		warn(`[follow_enemy] NPC {npc.Name} has no PrimaryPart or HumanoidRootPart`)
		return nil
	end

	local alignOrientation = primaryPart:FindFirstChild("AlignOrient")

	-- Only create if it doesn't exist
	if not alignOrientation then
		local rootAttachment = primaryPart:FindFirstChild("RootAttachment")
		if not rootAttachment then
			warn(`[follow_enemy] NPC {npc.Name} PrimaryPart has no RootAttachment`)
			return nil
		end

		alignOrientation = Instance.new("AlignOrientation") :: AlignOrientation
		alignOrientation.Name = "AlignOrient"
		alignOrientation.MaxTorque = 1000000
		alignOrientation.Responsiveness = 100
		alignOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
		alignOrientation.Enabled = true
		alignOrientation.Attachment0 = rootAttachment
		alignOrientation.Parent = primaryPart
	end

	-- Update the angle to face target
	local diff = (mainConfig.getNpcCFrame().Position - mainConfig.getTargetCFrame().Position)
	local angle = math.atan2(diff.X, diff.Z)
	alignOrientation.CFrame = CFrame.Angles(0, angle, 0)

	--task.desynchronize()
	return alignOrientation
end

local function clearAlignOrientation(npc)
	local primaryPart = npc.PrimaryPart or npc:FindFirstChild("HumanoidRootPart")
	if not primaryPart then
		return
	end

	local existingAlign = primaryPart:FindFirstChild("AlignOrient")
	if existingAlign then
		--task.synchronize()
		existingAlign:Destroy()
		--task.desynchronize()
	end
end


return function(actor: Actor, mainConfig: table )
	local npc = actor:FindFirstChildOfClass("Model")
	if not npc then
		return false
	end

	local root,humanoid = npc:FindFirstChild("HumanoidRootPart"),npc:FindFirstChild("Humanoid")
	if not root
		or not humanoid
	then
		return false
	end

	-- Skip if this is a combat NPC (ECS AI handles movement)
	-- Behavior tree should only handle combat actions, not movement
	-- Return true so the behavior tree continues to attack conditions
	if ECSBridge.isCombatNPC(npc) then
		return true
	end

	-- Check if NPC is dashing - if so, don't override the dash movement
	if mainConfig.Movement and mainConfig.Movement.IsDashing then
		-- NPC is dashing, let the dash system control movement
		return true
	end

	-- Check if NPC is performing an action - if so, stop movement to prevent choppy behavior
	local Server = require(game:GetService("ServerScriptService").ServerConfig.Server)
	local actions = npc:FindFirstChild("Actions")
	if actions and Server.Library.StateCount(actions) then
		-- NPC is performing an action (attacking, using skill, etc.) - stop movement
		humanoid:Move(Vector3.new(0, 0, 0))
		clearAlignOrientation(npc)

		-- Also clear any dash velocities that might be lingering
		for _, bodyMover in pairs(root:GetChildren()) do
			if bodyMover:IsA("LinearVelocity") or bodyMover:IsA("BodyVelocity") then
				if bodyMover.Name == "NPCDash" or bodyMover.Name == "NPCDodge" then
					bodyMover:Destroy()
				end
			end
		end

		return true -- Return true so behavior tree knows we're still following, just paused
	end

	local victim = mainConfig.getTarget()
	if not victim then
		clearAlignOrientation(npc)
		return false
	end

	-- Debug: Check if Guards are following
	if npc.Name:match("Guard") then
		------ print(`[Follow] {npc.Name} is following {victim.Name}`)
	end

	local vRoot,vHum = victim:FindFirstChild("HumanoidRootPart"),victim:FindFirstChild("Humanoid")
	if not vRoot or not vHum then
		return false
	end


	local PathState: PathState = "";

	-- Don't move during attacks to prevent stuttering
	local Server = require(game:GetService("ServerScriptService").ServerConfig.Server)
	if Server.Library.StateCheck(npc.Actions, "Attacking") then
		humanoid:Move(Vector3.new(0, 0, 0))
		-- Force walk speed during attacks
		if humanoid.WalkSpeed ~= mainConfig.HumanoidDefaults.WalkSpeed then
			humanoid.WalkSpeed = mainConfig.HumanoidDefaults.WalkSpeed
			local Library = require(game.ReplicatedStorage.Modules.Library)
			local runAnimation = mainConfig.getRunAnimation()
			if runAnimation then
				Library.StopAnimation(npc, runAnimation, 0.25)
			end
		end
		return true
	end

	-- Distance-based running: NPCs run when far from target
	local distanceToTarget = (vRoot.Position - root.Position).Magnitude
	local RUN_DISTANCE_THRESHOLD = 15 -- Run if more than 15 studs away
	local Library = require(game.ReplicatedStorage.Modules.Library)

	-- Check if NPC just attacked - add cooldown before running again
	local lastAttack = mainConfig.States and mainConfig.States.LastAttack or 0
	local RUN_COOLDOWN_AFTER_ATTACK = 1.0 -- 1 second cooldown after attacking before running
	local canRun = (os.clock() - lastAttack) > RUN_COOLDOWN_AFTER_ATTACK

	if distanceToTarget > RUN_DISTANCE_THRESHOLD and canRun then
		-- Far from target and cooldown expired - run
		if humanoid.WalkSpeed ~= mainConfig.HumanoidDefaults.RunSpeed then
			humanoid.WalkSpeed = mainConfig.HumanoidDefaults.RunSpeed

			-- Play run animation
			local runAnimation = mainConfig.getRunAnimation()
			if runAnimation then
				Library.PlayAnimation(npc, runAnimation)
			end
		end
	else
		-- Close to target or cooldown active - walk
		if humanoid.WalkSpeed ~= mainConfig.HumanoidDefaults.WalkSpeed then
			humanoid.WalkSpeed = mainConfig.HumanoidDefaults.WalkSpeed

			-- Stop run animation
			local runAnimation = mainConfig.getRunAnimation()
			if runAnimation then
				Library.StopAnimation(npc, runAnimation, 0.25)
			end
		end
	end

	local config = {
		[`Direct`] = function()
			local movementPatterns = {
				[`Still`] = function()
					-- Set target direction to zero for smooth stopping
					if mainConfig.Movement and mainConfig.Movement.TargetDirection then
						mainConfig.Movement.TargetDirection = Vector3.new(0, 0, 0)
					else
						humanoid:Move(Vector3.new(0, 0, 0))
					end
				end,

				[`Follow`] = function()
					------ print("follow")
					local toTarget = (mainConfig.getTargetCFrame().Position - mainConfig.getNpcCFrame().Position).Unit
					local rightVector = Vector3.new(-toTarget.Z, 0, toTarget.X)

					local patternBehaviors = {
						[`Strafe`] = function()
							------ print("strafe")
							local alignOrientation = createAlignment(npc, victim, mainConfig)
							local patterns = mainConfig.Movement.Patterns.Types.Strafe;

							local strafeDir = mainConfig.States.StrafeDirection or
								(math.random() > 0.5 and rightVector or -rightVector)
							mainConfig.States.StrafeDirection = strafeDir

							return (toTarget * patterns.ForwardMix) + (strafeDir * patterns.Speed)
						end,

						[`SideApproach`] = function()
							------ print("side approach")
							local alignOrientation = createAlignment(npc, victim, mainConfig)

							local patterns = mainConfig.Movement.Patterns.Types.SideApproach;
							local sideDir = patterns.Direction == "Right" and rightVector or -rightVector

							return (toTarget * patterns.ForwardSpeed) + (sideDir * patterns.SideSpeed)
						end,

						[`CircleStrafe`] = function()
							------ print("circle strafe")
							local alignOrientation = createAlignment(npc, victim, mainConfig)

							local patterns = mainConfig.Movement.Patterns.Types.CircleStrafe;

							local direction = mainConfig.States.PatternState.CircleDirection;
							local circleVector = rightVector * direction;

							local circleSpeed,radius = patterns.Speed,patterns.Radius

							return (toTarget * circleSpeed) + (circleVector * (circleSpeed * (radius/10)))
						end,

						[`ZigZag`] = function()
							------ print("zig zag")
							local alignOrientation = createAlignment(npc, victim, mainConfig)

							local patterns = mainConfig.Movement.Patterns.Types.ZigZag;
							local state = mainConfig.States.PatternState;

							local INTERVAL = 0.5; -- HOW FREQUENT YOU WANT IT TO SWITCH ZIG ZAGS

							if os.clock() - state.ZigZagTimer > INTERVAL then
								state.ZigZagDirection *= -1
								state.ZigZagTimer = os.clock()
							end

							local sideVector = rightVector * state.ZigZagDirection
							return (toTarget * patterns.ForwardSpeed) + (sideVector * patterns.SideSpeed)
						end,

						[`Direct`] = function()
							return toTarget -- ((mainConfig.getTargetCFrame() * CFrame.new(0,0,-4)).Position - mainConfig.getNpcCFrame().Position)
						end
					}

					local currentPattern = updateMovementPattern(mainConfig)
					------ print(currentPattern)
					local targetDirection = patternBehaviors[currentPattern]()

					local _ = currentPattern == "Direct" and clearAlignOrientation(npc)

					-- Smooth interpolation for movement direction
					-- Lerp from current direction to target direction for smooth transitions
					local alpha = mainConfig.Movement.SmoothingAlpha
					local smoothedDirection = mainConfig.Movement.CurrentDirection:Lerp(targetDirection, alpha)
					mainConfig.Movement.CurrentDirection = smoothedDirection

					-- Apply smoothed movement
					humanoid:Move(smoothedDirection)
				end
			}

			local DISTANCE_TO_STOP_FOLLOWING_AT: number = 3; -- Close combat distance - NPCs should get close to attack
			local indexType = if (mainConfig.getTargetCFrame().Position - mainConfig.getNpcCFrame().Position).Magnitude < DISTANCE_TO_STOP_FOLLOWING_AT then "Still"
				else "Follow"

			movementPatterns[indexType]()
		end,

		[`Pathfind`] = function()
			clearAlignOrientation(npc)
			pathfinding(npc, mainConfig, victim, mainConfig.getMimic())
		end
	}

	local typeIndex: any = typeof(victim)

	local TargetPosition = (typeIndex == "Vector3" and victim)
		or (victim:IsA("Model") and victim:GetPivot().Position) :: Vector3

	local RootPosition = root.Position
	local Direction: Vector3? = (TargetPosition - RootPosition)

	local UnitVector: any = Direction.Unit
	local MagnitudeIndex = Direction.Magnitude + 1;

	local Pass: number = 1;

	-- Raycast to check if there's a clear path to target
	local raycastResults: RaycastResult = workspace:Raycast(RootPosition, UnitVector * MagnitudeIndex, raycastParams)
	if raycastResults and raycastResults.Position then
		-- If raycast hit something before reaching the target, we need to pathfind
		local hitDistance = (raycastResults.Position - RootPosition).Magnitude
		local targetDistance = Direction.Magnitude

		-- If we hit something and it's significantly before the target (more than 2 studs away)
		if hitDistance < (targetDistance - 2) then
			Pass = 2
		end
	end

	local AiFolder: Folder = mainConfig.getMimic()
	if humanoid.FloorMaterial ~= Enum.Material.Air and humanoid.FloorMaterial ~= nil and Pass ~= AiFolder.PathState.Value then
		--task.synchronize()
		AiFolder.StateId.Value = math.random(1,9999)
		AiFolder.PathState.Value = Pass
		--task.desynchronize()
		if Pass == 2 then
			---- print(`[NPC Pathfinding] {npc.Name} detected obstacle, using pathfinding`)
			config.Pathfind()
		end
	end
	if Pass == 1 then
		config.Direct()
	end

	return true
end