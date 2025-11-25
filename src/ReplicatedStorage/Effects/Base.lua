-- Services
local Players = game:GetService("Players")
local StarterPack = game:GetService("StarterPack")
local TweenService = game:GetService("TweenService")
local Replicated = game:GetService("ReplicatedStorage")

-- Modules
local Misc = require(script.Parent.Misc)
local Library = require(Replicated.Modules.Library)
local Utilities = require(Replicated.Modules.Utilities)
local Debris = Utilities.Debris
local RockMod = require(Replicated.Modules.Utils.RockMod)
local EmitModule = require(game.ReplicatedStorage.Modules.Utils.EmitModule)

-- Variables
local Player = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local VFX = Replicated:WaitForChild("Assets").VFX
local SFX = Replicated:WaitForChild("Assets").SFX
local CamShake = require(Replicated.Modules.Utils.CamShake)

local Fusion = require(Replicated.Modules.Fusion)
local Children, scoped, peek, out = Fusion.Children, Fusion.scoped, Fusion.peek, Fusion.Out

local world = require(Replicated.Modules.ECS.jecs_world)
local ref = require(Replicated.Modules.ECS.jecs_ref)
local comps = require(Replicated.Modules.ECS.jecs_components)
local RunService = game:GetService("RunService")

local TInfo = TweenInfo.new(0.35, Enum.EasingStyle.Circular, Enum.EasingDirection.Out, 0)

-- Store original trail WidthScale values (so they persist across multiple dashes)
local originalTrailWidths = {}

local Base = {}

function Base.Emit(ToEmit)
	if ToEmit:IsA("ParticleEmitter") then
		if ToEmit:GetAttribute("EmitDelay") and ToEmit:GetAttribute("EmitDelay") > 0 then
			task.delay(ToEmit:GetAttribute("EmitDelay"), function()
				ToEmit:Emit(ToEmit:GetAttribute("EmitCount"))
			end)
		else
			ToEmit:Emit(ToEmit:GetAttribute("EmitCount"))
		end
	else
		for i, v in ToEmit:GetDescendants() do
			if v:IsA("ParticleEmitter") and not v:GetAttribute("Ignore") then
				if v:GetAttribute("EmitDelay") and v:GetAttribute("EmitDelay") > 0 then
					task.delay(v:GetAttribute("EmitDelay"), function()
						v:Emit(v:GetAttribute("EmitCount"))
					end)
				else
					v:Emit(v:GetAttribute("EmitCount"))
				end
			end
		end
	end
end

function Base.Slashes(Character: Model, Weapon: string, Combo: number)
	local Slash: BasePart = Replicated.Assets.VFX[Weapon .. "Slashes"][Combo]:Clone()

	-- Store the original orientation (angular rotation) of the slash
	-- local originalOrientation = Slash.Orientation

	-- Position the slash in front of the player and make it face the player's direction
	local playerCFrame = Character.HumanoidRootPart.CFrame

	if Weapon == "Fist" then
		if Combo == 1 then
		Slash.CFrame = playerCFrame * CFrame.new(0, 0, -1) * CFrame.Angles(0,0,math.rad(-77))
		elseif Combo == 2 then
			Slash.CFrame = playerCFrame * CFrame.new(0, 0, -1) * CFrame.Angles(0,math.rad(-30),math.rad(-77))
		elseif Combo == 3 then
			Slash.CFrame = playerCFrame * CFrame.new(0, 0, -1) * CFrame.Angles(0,0,math.rad(-62))
		elseif Combo == 4 then
			Slash.CFrame = playerCFrame * CFrame.new(0, 0, -1) * CFrame.Angles(0,0,math.rad(87))
		end

	end

	-- Reapply the original angular orientation while preserving the player's facing direction
	-- Slash.Orientation = originalOrientation + Vector3.new(0, playerCFrame.Rotation.Y * (180 / math.pi), 0)

	Slash.Parent = workspace.World.Visuals

	for _, v in Slash:GetDescendants() do
		if v:IsA("ParticleEmitter") then
			v:Emit(v:GetAttribute("EmitCount"))
		end
	end

	Debris:AddItem(Slash, 3)
end

function Base.PerfectDodge(Character: Model)
	for i, v in pairs(Replicated.Assets.VFX.PerfectDodge2:GetChildren()) do
		local Clone = v:Clone()
		Clone:Emit(Clone:GetAttribute("EmitCount"))
		Clone.Parent = Character.HumanoidRootPart

		Debris:AddItem(Clone, Clone.Lifetime.Max)
	end
end

function Base.Block(Character: Model)
	local BlockAttachment = VFX.Blocked.Attachment:Clone()
	BlockAttachment.Parent = Character.HumanoidRootPart

	Misc.Emit(BlockAttachment)
end

function Base.CriticalIndicator(Character: Model)
	local crit = Replicated.Assets.VFX.CritFX:Clone()
	crit.Parent = Character.HumanoidRootPart
	crit.CFrame = Character.HumanoidRootPart.CFrame

	for _, v in crit:GetDescendants() do
		if v:IsA("ParticleEmitter") then
			if v:GetAttribute("EmitDelay") and v:GetAttribute("EmitDelay") > 0 then
				task.delay(v:GetAttribute("EmitDelay"), function()
					v:Emit(v:GetAttribute("EmitCount"))
				end)
			else
				v:Emit(v:GetAttribute("EmitCount"))
			end
		end
	end

	-- Add red highlight effect
	local highlight = Instance.new("Highlight")
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.FillColor = Color3.fromRGB(255, 0, 0)
	highlight.FillTransparency = 0.5
	highlight.OutlineTransparency = 0.3
	highlight.OutlineColor = Color3.fromRGB(255, 50, 50)
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Parent = Character

	local TInfo = TweenInfo.new(0.5, Enum.EasingStyle.Circular, Enum.EasingDirection.InOut, 0)

	task.delay(0.1, function()
		local hTween = TweenService:Create(highlight, TInfo, {
			OutlineTransparency = 1,
			FillTransparency = 1,
		})
		hTween:Play()
		hTween.Completed:Connect(function()
			highlight:Destroy()
		end)
	end)
end

function Base.Clash(Character: Model, Enemy: Model)
	local ClashVFX = Replicated.Assets.VFX.ClashMain:Clone()
	ClashVFX:PivotTo(Character.HumanoidRootPart.CFrame * CFrame.new(0, 9.5, -3.03))
	ClashVFX.Parent = workspace.World.Visuals

	for i, v in pairs(ClashVFX:GetDescendants()) do
		if v:IsA("ParticleEmitter") then
			v:Emit(v:GetAttribute("EmitCount"))
		end
	end

	Debris:AddItem(ClashVFX, 5)

	task.wait(1)

	for i, v in pairs(ClashVFX:GetDescendants()) do
		if v:IsA("ParticleEmitter") then
			v.Enabled = false
		elseif v:IsA("PointLight") then
			TweenService:Create(v, TweenInfo.new(0.25, Enum.EasingStyle.Sine), { Range = 0 }):Play()
		end
	end

	if Character then
		local Drag = Replicated.Assets.VFX.ClashKnockbackVFX.Drag:Clone()
		Drag.Parent = Character.HumanoidRootPart

		Debris:AddItem(Drag, 3)

		task.delay(0.5, function()
			for i, v in pairs(Drag:GetChildren()) do
				v.Enabled = false
			end
		end)
	end

	if Enemy then
		local Drag = Replicated.Assets.VFX.ClashKnockbackVFX.Drag:Clone()
		Drag.Parent = Enemy.HumanoidRootPart

		Debris:AddItem(Drag, 3)

		task.delay(0.5, function()
			for i, v in pairs(Drag:GetChildren()) do
				v.Enabled = false
			end
		end)
	end
end

function Base.ClashFOV()
	TweenService:Create(Camera, TweenInfo.new(0.2, Enum.EasingStyle.Sine), { FieldOfView = 35 }):Play()

	task.spawn(function()
		while Library.StateCheck(Player.Character.Actions, "Clash") do
			task.wait()
			Misc.CameraShake("SmallSmall")
		end
	end)

	task.wait(0.2)

	TweenService:Create(Camera, TweenInfo.new(0.2, Enum.EasingStyle.Sine), { FieldOfView = 70 }):Play()
end

function Base.Parry(Character: Model, Target, Distance)
	print(`[PARRY VFX DEBUG] Called for {Character.Name} (parrier) vs {Target.Name} (parried)`)
	local Parry = VFX.Parry.Attachment:Clone()
	Parry.CFrame = Parry.CFrame
	Parry.Parent = Character.HumanoidRootPart

	local PointLight = VFX.Parry.PointLight:Clone()
	PointLight.Parent = Character.HumanoidRootPart
	print(`[PARRY VFX DEBUG] {Character.Name} - VFX spawned successfully`)

	coroutine.wrap(function()
		TweenService:Create(PointLight, TweenInfo.new(0.1), { Brightness = 8 }):Play()
		task.wait(0.5)
		TweenService:Create(PointLight, TweenInfo.new(0.5), { Brightness = 0 }):Play()
	end)()

	for i, v in pairs(Parry:GetChildren()) do
		if v:IsA("ParticleEmitter") then
			v:Emit(v:GetAttribute("EmitCount"))
		end
	end

	Debris:AddItem(Parry, 6)
	Debris:AddItem(PointLight, 3)
end

function Base.DashFX(Character: Model, Direction: string)
	if Base[Character.Name .. "DashVFX"] then
		task.cancel(Base[Character.Name .. "DashVFX"].TimeDelay)
		if Base[Character.Name .. "DashVFX"].Connection then
			Base[Character.Name .. "DashVFX"].Connection:Disconnect()
		end
		Base[Character.Name .. "DashVFX"] = nil
	end

	if Character.Humanoid.FloorMaterial ~= Enum.Material.Air then
		local DashVFX = Replicated.Assets.VFX.DashFX:Clone()
		DashVFX.Anchored = true
		DashVFX.CanCollide = false
		DashVFX.Parent = workspace.World.Visuals

		-- Get offset based on direction
		local offsetCFrame
		if Direction == "Left" then
			offsetCFrame = CFrame.new(2, -3, 0) * CFrame.Angles(0, math.rad(90), 0)
		elseif Direction == "Right" then
			offsetCFrame = CFrame.new(-2, -3, 0) * CFrame.Angles(0, math.rad(-90), 0)
		elseif Direction == "Forward" then
			offsetCFrame = CFrame.new(0, -3, 2)
		elseif Direction == "Backward" then
			offsetCFrame = CFrame.new(0, -3, -2) * CFrame.Angles(0, math.rad(180), 0)
		else
			offsetCFrame = CFrame.new(0, -3, 2)
		end

		-- Set initial position
		DashVFX.CFrame = Character.HumanoidRootPart.CFrame * offsetCFrame

		-- Raycast to get ground color
		local rayOrigin = Character.HumanoidRootPart.Position
		local rayDirection = Vector3.new(0, -10, 0)
		local raycastParams = RaycastParams.new()
		raycastParams.FilterDescendantsInstances = { Character }
		raycastParams.FilterType = Enum.RaycastFilterType.Exclude

		local raycastResult = workspace:Raycast(rayOrigin, rayDirection, raycastParams)

		-- Apply color if ray hits
		if raycastResult then
			local hitPart = raycastResult.Instance
			if hitPart:IsA("BasePart") and hitPart.Color then
				for _, particleEmitter in ipairs(DashVFX:GetDescendants()) do
					if particleEmitter:IsA("ParticleEmitter") then
						particleEmitter.Color = ColorSequence.new(hitPart.Color)
					end
				end
			end
		end

		-- Smoothly fade in trail WidthScale when dash starts and enable trails
		local trailData = {}

		for _, v in Character:GetDescendants() do
			if v:IsA("Trail") and v:GetAttribute("Dash") then
				-- Enable the trail
				v.Enabled = true

				-- Get or store the original WidthScale
				local originalWidthScale
				if not originalTrailWidths[v] then
					-- First time seeing this trail - store its original width
					originalTrailWidths[v] = v.WidthScale
					originalWidthScale = v.WidthScale
				else
					-- Use the stored original width
					originalWidthScale = originalTrailWidths[v]
				end

				-- Create a NumberValue to tween (workaround since WidthScale can't be tweened directly)
				local widthValue = Instance.new("NumberValue")
				widthValue.Value = 0

				-- Update WidthScale based on the NumberValue
				local connection
				connection = widthValue.Changed:Connect(function(value)
					if v and v.Parent then
						-- Scale the original NumberSequence by the value (0 to 1)
						local keypoints = {}
						for _, keypoint in ipairs(originalWidthScale.Keypoints) do
							table.insert(keypoints, NumberSequenceKeypoint.new(
								keypoint.Time,
								keypoint.Value * value,
								keypoint.Envelope * value
							))
						end
						v.WidthScale = NumberSequence.new(keypoints)
					else
						connection:Disconnect()
					end
				end)

				-- Tween the NumberValue from 0 to 1
				local tweenIn = TweenService:Create(
					widthValue,
					TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ Value = 1 }
				)
				tweenIn:Play()

				table.insert(trailData, {
					trail = v,
					widthValue = widthValue,
					connection = connection,
					originalWidthScale = originalWidthScale
				})
			end
		end

		-- Enable particles for the duration of the dash instead of just emitting once
		local dashDuration = 0.15  -- Match the dash duration from Movement.lua

		-- Enable all particle emitters
		for _, particleEmitter in ipairs(DashVFX:GetDescendants()) do
			if particleEmitter:IsA("ParticleEmitter") then
				particleEmitter.Enabled = true
			end
		end

		-- Update VFX position to follow the character during the dash
		local RunService = game:GetService("RunService")
		local updateConnection
		updateConnection = RunService.Heartbeat:Connect(function()
			if not Character or not Character.Parent or not Character:FindFirstChild("HumanoidRootPart") then
				updateConnection:Disconnect()
				return
			end

			-- Update position to follow character
			DashVFX.CFrame = Character.HumanoidRootPart.CFrame * offsetCFrame
		end)

		-- Disable particles and stop following after dash duration
		task.delay(dashDuration, function()
			if updateConnection then
				updateConnection:Disconnect()
			end

			-- Smoothly fade out trail WidthScale when dash ends
			for _, data in ipairs(trailData) do
				if data.trail and data.trail.Parent and data.widthValue then
					-- Tween the NumberValue from 1 to 0
					local tweenOut = TweenService:Create(
						data.widthValue,
						TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
						{ Value = 0 }
					)
					tweenOut:Play()

					-- Clean up after tween completes (keep trail enabled but at width 0)
					tweenOut.Completed:Connect(function()
						if data.connection then
							data.connection:Disconnect()
						end
						if data.widthValue then
							data.widthValue:Destroy()
						end
						-- Don't disable the trail - leave it enabled but at width 0
						-- This way it will work on the next dash
					end)
				end
			end

			for _, particleEmitter in ipairs(DashVFX:GetDescendants()) do
				if particleEmitter:IsA("ParticleEmitter") then
					particleEmitter.Enabled = false
				end
			end
		end)

		-- Clean up the VFX part after particles have faded
		local maxLifetime = 0
		for _, particleEmitter in ipairs(DashVFX:GetDescendants()) do
			if particleEmitter:IsA("ParticleEmitter") then
				if particleEmitter.Lifetime.Max > maxLifetime then
					maxLifetime = particleEmitter.Lifetime.Max
				end
			end
		end

		local cleanupTime = dashDuration + maxLifetime
		Debris:AddItem(DashVFX, cleanupTime)

		Base[Character.Name .. "DashVFX"] = {
			["Instance"] = DashVFX,
			["Timer"] = cleanupTime,
			["Connection"] = updateConnection,
			["TimeDelay"] = task.delay(cleanupTime, function()
				Base[Character.Name .. "DashVFX"] = nil
			end),
		}

		-- Library.PlaySound(Character, SFX.Dashes[Direction])
	end
