local function new(class: string, properties: { [string]: any })
	local object = Instance.new(class)

	for property: string, value: any in properties do
		object[property] = value
	end

	return object
end

return new("BallSocketConstraint", {
	Name = "Neck",
	LimitsEnabled = true,
	Restitution = 0,
	TwistLimitsEnabled = true,
	UpperAngle = 40,
	TwistUpperAngle = -45,
	TwistLowerAngle = 40,
}) :: BallSocketConstraint
