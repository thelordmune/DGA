--strict
local Modes = {
}


local TweenService = game:GetService("TweenService")


--Apear
function Modes.SizeUp(Part : BasePart, Settings : {}, Properties)
	local PartSize = Part.Size
	Part.Size = vector.create(0,0,0)
	
	TweenService:Create(
		Part,
		TweenInfo.new(Settings.Speed, Settings.EasingStyle, Settings.EasingDirection),
		{Size = PartSize}
	):Play()
	
end

function Modes.Elevate(Part : BasePart, Settings : {}, Properties)
	Part.CFrame *= CFrame.new(0, -3, 0)

	TweenService:Create(
		Part,
		TweenInfo.new(Settings.Speed, Settings.EasingStyle, Settings.EasingDirection),
		Properties.Goal
	):Play()

end

-- Expand

function Modes.Expand(Part : BasePart, Settings : {}, Properties)
	Part.CFrame =  CFrame.new(Properties.midpos)

	TweenService:Create(
		Part,
		TweenInfo.new(Settings.Speed, Settings.EasingStyle, Settings.EasingDirection),
		Properties.Goal
	):Play()

end


--Disapear


-- CollapseExpa
function Modes.SizeDown(Part : BasePart, Settings : {})

	TweenService:Create(
		Part,
		TweenInfo.new(Settings.Speed, Settings.EasingStyle, Settings.EasingDirection),
		{Size = vector.create(0, 0, 0)}
	):Play()



end





return Modes
