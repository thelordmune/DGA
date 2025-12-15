--Procedural Lightning Module. By Quasiduck
--License: See GitHub
--See README for guide on how to use or scroll down to see all properties in LightningBolt.new
--All properties update in real-time except PartCount which requires a new LightningBolt to change
--i.e. You can change a property at any time and it will still update the look of the bolt

local clock = os.clock

function DiscretePulse(input, s, k, f, t, min, max) --input should be between 0 and 1. See https://www.desmos.com/calculator/hg5h4fpfim for demonstration.
	return math.clamp(k / (2 * f) - math.abs((input - t * s + 0.5 * k) / f), min, max)
end

function NoiseBetween(x, y, z, min, max)
	return min + (max - min) * (math.noise(x, y, z) + 0.5)
end

function CubicBezier(p0, p1, p2, p3, t)
	return p0 * (1 - t) ^ 3 + p1 * 3 * t * (1 - t) ^ 2 + p2 * 3 * (1 - t) * t ^ 2 + p3 * t ^ 3
end

local BoltPart = Instance.new("Part")
BoltPart.TopSurface, BoltPart.BottomSurface = 0, 0
BoltPart.Anchored, BoltPart.CanCollide = true, false
BoltPart.Shape = "Cylinder"
BoltPart.Name = "BoltPart"
BoltPart.Material = Enum.Material.Neon
BoltPart.Color = Color3.new(1, 1, 1)
BoltPart.Transparency = 1

local xInverse = CFrame.lookAt(Vector3.new(), Vector3.new(1, 0, 0)):Inverse()

local LightningBolt = {}

local function MergeSettings(Original, Merge)
	local new = table.clone(Original)
	for k, v in next, Merge do
		if new[k] ~= nil then
			new[k] = v
		end
	end
	return new
end

local DefaultSettings = {
	-- Bolt Appearance
	Enabled = true,
	CurveSize0 = 0,
	CurveSize1 = 0,
	MinRadius = 0,
	MaxRadius = 2.4,
	Frequency = 1.25,
	AnimationSpeed = 7,
	Thickness = 3,
	MinThicknessMultiplier = 0.2,
	MaxThicknessMultiplier = 1,

	-- Bolt Kinetics
	MinTransparency = 0,
	MaxTransparency = 1,
	PulseSpeed = 2,
	PulseLength = 1000000,
	FadeLength = 0.2,
	ContractFrom = 0.5,

	-- Bolt Color
	Color = Color3.new(1, 1, 1),
	ColorOffsetSpeed = 3,
}

