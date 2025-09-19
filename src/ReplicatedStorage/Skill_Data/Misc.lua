return {
	Bike = {
		Connections = {},
		SoundLoop = nil,

		Cooldown = 1,
		Last_Used = 0,

		TopSpeed = 35,
		TurnSpeed = 1.5,
		Acceleration = {[-1] = 30, [0] = 0, [1] = 50},
		Damp = 0.6,
	},
	EatFood = {
		Cooldown = 1,
		Last_Used = 0,
		Connections = {}
	},
	ToggleAccessory = {
		Cooldown = 1,
		Last_Used = 0,
		Connections = {}
	},
	AerialDash = {
		Cooldown = 1,
		Last_Used = 0
	},
	Dash = {
		Stamina=15,
		Cooldown = 1.75,
		Last_Used = 0,
	},
	Charging = {
		Cooldown = 1,
		Last_Used = 0,
	},
	WallRun = {
		Cooldown = 1,
		Last_Used = 0,
	},
	Sliding = {
		Cooldown = 1,
		Last_Used = 0,
	},
	Carry = {
		Cooldown = .5,
		Last_Used = 0,

		Victim = nil,
		Connections = {}
	},
	Grip = {
		Cooldown = .25,
		Last_Used = 0,
		
		Thread = nil,
		Victim = nil,
		Connections = {}
	},
	DoubleJump = {
		Stamina=10,
		Cooldown = 2,
		Last_Used = 0,
	},
}