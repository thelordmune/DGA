local Ragdoller = {}

type Dictionary<i, v> = { [i]: v }
type Array<v> = Dictionary<number, v>

local RunService = game:GetService("RunService")
local Callbacks: Dictionary<string, Model> = require(script.Callbacks) :: Dictionary<string, Model>

-- Helper function to create instances with properties
local function NewInstance(class: string, properties: Dictionary<string, any>)
	local object = Instance.new(class)
	for property, value in properties do
		object[property] = value
	end
	return object
end

-- Helper function to check if character has a state (compatible with your ECS system)
local function HasState(character: Model, stateName: string): boolean
	-- Check if character has the state attribute or folder
	if character:GetAttribute(stateName) then
		return character:GetAttribute(stateName) > 0
	end

	-- Check in state folders (Actions, Stuns, etc.)
	local stateContainers = {"Actions", "Stuns", "Speeds", "Frames", "Statuses"}
	for _, containerName in stateContainers do
		local container = character:FindFirstChild(containerName)
		if container and container:FindFirstChild(stateName) then
			return true
		end
	end

	return false
end

-- Simple ragdoll function for direct use (duration-based)
function Ragdoller.Ragdoll(character: Model, duration: number)
	if not character or not character:FindFirstChild("Humanoid") then
		warn("[Ragdoll] Invalid character")
		return false
	end

	Ragdoller:Enable(character)

	task.delay(duration, function()
		if character and character.Parent then
			Ragdoller:Disable(character)
		end
	end)

	return true
end

function Ragdoller:Setup(Character)
	local Humanoid = Character:WaitForChild("Humanoid") :: Humanoid

	-- Use character directly for attributes (no PlayerStates folder)
	local connections = {}

	-- Listen for Ragdoll attribute changes
	connections[#connections + 1] = Character:GetAttributeChangedSignal("Ragdoll"):Connect(function()
		if HasState(Character, "Knocked") then
			return
		end
		if Character:GetAttribute("Ragdoll") and Character:GetAttribute("Ragdoll") > 0 then
			Ragdoller:Enable(Character)
		else
			Ragdoller:Disable(Character)
		end
	end)

	-- Listen for Knocked state changes
	connections[#connections + 1] = Character:GetAttributeChangedSignal("Knocked"):Connect(function()
		if Character:GetAttribute("Knocked") and Character:GetAttribute("Knocked") > 0 then
			Ragdoller:Enable(Character)
		else
			Ragdoller:Disable(Character)
		end
	end)

	-- Listen for Unconscious state changes
	connections[#connections + 1] = Character:GetAttributeChangedSignal("Unconscious"):Connect(function()
		if Character:GetAttribute("Unconscious") and Character:GetAttribute("Unconscious") > 0 then
			Ragdoller:Enable(Character)
		else
			Ragdoller:Disable(Character)
		end
	end)

	-- Cleanup on death
	connections[#connections + 1] = Humanoid.Died:Connect(function()
		for _, connection: RBXScriptConnection in connections :: {RBXScriptConnection} do
			connection:Disconnect()
		end
		table.clear(connections)
	end)
end

function Ragdoller:Enable(character: Model)
	if character:FindFirstChild("Ragdoll") then
		return
	end
	if HasState(character, "Hyperarmour") or HasState(character, "Hyperarmor") then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid") :: Humanoid

	local Ragdoll = NewInstance("BoolValue", {Name = "Ragdoll", Parent = character}) :: BoolValue

	humanoid.PlatformStand = true
	humanoid.AutoRotate = false
	humanoid.RequiresNeck = false

	if character:FindFirstChild("NoRagdollEffect") == nil then
		for _, v in character:GetDescendants() do
			if (v:IsA("Motor6D") or v:IsA("Weld")) and v:GetAttribute("C0Position") == nil then
				local X0, Y0, Z0 = v.C0:ToEulerAnglesXYZ()
				local X1, Y1, Z1 = v.C1:ToEulerAnglesXYZ()

				v:SetAttribute("C0Position", Vector3.new(v.C0.X, v.C0.Y, v.C0.Z))
				v:SetAttribute("C0Angle", Vector3.new(X0, Y0, Z0))

				v:SetAttribute("C1Position", Vector3.new(v.C1.X, v.C1.Y, v.C1.Z))
				v:SetAttribute("C1Angle", Vector3.new(X1, Y1, Z1))
			end

			if v:IsA("Motor6D") then
				local callback: any = Callbacks[v.Name]
				if callback then
					callback(character)
				end
			end
		end
	end

end

function Ragdoller:Disable(character: Model)
	if not character:FindFirstChild("Ragdoll") then
		return
	end

	if character:FindFirstChild("Ragdoll") then
		character.Ragdoll:Destroy()
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid") :: Humanoid
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	local old_rotation = rootPart.Orientation

	for _, v in character:GetDescendants() do
		if v:IsA("Motor6D") then
			if
				v.Name == "Right Shoulder"
				or v.Name == "Right Hip"
				or v.Name == "Left Shoulder"
				or v.Name == "Left Hip"
				or v.Name == "Neck"
			then
				v.Part0 = character.Torso
			end
		elseif v.Name == "RagdollAttachment" or v.Name == "ConstraintJoint" or v.Name == "Collision" then
			v:Destroy()
		end

		if (v:IsA("Motor6D") or v:IsA("Weld")) and v:GetAttribute("C0Position") ~= nil then
			local C0Position = v:GetAttribute("C0Position")
			local C1Position = v:GetAttribute("C1Position")
			local C0Angle = v:GetAttribute("C0Angle")
			local C1Angle = v:GetAttribute("C1Angle")

			v.C0 = CFrame.new(C0Position.X, C0Position.Y, C0Position.Z) * CFrame.Angles(C0Angle.X, C0Angle.Y, C0Angle.Z)
			v.C1 = CFrame.new(C1Position.X, C1Position.Y, C1Position.Z) * CFrame.Angles(C1Angle.X, C1Angle.Y, C1Angle.Z)
		end
	end

	humanoid.PlatformStand = false
	humanoid.AutoRotate = true

	task.delay(1, function()
		if humanoid then
			humanoid.RequiresNeck = true
		end
	end)

	-- Fix for a roblox bug that messes with the character's motors if they get rebuilt by a script
	pcall(function()
		-- Roots
		rootPart.RootJoint.C0 = CFrame.Angles(-math.pi / 2, 0, -math.pi)
		rootPart["Root Hip"].C0 = CFrame.Angles(-math.pi / 2, 0, -math.pi)
		rootPart["Root Hip"].C1 = CFrame.Angles(-math.pi / 2, 0, -math.pi)

		-- Hips
		character.Torso["Right Hip"].C0 = CFrame.new(1, -1, 0) * CFrame.Angles(0, math.pi / 2, 0)
		character.Torso["Left Hip"].C0 = CFrame.new(-1, -1, 0) * CFrame.Angles(0, -math.pi / 2, 0)

		-- Shoulders
		character.Torso["Right Shoulder"].C0 = CFrame.new(1, 0.5, 0) * CFrame.Angles(0, math.pi / 2, 0)
		character.Torso["Left Shoulder"].C0 = CFrame.new(-1, 0.5, 0) * CFrame.Angles(0, -math.pi / 2, 0)

		-- Heads
		character.Torso["Neck"].C0 = CFrame.new(0, 1, 0) * CFrame.Angles(-math.pi / 2, 0, -math.pi)
	end)

	rootPart.CFrame = CFrame.new(rootPart.Position + Vector3.new(0, 1.75, 0)) * CFrame.Angles(0, math.rad(old_rotation.Y), 0)

end

return Ragdoller