local module = {}

return function (args)
	local Start: Vector3 = args.Start
	local Direction: Vector3 = args.Direction
	local Params: RaycastParams = args.Params
	local Duration = args.Duration or 1
		
	local Hit = workspace:Raycast(Start, Direction, Params)
	
	local Distance = not Hit and Direction.Magnitude or (Hit.Position - Start).Magnitude
	local Offset =  CFrame.new(0, 0, -Distance / 2)

	--local visualizer = script.arrow:Clone()
	--visualizer.CFrame = CFrame.new(Start, Start + Direction) * Offset
	--visualizer.Size = Vector3.new(.1, .1, Distance)
	--visualizer.Color = Hit and Color3.new(0, 1, 0) or Color3.new(1, 0, 0)
	--visualizer.Transparency = 0.5
	--visualizer.Parent = workspace.FX
	--game.Debris:AddItem(visualizer, Duration)
	
	return Hit
end
