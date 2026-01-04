-- Services
local Players = game:GetService("Players")

local Player = Players.LocalPlayer

local ragdollValues = {"RagDoll", "ragdoll", "Ragdoll", "ragDoll"}
local cancelRagdollValues = {"BeingCarried", "GetUp"}
local forceUp = {"GetUp", "ForcePickup"}

local disableStates = {
	Enum.HumanoidStateType.Seated,
	Enum.HumanoidStateType.GettingUp,
	Enum.HumanoidStateType.RunningNoPhysics,
	Enum.HumanoidStateType.Running,
	Enum.HumanoidStateType.Freefall,
	Enum.HumanoidStateType.StrafingNoPhysics,
	Enum.HumanoidStateType.PlatformStanding,
	Enum.HumanoidStateType.Flying,
	Enum.HumanoidStateType.Climbing,
	Enum.HumanoidStateType.FallingDown
}

local enableStates = {
	Enum.HumanoidStateType.Seated,
	Enum.HumanoidStateType.GettingUp,
	Enum.HumanoidStateType.RunningNoPhysics,
	Enum.HumanoidStateType.Running,
	Enum.HumanoidStateType.Freefall,
	Enum.HumanoidStateType.StrafingNoPhysics,
	Enum.HumanoidStateType.PlatformStanding,
	Enum.HumanoidStateType.Flying,
	Enum.HumanoidStateType.Climbing,
	Enum.HumanoidStateType.FallingDown
}

local rag: boolean = false

-- Helper function to check if character has a state
local function HasState(character: Model, stateName: string): boolean
	-- Check if character has the state attribute
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

local function doUp(character: Model)
	local humanoid = character:FindFirstChild("Humanoid") :: Humanoid
	if not humanoid then return end
	
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if rootPart then
		for _, v in rootPart:GetChildren() do
			if v:IsA("LinearVelocity") or v:IsA("BodyMover") then
				v:Destroy()
			end
		end
	end

	rag = false
	humanoid.AutoRotate = true
	for _, state in enableStates :: {Enum.HumanoidStateType} do
		humanoid:SetStateEnabled(state, true)
	end
	humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
end

local function updValues(character: Model)
	if not character then return end
	
	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart
	local humanoid = character:FindFirstChild("Humanoid") :: Humanoid
	
	if not humanoid or not humanoidRootPart then return end
	
	local ragdolled: boolean = false

	-- Check for ragdoll values
	for _, instance in ragdollValues do
		if character:FindFirstChild(instance) then
			ragdolled = true
			break
		end
	end

	-- Check for cancel ragdoll values
	for _, instance in cancelRagdollValues do
		if character:FindFirstChild(instance) then
			ragdolled = false
			break
		end
	end

	-- Handle ragdoll for both alive and dead states
	-- Death threshold is 1 HP (not 0) to prevent Roblox's death system from interfering
	local isDead = humanoid.Health <= 1 or humanoid:GetState() == Enum.HumanoidStateType.Dead or character:GetAttribute("IsDead")

	if ragdolled then
		if not rag then
			rag = true
			humanoid.AutoRotate = false

			for _, state in disableStates do
				humanoid:SetStateEnabled(state, false)
			end

			-- Check if recently reset (within 2 seconds) and apply downward velocity
			local lastReset = character:GetAttribute("LastReset")
			if lastReset and os.clock() - lastReset < 2 then
				local fallVelocity = Vector3.new(0, -50, 0)
				humanoidRootPart.AssemblyLinearVelocity = fallVelocity
			end

			-- Change to Physics state for ragdoll effect (works for both alive and dead)
			humanoid:ChangeState(Enum.HumanoidStateType.Physics)
		end
	else
		-- Only allow getting up if alive
		if rag and not isDead then
			doUp(character)
		end
	end
end

local function init(character: Model)
	-- Reset rag state for new character
	rag = false

	local humanoid = character:WaitForChild("Humanoid", 5)
	if not humanoid then return end

	character.ChildAdded:Connect(function(child: Instance)
		if table.find(ragdollValues, child.Name) or table.find(cancelRagdollValues, child.Name) or table.find(forceUp, child.Name) then
			if HasState(character, "Knocked") then
				return
			end
			if HasState(character, "Unconscious") then
				return
			end
			if table.find(forceUp, child.Name) then
				doUp(character)
			end
			updValues(character)
		end
	end)

	character.ChildRemoved:Connect(function(child: Instance)
		if table.find(ragdollValues, child.Name) or table.find(cancelRagdollValues, child.Name) or table.find(forceUp, child.Name) then
			if table.find(forceUp, child.Name) then
				doUp(character)
			end
			updValues(character)
		end
	end)

	-- Handle death ragdoll - ensure physics state is set when player dies
	-- Listen for IsDead attribute (custom death at 1 HP threshold)
	character:GetAttributeChangedSignal("IsDead"):Connect(function()
		if character:GetAttribute("IsDead") then
			-- Force physics state for death ragdoll
			rag = true
			humanoid.AutoRotate = false
			for _, state in disableStates do
				humanoid:SetStateEnabled(state, false)
			end
			humanoid:ChangeState(Enum.HumanoidStateType.Physics)
		end
	end)

	-- Fallback: Also handle Humanoid.Died in case it somehow fires
	humanoid.Died:Connect(function()
		-- Check if ragdoll value exists
		for _, ragdollName in ragdollValues do
			if character:FindFirstChild(ragdollName) then
				-- Force physics state for death ragdoll
				rag = true
				humanoid.AutoRotate = false
				for _, state in disableStates do
					humanoid:SetStateEnabled(state, false)
				end
				humanoid:ChangeState(Enum.HumanoidStateType.Physics)
				break
			end
		end
	end)
end

local RagdollHandling = {}

-- Initialize the ragdoll handling system
function RagdollHandling.Init()
	-- Initialize when character is added
	if Player.Character then
		init(Player.Character)
	end

	Player.CharacterAdded:Connect(function(character)
		init(character)
	end)
end

return RagdollHandling

