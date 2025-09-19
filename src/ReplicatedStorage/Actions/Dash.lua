return function(character: Model, data: SkillData, ActionData, Skill_Setup)
	local root = character.PrimaryPart

	print(`{character.Name} is now doing the {data.skill} skill || timestamp: {data.timestamp}`) do
		local attackingValue = Instance.new("StringValue") :: StringValue
		attackingValue.Name = "Attacking"
		attackingValue.Value = data.skill
		attackingValue.Parent = character
		task.delay(ActionData.Windup, attackingValue.Destroy, attackingValue)
	end

	local humanoid = character:FindFirstChild("Humanoid")

	local moveDirection = humanoid.MoveDirection
	if moveDirection.Magnitude < 0.01 then
		return
	end
	
	
	local animationIndex = ((moveDirection:Dot(root.CFrame.LookVector * 1) >= .5 and "WDash") 
		or (moveDirection:Dot(root.CFrame.LookVector * -1) >= .5 and "SDash")) 
		or ((moveDirection:Dot(root.CFrame.RightVector * 1) >= .75 and "DDash")
			or (moveDirection:Dot(root.CFrame.RightVector * -1) >= .75 and "ADash")) or "SDash"

	local ang_direction = 180
	ang_direction = animationIndex == "ADash" and 
		90 or animationIndex == "DDash" and -90 or
		animationIndex == "SDash" and 180 or 0
	local Velocity = Instance.new("LinearVelocity")
	task.delay(.3 , Velocity.Destroy, Velocity)
	Velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	Velocity.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	Velocity.ForceLimitsEnabled = true
	Velocity.MaxAxesForce = Vector3.new(4e4, 0, 4e4)
	Velocity.VectorVelocity = (root.CFrame * CFrame.Angles(0, math.rad(ang_direction), 0)).LookVector * 60-- moveDirection * 0
	Velocity.Attachment0 = root:FindFirstChild("RootAttachment")
	Velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	Velocity.Parent = root
		
		
		warn("dADSSHESDDD")
	ActionData.Last_Used = os.clock()
end