end

function Base.EndDashFX(Character: Model)
	if Base[Character.Name .. "DashVFX"] then
		local Table = Base[Character.Name .. "DashVFX"]

		task.cancel(Table.TimeDelay)

		Table.Instance.Anchored = true

		Base[Character.Name .. "DashVFX"] = nil
	end
end

function Base.WallSlideDust(wall: BasePart, duration: number)
	-- Clone the dash particles to use for wall sliding
	local DashVFX = Replicated.Assets.VFX.DashFX:Clone()
	DashVFX.Parent = workspace.World.Visuals
	DashVFX.Anchored = true
	DashVFX.CanCollide = false

	-- Position at the wall
	DashVFX.CFrame = wall.CFrame

	-- Color the particles based on wall color
	for _, particleEmitter in ipairs(DashVFX:GetDescendants()) do
		if particleEmitter:IsA("ParticleEmitter") then
			particleEmitter.Color = ColorSequence.new(wall.Color)
			particleEmitter.Enabled = true
		end
	end

	-- Track the wall and emit particles as it moves
	local startTime = os.clock()
	local connection
	connection = game:GetService("RunService").Heartbeat:Connect(function()
		local elapsed = os.clock() - startTime
		if elapsed >= duration or not wall or not wall.Parent then
			-- Stop emitting and clean up
			for _, particleEmitter in ipairs(DashVFX:GetDescendants()) do
				if particleEmitter:IsA("ParticleEmitter") then
					particleEmitter.Enabled = false
				end
			end
			connection:Disconnect()
			Debris:AddItem(DashVFX, 2)
			return
		end

		-- Update position to follow the wall
		DashVFX.CFrame = wall.CFrame
	end)
end

function Base.WallRunDust(Character: Model, wallPosition: Vector3, wallNormal: Vector3, wallColor: Color3)
	-- Create a unique key for this character's wall run dust
	local dustKey = Character.Name .. "WallRunDust"

	-- If dust already exists, just update its position
	if Base[dustKey] then
		Base[dustKey].CFrame = CFrame.new(wallPosition, wallPosition + wallNormal)
		return Base[dustKey]
	end

	-- Clone the dash particles to use for wall running
	local DashVFX = Replicated.Assets.VFX.DashFX:Clone()
	DashVFX.Parent = workspace.World.Visuals
	DashVFX.Anchored = true
	DashVFX.CanCollide = false
	DashVFX.Size = Vector3.new(1, 1, 1)
	DashVFX.Transparency = 1

	-- Position at the wall contact point
	DashVFX.CFrame = CFrame.new(wallPosition, wallPosition + wallNormal)

	-- Color the particles based on wall color
	for _, particleEmitter in ipairs(DashVFX:GetDescendants()) do
		if particleEmitter:IsA("ParticleEmitter") then
			particleEmitter.Color = ColorSequence.new(wallColor)
			particleEmitter.Enabled = true
		end
	end

	Base[dustKey] = DashVFX

	return DashVFX
end

function Base.StopWallRunDust(Character: Model)
	local dustKey = Character.Name .. "WallRunDust"

	if Base[dustKey] then
		-- Stop emitting particles
		for _, particleEmitter in ipairs(Base[dustKey]:GetDescendants()) do
			if particleEmitter:IsA("ParticleEmitter") then
				particleEmitter.Enabled = false
			end
		end

		-- Clean up after particles fade
		Debris:AddItem(Base[dustKey], 2)
		Base[dustKey] = nil
	end
end

function Base.FlashStep(Character: Model)
	local Instanced = {}

	local newFX = VFX.NewFlashfx:Clone()
	newFX.CFrame = Character.HumanoidRootPart.CFrame
	newFX.Parent = Character.HumanoidRootPart
	Debris:AddItem(newFX, 2)

	for i, v in pairs(newFX:GetDescendants()) do
		if v:IsA("ParticleEmitter") then
			v:Emit(v:GetAttribute("EmitCount"))
		end
	end

	local whitelistedparts = { "Left Arm", "Head", "Torso", "Right Arm", "Left Leg", "Right Leg" }

	local Particles = {}

	Base[Character.Name .. "FlashStep"] = {
		["Instances"] = {},
		["CharacterInstances"] = {},
		["TimeDelay"] = task.delay(1, function()
			if Base[Character.Name .. "FlashStep"] then
				Base[Character.Name .. "FlashStep"].TimeDelay = nil

				Base.RemoveFlashStep(Character)

				Base[Character.Name .. "FlashStep"] = nil
			end
		end),
	}

	for _, limb in pairs(whitelistedparts) do
		local Correlating = Character:FindFirstChild(limb)

		local newPart1 = VFX.Skin1:Clone()
		local newPart2 = VFX.Skin2:Clone()
		newPart1.Parent = Correlating
		newPart2.Parent = Correlating
		newPart1.Color = ColorSequence.new(Correlating.Color)
		newPart1.Enabled = true
		newPart2.Enabled = true

		table.insert(Base[Character.Name .. "FlashStep"].Instances, newPart1)
		table.insert(Base[Character.Name .. "FlashStep"].Instances, newPart2)
	end

	for i, v in pairs(Character:GetDescendants()) do
		if v:IsA("BasePart") and v.Transparency == 0 then
			v.Transparency = 1
			table.insert(Base[Character.Name .. "FlashStep"].CharacterInstances, v)
		end
	end
end

function Base.RemoveFlashStep(Character: Model)
	local Table = Base[Character.Name .. "FlashStep"]

	if Table.TimeDelay then
		task.cancel(Table.TimeDelay)
	end

	for i, v in pairs(Table.Instances) do
		v:Destroy()
	end

	for i, v in pairs(Table.CharacterInstances) do
		v.Transparency = 0
	end

	Base[Character.Name .. "FlashStep"] = nil

	local newFX = VFX.FlashStepFX.Part2:Clone()
	newFX.Parent = Character.HumanoidRootPart
	Debris:AddItem(newFX, 2)

	for i, v in pairs(newFX:GetDescendants()) do
		if v:IsA("ParticleEmitter") then
			v:Emit(v:GetAttribute("EmitCount"))
		end
	end
end


function Base.RollCancel(Character: Model)
	local highlight = Instance.new("Highlight")

	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.FillColor = Color3.fromRGB(255, 212, 41)
	highlight.FillTransparency = 0.8
	highlight.OutlineTransparency = 0.6
	highlight.OutlineColor = Color3.fromRGB(0, 0, 0)
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Parent = Character

	local TInfo = TweenInfo.new(0.5, Enum.EasingStyle.Circular, Enum.EasingDirection.InOut, 0)

	task.delay(0.1, function()
		local hTween = TweenService:Create(highlight, TInfo, {
			OutlineTransparency = 1,
			FillTransparency = 1,
			FillColor = Color3.fromRGB(188, 165, 52),
			OutlineColor = Color3.fromRGB(188, 165, 52),
		})
		hTween:Play()
		hTween.Completed:Connect(function()
			highlight:Destroy()
		end)
	end)
end

function Base.Stall(Character: Model, Duration: number)
	local highlight = Instance.new("Highlight")

	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.FillColor = Color3.fromRGB(255, 255, 255)
	highlight.FillTransparency = 0.4
	highlight.OutlineTransparency = 0.2
	highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Parent = Character

	local TInfo = TweenInfo.new(0.1, Enum.EasingStyle.Circular, Enum.EasingDirection.InOut, -1)
	local hTween
	if Duration <= 1 then
		hTween = TweenService:Create(
			highlight,
			TInfo,
			{ OutlineColor = Color3.fromRGB(255, 227, 134), FillColor = Color3.fromRGB(255, 227, 134) }
		)
	elseif Duration > 1 and Duration <= 2 then
		hTween = TweenService:Create(
			highlight,
			TInfo,
			{ OutlineColor = Color3.fromRGB(255, 175, 129), FillColor = Color3.fromRGB(255, 175, 129) }
		)
	elseif Duration >= 2 then
		hTween = TweenService:Create(
			highlight,
			TInfo,
			{ OutlineColor = Color3.fromRGB(255, 0, 0), FillColor = Color3.fromRGB(255, 0, 0) }
		)
	end

	hTween:Play()

	task.delay(Duration, function()
		highlight:Destroy()
	end)
end

function Base.Clap(Character: Model, Duration: number)
	local root = Character.HumanoidRootPart
	local clap = Replicated.Assets.VFX.Clap:Clone()

	clap.CFrame = root.CFrame
	clap.Anchored = true
	clap.CanCollide = false
	clap.Parent = workspace.World.Visuals

	for _, v in (clap:GetDescendants()) do
		if v:IsA("ParticleEmitter") then
			v:Emit(v:GetAttribute("EmitCount"))
		end
	end

	if Duration and Duration > 0.2 then
		for _, v in (clap:GetDescendants()) do
			if v:IsA("ParticleEmitter") then
				v.TimeScale = 0
			end
		end
		task.delay(Duration, function()
			for _, v in (clap:GetDescendants()) do
				if v:IsA("ParticleEmitter") then
					v.TimeScale = 1
				end
			end
		end)

		task.delay(Duration + 3, function()
			clap:Destroy()
		end)
	end
end

function Base.Transmute(Character: Model)
	local root = Character.HumanoidRootPart
	local Construct = Replicated.Assets.VFX.Construct:Clone()

	Construct:PivotTo(root.CFrame * CFrame.new(0, 2, -3))
	-- Construct.Anchored = true
	-- Construct.CanCollide = false
	Construct.Parent = workspace.World.Visuals

	-- for _, v in (Construct:GetDescendants()) do
	-- 	if v:IsA("ParticleEmitter") then
	-- 		v:Emit(v:GetAttribute("EmitCount"))
	-- 	end
	-- end

	EmitModule.emit(Construct)

	local TInfo4 = TweenInfo.new(1, Enum.EasingStyle.Circular, Enum.EasingDirection.InOut, 0)
	local TInfo5 = TweenInfo.new(0.25, Enum.EasingStyle.Circular, Enum.EasingDirection.InOut, 0)

	local activeTweens = {}
	local t1 = TweenService:Create(Construct.Attachment.PointLight, TInfo4, { Range = 30 })
	table.insert(activeTweens, t1)
	t1:Play()

	local t2 = TweenService:Create(Construct.Attachment.PointLight, TInfo5, { Brightness = 0 })
	table.insert(activeTweens, t2)
	t1.Completed:Connect(function()
		t2:Play()
	end)
	t2.Completed:Connect(function()
		Construct:Destroy()
	end)
end

function Base.Shake(magnitude: number, frequency: number?, location: Vector3?)
	-- New camera shake system using CamShake from Utils
	-- More impactful and lively shakes with higher default values
	CamShake({
		Magnitude = magnitude * 1.5, -- Increased for more impact
		Frequency = frequency or 25, -- Higher frequency for more lively shakes
		Damp = 0.005, -- Slower dampening for longer lasting shakes
		Influence = Vector3.new(1.2, 1.2, 0.8), -- More influence on X and Y axes
		Location = location or workspace.CurrentCamera.CFrame.Position,
		Falloff = 100 -- Larger falloff distance
	})
end

function Base.SpecialShake(magnitude: number, frequency: number?, location: Vector3?)
	-- Special camera shake for intense moments (even more impactful)
	CamShake({
		Magnitude = magnitude * 2, -- Double magnitude for special shakes
		Frequency = frequency or 30, -- Even higher frequency
		Damp = 0.004, -- Even slower dampening
		Influence = Vector3.new(1.5, 1.5, 1), -- Maximum influence
		Location = location or workspace.CurrentCamera.CFrame.Position,
		Falloff = 120
	})
end

function Base.BloomBlur()
	-- Create circular inout bloom and blur tween that lasts for 0.2 seconds
	if true then
		-- Create circular inout bloom and blur tween that lasts for 0.2 seconds
		local lighting = game:GetService("Lighting")

		-- Get or create bloom and blur effects
		local bloom = lighting:FindFirstChild("Bloom") or Instance.new("BloomEffect")
		local blur = lighting:FindFirstChild("MotionBlur") or Instance.new("BlurEffect")

		if not bloom.Parent then
			bloom.Name = "Bloom"
			bloom.Parent = lighting
		end

		if not blur.Parent then
			blur.Name = "MotionBlur"
			blur.Parent = lighting
		end

		-- Store original values
		local originalBloomIntensity = bloom.Intensity
		local originalBloomSize = bloom.Size
		local originalBloomThreshold = bloom.Threshold
		local originalBlurSize = blur.Size

		-- Target values for the effect
		local targetBloomIntensity = Params.BloomIntensity or 2
		local targetBloomSize = Params.BloomSize or 56
		local targetBloomThreshold = Params.BloomThreshold or 0.8
		local targetBlurSize = Params.BlurSize or 24

		-- Create tween info for circular in-out easing
		local tweenInfo = TweenInfo.new(
			0.1, -- Half duration for in
			Enum.EasingStyle.Circular,
			Enum.EasingDirection.In,
			0,
			true, -- Reverses automatically
			0
		)

		-- Create tweens
		local bloomTween = TweenService:Create(bloom, tweenInfo, {
			Intensity = targetBloomIntensity,
			Size = targetBloomSize,
			Threshold = targetBloomThreshold,
		})

		local blurTween = TweenService:Create(blur, tweenInfo, {
			Size = targetBlurSize,
		})

		-- Start the tweens
		bloomTween:Play()
		blurTween:Play()

		-- Clean up after the effect completes
		bloomTween.Completed:Connect(function()
			-- Reset to original values
			bloom.Intensity = originalBloomIntensity
			bloom.Size = originalBloomSize
			bloom.Threshold = originalBloomThreshold
			blur.Size = originalBlurSize
		end)
	end
