local getPathState = require(script.GetPathState)
local pathfinding = require(script.Pathfinding)

local function updateMovementPattern(mainConfig)
	--print(mainConfig.Setting.CanStrafe)
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
			{name = "Direct",weight = 3}, --3/6 -> 50%
			{name = "Strafe",weight = 1}, --1/6 -> 17%
			{name = "SideApproach",weight = 2}, --2/6 -> 33%
			--{name="CircleStrafe", weight = 1},
			--{name = "ZigZag",Weight = 1},		
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
				--print(`Selected {pattern.name} as new pattern`)
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
	--task.synchronize()
	local alignOrientation= npc.PrimaryPart:FindFirstChild("AlignOrient") or Instance.new("AlignOrientation") :: AlignOrientation
	alignOrientation.Name = "AlignOrient"
	alignOrientation.MaxTorque = 1000000
	alignOrientation.Responsiveness = 100
	alignOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
	alignOrientation.Enabled = true
	alignOrientation.Attachment0 = npc.PrimaryPart.RootAttachment

	local diff = (mainConfig.getNpcCFrame().Position - mainConfig.getTargetCFrame().Position)
	local angle = math.atan2(diff.X, diff.Z)
	alignOrientation.CFrame = CFrame.Angles(0, angle, 0)


	alignOrientation.Parent = npc.PrimaryPart

	--task.desynchronize()
	return alignOrientation
end

local function clearAlignOrientation(npc)
	local existingAlign = npc.PrimaryPart:FindFirstChild("AlignOrient")
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

	local victim = mainConfig.getTarget()
	if not victim then
		clearAlignOrientation(npc)
		return false
	end

	local vRoot,vHum = victim:FindFirstChild("HumanoidRootPart"),victim:FindFirstChild("Humanoid")
	if not vRoot or not vHum then
		return false
	end

	mainConfig.Pathfinding.PathState = getPathState(npc, mainConfig)
	local config = {
		[`Direct`] = function()
			local movementPatterns = {
				[`Still`] = function()
					local toTarget = (mainConfig.getTargetCFrame().Position - mainConfig.getNpcCFrame().Position).Unit
					local targetLook = mainConfig.getTargetCFrame().LookVector
					local distance = (mainConfig.getTargetCFrame().Position - mainConfig.getNpcCFrame().Position).Magnitude

					local BACKUP_START_DISTANCE = 7;
					local BACKUP_MIN_DISTANCE = 2.5;
					local BACKUP_DOT_THRESHOLD = 0.6;

					local config = {
						[`true`] = function()
							local alignOrientation = createAlignment(npc,victim,mainConfig)
							local backupIntensity = math.clamp(
								1 - ((distance - BACKUP_MIN_DISTANCE) / (BACKUP_START_DISTANCE - BACKUP_MIN_DISTANCE)), 
								0.3,
								1
							)		

							local backupDirection = toTarget * backupIntensity * mainConfig.Movement.BackupSpeed

							--task.synchronize()
							humanoid:Move(-backupDirection)
							--task.desynchronize()
						end,
						[`false`] = function()
							clearAlignOrientation(npc)

							--task.synchronize()
							humanoid:Move(Vector3.zero)
							--task.desynchronize()
						end,
					}

					local isBeingPressed = targetLook:Dot(-toTarget) > BACKUP_DOT_THRESHOLD and distance < BACKUP_START_DISTANCE
					config[tostring(isBeingPressed)]()
				end,

				[`Follow`] = function()
					local toTarget = (mainConfig.getTargetCFrame().Position - mainConfig.getNpcCFrame().Position).Unit
					local rightVector = Vector3.new(-toTarget.Z, 0, toTarget.X)

					local patternBehaviors = {
						[`Strafe`] = function()
							--print("strafe")
							local alignOrientation = createAlignment(npc, victim, mainConfig)
							local patterns = mainConfig.Movement.Patterns.Types.Strafe;

							local strafeDir = mainConfig.States.StrafeDirection or 
								(math.random() > 0.5 and rightVector or -rightVector)
							mainConfig.States.StrafeDirection = strafeDir

							return (toTarget * patterns.ForwardMix) + (strafeDir * patterns.Speed)
						end,

						[`SideApproach`] = function()
							--print("side approach")
							local alignOrientation = createAlignment(npc, victim, mainConfig)

							local patterns = mainConfig.Movement.Patterns.Types.SideApproach;
							local sideDir = patterns.Direction == "Right" and rightVector or -rightVector

							return (toTarget * patterns.ForwardSpeed) + (sideDir * patterns.SideSpeed)
						end,

						[`CircleStrafe`] = function()
							--print("circle strafe")
							local alignOrientation = createAlignment(npc, victim, mainConfig)

							local patterns = mainConfig.Movement.Patterns.Types.CircleStrafe;

							local direction = mainConfig.States.PatternState.CircleDirection;
							local circleVector = rightVector * direction;

							local circleSpeed,radius = patterns.Speed,patterns.Radius

							return (toTarget * circleSpeed) + (circleVector * (circleSpeed * (radius/10)))
						end,

						[`ZigZag`] = function()
							--print("zig zag")
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
							return (mainConfig.getTargetCFrame().Position - mainConfig.getNpcCFrame().Position)
						end
					}

					local currentPattern = updateMovementPattern(mainConfig)
					--print(currentPattern)
					local finalDirection = patternBehaviors[currentPattern]()

					local _ = currentPattern == "Direct" and clearAlignOrientation(npc)

					--task.synchronize()
					humanoid:Move(finalDirection)
					--task.desynchronize()
				end
			}
			--local indexType = if (mainConfig.getTargetCFrame().Position - mainConfig.getNpcCFrame().Position).Magnitude < 4.5 then "Still" 
			--else "Follow"


			local TRANSITION_BUFFER = 1.5;
			local distance = (mainConfig.getTargetCFrame().Position - mainConfig.getNpcCFrame().Position).Magnitude


			local indexType = if distance < (7  - TRANSITION_BUFFER) then `Still` 
				elseif distance > (7 + TRANSITION_BUFFER) then `Follow`
				else mainConfig.States.LastMovementType or `Still`

			mainConfig.States.LastMovementType = indexType
			movementPatterns[indexType]()
		end,

		[`Pathfind`] = function()
			clearAlignOrientation(npc)
			pathfinding(npc, mainConfig, victim)
		end
	}

	config[mainConfig.Pathfinding.PathState]()
	return true
end