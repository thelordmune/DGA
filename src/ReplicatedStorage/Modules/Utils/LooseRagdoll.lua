--[[
	Loose Ragdoll System with BallSocketConstraints
	Creates ragdoll effect by replacing Motor6Ds with BallSocketConstraints
--]]

local LooseRagdoll = {}

-- Store original Motor6D data for restoration
local ragdollData = {}

-- Create BallSocketConstraint to replace a Motor6D
local function createBallSocket(motor6D)
	-- Skip the root joint to keep character stable
	if motor6D.Name == "Root" or motor6D.Name == "RootJoint" then
		return nil
	end

	local ballSocket = Instance.new("BallSocketConstraint")
	ballSocket.Name = motor6D.Name .. "_Ragdoll"

	-- Create attachments at the same positions as the Motor6D
	local att0 = Instance.new("Attachment")
	att0.Name = "RagdollAtt0"
	att0.CFrame = motor6D.C0
	att0.Parent = motor6D.Part0

	local att1 = Instance.new("Attachment")
	att1.Name = "RagdollAtt1"
	att1.CFrame = motor6D.C1
	att1.Parent = motor6D.Part1

	ballSocket.Attachment0 = att0
	ballSocket.Attachment1 = att1
	ballSocket.LimitsEnabled = true
	ballSocket.UpperAngle = 45 -- Allow some movement but not too loose
	ballSocket.TwistLimitsEnabled = true
	ballSocket.TwistLowerAngle = -45
	ballSocket.TwistUpperAngle = 45
	ballSocket.Parent = motor6D.Part0

	return ballSocket, att0, att1
end

-- Apply ragdoll to character
local function applyRagdoll(character, duration)
	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid then return end

	-- Store ragdoll data for this character
	ragdollData[character] = {
		motors = {},
		ballSockets = {},
		attachments = {},
		originalState = humanoid:GetState()
	}

	-- Change humanoid state to Physics so character falls down
	humanoid:ChangeState(Enum.HumanoidStateType.Physics)

	-- Find all Motor6Ds and replace with BallSockets
	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("Motor6D") then
			local ballSocket, att0, att1 = createBallSocket(descendant)

			if ballSocket then
				-- Store original motor data
				table.insert(ragdollData[character].motors, {
					motor = descendant,
					enabled = descendant.Enabled
				})

				-- Store created constraints/attachments for cleanup
				table.insert(ragdollData[character].ballSockets, ballSocket)
				table.insert(ragdollData[character].attachments, att0)
				table.insert(ragdollData[character].attachments, att1)

				-- Disable the motor
				descendant.Enabled = false

				print(`[LooseRagdoll] Created BallSocket for {descendant.Name}`)
			end
		end
	end

	print(`[LooseRagdoll] Ragdoll applied to {character.Name} for {duration} seconds`)

	-- Restore after duration
	task.delay(duration, function()
		if ragdollData[character] then
			local humanoid = character:FindFirstChild("Humanoid")

			-- Remove all BallSockets and attachments
			for _, ballSocket in ipairs(ragdollData[character].ballSockets) do
				if ballSocket and ballSocket.Parent then
					ballSocket:Destroy()
				end
			end

			for _, attachment in ipairs(ragdollData[character].attachments) do
				if attachment and attachment.Parent then
					attachment:Destroy()
				end
			end

			-- Re-enable motors
			for _, motorData in ipairs(ragdollData[character].motors) do
				if motorData.motor and motorData.motor.Parent then
					motorData.motor.Enabled = motorData.enabled
				end
			end

			-- Restore humanoid state (back to normal standing)
			if humanoid then
				humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
			end

			-- Clear data
			ragdollData[character] = nil

			print(`[LooseRagdoll] Ragdoll removed from {character.Name}`)
		end
	end)
end

-- Main ragdoll function
function LooseRagdoll.Ragdoll(character: Model, duration: number)
	if not character or not character:FindFirstChild("Humanoid") then
		warn("[LooseRagdoll] Invalid character")
		return false
	end

	local humanoid = character:FindFirstChild("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not rootPart then return false end

	-- Check PrimaryPart before ragdoll
	if not character.PrimaryPart then
		warn("[LooseRagdoll] Character has no PrimaryPart!")
		return false
	end

	print(`[LooseRagdoll] Applying ragdoll to {character.Name}`)

	-- Apply ragdoll
	applyRagdoll(character, duration)

	return true
end

return LooseRagdoll

