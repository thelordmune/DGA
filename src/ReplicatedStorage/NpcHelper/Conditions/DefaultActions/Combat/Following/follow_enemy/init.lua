local getPathState = require(script.GetPathState)
local pathfinding = require(script.Pathfinding)

local raycastParams: RaycastParams do
	raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = {workspace.World.Visuals,workspace.World.Live}
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
end

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
			{name = "Direct",weight = 6}, --3/6 -> 50%
			{name = "Strafe",weight = 2}, --1/6 -> 17%
			{name = "SideApproach",weight = 8}, --2/6 -> 33%
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
	-- Don't create AlignOrientation during attacks to prevent choppy movement
	local Server = require(game:GetService("ServerScriptService").ServerConfig.Server)
	if Server.Library.StateCheck(npc.Actions, "Attacking") then
		return nil
	end

	--task.synchronize()
	local alignOrientation = npc.PrimaryPart:FindFirstChild("AlignOrient")

	-- Only create if it doesn't exist
	if not alignOrientation then
		alignOrientation = Instance.new("AlignOrientation") :: AlignOrientation
		alignOrientation.Name = "AlignOrient"
		alignOrientation.MaxTorque = 1000000
		alignOrientation.Responsiveness = 100
		alignOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
		alignOrientation.Enabled = true
		alignOrientation.Attachment0 = npc.PrimaryPart.RootAttachment
		alignOrientation.Parent = npc.PrimaryPart
	end

	-- Update the angle to face target
	local diff = (mainConfig.getNpcCFrame().Position - mainConfig.getTargetCFrame().Position)
	local angle = math.atan2(diff.X, diff.Z)
	alignOrientation.CFrame = CFrame.Angles(0, angle, 0)

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

	-- Check if NPC is performing an action - if so, stop movement to prevent choppy behavior
	local Server = require(game:GetService("ServerScriptService").ServerConfig.Server)
	local actions = npc:FindFirstChild("Actions")
	if actions and Server.Library.StateCount(actions) then
		-- NPC is performing an action (attacking, using skill, etc.) - stop movement
		humanoid:Move(Vector3.new(0, 0, 0))
		clearAlignOrientation(npc)
		return true -- Return true so behavior tree knows we're still following, just paused
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


	local PathState: PathState = "";

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
					--print("follow")
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
							return toTarget -- ((mainConfig.getTargetCFrame() * CFrame.new(0,0,-4)).Position - mainConfig.getNpcCFrame().Position)
						end
					}

					local currentPattern = updateMovementPattern(mainConfig)
					--print(currentPattern)
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

			local DISTANCE_TO_STOP_FOLLOWING_AT: number = 6; -- Increased from 2.5 to maintain better spacing
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

	local raycastResults: RaycastResult = workspace:Raycast(RootPosition,UnitVector * MagnitudeIndex,raycastParams)
	if raycastResults and raycastResults.Position then
		local Difference: any = (raycastResults.Position-(RootPosition + (UnitVector * MagnitudeIndex))).Magnitude
		if Difference > 5 then
			Pass = 2;
		end
	end
	local AiFolder: Folder = mainConfig.getMimic()
	if humanoid.FloorMaterial ~= Enum.Material.Air and humanoid.FloorMaterial ~= nil and Pass ~= AiFolder.PathState.Value then
		--task.synchronize()
		AiFolder.StateId.Value = math.random(1,9999);
		AiFolder.PathState.Value = Pass;
		--task.desynchronize()
		if Pass == 2 then 
			print(" pathfind then gang")
			config.Pathfind()
		end
	end
	if Pass == 1 then
		config.Direct()
	end

	return true
end