end

function Base.Deconstruct(Character: Model)
	local root = Character.HumanoidRootPart

	local eff = Replicated.Assets.VFX.Deconstruct:Clone()
	eff.CFrame = root.CFrame * CFrame.new(0, 0, -2) * CFrame.Angles(0, math.rad(-180), 0)
	eff.Anchored = true
	eff.CanCollide = false
	eff.Parent = workspace.World.Visuals
	for _, v in (eff:GetDescendants()) do
		if v:IsA("ParticleEmitter") then
			v:Emit(v:GetAttribute("EmitCount"))
		end
	end
	task.delay(3, function()
		eff:Destroy()
	end)
end
function Base.AlchemicAssault(Character: Model, Type: string)
	if Type == "Jump" then
		local root = Character.HumanoidRootPart
		local p = Replicated.Assets.VFX.Jump:Clone()
		p.CFrame = root.CFrame * CFrame.new(0, -2, 0)
		p.Anchored = true
		p.Parent = workspace.World.Visuals
		Debris:AddItem(p, 1)

		for _, v in (p:GetDescendants()) do
			if v:IsA("ParticleEmitter") then
				v:Emit(v:GetAttribute("EmitCount"))
			end
		end
	end
end
function Base.WallErupt(Part: BasePart?, Character: Model)
	local effect = Replicated.Assets.VFX.Smash:Clone()
	effect.Anchored = true

	local charY = Character.Position.Y
	local partCFrame = Part.CFrame
	effect.CFrame = partCFrame - partCFrame.Position + Vector3.new(partCFrame.X, charY - 2, partCFrame.Z)

	effect.Parent = workspace.World.Visuals
	Debris:AddItem(effect, 3)

	for _, v in (effect:GetDescendants()) do
		if v:IsA("ParticleEmitter") then
			v:Emit(v:GetAttribute("EmitCount"))
		end
	end
end

function Base.Wallbang(Position: Vector3)
	local effect = Replicated.Assets.VFX.WallImpact:Clone()
	effect.Anchored = true
	effect.Position = Position
	effect.CFrame = effect.CFrame * CFrame.Angles(0, math.rad(90), 0)
	effect.Parent = workspace.World.Visuals
	effect.Transparency = 1
	Debris:AddItem(effect, 3)
	for _, v in (effect:GetDescendants()) do
		if v:IsA("ParticleEmitter") then
			v:Emit(v:GetAttribute("EmitCount"))
		end
	end
end

function Base.HandEffect(Character: Instance, Weapon: string, Combo: number)
	local effect = Replicated.Assets.VFX.HandEffect:Clone()
	local effect2 = Replicated.Assets.VFX.HandEffect:Clone()
	if Combo == 1 then
		for _, v in effect:GetDescendants() do
			if v:IsA("ParticleEmitter") then
				v.Parent = Character["Left Arm"].LeftGripAttachment
				v:Emit(v:GetAttribute("EmitCount"))
			end
		end
	end
	if Combo == 2 then
		for _, v in effect:GetDescendants() do
			if v:IsA("ParticleEmitter") then
				v.Parent = Character["Right Arm"].RightGripAttachment
				v:Emit(v:GetAttribute("EmitCount"))
			end
		end
	end
	if Combo == 3 then
		for _, v in effect:GetDescendants() do
			if v:IsA("ParticleEmitter") then
				v.Parent = Character["Left Arm"].LeftGripAttachment
				v:Emit(v:GetAttribute("EmitCount"))
			end
		end
		for _, v in effect2:GetDescendants() do
			if v:IsA("ParticleEmitter") then
				v.Parent = Character["Right Arm"].RightGripAttachment
				v:Emit(v:GetAttribute("EmitCount"))
			end
		end
	end
	if Combo == 4 then
		for _, v in effect:GetDescendants() do
			if v:IsA("ParticleEmitter") then
				v.Parent = Character["Left Arm"].LeftGripAttachment
				v:Emit(v:GetAttribute("EmitCount"))
			end
		end
		for _, v in effect2:GetDescendants() do
			if v:IsA("ParticleEmitter") then
				v.Parent = Character["Right Arm"].RightGripAttachment
				v:Emit(v:GetAttribute("EmitCount"))
			end
		end
	end
end

function Base.FlameProjExplosion(Frame: CFrame)
	local eff = Replicated.Assets.VFX.Explosion:Clone()
	eff.CFrame = Frame
	eff.Parent = workspace.World.Visuals

	for _, v in eff:GetDescendants() do
		if v:IsA("ParticleEmitter") then
			v:Emit(v:GetAttribute("EmitCount") or 10)
		end
	end

	Base.Shake(3, 20, Character.HumanoidRootPart.Position) -- Increased magnitude for more impact

	Debris:AddItem(eff, 5)
end

-- Store combat scopes per player to allow updating existing UI
local combatScopes = {}

function Base.InCombat(Plr: Player, value: boolean)
	-- Update global combat state for sound system
	_G.PlayerInCombat = value
	print("[InCombat] Combat state changed to:", value)

	-- If leaving combat, clean up existing scope
	if not value and combatScopes[Plr] then
		print("[InCombat] Cleaning up combat UI for", Plr.Name)
		combatScopes[Plr].incombat:set(false)
		combatScopes[Plr].started:set(false)
		-- The cleanup task will handle destroying the scope
		return
	end

	-- If entering combat and scope already exists, just update it
	if value and combatScopes[Plr] then
		print("[InCombat] Updating existing combat UI for", Plr.Name)
		combatScopes[Plr].incombat:set(true)
		return
	end

	-- Create new scope for entering combat
	if not value then return end -- Don't create scope if leaving combat

	local scope = scoped(Fusion, {})
	local ui = Plr.PlayerGui.ScreenGui
	local ent = ref.get("player", Plr)
	local TInfo = TweenInfo.new(1.5, Enum.EasingStyle.Circular, Enum.EasingDirection.InOut, 0)
	local incombat = scope:Value(value)
	local started = scope:Value(false)

	-- Store scope for later updates
	combatScopes[Plr] = {
		scope = scope,
		incombat = incombat,
		started = started
	}

	local observer = scope:Observer(incombat)

	observer:onBind(function()
		if peek(incombat) == true then
			task.wait(1)
			started:set(true)
		else
			-- Fade out when leaving combat
			started:set(false)
		end
	end)

	local combatFrame = scope:New("Frame")({
		Name = "CombatTag",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0.5, 0.02),
		Size = UDim2.fromScale(1, 1),
		Visible = true,
		Parent = ui,

		[Children] = {
			scope:New("ImageLabel")({
				Name = "ImageLabel",
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				Image = "rbxassetid://128748386139453",
				Position = UDim2.fromScale(0.423, 0.526),
				Size = UDim2.fromOffset(228, 103),
				ImageTransparency = scope:Tween(
					scope:Computed(function(use)
						return if use(started) then 0 else 1
					end),
					TInfo
				),
			}),
		},
	})

	-- Clean up the frame when combat ends and fade is complete
	task.spawn(function()
		while combatFrame and combatFrame.Parent do
			if not peek(incombat) and not peek(started) then
				task.wait(TInfo.Time) -- Wait for fade out to complete
				if combatFrame and combatFrame.Parent then
					print("[InCombat] Destroying combat UI for", Plr.Name)
					scope:doCleanup()
					combatScopes[Plr] = nil -- Clear stored scope
					break
				end
			end
			task.wait(0.5)
		end
	end)
end

function Base.Guardbreak(Character: Model)
	local eff = Replicated.Assets.VFX.Guardbreak:Clone()
	eff.CFrame = Character.HumanoidRootPart.CFrame
	eff.Parent = workspace.World.Visuals

	for _, v in eff:GetDescendants() do
		if v:IsA("ParticleEmitter") then
			v:Emit(v:GetAttribute("EmitCount"))
		end
	end

	Debris:AddItem(eff, 4.5)
end

function Base.Lightning(params: {})
	local Lightning = require(game:GetService("ReplicatedStorage").Lightning)
	-- print(params)
	local lightning = Lightning.new(table.unpack(params))
end

local function meshfunction(CF: CFrame?, Parent: Instance?)
	if CF then
		if typeof(CF) == "Vector3" then
			CF = CFrame.new(CF)
		elseif typeof(CF) ~= "CFrame" then
			CF = nil
		end
	end

	if not Parent then
		local cache = workspace:FindFirstChild("MeshCache")
		if not cache then
			cache = Instance.new("Folder")
			cache.Name = "MeshCache"
			cache.Parent = workspace
		end
		Parent = cache
	end

	local Main_CFrame = CF or CFrame.new(0, 0, 0)

	-- Settings

	local Visual_Directory = {
		["Bam"] = Replicated.Assets.VFX.GlockWind.WindHit.Bam,
		["Wind1"] = Replicated.Assets.VFX.GlockWind.WindHit.Wind1,
		["WindTime"] = Replicated.Assets.VFX.GlockWind.WindHit.WindTime,
	} :: { [string]: Instance }

	local Visual_Data = {
		[Visual_Directory["WindTime"]] = {
			General = {
				Offset = CFrame.new(
					0.142611697,
					-0.0974341929,
					0.223849222,
					0.82567358,
					3.2189073e-05,
					-0.564148188,
					-0.564148188,
					1.69824652e-05,
					-0.82567358,
					-1.69824652e-05,
					1,
					3.2189073e-05
				),
				Tween_Duration = 0.9,
				Transparency = 0.95,
			},

			BasePart = {
				Property = {
					Size = Vector3.new(11.642829895019531, 3.650705575942993, 11.277613639831543),
					CFrame = Main_CFrame * CFrame.new(
						0.142566457,
						-0.0974551663,
						-1.16666901,
						0.564148188,
						3.2189073e-05,
						0.82567358,
						0.82567358,
						1.69824652e-05,
						-0.564148188,
						-3.2189073e-05,
						1,
						-1.69824652e-05
					),
					Color = Color3.new(0.972549, 0.972549, 0.972549),
					Transparency = 1,
				},
				Tween = {
					Easing_Direction = Enum.EasingDirection.Out,
					Easing_Style = Enum.EasingStyle.Cubic,
				},
			},
		},

		[Visual_Directory["Wind1"]] = {
			General = {
				Offset = CFrame.new(
					-0.593957543,
					0.0688220412,
					0.827984631,
					-0.564148188,
					-3.2189073e-05,
					0.82567358,
					-0.82567358,
					-1.69824652e-05,
					-0.564148188,
					3.2189073e-05,
					-1,
					-1.69824652e-05
				),
				Tween_Duration = 0.9,
				Transparency = 0.95,
			},

			BasePart = {
				Property = {
					Size = Vector3.new(5.941439628601074, 2.281934976577759, 6.157501220703125),
					CFrame = Main_CFrame * CFrame.new(
						-0.594238997,
						0.0691366941,
						1.0633285,
						0,
						-5.12773113e-09,
						-1,
						1,
						9.7161319e-09,
						0,
						-9.71704139e-09,
						-1,
						-5.12864062e-09
					),
					Color = Color3.new(0.623529, 0.631373, 0.67451),
					Transparency = 1,
				},
				Tween = {
					Easing_Direction = Enum.EasingDirection.Out,
					Easing_Style = Enum.EasingStyle.Cubic,
				},
			},
		},

		[Visual_Directory["Bam"]] = {
			General = {
				Offset = CFrame.new(
					-0.786581635,
					0.379521042,
					1.66430068,
					-0.82567358,
					-3.2189073e-05,
					-0.564148188,
					0.564148188,
					-1.69824652e-05,
					-0.82567358,
					1.69824652e-05,
					-1,
					3.2189073e-05
				),
				Tween_Duration = 1,
				Transparency = 0.95,
			},

			BasePart = {
				Property = {
					Size = Vector3.new(9.895853996276855, 2.655467987060547, 9.895853996276855),
					CFrame = Main_CFrame * CFrame.new(
						-0.786581635,
						0.379521042,
						1.66430068,
						0.82567358,
						-3.2189073e-05,
						0.564148188,
						-0.564148188,
						-1.69824652e-05,
						0.82567358,
						-1.69824652e-05,
						-1,
						-3.2189073e-05
					),
					Color = Color3.new(0.670588, 0.670588, 0.670588),
					Transparency = 1,
				},
				Tween = {
					Easing_Direction = Enum.EasingDirection.Out,
					Easing_Style = Enum.EasingStyle.Quart,
				},
			},
		},
	}

	for Origin: any, Data in pairs(Visual_Data) do
		if not Origin or not Origin:IsDescendantOf(game) or not Origin:FindFirstChild("Start") then
			continue
		end

		-- Build

		local function Emit()
			local Visual = Origin.Start:Clone()
			Visual.Name = Origin.Name
			Visual.Transparency = Data.General.Transparency
			if Visual:FindFirstChildOfClass("Decal") then
				Visual:FindFirstChildOfClass("Decal").Transparency = Data.General.Transparency
				Visual.Transparency = 1
			end
			Visual.Anchored = true
			Visual.CanCollide = false
			Visual.CanQuery = false
			Visual.CanTouch = false
			Visual.Locked = true
			Visual.CFrame = Main_CFrame * Data.General.Offset
			Visual.Parent = Parent

			-- Initialize

			game:GetService("TweenService")
				:Create(
					Visual,
					TweenInfo.new(
						Data.General.Tween_Duration,
						Data.BasePart.Tween.Easing_Style,
						Data.BasePart.Tween.Easing_Direction
					),
					Data.BasePart.Property
				)
				:Play()

			-- Clean Up

			task.delay(Data.General.Tween_Duration, Visual.Destroy, Visual)
		end

		task.spawn(Emit)
	end
end

