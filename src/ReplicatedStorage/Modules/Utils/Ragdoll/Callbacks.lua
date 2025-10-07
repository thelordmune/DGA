local Constraints = {}

for _, v in script.Parent.Constraints:GetChildren() do
	Constraints[v.Name] = require(v)
end

type Dictionary<i, v> = { [i]: v }

local function new(class: string | Instance, properties: Dictionary<string, any>)
	local object = (type(class) == "string") and Instance.new(class) or class

	for property: string, value: any in properties do
		object[property] = value
	end

	return object
end

return {
	Neck = function(character: Model)
		local torso = character:FindFirstChild("Torso")
		local head = character:FindFirstChild("Head")

		if (not torso) or not head then
			return
		end

		local neck = torso:FindFirstChild("Neck")

		if not neck then
			return
		end

		neck.Part0 = nil

		local attachment0 = new("Attachment", {
			Position = Vector3.new(0, 1, 0),
			Orientation = Vector3.new(-90, -180, 0),
			Name = "RagdollAttachment",
			Parent = torso,
		})

		local attachment1 = new("Attachment", {
			Position = Vector3.new(0, -0.5, 0),
			Orientation = Vector3.new(-90, -180, 0),
			Name = "RagdollAttachment",
			Parent = head,
		})

		new(Constraints.HeadSocket:Clone(), {
			Name = "ConstraintJoint",
			Attachment0 = attachment0,
			Attachment1 = attachment1,
			Parent = torso,
		})

		local collider = new("Part", {
			Size = Vector3.new(1, 0.5, 0.5),
			Shape = "Block",
			Massless = true,
			TopSurface = "Smooth",
			BottomSurface = "Smooth",
			formFactor = "Symmetric",
			Transparency = 1,
			Name = "Collision",
			Parent = head,
		})

		new("Weld", {
			Part0 = head,
			Part1 = collider,
			Parent = collider,
		})
	end,

	["Left Hip"] = function(character: Model)
		local torso = character:FindFirstChild("Torso")
		local leg = character:FindFirstChild("Left Leg")

		if (not torso) or not leg then
			return
		end

		local hip = torso:FindFirstChild("Left Hip")

		if not hip then
			return
		end

		hip.Part0 = nil

		local attachment0 = new("Attachment", {
			Position = Vector3.new(-1, -1, 0),
			Orientation = Vector3.new(0, -90, 0),
			Name = "RagdollAttachment",
			Parent = torso,
		})

		local attachment1 = new("Attachment", {
			Position = Vector3.new(-0.5, 1, 0),
			Orientation = Vector3.new(0, -90, 0),
			Name = "RagdollAttachment",
			Parent = leg,
		})

		new(Constraints.LeftHip:Clone(), {
			Name = "ConstraintJoint",
			Attachment0 = attachment0,
			Attachment1 = attachment1,
			Parent = torso,
		})

		local collider = new("Part", {
			Size = Vector3.new(0.5, 1, 0.5),
			Shape = "Block",
			Massless = true,
			TopSurface = "Smooth",
			BottomSurface = "Smooth",
			formFactor = "Symmetric",
			Transparency = 1,
			Name = "Collision",
			Parent = leg,
		})

		new("Weld", {
			Part0 = leg,
			Part1 = collider,
			C0 = CFrame.new(0, -0.2, 0) * CFrame.fromEulerAnglesXYZ(0, 0, math.pi / 2),
			Parent = collider,
		})
	end,

	["Right Hip"] = function(character: Model)
		local torso = character:FindFirstChild("Torso")
		local leg = character:FindFirstChild("Right Leg")

		if (not torso) or not leg then
			return
		end

		local hip = torso:FindFirstChild("Right Hip")

		if not hip then
			return
		end

		hip.Part0 = nil

		local attachment0 = new("Attachment", {
			Position = Vector3.new(1, -1, 0),
			Orientation = Vector3.new(0, 90, 0),
			Name = "RagdollAttachment",
			Parent = torso,
		})

		local attachment1 = new("Attachment", {
			Position = Vector3.new(0.5, 1, 0),
			Orientation = Vector3.new(0, 90, 0),
			Name = "RagdollAttachment",
			Parent = leg,
		})

		new(Constraints.RightHip:Clone(), {
			Name = "ConstraintJoint",
			Attachment0 = attachment0,
			Attachment1 = attachment1,
			Parent = torso,
		})

		local collider = new("Part", {
			Size = Vector3.new(0.5, 1, 0.5),
			Shape = "Block",
			Massless = true,
			TopSurface = "Smooth",
			BottomSurface = "Smooth",
			formFactor = "Symmetric",
			Transparency = 1,
			Name = "Collision",
			Parent = leg,
		})

		new("Weld", {
			Part0 = leg,
			Part1 = collider,
			C0 = CFrame.new(0, -0.2, 0) * CFrame.fromEulerAnglesXYZ(0, 0, math.pi / 2),
			Parent = collider,
		})
	end,

	["Left Shoulder"] = function(character: Model)
		local torso = character:FindFirstChild("Torso")
		local arm = character:FindFirstChild("Left Arm")

		if (not torso) or not arm then
			return
		end

		local shoulder = torso:FindFirstChild("Left Shoulder")

		if not shoulder then
			return
		end

		shoulder.Part0 = nil

		local attachment0 = new("Attachment", {
			Position = Vector3.new(-1, 0.5, 0),
			Orientation = Vector3.new(0, -90, 0),
			Name = "RagdollAttachment",
			Parent = torso,
		})

		local attachment1 = new("Attachment", {
			Position = Vector3.new(0.5, 0.5, 0),
			Orientation = Vector3.new(0, -90, 0),
			Name = "RagdollAttachment",
			Parent = arm,
		})

		new(Constraints.LeftShoulder:Clone(), {
			Name = "ConstraintJoint",
			Attachment0 = attachment0,
			Attachment1 = attachment1,
			Parent = torso,
		})

		local collider = new("Part", {
			Size = Vector3.new(0.5, 1, 0.5),
			Shape = "Block",
			Massless = true,
			TopSurface = "Smooth",
			BottomSurface = "Smooth",
			formFactor = "Symmetric",
			Transparency = 1,
			Name = "Collision",
			Parent = arm,
		})

		new("Weld", {
			Part0 = arm,
			Part1 = collider,
			C0 = CFrame.new(0, -0.2, 0) * CFrame.fromEulerAnglesXYZ(0, 0, math.pi / 2),
			Parent = collider,
		})
	end,

	["Right Shoulder"] = function(character: Model)
		local torso = character:FindFirstChild("Torso")
		local arm = character:FindFirstChild("Right Arm")

		if (not torso) or not arm then
			return
		end

		local shoulder = torso:FindFirstChild("Right Shoulder")

		if not shoulder then
			return
		end

		shoulder.Part0 = nil

		local attachment0 = new("Attachment", {
			Position = Vector3.new(1, 0.5, 0),
			Orientation = Vector3.new(0, 90, 0),
			Name = "RagdollAttachment",
			Parent = torso,
		})

		local attachment1 = new("Attachment", {
			Position = Vector3.new(-0.5, 0.5, 0),
			Orientation = Vector3.new(0, 90, 0),
			Name = "RagdollAttachment",
			Parent = arm,
		})

		new(Constraints.RightShoulder:Clone(), {
			Name = "ConstraintJoint",
			Attachment0 = attachment0,
			Attachment1 = attachment1,
			Parent = torso,
		})

		local collider = new("Part", {
			Size = Vector3.new(0.5, 1, 0.5),
			Shape = "Block",
			Massless = true,
			TopSurface = "Smooth",
			BottomSurface = "Smooth",
			formFactor = "Symmetric",
			Transparency = 1,
			Name = "Collision",
			Parent = arm,
		})

		new("Weld", {
			Part0 = arm,
			Part1 = collider,
			C0 = CFrame.new(0, -0.2, 0) * CFrame.fromEulerAnglesXYZ(0, 0, math.pi / 2),
			Parent = collider,
		})
	end,
} :: Dictionary<string, (Model)>
