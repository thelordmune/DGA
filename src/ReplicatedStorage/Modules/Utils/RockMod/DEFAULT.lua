return {
	Rising = {
		
		
		Size = {.65, 1.25},
		RotationalForce = {45,65},
		PartCount = 10,
		Force = 10,
		SpreadAngle = 5,
		Radius = 5,
		RaycastLength = 30,
		IterationDelay = nil,
		LifeTime = 5,
		Info = TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		LifeCycle = {
			Entrance = {
				Type = 'SizeUp',
				Speed = .55,
				Division = 3,
				EasingStyle = Enum.EasingStyle.Sine,
				EasingDirection = Enum.EasingDirection.In

			},

			Exit = {
				Type = 'SizeDown',
				Speed = .3,
				Division = 2,
				EasingStyle = Enum.EasingStyle.Sine,
				EasingDirection = Enum.EasingDirection.In
			},

		}
	},
	
	Normal = {
		Size = {.25, .75},
		RotationalForce = {45,65},
		PartCount = 10,
		Radius = 9,
		UpForce = {2, 10},
		Spread = {2, 2},
		RaycastLength = 30,
		IterationDelay = nil,
		LifeTime = 5,
		LifeCycle = {
			Entrance = {
				Type = 'SizeUp',
				Speed = .15,
				Division = 3,
				EasingStyle = Enum.EasingStyle.Sine,
				EasingDirection = Enum.EasingDirection.In

			},
			
			Exit = {
				Type = 'SizeDown',
				Speed = .3,
				Division = 2,
				EasingStyle = Enum.EasingStyle.Sine,
				EasingDirection = Enum.EasingDirection.In
			},
			
		}
		
	},
	
	Orbit  = {
		Size = {2, 3.5},
		PartCount = 6,
		Radius = 8,
		CircleFraction = 1,
		RaycastLength = 30,
		IterationDelay = nil,
		LifeTime = 5,
		Height = {0, 0},
		Tilt = {0, 0},
		Angle = {45, 65},
		PartOffset = {0, 0},
		LifeCycle = {
			Entrance = {
				Type = 'SizeUp',
				Speed = .15,
				Division = 3,
				EasingStyle = Enum.EasingStyle.Sine,
				EasingDirection = Enum.EasingDirection.In

			},

			Exit = {
				Type = 'SizeDown',
				Speed = .3,
				Division = 2,
				EasingStyle = Enum.EasingStyle.Sine,
				EasingDirection = Enum.EasingDirection.In
			},

		}
	},
	
	Crater  = {
		SizeMultiplier = .65,
		PartCount = 6,
		SizeRandomness = true,
		RaycastLength = 30,
		Layers = {1, 1},
		Distance = {4, 5},
		LifeTime = 5,
		ExitIterationDelay = { 0.5, 1 },
		
		LifeCycle = {
			Entrance = {
				Type = 'Expand',
				Speed = .2,
				Division = 3,
				EasingStyle = Enum.EasingStyle.Quad,
				EasingDirection = Enum.EasingDirection.Out

			},

			Exit = {
				Type = 'SizeDown',
				Speed = .7,
				ExitIterationDelay = {0, 0},
				EasingStyle = Enum.EasingStyle.Sine,
				EasingDirection = Enum.EasingDirection.In
			},

		}
	}
}