function Base.Shot(Character: Model, Combo: number, LeftGun: MeshPart, RightGun: MeshPart)
	-- -- print("Base.Shot called - Character:", Character.Name, "Combo:", Combo, "LeftGun:", LeftGun and LeftGun.Name or "nil", "RightGun:", RightGun and RightGun.Name or "nil")
	if Combo == 1 then
		local eff = Replicated.Assets.VFX.Shot:Clone()
		eff.Parent = workspace.World.Visuals
		-- Use RightGun position and face forward in character's direction
		local effectPosition
		if LeftGun and LeftGun:FindFirstChild("EndPart") then
			local endPart = LeftGun:FindFirstChild("EndPart")
			effectPosition = endPart.Position
			-- -- print("Combo 1: Using LeftGun", endPart.Name, "position")
		elseif LeftGun then
			-- Use gun position even without End part
			effectPosition = LeftGun.Position
			-- -- print("Combo 1: Using LeftGun base position")
		else
			-- Fallback to hand position
			effectPosition = Character:FindFirstChild("RightHand").Position
			-- -- print("Combo 1: Using RightHand fallback")
		end
		-- Always face forward in character's direction
		eff.CFrame = CFrame.lookAt(effectPosition, effectPosition + Character.HumanoidRootPart.CFrame.LookVector)
			* CFrame.Angles(0, math.rad(90), 0)
		for _, v in eff:GetDescendants() do
			if v:IsA("ParticleEmitter") then
				v:Emit(v:GetAttribute("EmitCount"))
			end
		end
		task.delay(3, function()
			eff:Destroy()
		end)
	end
	if Combo == 2 then
		local eff = Replicated.Assets.VFX.Shot:Clone()
		eff.Parent = workspace.World.Visuals
		-- Use LeftGun position and face forward in character's direction
		local effectPosition
		if RightGun and RightGun:FindFirstChild("EndPart") then
			local endPart = RightGun:FindFirstChild("EndPart")
			effectPosition = endPart.Position
			-- -- print("Combo 2: Using RightGun", endPart.Name, "position")
		elseif RightGun then
			-- Use gun position even without End part
			effectPosition = RightGun.Position
			-- -- print("Combo 2: Using RightGun base position")
		else
			-- Fallback to hand position
			effectPosition = Character:FindFirstChild("LeftHand").Position
			-- -- print("Combo 2: Using LeftHand fallback")
		end
		-- Always face forward in character's direction
		eff.CFrame = CFrame.lookAt(effectPosition, effectPosition + Character.HumanoidRootPart.CFrame.LookVector)
			* CFrame.Angles(0, math.rad(90), 0)
		for _, v in eff:GetDescendants() do
			if v:IsA("ParticleEmitter") then
				v:Emit(v:GetAttribute("EmitCount"))
			end
		end
		task.delay(3, function()
			eff:Destroy()
		end)
	end
	if Combo == 3 then
		local eff = Replicated.Assets.VFX.Combined:Clone()
		eff.Parent = workspace.World.Visuals
		-- Position in front of character and face forward (no rotation)
		eff.CFrame = Character.HumanoidRootPart.CFrame * CFrame.new(0, 1.5, -2) * CFrame.Angles(0, math.rad(180), 0)
		-- -- print("Combo 3: Using Combined effect in front of character")

		for _, v in eff:GetDescendants() do
			if v:IsA("ParticleEmitter") then
				v:Emit(v:GetAttribute("EmitCount"))
			end
		end
		task.delay(3, function()
			eff:Destroy()
		end)

		meshfunction(eff.CFrame, workspace.World.Visuals)
	end
end

-- Track active dialogue sessions to prevent duplicates
local activeDialogueSessions = {}

function Base.Commence(Dialogue: { npc: Model, name: string, inrange: boolean, state: string })
	-- print("🎭 [Effects.Base] COMMENCE FUNCTION CALLED")
	-- print("📋 Dialogue data received:", Dialogue)

	-- Validate dialogue data
	if not Dialogue then
		-- print("❌ [Effects.Base] ERROR: No dialogue data provided!")
		return
	end

	if not Dialogue.npc then
		-- print("❌ [Effects.Base] ERROR: No NPC model in dialogue data!")
		return
	end

	if not Dialogue.name then
		-- print("❌ [Effects.Base] ERROR: No NPC name in dialogue data!")
		return
	end

	-- print("✅ [Effects.Base] Dialogue validation passed")
	-- print("🎯 [Effects.Base] NPC:", Dialogue.name, "| In Range:", Dialogue.inrange, "| State:", Dialogue.state)

	local npcId = Dialogue.npc:GetDebugId() -- Unique identifier for this NPC instance

	if Dialogue.inrange then
		-- Check if we already have an active session for this NPC
		if activeDialogueSessions[npcId] then
			-- print("⚠️ [Effects.Base] Dialogue session already active for", Dialogue.name, "- skipping")
			return
		end

		-- print("🎯 [Effects.Base] Player is in range, creating proximity UI...")
		activeDialogueSessions[npcId] = true

		-- Check if highlight already exists
		local highlight = Dialogue.npc:FindFirstChild("Highlight")
		if not highlight then
			-- print("✨ [Effects.Base] Creating new highlight for NPC")
			highlight = Instance.new("Highlight")
			highlight.Name = "Highlight"
			highlight.DepthMode = Enum.HighlightDepthMode.Occluded
			highlight.FillTransparency = 1
			highlight.OutlineTransparency = 1
			highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
			highlight.Parent = Dialogue.npc

			local hTween = TweenService:Create(highlight, TInfo, { OutlineTransparency = 0 })
			hTween:Play()
			-- print("🎬 [Effects.Base] Highlight tween started")
		else
			-- print("♻️ [Effects.Base] Highlight already exists, reusing it")
			-- Make sure it's visible
			if highlight.OutlineTransparency > 0.5 then
				local hTween = TweenService:Create(highlight, TInfo, { OutlineTransparency = 0 })
				hTween:Play()
			end
		end

		-- print("📦 [Effects.Base] Loading Fusion scope and Proximity component...")
		local scope = scoped(Fusion, {
			Proximity = require(Replicated.Client.Components.Proximity),
		})
		local start = scope:Value(false)
		-- print("✅ [Effects.Base] Fusion scope created successfully")

		local Target = scope:New("ScreenGui")({
			Name = "ScreenGui",
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
			Parent = Player.PlayerGui,
		})
		-- print("🖥️ [Effects.Base] ScreenGui created and parented to PlayerGui")

		local parent = Target

		-- print("🔗 [Effects.Base] Creating Proximity component...")
		scope:Proximity({
			begin = start,
			par = parent,
		})
		-- print("✅ [Effects.Base] Proximity component created")

		-- print("⏱️ [Effects.Base] Starting proximity animation sequence...")
		task.wait(0.3)
		-- print("🎬 [Effects.Base] Setting start to true")
		start:set(true)
		task.wait(2.5)
		-- print("🎬 [Effects.Base] Setting start to false")
		start:set(false)
		task.wait(0.5)
		-- print("🧹 [Effects.Base] Cleaning up scope")
		scope:doCleanup()

		-- Clear the active session
		activeDialogueSessions[npcId] = nil
		-- print("✅ [Effects.Base] Proximity effect complete")
	else
		-- print("🚫 [Effects.Base] Player not in range, removing highlight...")

		-- Clear any active session
		activeDialogueSessions[npcId] = nil

		local highlight = Dialogue.npc:FindFirstChild("Highlight")
		if highlight then
			-- print("✨ [Effects.Base] Found existing highlight, fading out...")
			local hTween = TweenService:Create(highlight, TInfo, { OutlineTransparency = 1 })
			hTween:Play()
			hTween.Completed:Connect(function()
				if highlight and highlight.Parent then
					highlight:Destroy()
					-- print("🗑️ [Effects.Base] Highlight destroyed")
				end
			end)
		else
			-- print("⚠️ [Effects.Base] No highlight found to remove")
		end
	end

	-- print("✅ [Effects.Base] COMMENCE FUNCTION COMPLETE")
end

function Base.RockSkewer(Character: Model, Frame: string, Wedge: WedgePart)
	if Frame == "Stomp" then
		local stompeffect = Replicated.Assets.VFX.Stone.uptiltrock:Clone()
		stompeffect.CFrame = Character.HumanoidRootPart.CFrame * CFrame.new(0, -2, -5)
		stompeffect.Parent = workspace.World.Visuals
		for _, v in stompeffect:GetDescendants() do
			if v:IsA("ParticleEmitter") then
				v:Emit(v:GetAttribute("EmitCount"))
			end
		end
		local meshfunction2 = require(Replicated.Assets.VFX.Stone.StoneMesh.wowmesh)

		require(Replicated.Assets.VFX.Stone.StoneMesh.wowmesh)(
			Character.HumanoidRootPart.CFrame * CFrame.new(0, -1, -5)
		)
		Debris:AddItem(stompeffect, 3)
	end

	if Frame == "Launch" then
		for _, v in Wedge:GetDescendants() do
			if v:IsA("Beam") then
				TweenService:Create(v, TInfo, { Width0 = 1.035, Width1 = 2.766 }):Play()
			end
		end
		local vfx1 = Replicated.Assets.VFX.Stone.lightninghit:Clone()
		local vfx2 = Replicated.Assets.VFX.Stone.rockfly:Clone()
		vfx2.boom.CFrame = Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, -5)
		vfx1.CFrame = Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, -5)
		vfx2.CFrame = Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, -5)
		vfx1.Parent = workspace.World.Visuals
		vfx2.Parent = workspace.World.Visuals
		for _, v in vfx1:GetDescendants() do
			if v:IsA("ParticleEmitter") then
				v:Emit(v:GetAttribute("EmitCount"))
			end
		end
		task.delay(0.1, function()
			for _, v in vfx2:GetDescendants() do
				if v:IsA("ParticleEmitter") then
					v:Emit(v:GetAttribute("EmitCount"))
				end
			end
		end)

		local armeffects = Replicated.Assets.VFX.Stone.Arm:Clone()
		for _, v in armeffects:GetDescendants() do
			if v:IsA("ParticleEmitter") then
				v.Parent = Character["Left Arm"].LeftGripAttachment
				v:Emit(v:GetAttribute("EmitCount"))
				v.Enabled = true
			end
		end
		task.delay(1, function()
			for _, v in Character["Left Arm"].LeftGripAttachment:GetDescendants() do
				if v:IsA("ParticleEmitter") then
					v.Enabled = false
					Debris:AddItem(v, 3)
				end
			end
		end)
		local pl = Replicated.Assets.VFX.Stone.PointLight:Clone()
		pl.Parent = Character.HumanoidRootPart
		local TInfo4 = TweenInfo.new(0.15, Enum.EasingStyle.Circular, Enum.EasingDirection.InOut, 0)
		local TInfo5 = TweenInfo.new(0.1, Enum.EasingStyle.Circular, Enum.EasingDirection.InOut, 0)
		local activeTweens = {}
		local t1 = TweenService:Create(pl, TInfo4, { Range = 5 })
		table.insert(activeTweens, t1)
		t1:Play()

		local t2 = TweenService:Create(pl, TInfo5, { Brightness = 0 })
		table.insert(activeTweens, t2)
		t1.Completed:Connect(function()
			t2:Play()
		end)
		t2.Completed:Connect(function()
			pl:Destroy()
		end)
		Debris:AddItem(vfx1, 2)
		Debris:AddItem(vfx2, 2)
		Debris:AddItem(Wedge, 2)
		require(Replicated.Assets.VFX.Stone.StoneMesh.woahMesh)(
			Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, -8.5)
		)
		require(Replicated.Assets.VFX.Stone.StoneMesh.wwMesh)(Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, -11))
		require(Replicated.Assets.VFX.Stone.StoneMesh.twoM)(Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, -3))
	end
end

function Base.Firestorm(Character: Model, Frame: string)
	if Frame == "Start" then
		local eff = Replicated.Assets.VFX.Firestorm:Clone()
		for _, v in eff:GetDescendants() do
			if v:IsA("Attachment") then
				v.Parent = Character.HumanoidRootPart
				for _, m in v:GetDescendants() do
					if m:IsA("ParticleEmitter") then
						task.delay(m:GetAttribute("EmitDelay"), function()
							m:Emit(m:GetAttribute("EmitCount"))
						end)
						-- m:Emit(m:GetAttribute("EmitCount"))
					end
				end
			end
		end
		task.delay(3, function()
			eff:Destroy()
		end)
	end
end

function Base.SpecialCritStone(Character)
	local eff = Replicated.Assets.VFX.Stone.Crit:Clone()
	eff.CFrame = Character.HumanoidRootPart.CFrame * CFrame.new(0, -2.5, -3)
	eff.Parent = workspace.World.Visuals
	for _, v in eff:GetDescendants() do
		if v:IsA("ParticleEmitter") then
			v:Emit(v:GetAttribute("EmitCount"))
		end
	end

	require(Replicated.Assets.VFX.Stone.StoneCrit.windM)(Character.HumanoidRootPart.CFrame * CFrame.new(0, -3, 0))
	require(Replicated.Assets.VFX.Stone.StoneCrit.circleW)(Character.HumanoidRootPart.CFrame * CFrame.new(0, -1, 0))
	require(Replicated.Assets.VFX.Stone.StoneCrit.rotateM)(Character.HumanoidRootPart.CFrame * CFrame.new(0, -1, 0))

	local pl = Replicated.Assets.VFX.Stone.PointLight:Clone()
	pl.Parent = Character.HumanoidRootPart
	local TInfo4 = TweenInfo.new(0.15, Enum.EasingStyle.Circular, Enum.EasingDirection.InOut, 0)
	local TInfo5 = TweenInfo.new(0.1, Enum.EasingStyle.Circular, Enum.EasingDirection.InOut, 0)
	local activeTweens = {}
	local t1 = TweenService:Create(pl, TInfo4, { Range = 5 })
	table.insert(activeTweens, t1)
	t1:Play()

	local t2 = TweenService:Create(pl, TInfo5, { Brightness = 0 })
	table.insert(activeTweens, t2)
	t1.Completed:Connect(function()
		t2:Play()
	end)
	task.delay(3, function()
		eff:Destroy()
	end)
end