function LightningBolt.Create(Attachment0, Attachment1, Settings)
	Settings = Settings or {}
	local PartCount = Settings.PartCount or 30

	-- Merge user settings with defaults
	local branch = MergeSettings(DefaultSettings, Settings)

	-- Set attachments (not part of defaults since they're required params)
	branch.Attachment0 = Attachment0
	branch.Attachment1 = Attachment1

	-- Internal state (not user-configurable)
	branch.Parts = {}
	branch.PartsHidden = false
	branch.DisabledTransparency = 1
	branch.StartT = clock()
	branch.RanNum = math.random() * 100

	-- Create bolt parts
	local a0, a1 = Attachment0, Attachment1
	local parent = workspace.World.Visuals
	local p0, p1, p2, p3 =
		a0.WorldPosition,
	a0.WorldPosition + a0.WorldAxis * branch.CurveSize0,
	a1.WorldPosition - a1.WorldAxis * branch.CurveSize1,
	a1.WorldPosition
	local PrevPoint, bezier0 = p0, p0
	local MainBranchN = PartCount

	for i = 1, MainBranchN do
		local t1 = i / MainBranchN
		local bezier1 = CubicBezier(p0, p1, p2, p3, t1)
		local NextPoint = i ~= MainBranchN and (CFrame.lookAt(bezier0, bezier1)).Position or bezier1
		local BPart = BoltPart:Clone()
		task.delay(1/branch.PulseSpeed + .1, BPart.Destroy, BPart)
		BPart.Size = Vector3.new((NextPoint - PrevPoint).Magnitude, 0, 0)
		BPart.CFrame = CFrame.lookAt(0.5 * (PrevPoint + NextPoint), NextPoint) * xInverse
		BPart.Parent = parent
		BPart.Locked, BPart.CastShadow = true, false
		branch.Parts[i] = BPart
		PrevPoint, bezier0 = NextPoint, bezier1
	end

	return branch
end

local offsetAngle = math.cos(math.rad(90))

function LightningBolt.Init(ActiveBranches, _)
	for _, ThisBranch in ActiveBranches do
		if ThisBranch.Enabled == true then
			ThisBranch.PartsHidden = false
			local MinOpa, MaxOpa = 1 - ThisBranch.MaxTransparency, 1 - ThisBranch.MinTransparency
			local MinRadius, MaxRadius = ThisBranch.MinRadius, ThisBranch.MaxRadius
			local thickness = ThisBranch.Thickness
			local Parts = ThisBranch.Parts
			local PartsN = #Parts
			local RanNum = ThisBranch.RanNum
			local StartT = ThisBranch.StartT
			local spd = ThisBranch.AnimationSpeed
			local freq = ThisBranch.Frequency
			local MinThick, MaxThick = ThisBranch.MinThicknessMultiplier, ThisBranch.MaxThicknessMultiplier
			local a0, a1, CurveSize0, CurveSize1 =
				ThisBranch.Attachment0, ThisBranch.Attachment1, ThisBranch.CurveSize0, ThisBranch.CurveSize1
			local p0, p1, p2, p3 =
				a0.WorldPosition,
			a0.WorldPosition + a0.WorldAxis * CurveSize0,
			a1.WorldPosition - a1.WorldAxis * CurveSize1,
			a1.WorldPosition
			local timePassed = clock() - StartT
			local PulseLength, PulseSpeed, FadeLength =
				ThisBranch.PulseLength, ThisBranch.PulseSpeed, ThisBranch.FadeLength
			local Color = ThisBranch.Color
			local ColorOffsetSpeed = ThisBranch.ColorOffsetSpeed
			local contractf = 1 - ThisBranch.ContractFrom
			local PrevPoint, bezier0 = p0, p0

			if timePassed < (PulseLength + 1) / PulseSpeed then
				for i = 1, PartsN do
					--local spd = NoiseBetween(i/PartsN, 1.5, 0.1*i/PartsN, -MinAnimationSpeed, MaxAnimationSpeed) --Can enable to have an alternative animation which doesn't shift the noisy lightning "Texture" along the bolt
					local BPart = Parts[i]
					local t1 = i / PartsN
					local Opacity = DiscretePulse(t1, PulseSpeed, PulseLength, FadeLength, timePassed, MinOpa, MaxOpa)
					local bezier1 = CubicBezier(p0, p1, p2, p3, t1)
					local time = -timePassed --minus to ensure bolt waves travel from a0 to a1
					local input, input2 =
						(spd * time) + freq * 10 * t1 - 0.2 + RanNum * 4,
					5 * ((spd * 0.01 * time) / 10 + freq * t1) + RanNum * 4
					local noise0 = NoiseBetween(5 * input, 1.5, 5 * 0.2 * input2, 0, 0.1 * 2 * math.pi)
						+ NoiseBetween(0.5 * input, 1.5, 0.5 * 0.2 * input2, 0, 0.9 * 2 * math.pi)
					local noise1 = NoiseBetween(3.4, input2, input, MinRadius, MaxRadius)
						* math.exp(-5000 * (t1 - 0.5) ^ 10)
					local thicknessNoise = NoiseBetween(2.3, input2, input, MinThick, MaxThick)
					local NextPoint = i ~= PartsN
						and (CFrame.new(bezier0, bezier1) * CFrame.Angles(0, 0, noise0) * CFrame.Angles(
							math.acos(math.clamp(NoiseBetween(input2, input, 2.7, offsetAngle, 1), -1, 1)),
							0,
							0
							) * CFrame.new(0, 0, -noise1)).Position
						or bezier1

					if Opacity > contractf then
						BPart.Size = Vector3.new(
							(NextPoint - PrevPoint).Magnitude,
							thickness * thicknessNoise * Opacity,
							thickness * thicknessNoise * Opacity
						)
						BPart.CFrame = CFrame.lookAt(0.5 * (PrevPoint + NextPoint), NextPoint) * xInverse
						BPart.Transparency = 1 - Opacity
					elseif Opacity > contractf - 1 / (PartsN * FadeLength) then
						local interp = (1 - (Opacity - (contractf - 1 / (PartsN * FadeLength))) * PartsN * FadeLength)
							* (t1 < timePassed * PulseSpeed - 0.5 * PulseLength and 1 or -1)
						BPart.Size = Vector3.new(
							(1 - math.abs(interp)) * (NextPoint - PrevPoint).Magnitude,
							thickness * thicknessNoise * Opacity,
							thickness * thicknessNoise * Opacity
						)
						BPart.CFrame = CFrame.lookAt(
							PrevPoint + (NextPoint - PrevPoint) * (math.max(0, interp) + 0.5 * (1 - math.abs(interp))),
							NextPoint
						) * xInverse
						BPart.Transparency = 1 - Opacity
					else
						BPart.Transparency = 1
					end

					if typeof(Color) == "Color3" then
						BPart.Color = Color
					else --ColorSequence
						t1 = (RanNum + t1 - timePassed * ColorOffsetSpeed) % 1
						local keypoints = Color.Keypoints
						for _ = 1, #keypoints - 1 do --convert colorsequence onto lightning
							if keypoints[i].Time < t1 and t1 < keypoints[i + 1].Time then
								BPart.Color = keypoints[i].Value:lerp(
									keypoints[i + 1].Value,
									(t1 - keypoints[i].Time) / (keypoints[i + 1].Time - keypoints[i].Time)
								)
								break
							end
						end
					end

					PrevPoint, bezier0 = NextPoint, bezier1
				end
			else
				ThisBranch.Destroy()
			end
		else --Enabled = false
			if ThisBranch.PartsHidden == false then
				ThisBranch.PartsHidden = true
				local datr = ThisBranch.DisabledTransparency
				for i = 1, #ThisBranch.Parts do
					ThisBranch.Parts[i].Transparency = datr
				end
			end
		end
	end
end

return LightningBolt