function Base.Cinder(Character: Model, Frame: string)
	if Frame == "Start" then
		local startup = Replicated.Assets.VFX.Cinder["RightArm"]["Move2Startup"]:Clone()
		startup.Parent = Character["Right Arm"]
		for _, v in pairs(startup:GetDescendants()) do
			if v:IsA("ParticleEmitter") then
				local emitCount = v:GetAttribute("EmitCount") or 1
				local emitDelay = v:GetAttribute("EmitDelay") or 0.1

				-- Start a coroutine to emit once after delay
				coroutine.wrap(function()
					task.wait(emitDelay)
					v:Emit(emitCount)
				end)()
			end
		end

		local fx2 = Replicated.Assets.VFX.Cinder.Move2BeamPart2:Clone()
		fx2.Parent = workspace.World.Visuals
		-- Use fresh CFrame to avoid dash position desync
		local currentCFrame = Character.HumanoidRootPart.CFrame
		fx2.CFrame = currentCFrame * CFrame.new(0, 0, -15)
		for _, v in pairs(fx2:GetDescendants()) do
			if v:IsA("ParticleEmitter") or v:IsA("Beam") then
				local emitDelay = v:GetAttribute("EmitDelay") or 0.1
				local emitDuration = v:GetAttribute("EmitDuration") or 1

				coroutine.wrap(function()
					task.wait(emitDelay) -- wait before enabling
					v.Enabled = true -- enable particle emission
					task.wait(emitDuration) -- wait for duration
					v.Enabled = false -- disable particle emission
				end)()
			end
		end

		local start = Replicated.Assets.VFX.Cinder.Move2BeamPart:Clone()
		start.Parent = workspace.World.Visuals
		start.CFrame = Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, -10)
		for _, v in pairs(start:GetDescendants()) do
			if v:IsA("ParticleEmitter") or v:IsA("Beam") then
				local emitDelay = v:GetAttribute("EmitDelay") or 0.1
				local emitDuration = v:GetAttribute("EmitDuration") or 1

				coroutine.wrap(function()
					task.wait(emitDelay)
					if v:IsA("ParticleEmitter") then
						v:Emit(v:GetAttribute("EmitCount"))
					end
					v.Enabled = true -- enable particle emission
					task.wait(emitDuration) -- wait for duration
					v.Enabled = false -- disable particle emission
				end)()
			end
		end

		local fx3 = Replicated.Assets.VFX.Cinder.Move2BeamPart3:Clone()
		fx3.Parent = workspace.World.Visuals
		fx3.CFrame = Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, -3)
		for _, v in pairs(fx3:GetDescendants()) do
			if v:IsA("ParticleEmitter") or v:IsA("Beam") then
				local emitDelay = v:GetAttribute("EmitDelay") or 0.1
				local emitDuration = v:GetAttribute("EmitDuration") or 1

				coroutine.wrap(function()
					task.wait(emitDelay) -- wait before enabling
					v.Enabled = true -- enable particle emission
					task.wait(emitDuration) -- wait for duration
					v.Enabled = false -- disable particle emission
				end)()
			end
		end
		task.delay(3, function()
			startup:Destroy()
			fx2:Destroy()
			fx3:Destroy()
		end)
	end
end

function Base.Cascade(Character: Model, Frame: string)
	if Frame == "Start" then
		local eff = Replicated.Assets.VFX.Cascade.Arms
		for _, v in eff:GetChildren() do
			local h = v:Clone()
			h.Parent = Character["Right Arm"].RightGripAttachment
			h:Emit(h:GetAttribute("EmitCount"))
		end
		for _, v in eff:GetChildren() do
			local h = v:Clone()
			h.Parent = Character["Left Arm"].LeftGripAttachment
			h:Emit(h:GetAttribute("EmitCount"))
		end
		task.delay(3, function()
			for _, v in Character["Right Arm"].RightGripAttachment:GetDescendants() do
				if v:IsA("ParticleEmitter") then
					v:Destroy()
				end
			end
			for _, v in Character["Left Arm"].LeftGripAttachment:GetDescendants() do
				if v:IsA("ParticleEmitter") then
					v:Destroy()
				end
			end
		end)
	end

	if Frame == "Summon" then
		local eff = Replicated.Assets.VFX.Cascade.Summon:Clone()
		eff.Parent = workspace.World.Visuals
		eff.CFrame = Character.HumanoidRootPart.CFrame * CFrame.new(0, -2.5, -4)
		for _, v in eff:GetDescendants() do
			if v:IsA("ParticleEmitter") then
				v:Emit(v:GetAttribute("EmitCount"))
			end
		end
		task.delay(3, function()
			eff:Destroy()
		end)
	end
end

function Base.NeedleThrust(Character: Model, Frame: string)
	if Frame == "Start" then
		local eff = Replicated.Assets.VFX.NeedleThrust.jump:Clone()
		eff.Parent = workspace.World.Visuals
		eff.CFrame = Character.HumanoidRootPart.CFrame * CFrame.new(0, -2.5, 0) * CFrame.Angles(math.rad(-15), 0, 0)
		for _, v in eff:GetDescendants() do
			if v:IsA("ParticleEmitter") then
				v:Emit(v:GetAttribute("EmitCount"))
			end
		end
		task.delay(3, function()
			eff:Destroy()
		end)

		require(Replicated.Assets.VFX.NeedleThrust.JumpModule)(
			Character.HumanoidRootPart.CFrame * CFrame.new(0, -3, 0) * CFrame.Angles(math.rad(-15), 0, 0)
		)
	end

	if Frame == "Hit" then
		local eff = Replicated.Assets.VFX.NeedleThrust.stabspear:Clone()
		eff.Parent = workspace.World.Visuals
		eff.CFrame = Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, -4)
		for _, v in eff:GetDescendants() do
			if v:IsA("ParticleEmitter") then
				v:Emit(v:GetAttribute("EmitCount"))
			end
		end

		local eff2 = Replicated.Assets.VFX.NeedleThrust.um:Clone()
		eff2.Parent = workspace.World.Visuals
		eff2.CFrame = Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, 4)
		for _, v in eff2:GetDescendants() do
			if v:IsA("ParticleEmitter") then
				v:Emit(v:GetAttribute("EmitCount"))
			end
		end
		task.delay(3, function()
			eff:Destroy()
			eff2:Destroy()
		end)

		require(Replicated.Assets.VFX.NeedleThrust.StabMesh)(Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, -4))
	end
end

function Base.ShellPiercer(Character: Model, Frame: string, tim: number)
	if Frame == "Start" then
		local eff = Replicated.Assets.VFX.ShellPiercer.Charge:Clone()
		local rGun = Character:FindFirstChild("RightGun")
		eff.Charge.Parent = rGun.EndPart
		for _, v in rGun.EndPart:GetDescendants() do
			if v:IsA("ParticleEmitter") then
				v:Emit(v:GetAttribute("EmitCount"))
				v.Enabled = true
			end
		end
		task.delay(tim, function()
			for _, v in rGun.EndPart:GetDescendants() do
				if v:IsA("ParticleEmitter") then
					v.Enabled = false
				end
			end
			rGun.EndPart.Charge:Destroy()
		end)
	end
	if Frame == "Hit" then
		local eff = Replicated.Assets.VFX.ShellPiercer.Hit:Clone()
		eff.Parent = workspace.World.Visuals
		eff.CFrame = Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, -4) * CFrame.Angles(0, math.rad(90), 0)
		for _, v in eff:GetDescendants() do
			if v:IsA("ParticleEmitter") then
				v:Emit(v:GetAttribute("EmitCount"))
			end
		end
		task.delay(3, function()
			eff:Destroy()
		end)

		-- Impactful camera shake for ultimate move
		Base.SpecialShake(8, 28, Character.HumanoidRootPart.Position)
		local lighting = game:GetService("Lighting")

		-- Get or create bloom and blur effects
		local bloom = lighting:FindFirstChild("Bloom")
		local blur = lighting:FindFirstChild("Blur")

		-- Create if they don't exist
		if not bloom then
			bloom = Instance.new("BloomEffect")
			bloom.Name = "Bloom"
			bloom.Intensity = 0
			bloom.Size = 0
			bloom.Threshold = 0
			bloom.Parent = lighting
		end

		if not blur then
			blur = Instance.new("BlurEffect")
			blur.Name = "Blur"
			blur.Size = 0
			blur.Parent = lighting
		end

		-- Store original values (should be 0 if properly cleaned up)
		local originalBloomIntensity = 0
		local originalBloomSize = 0
		local originalBloomThreshold = 0
		local originalBlurSize = 0

		-- Target values for the effect
		local targetBloomIntensity = 2
		local targetBloomSize = 56
		local targetBloomThreshold = 0.8
		local targetBlurSize = 24

		-- Use RenderStepped for smooth real-time blur effect
		local startTime = tick()
		local duration = 0.2 -- Total duration (in + out)

		local connection
		connection = RunService.RenderStepped:Connect(function()
			local elapsed = tick() - startTime
			local progress = math.min(elapsed / duration, 1)

			-- Circular in-out easing
			local alpha
			if progress < 0.5 then
				-- First half: ease in
				local t = progress * 2
				alpha = 1 - math.sqrt(1 - t * t)
			else
				-- Second half: ease out
				local t = (progress - 0.5) * 2
				alpha = 1 - (1 - math.sqrt(1 - (1 - t) * (1 - t)))
			end

			-- Apply values
			bloom.Intensity = originalBloomIntensity + (targetBloomIntensity - originalBloomIntensity) * alpha
			bloom.Size = originalBloomSize + (targetBloomSize - originalBloomSize) * alpha
			bloom.Threshold = originalBloomThreshold + (targetBloomThreshold - originalBloomThreshold) * alpha
			blur.Size = originalBlurSize + (targetBlurSize - originalBlurSize) * alpha

			-- Clean up when complete
			if progress >= 1 then
				connection:Disconnect()
				-- Reset to 0 (clean state)
				bloom.Intensity = 0
				bloom.Size = 0
				bloom.Threshold = 0
				blur.Size = 0
			end
		end)
	end
end

function Base.SC(Character: Model, Frame: string)
	if Frame == "Sweep" then
		local eff = Replicated.Assets.VFX.SC.Sweep:Clone()
		eff:SetPrimaryPartCFrame(Character.HumanoidRootPart.CFrame * CFrame.new(1.5, -2.5, -3.5))
		eff.Parent = workspace.World.Visuals
		for _, v in eff:GetDescendants() do
			if v:IsA("ParticleEmitter") then
				v:Emit(v:GetAttribute("EmitCount"))
			end
		end
		task.delay(3, function()
			eff:Destroy()
		end)
	end
	if Frame == "Up" then
		local eff = Replicated.Assets.VFX.SC.up:Clone()
		eff.CFrame = Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, -5) * CFrame.Angles(math.rad(90), 0, 0)
		eff.Parent = workspace.World.Visuals
		for _, v in eff:GetDescendants() do
			if v:IsA("ParticleEmitter") then
				v:Emit(v:GetAttribute("EmitCount"))
			end
		end
		task.delay(3, function()
			eff:Destroy()
		end)
	end
	if Frame == "Down" then
		local eff = Replicated.Assets.VFX.SC.down:Clone()
		eff.CFrame = Character.HumanoidRootPart.CFrame * CFrame.new(0, 3, -3) * CFrame.Angles(math.rad(-90), 0, 0)
		eff.Parent = workspace.World.Visuals
		for _, v in eff:GetDescendants() do
			if v:IsA("ParticleEmitter") then
				v:Emit(v:GetAttribute("EmitCount"))
			end
		end
		task.delay(3, function()
			eff:Destroy()
		end)
	end
	if Frame == "groundye" then
		local eff = Replicated.Assets.VFX.SC.groundye:Clone()
		eff.CFrame = Character.HumanoidRootPart.CFrame * CFrame.new(0, -2.5, -3)
		eff.Parent = workspace.World.Visuals
		for _, v in eff:GetDescendants() do
			if v:IsA("ParticleEmitter") then
				v:Emit(v:GetAttribute("EmitCount"))
			end
		end
		task.delay(3, function()
			eff:Destroy()
		end)
	end
	if Frame == "LFire" then
		local lGun = Character:FindFirstChild("LeftGun")
		for _, v in lGun:GetDescendants() do
			if v:IsA("ParticleEmitter") then
				v:Emit(v:GetAttribute("EmitCount"))
			end
		end
		-- task.delay(3, function()

		-- end)
	end
	if Frame == "RFire" then
		local rGun = Character:FindFirstChild("RightGun")
		for _, v in rGun:GetDescendants() do
			if v:IsA("ParticleEmitter") then
				v:Emit(v:GetAttribute("EmitCount"))
			end
		end
		-- task.delay(3, function()
		-- 	eff:Destroy()
		-- end)
	end
end

function Base.AxeKick(Character: Model, Frame: string)
	if Frame == "Swing" then
		local meshes = require(Replicated.Assets.VFX.axekickmeshes.AllMeshes)
		meshes(Character.HumanoidRootPart.CFrame, workspace.World.Visuals)
		local axekickVFX = Replicated.Assets.VFX:FindFirstChild("Axekick")
		if axekickVFX and axekickVFX:FindFirstChild("Downslam") then
			local eff = axekickVFX.Downslam:Clone()
			eff.CFrame = Character.HumanoidRootPart.CFrame
			eff.Parent = Character.HumanoidRootPart
			for _, v in eff:GetDescendants() do
				if v:IsA("ParticleEmitter") then
					task.delay(v:GetAttribute("EmitDelay") or 0, function()
						v:Emit(v:GetAttribute("EmitCount") or 10)
					end)
				end
			end
			task.delay(3, function()
				eff:Destroy()
			end)
			task.delay(0.1, function()
				local ak = Replicated.Assets.VFX:FindFirstChild("Axekick")
				if ak and ak:FindFirstChild("SlamFx") then
					local eff2 = ak.SlamFx:Clone()
					eff2.CFrame = Character.HumanoidRootPart.CFrame * CFrame.new(0, -2.5, -3)
					eff2.Parent = workspace.World.Visuals
					for _, v in eff2:GetDescendants() do
						if v:IsA("ParticleEmitter") then
							task.delay(v:GetAttribute("EmitDelay") or 0, function()
								v:Emit(v:GetAttribute("EmitCount") or 10)
							end)
						end
					end
					task.delay(3, function()
						eff2:Destroy()
					end)

					local impactPosition = Character.HumanoidRootPart.CFrame * CFrame.new(0, -2.5, -3)
					local craterPosition = impactPosition.Position + Vector3.new(0, 1, 0) -- Raise 1 stud above ground

					local success, err = pcall(function()
						local craterCFrame = CFrame.new(craterPosition)

						local effect = RockMod.New("Crater", craterCFrame, {
							Distance = { 5.5, 15 },
							SizeMultiplier = 0.3,
							PartCount = 12,
							Layers = { 3, 3 },
							ExitIterationDelay = { 0, 0 },
							LifeCycle = {
                Entrance = {
                    Type = "Elevate",
                    Speed = 0.25,
                    Division = 3,
                    EasingStyle = Enum.EasingStyle.Quad,
                    EasingDirection = Enum.EasingDirection.Out,
                },

                Exit = {
                    Type = "SizeDown",
                    Speed = 0.3,
                    Division = 2,
                    EasingStyle = Enum.EasingStyle.Sine,
                    EasingDirection = Enum.EasingDirection.In,
                },
            }, -- Instant, no delay
						})

						if effect then
							effect:Debris("Normal", {
								Size = { 0.75, 2.5 },
								UpForce = { 0.55, 0.95 },
								RotationalForce = { 15, 35 },
								Spread = { 8, 8 },
								PartCount = 10,
								Radius = 8,
								LifeTime = 5,
								LifeCycle = {
									Entrance = {
										Type = "SizeUp",
										Speed = 0.25,
										Division = 3,
										EasingStyle = Enum.EasingStyle.Quad,
										EasingDirection = Enum.EasingDirection.Out,
									},
									Exit = {
										Type = "SizeDown",
										Speed = 0.3,
										Division = 2,
										EasingStyle = Enum.EasingStyle.Sine,
										EasingDirection = Enum.EasingDirection.In,
									},
								},
							})
						end
					end)

					if not success then
						warn(`[AxeKick] Failed to create crater effect: {err}`)
					end

					-- Vicious but brief screenshake on impact
					Base.SpecialShake(10, 35, impactPos) -- Very impactful shake for axe kick

					-- Brief bloom effect on impact
					local lighting = game:GetService("Lighting")
					local bloom = lighting:FindFirstChild("Bloom")

					if not bloom then
						bloom = Instance.new("BloomEffect")
						bloom.Name = "Bloom"
						bloom.Enabled = true
						bloom.Intensity = 0
						bloom.Size = 24
						bloom.Threshold = 2
						bloom.Parent = lighting
					end

					-- Store original values
					local originalIntensity = bloom.Intensity
					local originalSize = bloom.Size
					local originalThreshold = bloom.Threshold

					-- Create brief bloom tween (in and out)
					local tweenInfo = TweenInfo.new(
						0.15, -- Duration for in (0.15 seconds)
						Enum.EasingStyle.Circular,
						Enum.EasingDirection.InOut,
						0,
						true, -- Reverses automatically
						0
					)

					local bloomTween = TweenService:Create(bloom, tweenInfo, {
						Intensity = 30,
						Size = 5,
						Threshold = .5,
					})

					bloomTween:Play()

					-- Reset to original values after completion
					bloomTween.Completed:Connect(function()
						bloom.Intensity = originalIntensity
						bloom.Size = originalSize
						bloom.Threshold = originalThreshold
					end)
				end
			end)
		end
	end
end

local function dsmesh(CF: CFrame, Parent: Instance)

	-- Base Setup 

	if CF then
		if typeof(CF) == "Vector3" then
			CF = CFrame.new(CF)
		elseif typeof(CF) ~= "CFrame" then
			CF = nil
		end
	end

	if not Parent then
		local cache = workspace:FindFirstChild("MeshCache")
		if not cache then
			cache = Instance.new("Folder")
			cache.Name = "MeshCache"
			cache.Parent = workspace
		end
		Parent = cache
	end

	local Main_CFrame = CF or CFrame.new(0,0,0)

	-- Settings

	local Visual_Directory = {
		["WindRing"] = Replicated.Assets.VFX.DownslamVFX.Jump.Jump.WindRing,
		["Wind"] = Replicated.Assets.VFX.DownslamVFX.Jump.Slam.Wind,
		["WindBig"] = Replicated.Assets.VFX.DownslamVFX.Jump.Slam.WindBig,
		["Kick"] = Replicated.Assets.VFX.DownslamVFX.Jump.Slam.Kick,
		["Wind1"] = Replicated.Assets.VFX.DownslamVFX.Jump.Slam.Wind1,
		["Wind2"] = Replicated.Assets.VFX.DownslamVFX.Jump.Jump.Wind2
	} :: {[string] : Instance}

	local Visual_Data = {
		[Visual_Directory["WindBig"]] = {
			General = {
				Offset = CFrame.new(0.14389044, -6.14201164, 0.147280157, -0.0871312022, 0, 0.996197224, 0, -1, 0, 0.996197283, 0, 0.0871317983),
				Tween_Duration = 0.3,
				Transparency = 0.7,
			},

			Random_Angles = {
				X = {0, 0},
				Y = {0, 0},
				Z = {0, 0},
			},
			BasePart = {
				Property = {
					Size = Vector3.new(22.354114532470703, 0.42486676573753357, 22.354108810424805),
					CFrame = Main_CFrame * CFrame.new(0.14389044, -8.68135548, 0.147280157, -0.996199965, 0, -0.0871019065, 0, -1.00000048, 0, -0.08710289, 0, 0.996199727),
					Color = Color3.new(0.639216, 0.635294, 0.647059),
					Transparency = 1,
				},
				Tween = {
					Easing_Direction = Enum.EasingDirection.Out,
					Easing_Style = Enum.EasingStyle.Cubic,
				},
			},

			Mesh = {
				Property = {
					Offset = Vector3.new(0, 0, 0),
					Scale = Vector3.new(-2.9735352993011475, -0.10105361044406891, -2.9735360145568848),
					VertexColor = Vector3.new(1, 1, 1),
				},
				Tween = {
					Easing_Direction = Enum.EasingDirection.Out,
					Easing_Style = Enum.EasingStyle.Cubic,
				},
			},

			Decal = {
				Property = {
					Color3 = Color3.new(10.0196, 10.0196, 10.0196),
					Transparency = 1,
				},
				Tween = {
					Easing_Direction = Enum.EasingDirection.Out,
					Easing_Style = Enum.EasingStyle.Cubic,
				},
			},
		},

		[Visual_Directory["Wind1"]] = {
			General = {
				Offset = CFrame.new(-0.113482013, -7.26768684, 4.91738319e-07, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Tween_Duration = 0.4,
				Transparency = 0.9,
			},

			Features = {
				Random_Angles = {
					X = {0, 0},
					Y = {-360, 360},
					Z = {0, 0},
				},
			},

			BasePart = {
				Property = {
					Size = Vector3.new(25.763809204101562, 2.8394811153411865, 25.763809204101562),
					CFrame = Main_CFrame * CFrame.new(-0.113482013, -7.35580206, 4.91738319e-07, -0.783837199, 0, 0.620966434, 0, 1, 0, -0.620966434, 0, -0.783837199),
					Color = Color3.new(1, 1, 1),
					Transparency = 1,
				},
				Tween = {
					Easing_Direction = Enum.EasingDirection.Out,
					Easing_Style = Enum.EasingStyle.Cubic,
				},
			},

		},

		[Visual_Directory["Wind"]] = {
			General = {
				Offset = CFrame.new(0.1087787, -6.41260242, 0.0389252082, -2.38418579e-07, 0, -1.00000012, 0, 1, 0, 1.00000012, 0, -2.38418579e-07),
				Tween_Duration = 0.5,
				Transparency = 0.95,
			},

			Random_Angles = {
				X = {0, 0},
				Y = {0, 0},
				Z = {0, 0},
			},
			BasePart = {
				Property = {
					Size = Vector3.new(25.052053451538086, 4.060371398925781, 25.052053451538086),
					CFrame = Main_CFrame * CFrame.new(0, -7.56635475, 0, 0.336982906, 0, 0.941510856, 0, 1, 0, -0.941510856, 0, 0.336982906),
					Color = Color3.new(0.972549, 0.972549, 0.972549),
					Transparency = 1,
				},
				Tween = {
					Easing_Direction = Enum.EasingDirection.Out,
					Easing_Style = Enum.EasingStyle.Cubic,
				},
			},

		},

		[Visual_Directory["Kick"]] = {
			General = {
				Offset = CFrame.new(-0.113484487, -4.35610867, 0.625125647, 0, 0, 1, 1, 0, 0, 0, 1, 0),
				Tween_Duration = 0.15,
				Transparency = 0.9,
			},

			Features = {
				Random_Angles = {
					X = {0, 0},
					Y = {-360, 360},
					Z = {0, 0},
				},
			},

			BasePart = {
				Property = {
					Size = Vector3.new(0.4741426110267639, 5.183227062225342, 5.183227062225342),
					CFrame = Main_CFrame * CFrame.new(-0.113484487, -7.55821896, 0.625125647, 0, 0, 1, 1, 0, 0, 0, 1, 0),
					Color = Color3.new(0.639216, 0.635294, 0.647059),
					Transparency = 1,
				},
				Tween = {
					Easing_Direction = Enum.EasingDirection.Out,
					Easing_Style = Enum.EasingStyle.Cubic,
				},
			},

			Mesh = {
				Property = {
					Offset = Vector3.new(0, 0, 0),
					Scale = Vector3.new(0.09007208794355392, 0.5183614492416382, 0.5183614492416382),
					VertexColor = Vector3.new(1, 1, 1),
				},
				Tween = {
					Easing_Direction = Enum.EasingDirection.Out,
					Easing_Style = Enum.EasingStyle.Cubic,
				},
			},

			Decal = {
				Property = {
					Color3 = Color3.new(100.216, 100.216, 100.216),
					Transparency = 1,
				},
				Tween = {
					Easing_Direction = Enum.EasingDirection.Out,
					Easing_Style = Enum.EasingStyle.Cubic,
				},
			},
		},

		[Visual_Directory["WindRing"]] = {
			General = {
				Offset = CFrame.new(0.152786076, -5.18276215, 0.375100195, 1, 0, 0, 0, 1, 0, 0, 0, 1),
				Tween_Duration = 0.3,
				Transparency = 0.7,
			},

			Random_Angles = {
				X = {0, 0},
				Y = {0, 0},
				Z = {0, 0},
			},
			BasePart = {
				Property = {
					Size = Vector3.new(15.603704452514648, 3.2936112880706787, 15.603704452514648),
					CFrame = Main_CFrame * CFrame.new(0.152969867, -8.23160553, 0.375163078, -0.965929806, 0, 0.258804828, 0, 1, 0, -0.258804828, 0, -0.965929806),
					Color = Color3.new(0.639216, 0.635294, 0.647059),
					Transparency = 1,
				},
				Tween = {
					Easing_Direction = Enum.EasingDirection.Out,
					Easing_Style = Enum.EasingStyle.Cubic,
				},
			},

			Mesh = {
				Property = {
					Offset = Vector3.new(0, 0, 0),
					Scale = Vector3.new(7.092589378356934, 3.2938053607940674, 7.092589378356934),
					VertexColor = Vector3.new(1, 1, 1),
				},
				Tween = {
					Easing_Direction = Enum.EasingDirection.Out,
					Easing_Style = Enum.EasingStyle.Cubic,
				},
			},

			Decal = {
				Property = {
					Color3 = Color3.new(3.92157, 3.92157, 3.92157),
					Transparency = 1,
				},
				Tween = {
					Easing_Direction = Enum.EasingDirection.Out,
					Easing_Style = Enum.EasingStyle.Cubic,
				},
			},
		},

		[Visual_Directory["Wind2"]] = {
			General = {
				Offset = CFrame.new(0.678757071, 2.8957653, 0.832559586, 0, 0, 1, 0, -1, 0, 1, 0, 0),
				Tween_Duration = 0.3,
				Transparency = 0.8,
			},

			Random_Angles = {
				X = {0, 0},
				Y = {0, 0},
				Z = {0, 0},
			},
			BasePart = {
				Property = {
					Size = Vector3.new(18.56374740600586, 0.9379472136497498, 18.790721893310547),
					CFrame = Main_CFrame * CFrame.new(0.750563145, -7.59732962, 0.9011935, -0.422593057, 0, -0.906319737, 0, -1, 0, -0.906319737, 0, 0.422593057),
					Color = Color3.new(0.639216, 0.635294, 0.647059),
					Transparency = 1,
				},
				Tween = {
					Easing_Direction = Enum.EasingDirection.Out,
					Easing_Style = Enum.EasingStyle.Quint,
				},
			},

		},

	}

	for Origin : any, Data in pairs(Visual_Data) do
		if not Origin or not Origin:IsDescendantOf(game) or not Origin:FindFirstChild("Start") then continue end

		-- Build

		local function Emit()
			local Visual = Origin.Start:Clone()
			Visual.Name = Origin.Name
			Visual.Transparency = Data.General.Transparency
			if Visual:FindFirstChildOfClass("Decal") then Visual:FindFirstChildOfClass("Decal").Transparency = Data.General.Transparency Visual.Transparency = 1 end
			Visual.Anchored = true
			Visual.CanCollide = false
			Visual.CanQuery = false
			Visual.CanTouch = false
			Visual.Locked = true
			Visual.CFrame = Main_CFrame * Data.General.Offset
			Visual.Parent = Parent

			-- Random Angles

			if Data.Features and Data.Features.Random_Angles then
				Data.BasePart.Property.CFrame *= CFrame.Angles(math.random(unpack(Data.Features.Random_Angles.X)), math.random(unpack(Data.Features.Random_Angles.Y)), math.random(unpack(Data.Features.Random_Angles.Z)))
			end

			-- Initialize

			game:GetService("TweenService"):Create(Visual, TweenInfo.new(Data.General.Tween_Duration, Data.BasePart.Tween.Easing_Style, Data.BasePart.Tween.Easing_Direction), Data.BasePart.Property):Play()
			if Data.Decal then game:GetService("TweenService"):Create(Visual:FindFirstChildOfClass("Decal"), TweenInfo.new(Data.General.Tween_Duration, Data.Decal.Tween.Easing_Style, Data.Decal.Tween.Easing_Direction), Data.Decal.Property):Play() end
			if Data.Mesh then game:GetService("TweenService"):Create(Visual:FindFirstChildOfClass("SpecialMesh"), TweenInfo.new(Data.General.Tween_Duration, Data.Mesh.Tween.Easing_Style, Data.Mesh.Tween.Easing_Direction), Data.Mesh.Property):Play() end

			-- Clean Up

			task.delay(Data.General.Tween_Duration,Visual.Destroy,Visual)
		end

		task.spawn(Emit)
	end

end

function Base.Downslam(Character: Model, Frame: string)
	if Frame == "Start" then
		local eff = Replicated.Assets.VFX.DownslamVFX.jumpvfx:Clone()
		eff.CFrame = Character.HumanoidRootPart.CFrame * CFrame.new(0, -2.5, 0)
		eff.Parent = workspace.World.Visuals
		for _, v in eff:GetDescendants() do
			if v:IsA("ParticleEmitter") then
				v:Emit(v:GetAttribute("EmitCount"))
			end
		end

		dsmesh(Character.HumanoidRootPart.CFrame, workspace.World.Visuals)

		task.delay(3, function()
			eff:Destroy()
		end)
	end
	if Frame == "Land" then
		local eff = Replicated.Assets.VFX.DownslamVFX.slam:Clone()
		eff.CFrame = Character.HumanoidRootPart.CFrame * CFrame.new(0, -2.5, 0)
		eff.Parent = workspace.World.Visuals
		for _, v in eff:GetDescendants() do
			if v:IsA("ParticleEmitter") then
				v:Emit(v:GetAttribute("EmitCount"))
			end
		end
		task.delay(3, function()
			eff:Destroy()
		end)

		-- Create crater impact effect
		local impactPosition = Character.HumanoidRootPart.CFrame * CFrame.new(0, -2.5, 0)
		local craterPosition = impactPosition.Position + Vector3.new(0, 1, 0) -- Raise 1 stud above ground

		local success, err = pcall(function()
			local craterCFrame = CFrame.new(craterPosition)

			local effect = RockMod.New("Crater", craterCFrame, {
				Distance = { 5.5, 15 },
				SizeMultiplier = 0.4,
				PartCount = 14,
				Layers = { 3, 4 },
				ExitIterationDelay = { 0, 0 },
				LifeCycle = {
                Entrance = {
                    Type = "Elevate",
                    Speed = 0.25,
                    Division = 3,
                    EasingStyle = Enum.EasingStyle.Quad,
                    EasingDirection = Enum.EasingDirection.Out,
                },

                Exit = {
                    Type = "SizeDown",
                    Speed = 0.3,
                    Division = 2,
                    EasingStyle = Enum.EasingStyle.Sine,
                    EasingDirection = Enum.EasingDirection.In,
                },
            }, -- Instant, no delay
			})

			if effect then
				effect:Debris("Normal", {
					Size = { 0.75, 2.5 },
					UpForce = { 0.6, 1.0 },
					RotationalForce = {20, 40},
					Spread = { 10, 10 },
					PartCount = 12,
					Radius = 10,
					LifeTime = 5,
					LifeCycle = {
						Entrance = {
							Type = "SizeUp",
							Speed = 0.25,
							Division = 3,
							EasingStyle = Enum.EasingStyle.Quad,
							EasingDirection = Enum.EasingDirection.Out,
						},
						Exit = {
							Type = "SizeDown",
							Speed = 0.3,
							Division = 2,
							EasingStyle = Enum.EasingStyle.Sine,
							EasingDirection = Enum.EasingDirection.In,
						},
					},
				})
			end
		end)

		if not success then
			warn(`[Downslam] Failed to create crater effect: {err}`)
		end
	end
end

function Base.TransmutationCircle(Character: Model, Destination: CFrame?)
	local eff = Replicated.Assets.VFX.TransmutationCircle:Clone()
	eff.CFrame = Destination * CFrame.new(0, -1.5, 0) or Character.HumanoidRootPart.CFrame * CFrame.new(0, -1.5, 0)
	eff.Parent = workspace.World.Visuals
	TweenService:Create(eff.Decal, TInfo, { Transparency = 0 }):Play()
	local emits = Replicated.Assets.VFX.Construct:Clone()
	emits.CFrame = Destination or Character.HumanoidRootPart.CFrame
	emits.Parent = workspace.World.Visuals
	task.delay(0.35, function()
		for _, v in emits:GetDescendants() do
			if v:IsA("ParticleEmitter") then
				v:Emit(v:GetAttribute("EmitCount"))
			end
		end
	end)

	local fadeInfo = TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	task.delay(3, function()
		TweenService:Create(eff.Decal, fadeInfo, { Transparency = 1 }):Play()
	end)

	task.delay(5, function()
		eff:Destroy()
		emits:Destroy()
	end)
end

function Base.Spawn(Position: Vector3)
	local eff = Replicated.Assets.VFX.SpawnEff:Clone()
	eff.Position = Position
	-- print("Spawning effect at:", tostring(eff.CFrame))
	eff.Parent = workspace.World.Visuals
	for _, v in eff:GetDescendants() do
		if v:IsA("ParticleEmitter") then
			v:Emit(v:GetAttribute("EmitCount"))
		end
	end
	task.delay(3, function()
		eff:Destroy()
	end)
end

function Base.TripleKick(Character: Model, Frame: string)
	if Frame == "Ground" then
		local tk = Replicated.Assets.VFX.TripleKick
		local eff = Replicated.Assets.VFX.TripleKick.Ground:Clone()
		eff.CFrame = Character.HumanoidRootPart.CFrame * CFrame.new(0, -2.5, 0)
		eff.Parent = workspace.World.Visuals
		for _, v in eff:GetDescendants() do
			if v:IsA("ParticleEmitter") then
				v:Emit(v:GetAttribute("EmitCount"))
			end
		end

		-- Add trail effects to right leg
		local rightLeg = Character:FindFirstChild("Right Leg")
		if rightLeg then
			for _, v in tk:GetChildren() do
				if v:IsA("Attachment") and v.Name == "L" or v.Name == "R" then
					local clone = v:Clone()
					clone.Parent = rightLeg
				elseif v:IsA("Trail") then
					local clone = v:Clone()
					clone.Parent = rightLeg
				end
			end
			task.delay(3, function()
				for _, v in rightLeg:GetDescendants() do
					if v:IsA("Attachment") or v:IsA("Trail") then
						v:Destroy()
					end
				end
			end)
		end

		task.delay(3, function()
			eff:Destroy()
		end)
	elseif Frame == "Hit" then
		local rightLeg = Character:FindFirstChild("Right Leg")
		if not rightLeg then return end

		local eff = Replicated.Assets.VFX.TripleKick.Shoot:Clone()
		eff.CanCollide = false
		eff.Anchored = false
		eff.Massless = true
		eff.Parent = workspace.World.Visuals
		local eff2 = Replicated.Assets.VFX.TripleKick.Part:Clone()
		eff2.CanCollide = false
		eff2.Anchored = false
		eff2.Massless = true
		eff2.Parent = workspace.World.Visuals

		-- Use RenderStepped to continuously update VFX position to follow the leg
		local RunService = game:GetService("RunService")
		local connection
		connection = RunService.RenderStepped:Connect(function()
			if rightLeg and rightLeg.Parent and eff and eff.Parent then
				eff.CFrame = rightLeg.CFrame * CFrame.new(0, -1, 0) * CFrame.Angles(0, 0, math.rad(-90))
				eff2.CFrame = rightLeg.CFrame * CFrame.new(0, -1, 0) * CFrame.Angles(0, 0, math.rad(-90))
			else
				if connection then
					connection:Disconnect()
				end
			end
		end)

		for _, v in eff:GetDescendants() do
			if v:IsA("ParticleEmitter") then
				v:Emit(v:GetAttribute("EmitCount"))
			end
		end

		for _, v in eff2:GetDescendants() do
			if v:IsA("ParticleEmitter") then
				v:Emit(v:GetAttribute("EmitCount"))
			end
		end

		task.delay(3, function()
			if connection then
				connection:Disconnect()
			end
			eff:Destroy()
		end)
	end
end

-- Store active IS effects per character
local activeISEffects = {}
local activeISConnections = {}

function Base.IS(Character: Model, Frame: string)
	local eff

	-- Get or create the effect for this character
	if Frame == "RightDust" then
		-- First frame - spawn the effect
		eff = Replicated.Assets.VFX.IS:Clone()
		eff:PivotTo(Character.HumanoidRootPart.CFrame * CFrame.new(0, -2.5, 0))
		eff.Parent = workspace.World.Visuals

		-- Store it for reuse
		activeISEffects[Character] = eff

		-- Store parts that should follow the character and their offset from HumanoidRootPart
		local followParts = {}
		local excludedNames = { "Lift", "Model" } -- Parts that should NOT follow

		for _, part in eff:GetDescendants() do
			if part:IsA("BasePart") then
				local shouldExclude = false
				for _, excludedName in excludedNames do
					if part.Name == excludedName or part:IsDescendantOf(eff:FindFirstChild(excludedName) or game) then
						shouldExclude = true
						break
					end
				end

				if not shouldExclude then
					-- Store the offset from the character's HumanoidRootPart
					local offset = Character.HumanoidRootPart.CFrame:ToObjectSpace(part.CFrame)
					followParts[part] = offset
				end
			end
		end

		-- Create a connection to update the effect's position every frame
		local connection = RunService.Heartbeat:Connect(function()
			if Character and Character.Parent and Character:FindFirstChild("HumanoidRootPart") and eff and eff.Parent then
				-- Update all parts that should follow
				for part, offset in followParts do
					if part and part.Parent then
						part.CFrame = Character.HumanoidRootPart.CFrame * CFrame.new(0,-5,0)
					end
				end
			else
				-- Character or effect was destroyed, disconnect
				if activeISConnections[Character] then
					activeISConnections[Character]:Disconnect()
					activeISConnections[Character] = nil
				end
			end
		end)
		activeISConnections[Character] = connection

		local rd = eff.Model
		for _, v in rd:GetDescendants() do if v:IsA("ParticleEmitter") then v:Emit(v:GetAttribute("EmitCount")) end end
		task.delay(3, function() rd:Destroy() end)
	else
		-- Subsequent frames - reuse the existing effect
		eff = activeISEffects[Character]
		if not eff then
			warn("[Base.IS] Effect not found for character. RightDust must be called first!")
			return
		end
	end

	if Frame == "Lift" then
		local lift = eff.Lift
		for _, v in lift:GetDescendants() do if v:IsA("ParticleEmitter") then v:Emit(v:GetAttribute("EmitCount")) end end
		task.delay(3, function() lift:Destroy() end)
	elseif Frame == "Start" then
		-- Enable existing particle emitters on character
		for _, v in Character:GetDescendants() do
			if v:IsA("ParticleEmitter") then
				v.Enabled = true
			end
		end

		for _, v in eff.HeadMove:GetDescendants() do
			if v:IsA("ParticleEmitter") then
				v.Enabled = true
			end
		end

		for _, v in eff.smoke:GetDescendants() do
			if v:IsA("ParticleEmitter") then
				v.Enabled = true
			end
		end

		local TweenService = game:GetService("TweenService")
		local TInfo = TweenInfo.new(0.05, Enum.EasingStyle.Circular, Enum.EasingDirection.InOut, 3, true)

		-- Get ISBody particle emitters
		local ISBodyFolder = Replicated.Assets.VFX.ISBody
		local bodyEmitters = {}
		for _, emitter in ISBodyFolder:GetChildren() do
			if emitter:IsA("ParticleEmitter") then
				table.insert(bodyEmitters, emitter)
			end
		end

		-- Apply transparency toggle and add ISBody particles to all body parts
		for _, part in Character:GetDescendants() do
			if (part:IsA("BasePart") or part:IsA("MeshPart")) and part ~= Character:FindFirstChild("HumanoidRootPart") then
				-- Apply transparency tween
				local itween = TweenService:Create(part, TInfo, { Transparency = 1 })
				itween:Play()

				-- Clone and attach ISBody particle emitters to this part
				for _, emitter in bodyEmitters do
					local clonedEmitter = emitter:Clone()
					clonedEmitter.Parent = part
					clonedEmitter.Enabled = true
					-- Don't destroy here - will be destroyed in "End" frame
				end
			end
		end
	elseif Frame == "End" then
		-- Disable particle emitters in effect parts
		for _, v in eff.HeadMove:GetDescendants() do
			if v:IsA("ParticleEmitter") then
				v.Enabled = false
			end
		end

		for _, v in eff.smoke:GetDescendants() do
			if v:IsA("ParticleEmitter") then
				v.Enabled = false
			end
		end

		for _, v in eff.Land:GetDescendants() do
			if v:IsA("ParticleEmitter") then
				v:Emit(v:GetAttribute("EmitCount"))
			end
		end

		-- Get ISBody emitter names to identify which particles to disable/destroy
		local ISBodyFolder = Replicated.Assets.VFX.ISBody
		local emitterNames = {}
		for _, emitter in ISBodyFolder:GetChildren() do
			if emitter:IsA("ParticleEmitter") then
				emitterNames[emitter.Name] = true
			end
		end

		-- Disable ALL particle emitters on character (including ISBody ones)
		for _, part in Character:GetDescendants() do
			if part:IsA("ParticleEmitter") then
				part.Enabled = false
			end
		end

		-- Destroy everything after 3 seconds
		task.delay(3, function()
			-- Only destroy ISBody particle emitters on character (the ones we added)
			for _, part in Character:GetDescendants() do
				if part:IsA("ParticleEmitter") and emitterNames[part.Name] then
					part:Destroy()
				end
			end

			-- Disconnect the position update connection
			if activeISConnections[Character] then
				activeISConnections[Character]:Disconnect()
				activeISConnections[Character] = nil
			end

			-- Destroy the effect
			if eff and eff.Parent then
				eff:Destroy()
			end

			-- Remove from active effects table
			activeISEffects[Character] = nil
		end)
	end
end

-- Bezier curve function for quadratic bezier
local function Bezier(t, start, control, endPos)
	return (1 - t)^2 * start + 2 * (1 - t) * t * control + t^2 * endPos
end

-- Branch alchemy skill visual effect
function Base.Branch(Character: Model, targetPos: Vector3, side: string, customSpawnSpeed: number?)
	local root = Character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local TweenService = game:GetService("TweenService")
	local Debris = game:GetService("Debris")
	local HttpService = game:GetService("HttpService")

	-- Get ground material and material variant from character OR target position
	local groundMaterial = Enum.Material.Slate
	local groundMaterialVariant = ""
	local groundColor = Color3.fromRGB(100, 100, 100)

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = {workspace.World.Live, workspace.World.Visuals}

	-- Try to get material from target position first (where rocks will spawn)
	local rayResult = workspace:Raycast(targetPos + Vector3.new(0, 5, 0), Vector3.new(0, -10, 0), rayParams)
	if not rayResult or not rayResult.Instance then
		-- Fallback to character position
		rayResult = workspace:Raycast(root.Position, Vector3.new(0, -10, 0), rayParams)
	end

	if rayResult and rayResult.Instance then
		groundMaterial = rayResult.Instance.Material
		groundMaterialVariant = rayResult.Instance.MaterialVariant
		groundColor = rayResult.Instance.Color
	end

	-- Determine start position based on side
	local startPos
	if side == "Left" then
		startPos = root.Position + (root.CFrame.RightVector * -15)
	else
		startPos = root.Position + (root.CFrame.RightVector * 15)
	end

	-- Control point for bezier curve with both horizontal and vertical arc
	-- The curve should arc AWAY from the straight line path (horizontally) AND upward (vertically)
	local midPoint = (startPos + targetPos) * 0.5

	-- Calculate perpendicular direction for horizontal arc
	local pathDirection = (targetPos - startPos).Unit
	local perpendicular = Vector3.new(pathDirection.Z, 0, -pathDirection.X).Unit

	-- Left side arcs +25 studs, right side arcs -25 studs
	local horizontalOffset
	if side == "Left" then
		horizontalOffset = perpendicular * 25
	else
		horizontalOffset = perpendicular * -25
	end

	-- Combine horizontal and vertical offset for extreme curve
	local controlPos = midPoint + Vector3.new(0, 15, 0) + horizontalOffset

	-- Calculate bezier points (fewer segments)
	local numSegments = 12
	local bezierPoints = {}
	for i = 0, numSegments do
		local t = i / numSegments
		local pos = Bezier(t, startPos, controlPos, targetPos)
		table.insert(bezierPoints, pos)
	end

	-- Track previous plank position for spawning effect
	local previousPlankPos = startPos
	local plankCount = 0

	-- Different timing for left vs right
	local baseDelay = side == "Left" and 0 or 0.3 -- Right starts 0.3s later
	-- Use custom spawn speed if provided, otherwise use default
	local spawnSpeed = customSpawnSpeed or (side == "Left" and 0.05 or 0.07)

	-- Create connected planks along the bezier path
	for i = 1, #bezierPoints - 1 do
		local currentPoint = bezierPoints[i]
		local nextPoint = bezierPoints[i + 1]

		-- Calculate direction and distance between points
		local direction = (nextPoint - currentPoint)
		local distance = direction.Magnitude
		direction = direction.Unit

		-- Progress along the path (0 to 1)
		local t = i / #bezierPoints

		-- Size progression: start as long skinny rectangles, end as bigger squares
		local plankWidth = (1 + (t * 5)) -- 1 to 6 (thin to wide)
		local plankHeight = (1 + (t * 5)) -- 1 to 6 (thin to wide, matching width for square)
		local plankLength = distance -- Length is the distance between bezier points

		plankCount = plankCount + 1

		-- Capture the previous position for this plank
		local spawnFromPos = previousPlankPos

		task.delay(baseDelay + (plankCount - 1) * spawnSpeed, function()
			-- Create plank
			local plank = Instance.new("Part")
			plank.Name = "BranchRock_" .. HttpService:GenerateGUID(false)
			plank.Anchored = true
			plank.CanCollide = false
			plank.Material = groundMaterial
			plank.MaterialVariant = groundMaterialVariant
			plank.Color = groundColor
			plank.Transparency = 1 -- Start fully transparent
			plank.Size = Vector3.new(plankWidth, plankHeight, plankLength)

			plank.Parent = workspace.World.Visuals

			-- Add Highlight (white) - must be added AFTER parenting
			local highlight = Instance.new("Highlight")
			highlight.FillColor = Color3.fromRGB(255, 255, 255)
			highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
			highlight.FillTransparency = 0
			highlight.OutlineTransparency = 0
			highlight.Adornee = plank
			highlight.Parent = plank

			-- Add WallVFX particles
			local wallVFX = Replicated.Assets.VFX.WallVFX:Clone()
			for _, v in wallVFX:GetChildren() do
				if v:IsA("ParticleEmitter") then
					v.Parent = plank
				end
			end

			-- Add Jump VFX particles
			local jumpVFX = Replicated.Assets.VFX.Jump:Clone()
			for _, v in jumpVFX:GetChildren() do
				if v:IsA("ParticleEmitter") then
					v.Parent = plank
				end
			end

			-- Position plank using CFrame.lookAt (like zipline example)
			-- Position the plank so its center is exactly at currentPoint
			local finalCFrame = CFrame.lookAt(currentPoint, nextPoint)
			plank.Position = currentPoint -- Set position explicitly to ensure center is at currentPoint

			-- Add slight random rotation
			local randomRotation = CFrame.Angles(
				math.rad((math.random() - 0.5) * 5),
				math.rad((math.random() - 0.5) * 5),
				math.rad((math.random() - 0.5) * 5)
			)
			finalCFrame = finalCFrame * randomRotation

			-- Start CFrame: at previous position, facing the same direction
			local startCFrame = CFrame.lookAt(spawnFromPos, spawnFromPos + direction) * randomRotation
			plank.CFrame = startCFrame

			-- Tween from previous position to final position AND fade in
			local tweenDuration = 0.15 + (math.random() * 0.1)
			local tweenInfo = TweenInfo.new(tweenDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			local tween = TweenService:Create(plank, tweenInfo, {
				CFrame = finalCFrame,
				Transparency = 0
			})
			tween:Play()

			-- Fade out highlight
			TweenService:Create(highlight, TweenInfo.new(tweenDuration * 1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
				FillTransparency = 1,
				OutlineTransparency = 1
			}):Play()

			-- Emit particles once spawned
			tween.Completed:Connect(function()
				for _, v in plank:GetChildren() do
					if v:IsA("ParticleEmitter") then
						local emitCount = v:GetAttribute("EmitCount")
						if emitCount then
							v:Emit(emitCount)
						end
					end
				end
			end)

			-- Crumble and fade out when despawning
			task.delay(2.5, function()
				-- Break into smaller pieces (crumble effect)
				for _ = 1, 3 do
					local crumble = Instance.new("Part")
					crumble.Name = "BranchCrumble"
					crumble.Anchored = false
					crumble.CanCollide = false
					crumble.Material = groundMaterial
					crumble.MaterialVariant = groundMaterialVariant
					crumble.Color = groundColor
					crumble.Size = plank.Size / 3
					crumble.CFrame = plank.CFrame * CFrame.new(
						(math.random() - 0.5) * plank.Size.X,
						(math.random() - 0.5) * plank.Size.Y,
						(math.random() - 0.5) * plank.Size.Z
					)
					crumble.Parent = workspace.World.Visuals

					-- Add velocity to crumbles
					local velocity = Instance.new("BodyVelocity")
					velocity.MaxForce = Vector3.new(4000, 4000, 4000)
					velocity.Velocity = Vector3.new(
						(math.random() - 0.5) * 10,
						-5,
						(math.random() - 0.5) * 10
					)
					velocity.Parent = crumble

					-- Fade out crumbles
					TweenService:Create(crumble, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {
						Transparency = 1
					}):Play()

					game:GetService("Debris"):AddItem(crumble, 0.6)
				end

				-- Fade out main plank
				local fadeTween = TweenService:Create(plank, TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {
					Transparency = 1
				})
				fadeTween:Play()
				game:GetService("Debris"):AddItem(plank, 0.4)
			end)
		end)

		-- Update previous position for next plank (use nextPoint as the new starting position)
		previousPlankPos = nextPoint
	end
end

-- Branch Crater Effect
Base.BranchCrater = function(targetPos)
	local craterPosition = targetPos + Vector3.new(0, 1, 0) -- Raise 1 stud above ground

	local success, err = pcall(function()
		local craterCFrame = CFrame.new(craterPosition)

		local effect = RockMod.New("Crater", craterCFrame, {
			Distance = { 5, 12 },
			SizeMultiplier = 0.5,
			PartCount = 10,
			Layers = { 2, 3 },
			ExitIterationDelay = { 0.5, 1 },
			LifeCycle = {
				Entrance = {
					Type = "Elevate",
					Speed = 0.25,
					Division = 3,
					EasingStyle = Enum.EasingStyle.Quad,
					EasingDirection = Enum.EasingDirection.Out,
				},
				Exit = {
					Type = "SizeDown",
					Speed = 0.3,
					Division = 2,
					EasingStyle = Enum.EasingStyle.Sine,
					EasingDirection = Enum.EasingDirection.In,
				},
			},
		})

		if effect then
			effect:Debris("Normal", {
				Size = { 0.5, 1.5 },
				UpForce = { 0.4, 0.8 },
				RotationalForce = {10, 25},
				Spread = { 6, 6 },
				PartCount = 8,
				Radius = 6,
				LifeTime = 4,
				LifeCycle = {
					Entrance = {
						Type = "SizeUp",
						Speed = 0.25,
						Division = 3,
						EasingStyle = Enum.EasingStyle.Quad,
						EasingDirection = Enum.EasingDirection.Out,
					},
					Exit = {
						Type = "SizeDown",
						Speed = 0.3,
						Division = 2,
						EasingStyle = Enum.EasingStyle.Sine,
						EasingDirection = Enum.EasingDirection.In,
					},
				},
			})
		end
	end)

	if not success then
		warn("[BranchCrater] Error creating crater:", err)
	end
end

-- Ground Decay Effect (CXZ combination)
-- Creates 3 delayed craters centered on the player
-- First crater: big rocks, small diameter
-- Second crater: medium rocks, medium diameter
-- Third crater: small rocks, big diameter
Base.GroundDecay = function(Character)
	local root = Character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local centerPos = root.Position

	-- Get ground material and material variant from character position
	local groundMaterial = Enum.Material.Slate
	local groundMaterialVariant = ""

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = {workspace.World.Live, workspace.World.Visuals}

	local rayResult = workspace:Raycast(root.Position, Vector3.new(0, -10, 0), rayParams)
	if rayResult and rayResult.Instance then
		groundMaterial = rayResult.Instance.Material
		groundMaterialVariant = rayResult.Instance.MaterialVariant
	end

	-- First crater: Big rocks, small diameter
	task.delay(0, function()
		local craterCFrame = CFrame.new(centerPos + Vector3.new(0, 1, 0))

		local effect = RockMod.New("Crater", craterCFrame, {
			Distance = { 3, 6 }, -- Small diameter
			SizeMultiplier = 1.2, -- Big rocks
			PartCount = 8,
			Layers = { 2, 2 },
			Material = groundMaterial,
			MaterialVariant = groundMaterialVariant,
			ExitIterationDelay = { 0.5, 1 },
			LifeCycle = {
				Entrance = {
					Type = "Elevate",
					Speed = 0.3,
					Division = 3,
					EasingStyle = Enum.EasingStyle.Quad,
					EasingDirection = Enum.EasingDirection.Out,
				},
				Exit = {
					Type = "SizeDown",
					Speed = 0.4,
					Division = 2,
					EasingStyle = Enum.EasingStyle.Sine,
					EasingDirection = Enum.EasingDirection.In,
				},
			},
		})

		if effect then
			effect:Debris("Normal", {
				Size = { 1, 2 }, -- Big debris
				UpForce = { 0.5, 0.9 },
				RotationalForce = {15, 30},
				Spread = { 5, 5 },
				PartCount = 6,
				Radius = 5,
				LifeTime = 5,
				LifeCycle = {
					Entrance = {
						Type = "SizeUp",
						Speed = 0.25,
						Division = 3,
						EasingStyle = Enum.EasingStyle.Quad,
						EasingDirection = Enum.EasingDirection.Out,
					},
					Exit = {
						Type = "SizeDown",
						Speed = 0.3,
						Division = 2,
						EasingStyle = Enum.EasingStyle.Sine,
						EasingDirection = Enum.EasingDirection.In,
					},
				},
			})
		end

		-- Brief bouncy stark screenshake for first crater
		Base.Shake(6, 30, centerPos) -- Impactful shake for first crater
	end)

	-- Second crater: Medium rocks, medium diameter
	task.delay(0.4, function()
		local craterCFrame = CFrame.new(centerPos + Vector3.new(0, 1, 0))

		local effect = RockMod.New("Crater", craterCFrame, {
			Distance = { 6, 12 }, -- Medium diameter
			SizeMultiplier = 0.8, -- Medium rocks
			PartCount = 12,
			Layers = { 2, 3 },
			Material = groundMaterial,
			MaterialVariant = groundMaterialVariant,
			ExitIterationDelay = { 0.5, 1 },
			LifeCycle = {
				Entrance = {
					Type = "Elevate",
					Speed = 0.3,
					Division = 3,
					EasingStyle = Enum.EasingStyle.Quad,
					EasingDirection = Enum.EasingDirection.Out,
				},
				Exit = {
					Type = "SizeDown",
					Speed = 0.4,
					Division = 2,
					EasingStyle = Enum.EasingStyle.Sine,
					EasingDirection = Enum.EasingDirection.In,
				},
			},
		})

		if effect then
			effect:Debris("Normal", {
				Size = { 0.6, 1.2 }, -- Medium debris
				UpForce = { 0.5, 0.9 },
				RotationalForce = {15, 30},
				Spread = { 7, 7 },
				PartCount = 10,
				Radius = 8,
				LifeTime = 5,
				LifeCycle = {
					Entrance = {
						Type = "SizeUp",
						Speed = 0.25,
						Division = 3,
						EasingStyle = Enum.EasingStyle.Quad,
						EasingDirection = Enum.EasingDirection.Out,
					},
					Exit = {
						Type = "SizeDown",
						Speed = 0.3,
						Division = 2,
						EasingStyle = Enum.EasingStyle.Sine,
						EasingDirection = Enum.EasingDirection.In,
					},
				},
			})
		end

		-- Brief bouncy stark screenshake for second crater
		Base.Shake(7, 32, centerPos) -- Stronger shake for second crater
	end)

	-- Third crater: Small rocks, big diameter
	task.delay(0.8, function()
		local craterCFrame = CFrame.new(centerPos + Vector3.new(0, 1, 0))

		local effect = RockMod.New("Crater", craterCFrame, {
			Distance = { 12, 20 }, -- Big diameter
			SizeMultiplier = 0.4, -- Small rocks
			PartCount = 16,
			Layers = { 3, 4 },
			Material = groundMaterial,
			MaterialVariant = groundMaterialVariant,
			ExitIterationDelay = { 0.5, 1 },
			LifeCycle = {
				Entrance = {
					Type = "Elevate",
					Speed = 0.3,
					Division = 3,
					EasingStyle = Enum.EasingStyle.Quad,
					EasingDirection = Enum.EasingDirection.Out,
				},
				Exit = {
					Type = "SizeDown",
					Speed = 0.4,
					Division = 2,
					EasingStyle = Enum.EasingStyle.Sine,
					EasingDirection = Enum.EasingDirection.In,
				},
			},
		})

		if effect then
			effect:Debris("Normal", {
				Size = { 0.3, 0.8 }, -- Small debris
				UpForce = { 0.5, 0.9 },
				RotationalForce = {15, 30},
				Spread = { 10, 10 },
				PartCount = 14,
				Radius = 12,
				LifeTime = 5,
				LifeCycle = {
					Entrance = {
						Type = "SizeUp",
						Speed = 0.25,
						Division = 3,
						EasingStyle = Enum.EasingStyle.Quad,
						EasingDirection = Enum.EasingDirection.Out,
					},
					Exit = {
						Type = "SizeDown",
						Speed = 0.3,
						Division = 2,
						EasingStyle = Enum.EasingStyle.Sine,
						EasingDirection = Enum.EasingDirection.In,
					},
				},
			})
		end

		-- Brief bouncy stark screenshake for third crater (biggest)
		Base.SpecialShake(9, 35, centerPos) -- Most impactful shake for biggest crater
	end)
end

return Base
