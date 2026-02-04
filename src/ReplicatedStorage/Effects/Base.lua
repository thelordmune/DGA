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
local VFXCleanup = require(Replicated.Modules.Utils.VFXCleanup)
local AB = require(Replicated.Modules.Utils.AymanBolt)

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
local StateManager = require(Replicated.Modules.ECS.StateManager)

local TInfo = TweenInfo.new(0.35, Enum.EasingStyle.Circular, Enum.EasingDirection.Out, 0)

-- Store original trail WidthScale values (so they persist across multiple dashes)
local originalTrailWidths = {}

local Base = {}

-- Safe delayed destroy helper - checks if instance exists before destroying
-- Prevents errors when VFX is cancelled early by ActionCancellation
local function safeDelayedDestroy(instance, delay)
	task.delay(delay, function()
		if instance and instance.Parent then
			instance:Destroy()
		end
	end)
end

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
	if Weapon == "Fist" then
		local eff = Replicated.Assets.VFX.M1:Clone()
		eff.Parent = workspace.World.Visuals
		if Combo == 1 then
			eff:PivotTo(Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, -2.5) * CFrame.Angles(math.rad(180), 0, 0))
			EmitModule.emit(eff["1"])
		elseif Combo == 2 then
			eff:PivotTo(Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, -2.5) * CFrame.Angles(math.rad(180), 0, 0))
			EmitModule.emit(eff["2"])
		elseif Combo == 3 then
			eff:PivotTo(Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, -2.5) * CFrame.Angles(math.rad(180), 0, 0))
			EmitModule.emit(eff["3"])
		elseif Combo == 4 then
			eff:PivotTo(Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, -2.5) * CFrame.Angles(math.rad(180), 0, 0))
			EmitModule.emit(eff["4"])
			safeDelayedDestroy(eff, 3)
		end
	else
		local Slash: BasePart = Replicated.Assets.VFX[Weapon .. "Slashes"][Combo]:Clone()

		-- Store the original orientation (angular rotation) of the slash
		-- local originalOrientation = Slash.Orientation

		-- Position the slash in front of the player and make it face the player's direction
		local playerCFrame = Character.HumanoidRootPart.CFrame

		-- if Weapon == "Fist" then
		-- 	if Combo == 1 then
		-- 	Slash.CFrame = playerCFrame * CFrame.new(0, 0, -1) * CFrame.Angles(0,0,math.rad(-77))
		-- 	elseif Combo == 2 then
		-- 		Slash.CFrame = playerCFrame * CFrame.new(0, 0, -1) * CFrame.Angles(0,math.rad(-30),math.rad(-77))
		-- 	elseif Combo == 3 then
		-- 		Slash.CFrame = playerCFrame * CFrame.new(0, 0, -1) * CFrame.Angles(0,0,math.rad(-62))
		-- 	elseif Combo == 4 then
		-- 		Slash.CFrame = playerCFrame * CFrame.new(0, 0, -1) * CFrame.Angles(0,0,math.rad(87))
		-- 	end

		-- end

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
		while Player.Character and StateManager.StateCheck(Player.Character, "Actions", "Clash") do
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
							table.insert(
								keypoints,
								NumberSequenceKeypoint.new(
									keypoint.Time,
									keypoint.Value * value,
									keypoint.Envelope * value
								)
							)
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
					originalWidthScale = originalWidthScale,
				})
			end
		end

		-- Enable particles for the duration of the dash instead of just emitting once
		local dashDuration = 0.15 -- Match the dash duration from Movement.lua

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

function Base.Transmute(Character: Model, Distance: number?, Height: number?)
	local root = Character.HumanoidRootPart
	local Construct = Replicated.Assets.VFX.Construct:Clone()
	local CirlceBreak = Replicated.Assets.VFX.TP.CircleBreak:Clone()

	local dist = Distance or -3
	local height = Height or 2
	Construct:PivotTo(root.CFrame * CFrame.new(0, height, dist))
	CirlceBreak:PivotTo(root.CFrame * CFrame.new(0, 0, 0))
	-- Construct.Anchored = true
	-- Construct.CanCollide = false
	CirlceBreak.Parent = workspace.World.Visuals
	Construct.Parent = workspace.World.Visuals

	-- for _, v in (Construct:GetDescendants()) do
	-- 	if v:IsA("ParticleEmitter") then
	-- 		v:Emit(v:GetAttribute("EmitCount"))
	-- 	end
	-- end

	EmitModule.emit(Construct)

	-- Play transmute sound (alchemy sound, not clap)
	local transmuteSound = Replicated.Assets.SFX.FMAB.Transmute:Clone()
	transmuteSound.Volume = 2
	transmuteSound.Parent = root
	transmuteSound:Play()
	game:GetService("Debris"):AddItem(transmuteSound, transmuteSound.TimeLength)

	local TInfo4 = TweenInfo.new(1, Enum.EasingStyle.Circular, Enum.EasingDirection.InOut, 0)
	local TInfo5 = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0) -- Extended fade time
	local TInfoDecalFade = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0)

	local activeTweens = {}
	local t1 = TweenService:Create(Construct.Attachment.PointLight, TInfo4, { Range = 30 })
	table.insert(activeTweens, t1)
	t1:Play()

	local t2 = TweenService:Create(Construct.Attachment.PointLight, TInfo5, { Brightness = 0 })
	table.insert(activeTweens, t2)

	-- Fade out decals and textures (the visual effects of the transmutation circle)
	local fadeOutDecals = {}
	for _, v in Construct:GetDescendants() do
		local success, fadeTween = pcall(function()
			if v:IsA("ParticleEmitter") or v:IsA("Beam") then
				return TweenService:Create(v, TInfoDecalFade, { Transparency = NumberSequence.new(1) })
			elseif v:IsA("Decal") or v:IsA("Texture") then
				return TweenService:Create(v, TInfoDecalFade, { Transparency = 1 })
			end
		end)

		if success and fadeTween then
			table.insert(fadeOutDecals, fadeTween)
		end
	end

	t1.Completed:Connect(function()
		task.delay(.15, function()
EmitModule.emit(CirlceBreak)
		local Breaksound = Replicated.Assets.SFX.MISC.Break:Clone()
	Breaksound.Volume = 2
	Breaksound.Parent = root
	Breaksound:Play()
	game:GetService("Debris"):AddItem(Breaksound, Breaksound.TimeLength)
	CamShake({
		Location = root.Position,
		Magnitude = 5.5,
		Damp = 0.00005,
		Frequency = 35,
		Influence = Vector3.new(0.55, 1, 0.55),
		Falloff = 89,
	})
		end)
		
		t2:Play()
		-- Start fading out the decals/textures
		for _, tween in fadeOutDecals do
			tween:Play()
		end
	end)
	t2.Completed:Connect(function()
		-- Wait for decal fade to complete before destroying
		
		
		task.wait(0.5)
		Construct:Destroy()
	end)
end

function Base.TeleportGlow(Character: Model)
	-- Create a white glow effect on the character before teleport
	local root = Character.HumanoidRootPart

	-- Create a bright white point light at the character
	local glowAttachment = Instance.new("Attachment")
	glowAttachment.Parent = root

	local pointLight = Instance.new("PointLight")
	pointLight.Color = Color3.fromRGB(255, 255, 255)
	pointLight.Brightness = 0
	pointLight.Range = 0
	pointLight.Parent = glowAttachment

	-- Tween the light to full brightness
	local glowTween = TweenService:Create(
		pointLight,
		TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Brightness = 10, Range = 25 }
	)
	glowTween:Play()

	-- Store original colors and tween to white
	local originalColors = {}
	for _, part in Character:GetDescendants() do
		if part:IsA("BasePart") or part:IsA("MeshPart") then
			originalColors[part] = part.Color
			local colorTween = TweenService:Create(
				part,
				TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Color = Color3.fromRGB(255, 255, 255) }
			)
			colorTween:Play()
		end
	end

	-- Store the original colors on the character for later restoration
	Character:SetAttribute("_TeleportOriginalColors", true)
	for part, color in pairs(originalColors) do
		part:SetAttribute("_OriginalColor", color)
	end
	-- Cleanup after effect completes
	task.delay(3, function()
		glowAttachment:Destroy()
	end)
end

function Base.TeleportFadeOut(Character: Model)
	-- Store original transparencies before fading out
	for _, part in Character:GetDescendants() do
		if part:IsA("BasePart") or part:IsA("MeshPart") then
			-- Store original transparency as an attribute
			if not part:GetAttribute("_OriginalTransparency") then
				part:SetAttribute("_OriginalTransparency", part.Transparency)
			end
		elseif part:IsA("Decal") or part:IsA("Texture") then
			if not part:GetAttribute("_OriginalTransparency") then
				part:SetAttribute("_OriginalTransparency", part.Transparency)
			end
		end
	end

	-- Fade out the character and all parts
	local fadeTime = 0.5

	for _, part in Character:GetDescendants() do
		if part:IsA("BasePart") or part:IsA("MeshPart") then
			local fadeTween = TweenService:Create(
				part,
				TweenInfo.new(fadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ Transparency = 1 }
			)
			fadeTween:Play()
		elseif part:IsA("Decal") or part:IsA("Texture") then
			local fadeTween = TweenService:Create(
				part,
				TweenInfo.new(fadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ Transparency = 1 }
			)
			fadeTween:Play()
		end
	end
end

function Base.TeleportFadeIn(Character: Model)
	-- Retrieve stored transparencies and colors from attributes
	local originalTransparencies = {}
	local originalColors = {}

	for _, part in Character:GetDescendants() do
		if part:IsA("BasePart") or part:IsA("MeshPart") then
			-- Get stored transparency or default to 0
			local storedTransparency = part:GetAttribute("_OriginalTransparency")
			originalTransparencies[part] = storedTransparency or 0
			part.Transparency = 1

			-- Restore original color from attribute if it exists
			local storedColor = part:GetAttribute("_OriginalColor")
			if storedColor then
				originalColors[part] = storedColor
				part.Color = storedColor
			else
				originalColors[part] = part.Color
			end
		elseif part:IsA("Decal") or part:IsA("Texture") then
			local storedTransparency = part:GetAttribute("_OriginalTransparency")
			originalTransparencies[part] = storedTransparency or 0
			part.Transparency = 1
		end
	end

	-- Track which parts we've already faded in
	local fadedParts = {}

	-- Get all body parts in order for reassembly effect
	local bodyParts = {
		Character:FindFirstChild("HumanoidRootPart"),
		Character:FindFirstChild("Torso") or Character:FindFirstChild("UpperTorso"),
		Character:FindFirstChild("Head"),
		Character:FindFirstChild("Left Arm") or Character:FindFirstChild("LeftUpperArm"),
		Character:FindFirstChild("Right Arm") or Character:FindFirstChild("RightUpperArm"),
		Character:FindFirstChild("Left Leg") or Character:FindFirstChild("LeftUpperLeg"),
		Character:FindFirstChild("Right Leg") or Character:FindFirstChild("RightUpperLeg"),
	}

	-- Fade in each part with a slight delay for reassembly effect
	local baseDelay = 0
	local delayIncrement = 0.1

	for i, part in ipairs(bodyParts) do
		if part then
			fadedParts[part] = true
			local delay = baseDelay + (i - 1) * delayIncrement
			task.delay(delay, function()
				-- Fade in the part transparency
				local originalTrans = originalTransparencies[part] or 0
				local fadeTween = TweenService:Create(
					part,
					TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ Transparency = originalTrans }
				)
				fadeTween:Play()

				-- Restore original color if it was stored
				if originalColors[part] then
					local colorTween = TweenService:Create(
						part,
						TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
						{ Color = originalColors[part] }
					)
					colorTween:Play()

					-- Clean up the attributes after restoring
					part:SetAttribute("_OriginalColor", nil)
				end

				-- Clean up transparency attribute
				part:SetAttribute("_OriginalTransparency", nil)

				-- Fade in all accessories and decals attached to this part
				for _, child in part:GetDescendants() do
					fadedParts[child] = true
					if originalTransparencies[child] then
						local childTween = TweenService:Create(
							child,
							TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
							{ Transparency = originalTransparencies[child] }
						)
						childTween:Play()

						-- Clean up child transparency attribute
						child:SetAttribute("_OriginalTransparency", nil)
					end

					-- Restore child colors too
					if (child:IsA("BasePart") or child:IsA("MeshPart")) and originalColors[child] then
						local childColorTween = TweenService:Create(
							child,
							TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
							{ Color = originalColors[child] }
						)
						childColorTween:Play()
						child:SetAttribute("_OriginalColor", nil)
					end
				end
			end)
		end
	end

	-- Fade in any remaining parts that weren't in the bodyParts list (fallback)
	task.delay(0.8, function()
		for part, transparency in pairs(originalTransparencies) do
			if not fadedParts[part] then
				if part:IsA("BasePart") or part:IsA("MeshPart") then
					local fadeTween = TweenService:Create(
						part,
						TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
						{ Transparency = transparency }
					)
					fadeTween:Play()
					part:SetAttribute("_OriginalTransparency", nil)

					if originalColors[part] then
						local colorTween = TweenService:Create(
							part,
							TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
							{ Color = originalColors[part] }
						)
						colorTween:Play()
						part:SetAttribute("_OriginalColor", nil)
					end
				elseif part:IsA("Decal") or part:IsA("Texture") then
					local fadeTween = TweenService:Create(
						part,
						TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
						{ Transparency = transparency }
					)
					fadeTween:Play()
					part:SetAttribute("_OriginalTransparency", nil)
				end
			end
		end
	end)

	-- Clean up the character attribute
	task.delay(1, function()
		Character:SetAttribute("_TeleportOriginalColors", nil)
	end)
end

function Base.Shake(magnitude: number, frequency: number?, location: Vector3?)
	-- New camera shake system using CamShake from Utils
	-- More impactful and lively shakes with higher default values

	-- Convert magnitude to number if it's a string (network serialization can cause this)
	local mag = tonumber(magnitude) or 0
	local freq = tonumber(frequency) or 25

	CamShake({
		Magnitude = mag * 1.5, -- Increased for more impact
		Frequency = freq, -- Higher frequency for more lively shakes
		Damp = 0.005, -- Slower dampening for longer lasting shakes
		Influence = Vector3.new(1.2, 1.2, 0.8), -- More influence on X and Y axes
		Location = location or workspace.CurrentCamera.CFrame.Position,
		Falloff = 100, -- Larger falloff distance
	})
end

function Base.SpecialShake(magnitude: number, frequency: number?, location: Vector3?)
	-- Special camera shake for intense moments (even more impactful)

	-- Convert magnitude to number if it's a string (network serialization can cause this)
	local mag = tonumber(magnitude) or 0
	local freq = tonumber(frequency) or 30

	CamShake({
		Magnitude = mag * 2, -- Double magnitude for special shakes
		Frequency = freq, -- Even higher frequency
		Damp = 0.004, -- Even slower dampening
		Influence = Vector3.new(1.5, 1.5, 1), -- Maximum influence
		Location = location or workspace.CurrentCamera.CFrame.Position,
		Falloff = 120,
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

	-- Camera shake like Rapid Thrust
	CamShake({
		Location = root.Position,
		Magnitude = 5.5,
		Damp = 0.00005,
		Frequency = 18,
		Influence = Vector3.new(0.45, 1, 0.45),
		Falloff = 65,
	})

	safeDelayedDestroy(eff, 3)
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
	if not value then
		return
	end -- Don't create scope if leaving combat

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
		started = started,
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
				Image = "rbxassetid://120479076364263",
				Position = UDim2.fromScale(0.44, 0.526),
				Size = UDim2.fromOffset(170, 85),
				ScaleType = Enum.ScaleType.Fit,
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
	---- print(params)
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
	-- ---- print("Base.Shot called - Character:", Character.Name, "Combo:", Combo, "LeftGun:", LeftGun and LeftGun.Name or "nil", "RightGun:", RightGun and RightGun.Name or "nil")
	if Combo == 1 then
		local eff = Replicated.Assets.VFX.Shot:Clone()
		eff.Parent = workspace.World.Visuals
		-- Use RightGun position and face forward in character's direction
		local effectPosition
		if LeftGun and LeftGun:FindFirstChild("EndPart") then
			local endPart = LeftGun:FindFirstChild("EndPart")
			effectPosition = endPart.Position
			-- ---- print("Combo 1: Using LeftGun", endPart.Name, "position")
		elseif LeftGun then
			-- Use gun position even without End part
			effectPosition = LeftGun.Position
			-- ---- print("Combo 1: Using LeftGun base position")
		else
			-- Fallback to hand position
			effectPosition = Character:FindFirstChild("RightHand").Position
			-- ---- print("Combo 1: Using RightHand fallback")
		end
		-- Always face forward in character's direction
		eff.CFrame = CFrame.lookAt(effectPosition, effectPosition + Character.HumanoidRootPart.CFrame.LookVector)
			* CFrame.Angles(0, math.rad(90), 0)
		for _, v in eff:GetDescendants() do
			if v:IsA("ParticleEmitter") then
				v:Emit(v:GetAttribute("EmitCount"))
			end
		end
		safeDelayedDestroy(eff, 3)
	end
	if Combo == 2 then
		local eff = Replicated.Assets.VFX.Shot:Clone()
		eff.Parent = workspace.World.Visuals
		-- Use LeftGun position and face forward in character's direction
		local effectPosition
		if RightGun and RightGun:FindFirstChild("EndPart") then
			local endPart = RightGun:FindFirstChild("EndPart")
			effectPosition = endPart.Position
			-- ---- print("Combo 2: Using RightGun", endPart.Name, "position")
		elseif RightGun then
			-- Use gun position even without End part
			effectPosition = RightGun.Position
			-- ---- print("Combo 2: Using RightGun base position")
		else
			-- Fallback to hand position
			effectPosition = Character:FindFirstChild("LeftHand").Position
			-- ---- print("Combo 2: Using LeftHand fallback")
		end
		-- Always face forward in character's direction
		eff.CFrame = CFrame.lookAt(effectPosition, effectPosition + Character.HumanoidRootPart.CFrame.LookVector)
			* CFrame.Angles(0, math.rad(90), 0)
		for _, v in eff:GetDescendants() do
			if v:IsA("ParticleEmitter") then
				v:Emit(v:GetAttribute("EmitCount"))
			end
		end
		safeDelayedDestroy(eff, 3)
	end
	if Combo == 3 then
		local eff = Replicated.Assets.VFX.Combined:Clone()
		eff.Parent = workspace.World.Visuals
		-- Position in front of character and face forward (no rotation)
		eff.CFrame = Character.HumanoidRootPart.CFrame * CFrame.new(0, 1.5, -2) * CFrame.Angles(0, math.rad(180), 0)
		-- ---- print("Combo 3: Using Combined effect in front of character")

		for _, v in eff:GetDescendants() do
			if v:IsA("ParticleEmitter") then
				v:Emit(v:GetAttribute("EmitCount"))
			end
		end
		safeDelayedDestroy(eff, 3)

		meshfunction(eff.CFrame, workspace.World.Visuals)
	end
end

-- Track active dialogue sessions to prevent duplicates
local activeDialogueSessions = {}

function Base.Commence(Dialogue: { npc: Model, name: string, inrange: boolean, state: string })
	---- print("🎭 [Effects.Base] COMMENCE FUNCTION CALLED")
	---- print("📋 Dialogue data received:", Dialogue)

	-- Validate dialogue data
	if not Dialogue then
		---- print("❌ [Effects.Base] ERROR: No dialogue data provided!")
		return
	end

	if not Dialogue.npc then
		---- print("❌ [Effects.Base] ERROR: No NPC model in dialogue data!")
		return
	end

	if not Dialogue.name then
		---- print("❌ [Effects.Base] ERROR: No NPC name in dialogue data!")
		return
	end

	---- print("✅ [Effects.Base] Dialogue validation passed")
	---- print("🎯 [Effects.Base] NPC:", Dialogue.name, "| In Range:", Dialogue.inrange, "| State:", Dialogue.state)

	local npcId = Dialogue.npc:GetDebugId() -- Unique identifier for this NPC instance

	if Dialogue.inrange then
		-- Check if we already have an active session for this NPC
		if activeDialogueSessions[npcId] then
			---- print("⚠️ [Effects.Base] Dialogue session already active for", Dialogue.name, "- skipping")
			return
		end

		---- print("🎯 [Effects.Base] Player is in range, creating proximity UI...")
		activeDialogueSessions[npcId] = true

		-- Check if highlight already exists
		local highlight = Dialogue.npc:FindFirstChild("Highlight")
		if not highlight then
			---- print("✨ [Effects.Base] Creating new highlight for NPC")
			highlight = Instance.new("Highlight")
			highlight.Name = "Highlight"
			highlight.DepthMode = Enum.HighlightDepthMode.Occluded
			highlight.FillTransparency = 1
			highlight.OutlineTransparency = 1
			highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
			highlight.Parent = Dialogue.npc

			local hTween = TweenService:Create(highlight, TInfo, { OutlineTransparency = 0 })
			hTween:Play()
			---- print("🎬 [Effects.Base] Highlight tween started")
		else
			---- print("♻️ [Effects.Base] Highlight already exists, reusing it")
			-- Make sure it's visible
			if highlight.OutlineTransparency > 0.5 then
				local hTween = TweenService:Create(highlight, TInfo, { OutlineTransparency = 0 })
				hTween:Play()
			end
		end

		---- print("📦 [Effects.Base] Loading Fusion scope and Proximity component...")
		local scope = scoped(Fusion, {
			Proximity = require(Replicated.Client.Components.Proximity),
		})
		local start = scope:Value(false)
		---- print("✅ [Effects.Base] Fusion scope created successfully")

		local Target = scope:New("ScreenGui")({
			Name = "ScreenGui",
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
			Parent = Player.PlayerGui,
		})
		---- print("🖥️ [Effects.Base] ScreenGui created and parented to PlayerGui")

		local parent = Target

		---- print("🔗 [Effects.Base] Creating Proximity component...")
		scope:Proximity({
			begin = start,
			par = parent,
		})
		---- print("✅ [Effects.Base] Proximity component created")

		---- print("⏱️ [Effects.Base] Starting proximity animation sequence...")
		task.wait(0.3)
		---- print("🎬 [Effects.Base] Setting start to true")
		start:set(true)
		task.wait(2.5)
		---- print("🎬 [Effects.Base] Setting start to false")
		start:set(false)
		task.wait(0.5)
		---- print("🧹 [Effects.Base] Cleaning up scope")
		scope:doCleanup()

		-- Clear the active session
		activeDialogueSessions[npcId] = nil
		---- print("✅ [Effects.Base] Proximity effect complete")
	else
		---- print("🚫 [Effects.Base] Player not in range, removing highlight...")

		-- Clear any active session
		activeDialogueSessions[npcId] = nil

		local highlight = Dialogue.npc:FindFirstChild("Highlight")
		if highlight then
			---- print("✨ [Effects.Base] Found existing highlight, fading out...")
			local hTween = TweenService:Create(highlight, TInfo, { OutlineTransparency = 1 })
			hTween:Play()
			hTween.Completed:Connect(function()
				if highlight and highlight.Parent then
					highlight:Destroy()
					---- print("🗑️ [Effects.Base] Highlight destroyed")
				end
			end)
		else
			---- print("⚠️ [Effects.Base] No highlight found to remove")
		end
	end

	---- print("✅ [Effects.Base] COMMENCE FUNCTION COMPLETE")
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
		-- for _, v in Wedge:GetDescendants() do
		-- 	if v:IsA("Beam") then
		-- 		TweenService:Create(v, TInfo, { Width0 = 1.035, Width1 = 2.766 }):Play()
		-- 	end
		-- end
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
	local eff = Replicated.Assets.VFX.NewNT:Clone()
	if Frame == "Start" then
		eff.Parent = workspace.World.Visuals
		eff:PivotTo(Character.HumanoidRootPart.CFrame * CFrame.new(0, -2.5, 0))
		EmitModule.emit(eff.jump, eff.spearpushwoahhh)
	end

	if Frame == "Hit" then
		eff:PivotTo(Character.HumanoidRootPart.CFrame * CFrame.new(0, -2.5, 0))
		EmitModule.emit(eff.Pierce, eff.bloodhit)
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
		-- Base.SpecialShake(8, 28, Character.HumanoidRootPart.Position)
		CamShake({
			Location = Character.PrimaryPart.Position,
			Magnitude = 14.5,
			Damp = 0.00005,
			Frequency = 45,
			Influence = Vector3.new(0.35, 1, 0.35),
			Falloff = 45,
		})
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
						Threshold = 0.5,
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

	local Main_CFrame = CF or CFrame.new(0, 0, 0)

	-- Settings

	local Visual_Directory = {
		["WindRing"] = Replicated.Assets.VFX.DownslamVFX.Jump.Jump.WindRing,
		["Wind"] = Replicated.Assets.VFX.DownslamVFX.Jump.Slam.Wind,
		["WindBig"] = Replicated.Assets.VFX.DownslamVFX.Jump.Slam.WindBig,
		["Kick"] = Replicated.Assets.VFX.DownslamVFX.Jump.Slam.Kick,
		["Wind1"] = Replicated.Assets.VFX.DownslamVFX.Jump.Slam.Wind1,
		["Wind2"] = Replicated.Assets.VFX.DownslamVFX.Jump.Jump.Wind2,
	} :: { [string]: Instance }

	local Visual_Data = {
		[Visual_Directory["WindBig"]] = {
			General = {
				Offset = CFrame.new(
					0.14389044,
					-6.14201164,
					0.147280157,
					-0.0871312022,
					0,
					0.996197224,
					0,
					-1,
					0,
					0.996197283,
					0,
					0.0871317983
				),
				Tween_Duration = 0.3,
				Transparency = 0.7,
			},

			Random_Angles = {
				X = { 0, 0 },
				Y = { 0, 0 },
				Z = { 0, 0 },
			},
			BasePart = {
				Property = {
					Size = Vector3.new(22.354114532470703, 0.42486676573753357, 22.354108810424805),
					CFrame = Main_CFrame * CFrame.new(
						0.14389044,
						-8.68135548,
						0.147280157,
						-0.996199965,
						0,
						-0.0871019065,
						0,
						-1.00000048,
						0,
						-0.08710289,
						0,
						0.996199727
					),
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
					X = { 0, 0 },
					Y = { -360, 360 },
					Z = { 0, 0 },
				},
			},

			BasePart = {
				Property = {
					Size = Vector3.new(25.763809204101562, 2.8394811153411865, 25.763809204101562),
					CFrame = Main_CFrame * CFrame.new(
						-0.113482013,
						-7.35580206,
						4.91738319e-07,
						-0.783837199,
						0,
						0.620966434,
						0,
						1,
						0,
						-0.620966434,
						0,
						-0.783837199
					),
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
				Offset = CFrame.new(
					0.1087787,
					-6.41260242,
					0.0389252082,
					-2.38418579e-07,
					0,
					-1.00000012,
					0,
					1,
					0,
					1.00000012,
					0,
					-2.38418579e-07
				),
				Tween_Duration = 0.5,
				Transparency = 0.95,
			},

			Random_Angles = {
				X = { 0, 0 },
				Y = { 0, 0 },
				Z = { 0, 0 },
			},
			BasePart = {
				Property = {
					Size = Vector3.new(25.052053451538086, 4.060371398925781, 25.052053451538086),
					CFrame = Main_CFrame * CFrame.new(
						0,
						-7.56635475,
						0,
						0.336982906,
						0,
						0.941510856,
						0,
						1,
						0,
						-0.941510856,
						0,
						0.336982906
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

		[Visual_Directory["Kick"]] = {
			General = {
				Offset = CFrame.new(-0.113484487, -4.35610867, 0.625125647, 0, 0, 1, 1, 0, 0, 0, 1, 0),
				Tween_Duration = 0.15,
				Transparency = 0.9,
			},

			Features = {
				Random_Angles = {
					X = { 0, 0 },
					Y = { -360, 360 },
					Z = { 0, 0 },
				},
			},

			BasePart = {
				Property = {
					Size = Vector3.new(0.4741426110267639, 5.183227062225342, 5.183227062225342),
					CFrame = Main_CFrame
						* CFrame.new(-0.113484487, -7.55821896, 0.625125647, 0, 0, 1, 1, 0, 0, 0, 1, 0),
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
				X = { 0, 0 },
				Y = { 0, 0 },
				Z = { 0, 0 },
			},
			BasePart = {
				Property = {
					Size = Vector3.new(15.603704452514648, 3.2936112880706787, 15.603704452514648),
					CFrame = Main_CFrame * CFrame.new(
						0.152969867,
						-8.23160553,
						0.375163078,
						-0.965929806,
						0,
						0.258804828,
						0,
						1,
						0,
						-0.258804828,
						0,
						-0.965929806
					),
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
				X = { 0, 0 },
				Y = { 0, 0 },
				Z = { 0, 0 },
			},
			BasePart = {
				Property = {
					Size = Vector3.new(18.56374740600586, 0.9379472136497498, 18.790721893310547),
					CFrame = Main_CFrame * CFrame.new(
						0.750563145,
						-7.59732962,
						0.9011935,
						-0.422593057,
						0,
						-0.906319737,
						0,
						-1,
						0,
						-0.906319737,
						0,
						0.422593057
					),
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

			-- Random Angles

			if Data.Features and Data.Features.Random_Angles then
				Data.BasePart.Property.CFrame *= CFrame.Angles(
					math.random(unpack(Data.Features.Random_Angles.X)),
					math.random(unpack(Data.Features.Random_Angles.Y)),
					math.random(unpack(Data.Features.Random_Angles.Z))
				)
			end

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
			if Data.Decal then
				game:GetService("TweenService")
					:Create(
						Visual:FindFirstChildOfClass("Decal"),
						TweenInfo.new(
							Data.General.Tween_Duration,
							Data.Decal.Tween.Easing_Style,
							Data.Decal.Tween.Easing_Direction
						),
						Data.Decal.Property
					)
					:Play()
			end
			if Data.Mesh then
				game:GetService("TweenService")
					:Create(
						Visual:FindFirstChildOfClass("SpecialMesh"),
						TweenInfo.new(
							Data.General.Tween_Duration,
							Data.Mesh.Tween.Easing_Style,
							Data.Mesh.Tween.Easing_Direction
						),
						Data.Mesh.Property
					)
					:Play()
			end

			-- Clean Up

			task.delay(Data.General.Tween_Duration, Visual.Destroy, Visual)
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
					RotationalForce = { 20, 40 },
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

function Base.TransmutationCircle(Character: Model, Destination: CFrame?, CleanupDelay: number?)
	-- CleanupDelay: Optional parameter to specify when to start fading out (default 3 seconds)
	local cleanupDelay = CleanupDelay or 3

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

	-- Start fade out at specified delay
	task.delay(cleanupDelay, function()
		if eff and eff.Parent and eff:FindFirstChild("Decal") then
			TweenService:Create(eff.Decal, fadeInfo, { Transparency = 1 }):Play()
		end
	end)

	-- Destroy after fade completes (cleanup delay + fade duration)
	task.delay(cleanupDelay + 1.5, function()
		if eff and eff.Parent then
			eff:Destroy()
		end
		if emits and emits.Parent then
			emits:Destroy()
		end
	end)
end

function Base.Spawn(Position: Vector3)
	local eff = Replicated.Assets.VFX.SpawnEff:Clone()
	eff.Position = Position
	---- print("Spawning effect at:", tostring(eff.CFrame))
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
		if not rightLeg then
			return
		end

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
			if
				Character
				and Character.Parent
				and Character:FindFirstChild("HumanoidRootPart")
				and eff
				and eff.Parent
			then
				-- Update all parts that should follow
				for part, offset in followParts do
					if part and part.Parent then
						part.CFrame = Character.HumanoidRootPart.CFrame * CFrame.new(0, -5, 0)
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

		-- Register VFX with cleanup system
		VFXCleanup.RegisterVFX(Character, eff, connection)

		local rd = eff.Model
		for _, v in rd:GetDescendants() do
			if v:IsA("ParticleEmitter") then
				v:Emit(v:GetAttribute("EmitCount"))
			end
		end
		task.delay(3, function()
			rd:Destroy()
		end)
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
		for _, v in lift:GetDescendants() do
			if v:IsA("ParticleEmitter") then
				v:Emit(v:GetAttribute("EmitCount"))
			end
		end
		task.delay(3, function()
			lift:Destroy()
		end)
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
			if
				(part:IsA("BasePart") or part:IsA("MeshPart"))
				and part ~= Character:FindFirstChild("HumanoidRootPart")
			then
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
	return (1 - t) ^ 2 * start + 2 * (1 - t) * t * control + t ^ 2 * endPos
end

-- Branch alchemy skill visual effect
function Base.Branch(Character: Model, targetPos: Vector3, side: string, customSpawnSpeed: number?)
	local root = Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end

	local TweenService = game:GetService("TweenService")
	local Debris = game:GetService("Debris")
	local HttpService = game:GetService("HttpService")

	-- Get ground material and material variant from character OR target position
	local groundMaterial = Enum.Material.Slate
	local groundMaterialVariant = ""
	local groundColor = Color3.fromRGB(100, 100, 100)

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { workspace.World.Live, workspace.World.Visuals }

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

	-- Calculate bezier points (fewer segments for better spacing with meshes)
	local numSegments = 10
	local bezierPoints = {}
	for i = 0, numSegments do
		local t = i / numSegments
		local pos = Bezier(t, startPos, controlPos, targetPos)
		table.insert(bezierPoints, pos)
	end

	-- Track previous plank position for spawning effect
	local previousPlankPos = startPos
	local plankCount = 0

	-- SPAWN ALL AT THE SAME TIME - no delay between left and right
	local baseDelay = 0
	-- Much faster spawn speed
	local spawnSpeed = customSpawnSpeed or 0.02

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
		-- INCREASED SIZE to ensure meshes touch each other
		local plankWidth = (2 + (t * 6)) -- 2 to 8 (bigger to ensure overlap)
		local plankHeight = (2 + (t * 6)) -- 2 to 8 (bigger to ensure overlap)
		local plankLength = distance * 1.5 -- INCREASED length to ensure rocks touch

		plankCount = plankCount + 1

		-- Capture the previous position for this plank
		local spawnFromPos = previousPlankPos

		task.delay(baseDelay + (plankCount - 1) * spawnSpeed, function()
			-- Create plank
			local plank = Replicated.Assets.VFX.WALL:Clone()
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

			task.spawn(function()
				for _ = 1, 3 do
					AB.new(plank.CFrame, finalCFrame, {
						PartCount = 10, -- self explanatory
						CurveSize0 = 5, -- self explanatory
						CurveSize1 = 5, -- self explanatory
						PulseSpeed = 11, -- how fast the bolts will be
						PulseLength = 1, -- how long each bolt is
						FadeLength = 0.25, -- self explanatory
						MaxRadius = math.random(10,18), -- the zone of the bolts
						Thickness = 0.2, -- self explanatory
						Frequency = 0.55, -- how much it will zap around the less frequency (jitter amp)
						Color = Color3.fromRGB(46, 176, 231),
					})
					task.wait(0.065)
				end
			end)

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
				Transparency = 0,
			})
			tween:Play()

			-- Fade out highlight
			TweenService
				:Create(
					highlight,
					TweenInfo.new(tweenDuration * 1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
					{
						FillTransparency = 1,
						OutlineTransparency = 1,
					}
				)
				:Play()

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
					crumble.CFrame = plank.CFrame
						* CFrame.new(
							(math.random() - 0.5) * plank.Size.X,
							(math.random() - 0.5) * plank.Size.Y,
							(math.random() - 0.5) * plank.Size.Z
						)
					crumble.Parent = workspace.World.Visuals

					-- Add velocity to crumbles
					local velocity = Instance.new("BodyVelocity")
					velocity.MaxForce = Vector3.new(4000, 4000, 4000)
					velocity.Velocity = Vector3.new((math.random() - 0.5) * 10, -5, (math.random() - 0.5) * 10)
					velocity.Parent = crumble

					-- Fade out crumbles
					TweenService:Create(crumble, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {
						Transparency = 1,
					}):Play()

					game:GetService("Debris"):AddItem(crumble, 0.6)
				end

				-- Fade out main plank
				local fadeTween =
					TweenService:Create(plank, TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {
						Transparency = 1,
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
				RotationalForce = { 10, 25 },
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

-- WhirlWind Crater Effect
Base.WhirlWindCrater = function(targetPos)
	local craterPosition = targetPos + Vector3.new(0, 1, 0) -- Raise 1 stud above ground

	local success, err = pcall(function()
		local craterCFrame = CFrame.new(craterPosition)

		local effect = RockMod.New("Crater", craterCFrame, {
			Distance = { 4, 10 },
			SizeMultiplier = 0.4,
			PartCount = 8,
			Layers = { 2, 2 },
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
					Speed = 0.35,
					Division = 2,
					EasingStyle = Enum.EasingStyle.Sine,
					EasingDirection = Enum.EasingDirection.In,
				},
			},
		})

		if effect then
			effect:Debris("Normal", {
				Size = { 0.4, 1.2 },
				UpForce = { 0.3, 0.6 },
				RotationalForce = { 8, 20 },
				Spread = { 5, 5 },
				PartCount = 6,
				Radius = 5,
				LifeTime = 3.5,
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
		warn("[WhirlWindCrater] Error creating crater:", err)
	end
end

-- Stone Lance Crater Effect
Base.StoneLanceCrater = function(targetPos)
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
					Speed = 0.4,
					Division = 2,
					EasingStyle = Enum.EasingStyle.Sine,
					EasingDirection = Enum.EasingDirection.In,
				},
			},
		})

		if effect then
			effect:Debris("Normal", {
				Size = { 0.5, 1.5 },
				UpForce = { 0.4, 0.7 },
				RotationalForce = { 10, 25 },
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
		warn("[StoneLanceCrater] Error creating crater:", err)
	end
end

-- Ground Decay Effect (CXZ combination)
-- Creates 3 delayed craters centered on the player
-- First crater: big rocks, small diameter
-- Second crater: medium rocks, medium diameter
-- Third crater: small rocks, big diameter
Base.GroundDecay = function(Character)
	local root = Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end

	local centerPos = root.Position

	-- Get ground material and material variant from character position
	local groundMaterial = Enum.Material.Slate
	local groundMaterialVariant = ""

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { workspace.World.Live, workspace.World.Visuals }

	local rayResult = workspace:Raycast(root.Position, Vector3.new(0, -10, 0), rayParams)
	if rayResult and rayResult.Instance then
		groundMaterial = rayResult.Instance.Material
		groundMaterialVariant = rayResult.Instance.MaterialVariant
	end

	-- First crater: Big rocks, small diameter
	task.delay(0, function()
		CamShake({
			Location = Character.PrimaryPart.Position,
			Magnitude = 3.5,
			Damp = 0.00005,
			Frequency = 35,
			Influence = Vector3.new(0.55, 0.15, 0.55),
			Falloff = 89,
		})
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
				RotationalForce = { 15, 30 },
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
		-- Base.Shake(6, 30, centerPos) -- Impactful shake for first crater
	end)

	-- Second crater: Medium rocks, medium diameter
	task.delay(0.4, function()
		CamShake({
			Location = Character.PrimaryPart.Position,
			Magnitude = 4.5,
			Damp = 0.00005,
			Frequency = 35,
			Influence = Vector3.new(0.55, 0.5, 0.55),
			Falloff = 89,
		})
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
				RotationalForce = { 15, 30 },
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
		-- Base.Shake(7, 32, centerPos) -- Stronger shake for second crater
	end)

	-- Third crater: Small rocks, big diameter
	task.delay(0.8, function()
		CamShake({
			Location = Character.PrimaryPart.Position,
			Magnitude = 7.5,
			Damp = 0.00005,
			Frequency = 41,
			Influence = Vector3.new(0.55, 1, 0.55),
			Falloff = 89,
		})
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
				RotationalForce = { 15, 30 },
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
		-- Base.SpecialShake(9, 35, centerPos) -- Most impactful shake for biggest crater
	end)
end

--- Stone Lance Path Camera Shake
--- Subtle shake when each lance emerges from the ground
Base.StoneLancePathShake = function(lancePosition)
	CamShake({
		Location = lancePosition,
		Magnitude = 2.5,
		Damp = 0.00008,
		Frequency = 30,
		Influence = Vector3.new(0.4, 0.1, 0.4),
		Falloff = 65,
	})
end

--- Stone Lance Camera Shake
--- More pronounced shake for the single large lance
Base.StoneLanceShake = function(lancePosition)
	CamShake({
		Location = lancePosition,
		Magnitude = 4.0,
		Damp = 0.00005,
		Frequency = 35,
		Influence = Vector3.new(0.5, 0.15, 0.5),
		Falloff = 80,
	})
end

-- Screen fade to white for teleportation effects
function Base.ScreenFadeWhiteOut()
	local PlayerGui = Player:WaitForChild("PlayerGui")

	-- Create or get the fade screen GUI
	local fadeScreen = PlayerGui:FindFirstChild("TeleportFadeScreen")
	if not fadeScreen then
		fadeScreen = Instance.new("ScreenGui")
		fadeScreen.Name = "TeleportFadeScreen"
		fadeScreen.DisplayOrder = 1000 -- High display order to be on top
		fadeScreen.IgnoreGuiInset = true
		fadeScreen.Parent = PlayerGui

		local fadeFrame = Instance.new("Frame")
		fadeFrame.Name = "FadeFrame"
		fadeFrame.Size = UDim2.new(1, 0, 1, 0)
		fadeFrame.Position = UDim2.new(0, 0, 0, 0)
		fadeFrame.BackgroundColor3 = Color3.new(1, 1, 1) -- White
		fadeFrame.BackgroundTransparency = 1
		fadeFrame.BorderSizePixel = 0
		fadeFrame.Parent = fadeScreen
	end

	local fadeFrame = fadeScreen.FadeFrame
	fadeFrame.BackgroundTransparency = 1

	-- Fade to white
	local fadeTween = TweenService:Create(
		fadeFrame,
		TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ BackgroundTransparency = 0 }
	)
	fadeTween:Play()
end

-- Screen fade from white back to normal
function Base.ScreenFadeWhiteIn()
	local PlayerGui = Player:WaitForChild("PlayerGui")
	local fadeScreen = PlayerGui:FindFirstChild("TeleportFadeScreen")

	if fadeScreen then
		local fadeFrame = fadeScreen.FadeFrame

		-- Fade from white back to transparent
		local fadeTween = TweenService:Create(
			fadeFrame,
			TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ BackgroundTransparency = 1 }
		)
		fadeTween:Play()

		-- Clean up after fade completes
		fadeTween.Completed:Connect(function()
			task.wait(0.1)
			if fadeScreen and fadeScreen.Parent then
				fadeScreen:Destroy()
			end
		end)
	end
end

-- Truth Move - Gate of Truth sequence from FMA Brotherhood (CHAOTIC VERSION)
function Base.TruthSequence(Character: Model, Quotes: {string}, TeleportPosition: Vector3?, Duration: number?)
	local PlayerGui = Player:WaitForChild("PlayerGui")
	local Lighting = game:GetService("Lighting")
	local totalDuration = Duration or 8

	-- Track if sequence is active for continuous effects
	local sequenceActive = true

	-- Create the Truth UI screen
	local truthScreen = Instance.new("ScreenGui")
	truthScreen.Name = "TruthScreen"
	truthScreen.DisplayOrder = 999
	truthScreen.IgnoreGuiInset = true
	truthScreen.Parent = PlayerGui

	-- Background that fades to white
	local background = Instance.new("Frame")
	background.Name = "Background"
	background.Size = UDim2.new(1, 0, 1, 0)
	background.BackgroundColor3 = Color3.new(1, 1, 1)
	background.BackgroundTransparency = 1
	background.BorderSizePixel = 0
	background.Parent = truthScreen

	-- Container for cryptic text
	local textContainer = Instance.new("Frame")
	textContainer.Name = "TextContainer"
	textContainer.Size = UDim2.new(1, 0, 1, 0)
	textContainer.BackgroundTransparency = 1
	textContainer.ClipsDescendants = false
	textContainer.Parent = truthScreen

	-- ═══════════════════════════════════════════════════════════════════════════
	-- WHISPERS SOUND - Plays looped while messages are on screen
	-- ═══════════════════════════════════════════════════════════════════════════
	local whispersSound
	local truthSFX = Replicated.Assets.SFX:FindFirstChild("Truth")
	if truthSFX then
		local whispers = truthSFX:FindFirstChild("Whispers")
		if whispers then
			whispersSound = whispers:Clone()
			whispersSound.Looped = true
			whispersSound.Parent = PlayerGui
			whispersSound:Play()
		end
	end

	-- CONTINUOUS SCREEN SHAKE - runs until teleport
	task.spawn(function()
		local shakeIntensity = 5
		while sequenceActive do
			-- Escalating shake intensity
			shakeIntensity = math.min(shakeIntensity + 0.5, 25)

			CamShake({
				Magnitude = shakeIntensity,
				Frequency = 20 + shakeIntensity,
				Damp = 0.01,
				Influence = Vector3.new(1.5, 1.5, 1),
				Location = Camera.CFrame.Position,
				Falloff = 200,
			})
			task.wait(0.3)
		end
	end)

	-- Use Sarpanch for all Truth text
	local fonts = {
		Enum.Font.Unknown, -- Will use FontFace below
	}

	-- Glitch characters
	local glitchChars = {"█", "▓", "▒", "░", "◊", "◆", "●", "○", "▲", "▼", "◀", "▶", "■", "□", "◈", "◉"}

	-- Function to create a CHAOTIC cryptic text label
	local function createChaoticText(text, posX, posY, textSize, delay)
		task.delay(delay, function()
			if not sequenceActive then return end

			local label = Instance.new("TextLabel")
			label.Name = "CrypticText"
			label.Size = UDim2.new(0, textSize * #text * 0.6, 0, textSize * 1.5)
			label.Position = UDim2.new(posX, 0, posY, 0)
			label.AnchorPoint = Vector2.new(0.5, 0.5)
			label.BackgroundTransparency = 1
			label.Text = ""
			label.TextColor3 = Color3.new(0, 0, 0) -- Black text
			label.TextStrokeColor3 = Color3.fromRGB(150, 50, 200) -- Purple stroke
			label.TextStrokeTransparency = 0
			label.FontFace = Font.new("rbxasset://fonts/families/Sarpanch.json") -- Sarpanch font
			label.TextSize = textSize
			label.TextTransparency = 1
			label.Rotation = math.random(-15, 15)
			label.Parent = textContainer

			-- Add UIStroke for purple glow
			local stroke = Instance.new("UIStroke")
			stroke.Color = Color3.fromRGB(math.random(120, 180), math.random(30, 80), math.random(180, 255)) -- Purple variations
			stroke.Thickness = .3
			stroke.Transparency = 1
			stroke.Parent = label

			-- Fade in fast
			local fadeIn = TweenService:Create(label, TweenInfo.new(0.15), { TextTransparency = 0 })
			local strokeFadeIn = TweenService:Create(stroke, TweenInfo.new(0.15), { Transparency = 0.2 })
			fadeIn:Play()
			strokeFadeIn:Play()

			-- Typewriter with glitch
			for i = 1, #text do
				if not sequenceActive then break end
				label.Text = string.sub(text, 1, i)

				-- Random glitch
				if math.random() < 0.25 then
					local originalText = label.Text
					label.Text = originalText .. glitchChars[math.random(1, #glitchChars)]
					task.wait(0.015)
					label.Text = originalText
				end
				task.wait(0.025)
			end

			-- Random movement/drift
			task.spawn(function()
				while label and label.Parent and sequenceActive and not label:GetAttribute("Frozen") do
					local driftTween = TweenService:Create(label, TweenInfo.new(0.5, Enum.EasingStyle.Sine), {
						Position = label.Position + UDim2.new(0, math.random(-20, 20), 0, math.random(-20, 20)),
						Rotation = label.Rotation + math.random(-5, 5)
					})
					driftTween:Play()
					task.wait(0.5)
				end
			end)

			-- Pulse stroke (purple variations)
			task.spawn(function()
				while label and label.Parent and sequenceActive and not label:GetAttribute("Frozen") do
					local pulse = TweenService:Create(stroke, TweenInfo.new(0.3), {
						Thickness = math.random(1,2),
						Color = Color3.fromRGB(math.random(100, 200), math.random(20, 100), math.random(150, 255)) -- Purple pulse
					})
					pulse:Play()
					task.wait(0.3)
				end
			end)
		end)
	end

	-- SPAWN TEXT EVERYWHERE - Chaotic phase
	-- Initial burst of text
	for i = 1, 15 do
		local quote = Quotes[math.random(1, #Quotes)]
		local posX = math.random(5, 95) / 100
		local posY = math.random(5, 95) / 100
		local textSize = math.random(18, 40)
		createChaoticText(quote, posX, posY, textSize, i * 0.15)
	end

	-- Continuous spawning of more text
	task.spawn(function()
		local spawnCount = 0
		while sequenceActive and spawnCount < 30 do
			task.wait(0.25)
			local quote = Quotes[math.random(1, #Quotes)]
			local posX = math.random(5, 95) / 100
			local posY = math.random(5, 95) / 100
			local textSize = math.random(14, 50)
			createChaoticText(quote, posX, posY, textSize, 0)
			spawnCount = spawnCount + 1
		end
	end)

	-- Phase 2: Text exit animation then shattering (after 3 seconds)
	task.delay(3, function()
		if not sequenceActive then return end

		-- First, FREEZE all text in place (stop drift/pulse)
		for _, label in textContainer:GetChildren() do
			if label:IsA("TextLabel") then
				-- Mark as frozen to stop drift loops
				label:SetAttribute("Frozen", true)
			end
		end

		-- EXIT ANIMATION: Text shrinks, vibrates, then pulls toward center before shattering
		for _, label in textContainer:GetChildren() do
			if label:IsA("TextLabel") then
				-- Quick vibration effect
				task.spawn(function()
					for i = 1, 6 do
						if not label or not label.Parent then break end
						local offsetX = math.random(-8, 8)
						local offsetY = math.random(-8, 8)
						label.Position = label.Position + UDim2.new(0, offsetX, 0, offsetY)
						task.wait(0.03)
					end
				end)

				-- Shrink and pull toward center
				local pullTween = TweenService:Create(label, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
					Position = UDim2.new(0.5, 0, 0.5, 0),
					Size = UDim2.new(0, label.TextSize * 0.5, 0, label.TextSize * 0.5),
					TextTransparency = 0.3
				})
				pullTween:Play()
			end
		end

		-- Brief dramatic pause after pull (0.4 seconds)
		task.wait(0.5)

		-- NOW shatter all text explosively from center
		for _, label in textContainer:GetChildren() do
			if label:IsA("TextLabel") then
				task.spawn(function()
					local text = label.Text
					local labelPos = label.AbsolutePosition

					-- Create scattered characters
					for charIndex = 1, math.min(#text, 20) do
						local char = string.sub(text, charIndex, charIndex)
						if char ~= " " then
							local charLabel = Instance.new("TextLabel")
							charLabel.Size = UDim2.new(0, 25, 0, 35)
							charLabel.Position = UDim2.new(0, labelPos.X + (charIndex - 1) * 10, 0, labelPos.Y)
							charLabel.BackgroundTransparency = 1
							charLabel.Text = char
							charLabel.TextColor3 = Color3.new(0, 0, 0) -- Black
							charLabel.FontFace = Font.new("rbxasset://fonts/families/Sarpanch.json") -- Sarpanch font
							charLabel.TextSize = label.TextSize
							charLabel.TextTransparency = 0
							charLabel.TextStrokeTransparency = 0
							charLabel.TextStrokeColor3 = Color3.fromRGB(150, 50, 200) -- Purple
							charLabel.Parent = truthScreen

							-- Explosive scatter from center
							local randomX = math.random(-600, 600)
							local randomY = math.random(-600, 600)
							local randomRot = math.random(-720, 720) -- More rotation

							local scatterTween = TweenService:Create(charLabel, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
								Position = charLabel.Position + UDim2.new(0, randomX, 0, randomY),
								Rotation = randomRot,
								TextTransparency = 1,
								TextStrokeTransparency = 1
							})
							scatterTween:Play()
							scatterTween.Completed:Connect(function()
								charLabel:Destroy()
							end)
						end
					end
					label:Destroy()
				end)
			end
		end
	end)

	-- Phase 3: World turns white (after 2 seconds - faster fade in)
	task.delay(2, function()
		if not sequenceActive then return end

		local whiteFade = TweenService:Create(background, TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundTransparency = 0
		})
		whiteFade:Play()

		-- Bloom effect
		local bloom = Lighting:FindFirstChild("TruthBloom") or Instance.new("BloomEffect")
		bloom.Name = "TruthBloom"
		bloom.Intensity = 0
		bloom.Size = 24
		bloom.Threshold = 0.8
		bloom.Parent = Lighting

		local bloomTween = TweenService:Create(bloom, TweenInfo.new(1.5), {
			Intensity = 4,
			Size = 70
		})
		bloomTween:Play()

		-- ColorCorrection for white out
		local cc = Instance.new("ColorCorrectionEffect")
		cc.Name = "TruthCC"
		cc.Brightness = 0
		cc.Contrast = 0
		cc.Saturation = 0
		cc.Parent = Lighting

		local ccTween = TweenService:Create(cc, TweenInfo.new(1.5), {
			Brightness = 1,
			Contrast = -0.5,
			Saturation = -1
		})
		ccTween:Play()
	end)

	-- Phase 4: Character body parts fade with neon effect (after 4 seconds)
	task.delay(4, function()
		if not sequenceActive or not Character then return end

		local bodyParts = {"Left Leg", "Right Leg", "Left Arm", "Right Arm", "Torso", "Head"}

		for i, partName in ipairs(bodyParts) do
			task.delay((i - 1) * 0.3, function()
				local part = Character:FindFirstChild(partName)
				if part and part:IsA("BasePart") then
					-- Add highlight that flashes
					local highlight = Instance.new("Highlight")
					highlight.FillColor = Color3.new(1, 1, 1)
					highlight.FillTransparency = 0
					highlight.OutlineColor = Color3.new(1, 1, 1)
					highlight.OutlineTransparency = 0
					highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
					highlight.Parent = Character

					-- Flash effect
					task.spawn(function()
						for j = 1, 3 do
							highlight.FillTransparency = 0
							task.wait(0.05)
							highlight.FillTransparency = 0.5
							task.wait(0.05)
						end

						-- Fade out
						local fadeHighlight = TweenService:Create(highlight, TweenInfo.new(0.4), {
							FillTransparency = 1,
							OutlineTransparency = 1
						})
						fadeHighlight:Play()
						fadeHighlight.Completed:Connect(function()
							highlight:Destroy()
						end)
					end)

					-- Extra intense shake for each part
					CamShake({
						Magnitude = 15,
						Frequency = 35,
						Damp = 0.005,
						Influence = Vector3.new(2, 2, 1.5),
						Location = Camera.CFrame.Position,
						Falloff = 200,
					})
				end
			end)
		end
	end)

	-- Final cleanup (after duration) - SHATTER ALL REMAINING TEXT AFTER TELEPORT
	task.delay(totalDuration - 0.5, function()
		sequenceActive = false

		-- Stop whispers sound
		if whispersSound then
			whispersSound:Stop()
			whispersSound:Destroy()
		end

		-- Final intense shake
		CamShake({
			Magnitude = 30,
			Frequency = 50,
			Damp = 0.001,
			Influence = Vector3.new(3, 3, 2),
			Location = Camera.CFrame.Position,
			Falloff = 300,
		})

		-- SHATTER ALL REMAINING TEXT (any text that wasn't shattered in phase 2)
		-- First freeze all text
		for _, label in textContainer:GetChildren() do
			if label:IsA("TextLabel") then
				label:SetAttribute("Frozen", true)
			end
		end

		-- Quick pull to center then shatter
		for _, label in textContainer:GetChildren() do
			if label:IsA("TextLabel") then
				local pullTween = TweenService:Create(label, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
					Position = UDim2.new(0.5, 0, 0.5, 0),
					Size = UDim2.new(0, label.TextSize * 0.5, 0, label.TextSize * 0.5),
					TextTransparency = 0.3
				})
				pullTween:Play()
			end
		end

		task.wait(0.25)

		-- Shatter all text explosively
		for _, label in textContainer:GetChildren() do
			if label:IsA("TextLabel") then
				task.spawn(function()
					local text = label.Text
					local labelPos = label.AbsolutePosition

					-- Create scattered characters
					for charIndex = 1, math.min(#text, 20) do
						local char = string.sub(text, charIndex, charIndex)
						if char ~= " " then
							local charLabel = Instance.new("TextLabel")
							charLabel.Size = UDim2.new(0, 25, 0, 35)
							charLabel.Position = UDim2.new(0, labelPos.X + (charIndex - 1) * 10, 0, labelPos.Y)
							charLabel.BackgroundTransparency = 1
							charLabel.Text = char
							charLabel.TextColor3 = Color3.new(0, 0, 0)
							charLabel.FontFace = Font.new("rbxasset://fonts/families/Sarpanch.json")
							charLabel.TextSize = label.TextSize
							charLabel.TextTransparency = 0
							charLabel.TextStrokeTransparency = 0
							charLabel.TextStrokeColor3 = Color3.fromRGB(150, 50, 200)
							charLabel.Parent = truthScreen

							-- Explosive scatter
							local randomX = math.random(-600, 600)
							local randomY = math.random(-600, 600)
							local randomRot = math.random(-720, 720)

							local scatterTween = TweenService:Create(charLabel, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
								Position = charLabel.Position + UDim2.new(0, randomX, 0, randomY),
								Rotation = randomRot,
								TextTransparency = 1,
								TextStrokeTransparency = 1
							})
							scatterTween:Play()
							scatterTween.Completed:Connect(function()
								charLabel:Destroy()
							end)
						end
					end
					label:Destroy()
				end)
			end
		end

		task.wait(0.25)

		-- Fade out
		local fadeOut = TweenService:Create(background, TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			BackgroundTransparency = 1
		})
		fadeOut:Play()

		-- Cleanup lighting effects
		local bloom = Lighting:FindFirstChild("TruthBloom")
		if bloom then
			local bloomFade = TweenService:Create(bloom, TweenInfo.new(1), { Intensity = 0 })
			bloomFade:Play()
			bloomFade.Completed:Connect(function()
				bloom:Destroy()
			end)
		end

		local cc = Lighting:FindFirstChild("TruthCC")
		if cc then
			local ccFade = TweenService:Create(cc, TweenInfo.new(1), {
				Brightness = 0,
				Contrast = 0,
				Saturation = 0
			})
			ccFade:Play()
			ccFade.Completed:Connect(function()
				cc:Destroy()
			end)
		end

		fadeOut.Completed:Connect(function()
			truthScreen:Destroy()
		end)
	end)
end

-- Truth Consequence - Called after Truth dialogue ends
-- Player gets knocked back/up, parts fly away, screen fades to white, then teleported back
function Base.TruthConsequence(Character: Model, organMessage: string, debuffMessage: string)
	local PlayerGui = Player:WaitForChild("PlayerGui")
	local Lighting = game:GetService("Lighting")
	local Debris = game:GetService("Debris")

	local HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart")
	local Humanoid = Character:FindFirstChildOfClass("Humanoid")
	if not HumanoidRootPart then return end

	-- Create the consequence UI screen
	local consequenceScreen = Instance.new("ScreenGui")
	consequenceScreen.Name = "TruthConsequenceScreen"
	consequenceScreen.DisplayOrder = 1000
	consequenceScreen.IgnoreGuiInset = true
	consequenceScreen.Parent = PlayerGui

	-- Play Loss sound (toll payment)
	local truthSFX = Replicated.Assets.SFX:FindFirstChild("Truth")
	if truthSFX then
		local lossSound = truthSFX:FindFirstChild("Loss")
		if lossSound then
			local lossClone = lossSound:Clone()
			lossClone.Parent = PlayerGui
			lossClone:Play()
			lossClone.Ended:Connect(function()
				lossClone:Destroy()
			end)
		end
	end

	-- ═══════════════════════════════════════════════════════════════
	-- PHASE 1: KNOCKBACK - Player gets knocked back and upward
	-- ═══════════════════════════════════════════════════════════════

	-- Apply knockback force (up and back)
	local knockbackForce = Instance.new("BodyVelocity")
	knockbackForce.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
	-- Knock upward and slightly backward from where they're facing
	local lookVector = HumanoidRootPart.CFrame.LookVector
	knockbackForce.Velocity = Vector3.new(-lookVector.X * 30, 80, -lookVector.Z * 30)
	knockbackForce.Parent = HumanoidRootPart
	Debris:AddItem(knockbackForce, 0.3)

	-- Intense initial shake
	CamShake({
		Magnitude = 50,
		Frequency = 60,
		Damp = 0.002,
		Influence = Vector3.new(4, 4, 3),
		Location = Camera.CFrame.Position,
		Falloff = 400,
	})

	-- Red flash on impact
	local impactFlash = Instance.new("Frame")
	impactFlash.Name = "ImpactFlash"
	impactFlash.Size = UDim2.new(1, 0, 1, 0)
	impactFlash.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
	impactFlash.BackgroundTransparency = 0.3
	impactFlash.BorderSizePixel = 0
	impactFlash.ZIndex = 10
	impactFlash.Parent = consequenceScreen

	local flashFade = TweenService:Create(impactFlash, TweenInfo.new(0.5, Enum.EasingStyle.Quad), {
		BackgroundTransparency = 1
	})
	flashFade:Play()
	flashFade.Completed:Connect(function()
		impactFlash:Destroy()
	end)

	-- ═══════════════════════════════════════════════════════════════
	-- PHASE 2: PARTS FLY AWAY - Environment parts around player dissolve
	-- ═══════════════════════════════════════════════════════════════

	task.delay(0.2, function()
		local playerPos = HumanoidRootPart.Position
		local EFFECT_RADIUS = 40
		local affectedParts = {}

		-- Find parts around the player
		for _, obj in workspace:GetDescendants() do
			if obj:IsA("BasePart") and not obj:IsDescendantOf(Character) then
				local distance = (obj.Position - playerPos).Magnitude
				if distance <= EFFECT_RADIUS and obj.Anchored and obj.CanCollide then
					-- Skip very large parts (floors, walls)
					local size = obj.Size
					if size.X < 20 and size.Y < 20 and size.Z < 20 then
						-- Skip floor parts (parts that are below and mostly horizontal)
						local relativeY = obj.Position.Y - playerPos.Y
						local isFloorLike = relativeY < -2 and size.Y < 3 and (size.X > 4 or size.Z > 4)

						-- Skip parts in essential folders (terrain, spawn areas, etc.)
						local isEssential = obj:IsDescendantOf(workspace:FindFirstChild("Terrain") or workspace)
							or obj.Name:lower():find("floor")
							or obj.Name:lower():find("ground")
							or obj.Name:lower():find("spawn")

						if not isFloorLike and not isEssential then
							table.insert(affectedParts, {part = obj, distance = distance})
						end
					end
				end
			end
		end

		-- Sort by distance (closest first)
		table.sort(affectedParts, function(a, b) return a.distance < b.distance end)

		-- Limit to prevent performance issues
		local maxParts = math.min(#affectedParts, 30)

		-- Get or create visuals folder for cleanup
		local visualsFolder = workspace:FindFirstChild("World") and workspace.World:FindFirstChild("Visuals")
		if not visualsFolder then
			visualsFolder = workspace
		end

		-- Make parts fade out in place (clones only - originals stay in place)
		for i = 1, maxParts do
			local data = affectedParts[i]
			local part = data.part

			-- Clone the part for the effect (don't destroy originals)
			local clone = part:Clone()
			clone.Name = "TruthVFX_" .. part.Name
			clone.Anchored = true -- Keep anchored so it stays in place
			clone.CanCollide = false
			clone.CanQuery = false
			clone.CanTouch = false
			clone.CastShadow = false
			clone.Parent = visualsFolder

			-- Stagger the fade based on distance (closer parts fade first)
			local fadeDelay = (data.distance / EFFECT_RADIUS) * 0.5

			task.delay(fadeDelay, function()
				-- Fade out the clone in place
				if clone and clone.Parent then
					local fadeTween = TweenService:Create(clone, TweenInfo.new(1.5, Enum.EasingStyle.Quad), {
						Transparency = 1
					})
					fadeTween:Play()
					fadeTween.Completed:Connect(function()
						if clone and clone.Parent then
							clone:Destroy()
						end
					end)
				end
			end)

			-- Cleanup after effect
			Debris:AddItem(clone, 3)
		end
	end)

	-- ═══════════════════════════════════════════════════════════════
	-- PHASE 3: ORGAN LOSS MESSAGE - Show what was taken
	-- ═══════════════════════════════════════════════════════════════

	task.delay(0.5, function()
		-- Organ loss message (what was taken)
		local organLabel = Instance.new("TextLabel")
		organLabel.Name = "OrganMessage"
		organLabel.Size = UDim2.new(0.8, 0, 0, 60)
		organLabel.Position = UDim2.new(0.5, 0, 0.35, 0)
		organLabel.AnchorPoint = Vector2.new(0.5, 0.5)
		organLabel.BackgroundTransparency = 1
		organLabel.Text = organMessage
		organLabel.TextColor3 = Color3.fromRGB(180, 30, 30) -- Dark red
		organLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
		organLabel.TextStrokeTransparency = 0
		organLabel.FontFace = Font.new("rbxasset://fonts/families/Sarpanch.json")
		organLabel.TextSize = 32
		organLabel.TextTransparency = 1
		organLabel.Parent = consequenceScreen

		local organFadeIn = TweenService:Create(organLabel, TweenInfo.new(0.5), {
			TextTransparency = 0
		})
		organFadeIn:Play()
	end)

	-- Show "DEBILITATION EXCHANGED" after 1.5 seconds
	task.delay(1.5, function()
		-- Main notification - DEBILITATION EXCHANGED
		local mainNotif = Instance.new("TextLabel")
		mainNotif.Name = "DebilitationExchanged"
		mainNotif.Size = UDim2.new(0.9, 0, 0, 100)
		mainNotif.Position = UDim2.new(0.5, 0, 0.5, 0)
		mainNotif.AnchorPoint = Vector2.new(0.5, 0.5)
		mainNotif.BackgroundTransparency = 1
		mainNotif.Text = "DEBILITATION EXCHANGED"
		mainNotif.TextColor3 = Color3.fromRGB(120, 0, 0) -- Very dark red
		mainNotif.TextStrokeColor3 = Color3.fromRGB(50, 0, 50) -- Dark purple stroke
		mainNotif.TextStrokeTransparency = 0
		mainNotif.FontFace = Font.new("rbxasset://fonts/families/Sarpanch.json")
		mainNotif.TextSize = 56
		mainNotif.TextTransparency = 1
		mainNotif.Parent = consequenceScreen

		-- UIStroke for extra emphasis
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(80, 20, 80) -- Purple
		stroke.Thickness = .3
		stroke.Transparency = 1
		stroke.Parent = mainNotif

		-- Fade in with impact
		local notifFadeIn = TweenService:Create(mainNotif, TweenInfo.new(0.3), {
			TextTransparency = 0
		})
		local strokeFadeIn = TweenService:Create(stroke, TweenInfo.new(0.3), {
			Transparency = 0
		})
		notifFadeIn:Play()
		strokeFadeIn:Play()

		-- Another shake
		CamShake({
			Magnitude = 30,
			Frequency = 50,
			Damp = 0.003,
			Influence = Vector3.new(3, 3, 2),
			Location = Camera.CFrame.Position,
			Falloff = 300,
		})
	end)

	-- Show debuff message after 2 seconds
	task.delay(2, function()
		local debuffLabel = Instance.new("TextLabel")
		debuffLabel.Name = "DebuffMessage"
		debuffLabel.Size = UDim2.new(0.8, 0, 0, 40)
		debuffLabel.Position = UDim2.new(0.5, 0, 0.65, 0)
		debuffLabel.AnchorPoint = Vector2.new(0.5, 0.5)
		debuffLabel.BackgroundTransparency = 1
		debuffLabel.Text = debuffMessage
		debuffLabel.TextColor3 = Color3.fromRGB(150, 100, 100) -- Muted red
		debuffLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
		debuffLabel.TextStrokeTransparency = 0.3
		debuffLabel.FontFace = Font.new("rbxasset://fonts/families/Sarpanch.json")
		debuffLabel.TextSize = 24
		debuffLabel.TextTransparency = 1
		debuffLabel.Parent = consequenceScreen

		local debuffFadeIn = TweenService:Create(debuffLabel, TweenInfo.new(0.5), {
			TextTransparency = 0
		})
		debuffFadeIn:Play()
	end)

	-- ═══════════════════════════════════════════════════════════════
	-- PHASE 4: FADE TO WHITE - Screen goes white before teleport
	-- ═══════════════════════════════════════════════════════════════

	task.delay(2.5, function()
		-- Create white overlay for fade to white
		local whiteOverlay = Instance.new("Frame")
		whiteOverlay.Name = "WhiteOverlay"
		whiteOverlay.Size = UDim2.new(1, 0, 1, 0)
		whiteOverlay.BackgroundColor3 = Color3.new(1, 1, 1)
		whiteOverlay.BackgroundTransparency = 1
		whiteOverlay.BorderSizePixel = 0
		whiteOverlay.ZIndex = 100
		whiteOverlay.Parent = consequenceScreen

		-- Fade text out as white fades in
		for _, child in consequenceScreen:GetChildren() do
			if child:IsA("TextLabel") then
				local fade = TweenService:Create(child, TweenInfo.new(1), {
					TextTransparency = 1,
					TextStrokeTransparency = 1
				})
				fade:Play()
			end
		end

		-- Fade to white
		local whiteIn = TweenService:Create(whiteOverlay, TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			BackgroundTransparency = 0
		})
		whiteIn:Play()

		-- Add bloom effect for white-out
		local bloom = Instance.new("BloomEffect")
		bloom.Name = "TruthWhiteoutBloom"
		bloom.Intensity = 0
		bloom.Size = 24
		bloom.Threshold = 0.8
		bloom.Parent = Lighting

		local bloomTween = TweenService:Create(bloom, TweenInfo.new(1), {
			Intensity = 3,
			Threshold = 0
		})
		bloomTween:Play()

		-- Cleanup after teleport happens (at 4 seconds from server)
		task.delay(1.5, function()
			-- Fade bloom back
			local bloomFade = TweenService:Create(bloom, TweenInfo.new(0.5), {
				Intensity = 0,
				Threshold = 0.8
			})
			bloomFade:Play()
			bloomFade.Completed:Connect(function()
				bloom:Destroy()
			end)

			-- Fade white overlay out
			local whiteOut = TweenService:Create(whiteOverlay, TweenInfo.new(1, Enum.EasingStyle.Quad), {
				BackgroundTransparency = 1
			})
			whiteOut:Play()
			whiteOut.Completed:Connect(function()
				consequenceScreen:Destroy()
			end)
		end)
	end)
end

-- Truth Room Sounds - Plays Area and Theme sounds (both looped with fade in) when teleported to Truth room
function Base.TruthRoomSounds(Character: Model)
	local PlayerGui = Player:WaitForChild("PlayerGui")

	-- Set global flag to disable other themes
	_G.TruthActive = true

	-- Get Truth SFX folder
	local truthSFX = Replicated.Assets.SFX:FindFirstChild("Truth")
	if not truthSFX then return end

	-- Fade duration for sounds
	local FADE_DURATION = 2

	-- Play Area sound (looped with fade in)
	local areaSound = truthSFX:FindFirstChild("Area")
	if areaSound then
		-- Stop any existing Area sound first
		if _G.TruthAreaSound then
			_G.TruthAreaSound:Stop()
			_G.TruthAreaSound:Destroy()
		end

		local areaClone = areaSound:Clone()
		areaClone.Looped = true
		areaClone.Volume = 0 -- Start at 0 for fade in
		areaClone.Parent = PlayerGui
		areaClone:Play()
		_G.TruthAreaSound = areaClone

		-- Fade in the area sound
		local targetVolume = areaSound.Volume or 0.5
		local areaFade = TweenService:Create(areaClone, TweenInfo.new(FADE_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Volume = targetVolume
		})
		areaFade:Play()
	end

	-- Play Theme sound (looped with fade in) - stored globally so we can stop it later
	local themeSound = truthSFX:FindFirstChild("Theme")
	if themeSound then
		-- Stop any existing Truth theme first
		if _G.TruthThemeSound then
			_G.TruthThemeSound:Stop()
			_G.TruthThemeSound:Destroy()
		end

		local themeClone = themeSound:Clone()
		themeClone.Looped = true
		themeClone.Volume = 0 -- Start at 0 for fade in
		themeClone.Parent = PlayerGui
		themeClone:Play()
		_G.TruthThemeSound = themeClone

		-- Fade in the theme sound
		local targetVolume = themeSound.Volume or 0.5
		local themeFade = TweenService:Create(themeClone, TweenInfo.new(FADE_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Volume = targetVolume
		})
		themeFade:Play()
	end
end

-- Stop Truth Room Theme - Called when leaving Truth room
function Base.StopTruthRoomSounds()
	-- Clear the global flag
	_G.TruthActive = false

	-- Stop and cleanup the area sound
	if _G.TruthAreaSound then
		_G.TruthAreaSound:Stop()
		_G.TruthAreaSound:Destroy()
		_G.TruthAreaSound = nil
	end

	-- Stop and cleanup the theme sound
	if _G.TruthThemeSound then
		_G.TruthThemeSound:Stop()
		_G.TruthThemeSound:Destroy()
		_G.TruthThemeSound = nil
	end
end

-- Scythe Critical VFX
-- This is called at WaitTime (frame 46) - VFX happens earlier
-- Timeline:
--   Now (frame 46): Color correction flash, sounds, Nen type text
--   Hitbox: frame 46-54
function Base.SpecialCritScythe(Character: Model)
	local Lighting = game:GetService("Lighting")
	local TextPlus = require(Replicated.Modules.Utils.Text)
	local Global = require(Replicated.Modules.Shared.Global)

	-- Constants for white color detection
	local WHITE_THRESHOLD = 0.95 -- How close to white a color must be (0-1)

	-- Check if a color is white or nearly white
	local function isWhiteColor(color: Color3): boolean
		local r, g, b = color.R, color.G, color.B
		return r >= WHITE_THRESHOLD and g >= WHITE_THRESHOLD and b >= WHITE_THRESHOLD
	end

	-- Ensure Nen color is always bright and vibrant (no dark or desaturated colors)
	-- Enforces minimum saturation and brightness for visibility
	local function ensureBrightColor(color: Color3): Color3
		local h, s, v = color:ToHSV()
		-- Enforce minimum saturation (at least 0.5 for vibrant colors)
		-- Enforce minimum brightness (at least 0.7 for visibility)
		local newS = math.max(s, 0.5)
		local newV = math.max(v, 0.7)
		return Color3.fromHSV(h, newS, newV)
	end

	-- Generate a color variation (lighter or darker) of the base color
	-- Keeps colors bright - only varies within the bright range
	local function getColorVariation(baseColor: Color3): Color3
		local variationAmount = (math.random() * 0.2 - 0.1) -- -0.1 to +0.1 (smaller range)
		local h, s, v = baseColor:ToHSV()
		-- Keep brightness high (0.7 to 1.0) and saturation strong (0.4 to 1.0)
		local newV = math.clamp(v + variationAmount, 0.7, 1.0)
		local newS = math.clamp(s + (variationAmount * 0.3), 0.4, 1.0)
		return Color3.fromHSV(h, newS, newV)
	end

	-- Apply Nen color to a ParticleEmitter if it has white color
	local function applyNenColorToParticle(particle: ParticleEmitter, nenColor: Color3)
		local colorSeq = particle.Color
		local keypoints = colorSeq.Keypoints

		local hasWhite = false
		for _, kp in keypoints do
			if isWhiteColor(kp.Value) then
				hasWhite = true
				break
			end
		end

		if hasWhite then
			local targetColor = getColorVariation(nenColor)
			local newKeypoints = {}
			for _, kp in keypoints do
				if isWhiteColor(kp.Value) then
					table.insert(newKeypoints, ColorSequenceKeypoint.new(kp.Time, targetColor))
				else
					table.insert(newKeypoints, kp)
				end
			end
			particle.Color = ColorSequence.new(newKeypoints)
		end
	end

	-- Apply Nen color to a Beam if it has white color
	local function applyNenColorToBeam(beam: Beam, nenColor: Color3)
		local colorSeq = beam.Color
		local keypoints = colorSeq.Keypoints

		local hasWhite = false
		for _, kp in keypoints do
			if isWhiteColor(kp.Value) then
				hasWhite = true
				break
			end
		end

		if hasWhite then
			local targetColor = getColorVariation(nenColor)
			local newKeypoints = {}
			for _, kp in keypoints do
				if isWhiteColor(kp.Value) then
					table.insert(newKeypoints, ColorSequenceKeypoint.new(kp.Time, targetColor))
				else
					table.insert(newKeypoints, kp)
				end
			end
			beam.Color = ColorSequence.new(newKeypoints)
		end
	end

	-- Apply Nen color to a Trail if it has white color
	local function applyNenColorToTrail(trail: Trail, nenColor: Color3)
		local colorSeq = trail.Color
		local keypoints = colorSeq.Keypoints

		local hasWhite = false
		for _, kp in keypoints do
			if isWhiteColor(kp.Value) then
				hasWhite = true
				break
			end
		end

		if hasWhite then
			local targetColor = getColorVariation(nenColor)
			local newKeypoints = {}
			for _, kp in keypoints do
				if isWhiteColor(kp.Value) then
					table.insert(newKeypoints, ColorSequenceKeypoint.new(kp.Time, targetColor))
				else
					table.insert(newKeypoints, kp)
				end
			end
			trail.Color = ColorSequence.new(newKeypoints)
		end
	end

	-- Apply Nen color to all applicable effects in an instance tree
	local function applyNenColorToEffects(instance: Instance, nenColor: Color3)
		for _, descendant in instance:GetDescendants() do
			if descendant:IsA("ParticleEmitter") then
				applyNenColorToParticle(descendant, nenColor)
			elseif descendant:IsA("Beam") then
				applyNenColorToBeam(descendant, nenColor)
			elseif descendant:IsA("Trail") then
				applyNenColorToTrail(descendant, nenColor)
			end
		end

		-- Also check the instance itself
		if instance:IsA("ParticleEmitter") then
			applyNenColorToParticle(instance, nenColor)
		elseif instance:IsA("Beam") then
			applyNenColorToBeam(instance, nenColor)
		elseif instance:IsA("Trail") then
			applyNenColorToTrail(instance, nenColor)
		end
	end

	-- Get Scythe VFX folder
	local scytheVFX = VFX:FindFirstChild("Scythe")
	if not scytheVFX then return end

	-- Get root part for sound parenting
	local rootPart = Character:FindFirstChild("HumanoidRootPart") or Character.PrimaryPart

	-- Get player from character early - try multiple methods for reliability
	local playerFromChar = Players:GetPlayerFromCharacter(Character)
	if not playerFromChar then
		-- Fallback: check if this is local player's character
		local localPlayer = Players.LocalPlayer
		if localPlayer and localPlayer.Character == Character then
			playerFromChar = localPlayer
		end
	end

	-- Get player's Nen data early (for VFX colors and text)
	local nenType = "Enhance"
	local nenColor = Color3.fromRGB(100, 200, 255) -- Default light blue for Nen effects
	local hasCustomNenColor = true -- Always apply color to Nen effects
	if playerFromChar then
		local nenData = Global.GetData(playerFromChar, "Nen")
		if nenData then
			if nenData.Type then
				nenType = nenData.Type
			end
			if nenData.Color then
				local r, g, b = nenData.Color.R, nenData.Color.G, nenData.Color.B
				-- Only use custom color if it's NOT white (255, 255, 255)
				-- Otherwise use the default light blue
				if not (r >= 250 and g >= 250 and b >= 250) then
					-- Get color and ensure it's bright/vibrant (no dark colors allowed)
					local rawColor = Color3.fromRGB(r, g, b)
					nenColor = ensureBrightColor(rawColor)
				end
			end
		end
	end

	-- Play ScytheCrit sounds (1, 2, 3) immediately at animation start
	-- ScytheCrit folder is under SFX > Nen > ScytheCrit
	local nenSfxFolder = SFX:FindFirstChild("Nen")
	local scytheCritFolder = nenSfxFolder and nenSfxFolder:FindFirstChild("ScytheCrit")
	if scytheCritFolder and rootPart then
		-- Play all 3 sounds in a separate thread so they don't block VFX
		task.spawn(function()
			for i = 1, 2 do
				local sound = scytheCritFolder:FindFirstChild(tostring(i))
				if sound and sound:IsA("Sound") then
					local soundClone = sound:Clone()
					soundClone.Parent = rootPart
					soundClone:Play()
					soundClone.Ended:Once(function()
						soundClone:Destroy()
					end)
				end
				if i < 2 then
					task.wait(0.05)
				end
			end
		end)
	end

	-- Clone Crit model to character's root part
	local critModel = scytheVFX:FindFirstChild("Crit")
	local critClone = nil
	local warnPart = nil
	local wwwwModel = nil

	if critModel then
		critClone = critModel:Clone()
		local humanoidRootPart = Character:FindFirstChild("HumanoidRootPart")
		if humanoidRootPart then
			critClone:PivotTo(humanoidRootPart.CFrame)
			critClone.Parent = humanoidRootPart
		end
		-- Find warn part and wwww model for later emission
		warnPart = critClone:FindFirstChild("warn", true)
		wwwwModel = critClone:FindFirstChild("wwww", true)

		-- Apply custom Nen color to ALL crit VFX (white effects get tinted)
		-- This includes warn, wwww, and any other effects in the crit model
		if hasCustomNenColor then
			applyNenColorToEffects(critClone, nenColor)
			-- Also specifically apply to warn and wwww if found
			if warnPart then
				applyNenColorToEffects(warnPart, nenColor)
			end
			if wwwwModel then
				applyNenColorToEffects(wwwwModel, nenColor)
			end
		end
	end

	-- Emit warn part immediately (color already applied above)
	if warnPart then
		EmitModule.emit(warnPart)
	end

	-- Emit Bling attachment first
	for _, descendant in Character:GetDescendants() do
		if descendant.Name == "Bling" and descendant:IsA("Attachment") then
			for _, particle in descendant:GetChildren() do
				if particle:IsA("ParticleEmitter") then
					particle:Emit(particle:GetAttribute("EmitCount") or 1)
				end
			end
			break
		end
	end

	-- Emit ALL effects on weapon parts (parts with "Weapon" attribute) and enable them for 10 seconds
	-- Weapon parts are direct children of Character with "Weapon" attribute set
	-- Skip effects under "Bling" attachment - those should only emit, not stay enabled
	-- Apply custom Nen color to white effects (with slight variations)
	local weaponEffects = {}
	for _, weaponPart in Character:GetChildren() do
		if weaponPart:GetAttribute("Weapon") then
			for _, effect in weaponPart:GetDescendants() do
				-- Check if this effect is under a Bling attachment
				local isUnderBling = false
				local parent = effect.Parent
				while parent and parent ~= weaponPart do
					if parent.Name == "Bling" then
						isUnderBling = true
						break
					end
					parent = parent.Parent
				end

				if effect:IsA("ParticleEmitter") then
					-- Apply custom Nen color to white particles
					if hasCustomNenColor then
						applyNenColorToParticle(effect, nenColor)
					end
					effect:Emit(effect:GetAttribute("EmitCount") or 1)
					-- Only enable if not under Bling
					if not isUnderBling then
						effect.Enabled = true
						table.insert(weaponEffects, effect)
					end
				elseif effect:IsA("Trail") then
					-- Apply custom Nen color to white trails
					if hasCustomNenColor then
						applyNenColorToTrail(effect, nenColor)
					end
					-- Only enable if not under Bling
					if not isUnderBling then
						effect.Enabled = true
						table.insert(weaponEffects, effect)
					end
				elseif effect:IsA("Beam") then
					-- Apply custom Nen color to white beams
					if hasCustomNenColor then
						applyNenColorToBeam(effect, nenColor)
					end
					-- Only enable if not under Bling
					if not isUnderBling then
						effect.Enabled = true
						table.insert(weaponEffects, effect)
					end
				end
			end
		end
	end

	-- Emit wwww model immediately (no delay)
	if wwwwModel then
		EmitModule.emit(wwwwModel)
	end

	-- local effect = RockMod.New("Path", Character.HumanoidRootPart.CFrame, {})

	-- 	if effect then
	-- 		effect:Debris("Normal", {
	-- 			Size = { 0.4, 1.2 },
	-- 			UpForce = { 0.3, 0.6 },
	-- 			RotationalForce = { 8, 20 },
	-- 			Spread = { 5, 5 },
	-- 			PartCount = 6,
	-- 			Radius = 5,
	-- 			LifeTime = 3.5,
	-- 			LifeCycle = {
	-- 				Entrance = {
	-- 					Type = "SizeUp",
	-- 					Speed = 0.25,
	-- 					Division = 3,
	-- 					EasingStyle = Enum.EasingStyle.Quad,
	-- 					EasingDirection = Enum.EasingDirection.Out,
	-- 				},
	-- 				Exit = {
	-- 					Type = "SizeDown",
	-- 					Speed = 0.3,
	-- 					Division = 2,
	-- 					EasingStyle = Enum.EasingStyle.Sine,
	-- 					EasingDirection = Enum.EasingDirection.In,
	-- 				},
	-- 			},
	-- 		})
	-- 	end


	-- Play Nen type sound
	if nenSfxFolder and rootPart then
		local soundName = nenType
		local nenTypeSound = nenSfxFolder:FindFirstChild(soundName)
		if nenTypeSound and nenTypeSound:IsA("Sound") then
			local typeSoundClone = nenTypeSound:Clone()
			typeSoundClone.Parent = rootPart
			typeSoundClone:Play()
			typeSoundClone.Ended:Once(function()
				typeSoundClone:Destroy()
			end)
		end
	end

	-- Color correction flash effect with sound timing
	local impactScythe = scytheVFX:FindFirstChild("ImpactScythe")
	if impactScythe then
		local colorCorrections = {}
		for _, child in pairs(impactScythe:GetChildren()) do
			if child:IsA("ColorCorrectionEffect") then
				local clone = child:Clone()
				clone.Parent = Lighting
				table.insert(colorCorrections, clone)
			end
		end

		-- Sort by name to ensure numbered order (cc, cc2, cc3, cc4)
		table.sort(colorCorrections, function(a, b)
			return a.Name < b.Name
		end)

		-- Loop through 2 complete playthroughs
		task.spawn(function()
			for i = 1, 2 do
				for _, cc in ipairs(colorCorrections) do
					cc.Enabled = true
					task.wait(0.002)
					cc.Enabled = false
				end
			end
			-- Delete all clones
			for _, cc in ipairs(colorCorrections) do
				cc:Destroy()
			end
		end)
	end

	-- Camera shake - FIRM like Rapid Thrust (increased magnitude)
	CamShake({
		Location = Character.PrimaryPart and Character.PrimaryPart.Position or Character:GetPivot().Position,
		Magnitude = 10,
		Damp = 0.00005,
		Frequency = 13,
		Influence = Vector3.new(0.5, 1, 0.5),
		Falloff = 65,
	})

	-- Create aggressive Nen type text using TextPlus (positioned at character's feet/Load VFX area)
	local hrp = Character:FindFirstChild("HumanoidRootPart")
	-- if hrp then
	-- 	-- Create a part at the feet to anchor the billboard
	-- 	local footAnchor = Instance.new("Part")
	-- 	footAnchor.Name = "NenTextAnchor"
	-- 	footAnchor.Anchored = true
	-- 	footAnchor.CanCollide = false
	-- 	footAnchor.Transparency = 1
	-- 	footAnchor.Size = Vector3.new(1, 1, 1)
	-- 	footAnchor.CFrame = hrp.CFrame * CFrame.new(0, -hrp.Size.Y / 2 - 1, 0)
	-- 	footAnchor.Parent = workspace.World.Visuals

	-- 	-- Create BillboardGui at feet (Load VFX position)
	-- 	local billboardGui = Instance.new("BillboardGui")
	-- 	billboardGui.Name = "NenCritText"
	-- 	billboardGui.Adornee = footAnchor
	-- 	billboardGui.Size = UDim2.fromOffset(800, 200) -- Larger size to prevent cropping
	-- 	billboardGui.StudsOffset = Vector3.new(0, 1, 0) -- Slightly above ground
	-- 	billboardGui.AlwaysOnTop = true
	-- 	billboardGui.MaxDistance = 100
	-- 	billboardGui.Parent = Players.LocalPlayer and Players.LocalPlayer:FindFirstChild("PlayerGui")

	-- 	-- Create text container frame for TextPlus
	-- 	local textFrame = Instance.new("Frame")
	-- 	textFrame.Name = "TextFrame"
	-- 	textFrame.BackgroundTransparency = 1
	-- 	textFrame.Size = UDim2.fromScale(1, 1)
	-- 	textFrame.Position = UDim2.fromScale(0.5, 0.5)
	-- 	textFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	-- 	textFrame.Parent = billboardGui

	-- 	-- Create text using TextPlus with Jura font, black stroke
	-- 	TextPlus.Create(textFrame, nenType:upper(), {
	-- 		Size = 52,
	-- 		Color = nenColor,
	-- 		Font = Font.new("rbxasset://fonts/families/Jura.json", Enum.FontWeight.Bold, Enum.FontStyle.Italic),
	-- 		StrokeSize = 3,
	-- 		StrokeColor = Color3.new(0, 0, 0),
	-- 		StrokeTransparency = 0,
	-- 		XAlignment = "Center",
	-- 		YAlignment = "Center",
	-- 		CharacterSpacing = 1.2, -- Slightly wider spacing
	-- 	})

	-- 	-- Animate: start transparent, fade in, then enlarge and fade out
	-- 	task.spawn(function()
	-- 		-- Set initial transparency (fade in effect)
	-- 		for _, child in textFrame:GetDescendants() do
	-- 			if child:IsA("TextLabel") then
	-- 				child.TextTransparency = 1
	-- 				local stroke = child:FindFirstChildOfClass("UIStroke")
	-- 				if stroke then
	-- 					stroke.Transparency = 1
	-- 				end
	-- 			end
	-- 		end

	-- 		-- Fade in
	-- 		local fadeInTime = 0.2
	-- 		local startTime = tick()
	-- 		while tick() - startTime < fadeInTime do
	-- 			local alpha = (tick() - startTime) / fadeInTime
	-- 			for _, child in textFrame:GetDescendants() do
	-- 				if child:IsA("TextLabel") then
	-- 					child.TextTransparency = 1 - alpha
	-- 					local stroke = child:FindFirstChildOfClass("UIStroke")
	-- 					if stroke then
	-- 						stroke.Transparency = 1 - alpha
	-- 					end
	-- 				end
	-- 			end
	-- 			task.wait()
	-- 		end

	-- 		-- Ensure fully visible
	-- 		for _, child in textFrame:GetDescendants() do
	-- 			if child:IsA("TextLabel") then
	-- 				child.TextTransparency = 0
	-- 				local stroke = child:FindFirstChildOfClass("UIStroke")
	-- 				if stroke then
	-- 					stroke.Transparency = 0
	-- 				end
	-- 			end
	-- 		end

	-- 		-- Hold briefly
	-- 		task.wait(0.3)

	-- 		-- Enlarge and fade out
	-- 		local fadeOutTime = 0.25
	-- 		startTime = tick()
	-- 		while tick() - startTime < fadeOutTime do
	-- 			local alpha = (tick() - startTime) / fadeOutTime
	-- 			for _, child in textFrame:GetDescendants() do
	-- 				if child:IsA("TextLabel") then
	-- 					child.TextTransparency = alpha
	-- 					child.TextSize = 52 * (1 + alpha * 0.8) -- Enlarge to 1.8x
	-- 					local stroke = child:FindFirstChildOfClass("UIStroke")
	-- 					if stroke then
	-- 						stroke.Transparency = alpha
	-- 					end
	-- 				end
	-- 			end
	-- 			task.wait()
	-- 		end

	-- 		-- Cleanup
	-- 		if billboardGui.Parent then
	-- 			billboardGui:Destroy()
	-- 		end
	-- 		if footAnchor.Parent then
	-- 			footAnchor:Destroy()
	-- 		end
	-- 	end)
	-- end

	-- RockMod Forward effect - straight forward debris path with lots of rocks
	print("[ScytheCrit] Starting RockMod Forward effect, hrp:", hrp)
	if hrp then
		-- Raycast down to get ground normal
		local rayParams = RaycastParams.new()
		rayParams.FilterType = Enum.RaycastFilterType.Exclude
		rayParams.FilterDescendantsInstances = {Character, workspace.World.Live}

		local groundRay = workspace:Raycast(hrp.Position, Vector3.new(0, -10, 0), rayParams)
		print("[ScytheCrit] Ground raycast result:", groundRay and "HIT" or "MISS", groundRay and groundRay.Instance or "nil")
		if groundRay then
			-- Get character's facing direction (flatten to XZ plane)
			local lookVector = -hrp.CFrame.LookVector
			local flatLookVector = Vector3.new(lookVector.X, 0, lookVector.Z).Unit

			-- Position at character's feet
			local startCFrame = CFrame.new(groundRay.Position)

			print("[ScytheCrit] Creating RockMod.New Forward at", groundRay.Position, "direction:", flatLookVector)
			local _forwardEffect = RockMod.New("Forward", startCFrame, {
				Normal = groundRay.Normal,
				Direction = flatLookVector, -- Use character's actual facing direction (forward)
				Length = 30, -- Long path going straight forward
				StepSize = 1.2, -- More debris (smaller step = more rocks)
				BaseSize = 1.8, -- Size of debris
				ScaleFactor = 1.065, -- Rocks grow slightly larger as they go
				Distance = {2, 5}, -- Spread from center line
				Rotation = {-25, 25},
				PartLifeTime = 1.8,
				LifeCycle = {
					Entrance = {
						Type = "SizeUp",
						Speed = 0.15,
						EasingStyle = Enum.EasingStyle.Circular,
						EasingDirection = Enum.EasingDirection.Out,
					},
					Exit = {
						Type = "SizeDown",
						Speed = 0.25,
						EasingStyle = Enum.EasingStyle.Quad,
						EasingDirection = Enum.EasingDirection.In,
					},
				},
			})
			print("[ScytheCrit] RockMod.New returned:", _forwardEffect)
		else
			print("[ScytheCrit] Ground raycast MISSED - no RockMod effect created")
		end
	else
		print("[ScytheCrit] No HumanoidRootPart found!")
	end

	-- Cleanup: disable weapon effects after 10 seconds
	task.delay(10, function()
		for _, effect in weaponEffects do
			if effect and effect.Parent then
				effect.Enabled = false
			end
		end
	end)

	-- Cleanup crit model after effect
	task.delay(2, function()
		if critClone and critClone.Parent then
			critClone:Destroy()
		end
	end)
end

--[[
	ScytheCritLoad - Ground charging VFX for Scythe critical attack
	Called when crit animation STARTS (not at frame 46)

	Timeline (at 60fps):
	- Frame 0: Position at character's feet, enable particles (normal TimeScale = 1)
	- Frame 40: TimeScale set to 0 (freeze effect)
	- Frame 46: TimeScale set back to 1, then Enabled = false
]]
function Base.ScytheCritLoad(Character: Model)
	print("[ScytheCritLoad] Function called for:", Character and Character.Name or "nil")

	local Global = require(Replicated.Modules.Shared.Global)

	-- Get Scythe VFX folder
	local scytheVFX = VFX:FindFirstChild("Scythe")
	if not scytheVFX then
		warn("[ScytheCritLoad] Scythe VFX folder not found!")
		return
	end

	-- Get the Load model
	local loadModel = scytheVFX:FindFirstChild("Load")
	if not loadModel then
		warn("[ScytheCritLoad] Load model not found in Scythe VFX folder!")
		return
	end

	-- Get character's root part for positioning
	local humanoidRootPart = Character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then
		warn("[ScytheCritLoad] HumanoidRootPart not found!")
		return
	end

	print("[ScytheCritLoad] All checks passed, creating VFX")

	-- Constants for white color detection
	local WHITE_THRESHOLD = 0.95

	local function isWhiteColor(color: Color3): boolean
		return color.R >= WHITE_THRESHOLD and color.G >= WHITE_THRESHOLD and color.B >= WHITE_THRESHOLD
	end

	local function ensureBrightColor(color: Color3): Color3
		local h, s, v = color:ToHSV()
		local newS = math.max(s, 0.5)
		local newV = math.max(v, 0.7)
		return Color3.fromHSV(h, newS, newV)
	end

	local function getColorVariation(baseColor: Color3): Color3
		local variationAmount = (math.random() * 0.2 - 0.1)
		local h, s, v = baseColor:ToHSV()
		local newV = math.clamp(v + variationAmount, 0.7, 1.0)
		local newS = math.clamp(s + (variationAmount * 0.3), 0.4, 1.0)
		return Color3.fromHSV(h, newS, newV)
	end

	-- Apply Nen color to a ParticleEmitter
	local function applyNenColorToParticle(particle: ParticleEmitter, nenColor: Color3)
		local colorSeq = particle.Color
		local keypoints = colorSeq.Keypoints

		local hasWhite = false
		for _, kp in keypoints do
			if isWhiteColor(kp.Value) then
				hasWhite = true
				break
			end
		end

		if hasWhite then
			local targetColor = getColorVariation(nenColor)
			local newKeypoints = {}
			for _, kp in keypoints do
				if isWhiteColor(kp.Value) then
					table.insert(newKeypoints, ColorSequenceKeypoint.new(kp.Time, targetColor))
				else
					table.insert(newKeypoints, kp)
				end
			end
			particle.Color = ColorSequence.new(newKeypoints)
		end
	end

	-- Get player's Nen color
	local nenColor = Color3.fromRGB(100, 200, 255) -- Default light blue
	local playerFromChar = Players:GetPlayerFromCharacter(Character)
	if not playerFromChar then
		local localPlayer = Players.LocalPlayer
		if localPlayer and localPlayer.Character == Character then
			playerFromChar = localPlayer
		end
	end

	if playerFromChar then
		local nenData = Global.GetData(playerFromChar, "Nen")
		if nenData and nenData.Color then
			local r, g, b = nenData.Color.R, nenData.Color.G, nenData.Color.B
			if not (r >= 250 and g >= 250 and b >= 250) then
				nenColor = ensureBrightColor(Color3.fromRGB(r, g, b))
			end
		end
	end

	-- Clone the Load model
	local loadClone = loadModel:Clone()

	-- Position at character's feet (ground level)
	local footOffset = Vector3.new(0, -humanoidRootPart.Size.Y / 2 - 1.5, 0)
	local footCFrame = humanoidRootPart.CFrame * CFrame.new(footOffset)
	loadClone:PivotTo(footCFrame)
	loadClone.Parent = workspace.World.Visuals

	print("[ScytheCritLoad] VFX cloned and parented to workspace.World.Visuals")

	-- Collect all particle emitters and apply Nen color
	local particles = {}

	-- Check all descendants
	for _, descendant in loadClone:GetDescendants() do
		if descendant:IsA("ParticleEmitter") then
			-- Apply Nen color
			applyNenColorToParticle(descendant, nenColor)
			-- Enable the particle
			descendant.Enabled = true
			-- Also emit in case Rate is 0
			local emitCount = descendant:GetAttribute("EmitCount") or 50
			descendant:Emit(emitCount)
			table.insert(particles, descendant)
		end
	end

	-- Also check direct children if loadClone is a BasePart
	if loadClone:IsA("BasePart") then
		for _, child in loadClone:GetChildren() do
			if child:IsA("ParticleEmitter") then
				applyNenColorToParticle(child, nenColor)
				child.Enabled = true
				local emitCount = child:GetAttribute("EmitCount") or 50
				child:Emit(emitCount)
				table.insert(particles, child)
			end
		end
	end

	print("[ScytheCritLoad] Found and enabled", #particles, "particle emitters")

	local hrp = Character:FindFirstChild("HumanoidRootPart")
	local nenType = "Enhance"
	if hrp then
		-- Create a part at the feet to anchor the billboard
		local footAnchor = Instance.new("Part")
		footAnchor.Name = "NenTextAnchor"
		footAnchor.Anchored = true
		footAnchor.CanCollide = false
		footAnchor.Transparency = 1
		footAnchor.Size = Vector3.new(1, 1, 1)
		footAnchor.CFrame = hrp.CFrame * CFrame.new(0, -hrp.Size.Y / 2 - 1, 0)
		footAnchor.Parent = workspace.World.Visuals

		-- Create BillboardGui at feet (Load VFX position)
		local billboardGui = Instance.new("BillboardGui")
		billboardGui.Name = "NenCritText"
		billboardGui.Adornee = footAnchor
		billboardGui.Size = UDim2.fromOffset(800, 200) -- Larger size to prevent cropping
		billboardGui.StudsOffset = Vector3.new(0, 1, 0) -- Slightly above ground
		billboardGui.AlwaysOnTop = true
		billboardGui.MaxDistance = 100
		billboardGui.Parent = Players.LocalPlayer and Players.LocalPlayer:FindFirstChild("PlayerGui")

		-- Create text container frame
		local textFrame = Instance.new("Frame")
		textFrame.Name = "TextFrame"
		textFrame.BackgroundTransparency = 1
		textFrame.Size = UDim2.fromScale(.5, .5)
		textFrame.Position = UDim2.fromScale(1, 0.5)
		textFrame.AnchorPoint = Vector2.new(0.5, 0.5)
		textFrame.ClipsDescendants = false
		textFrame.Parent = billboardGui

		-- Create text using TextPlus with Jura font, black stroke
		local TextPlus = require(Replicated.Modules.Utils.Text)
		TextPlus.Create(textFrame, nenType:upper(), {
			Size = 52,
			Color = nenColor,
			Font = Font.new("rbxasset://fonts/families/Jura.json", Enum.FontWeight.Bold, Enum.FontStyle.Italic),
			StrokeSize = 3,
			StrokeColor = Color3.new(0, 0, 0),
			StrokeTransparency = 0,
			XAlignment = "Center",
			YAlignment = "Center",
			CharacterSpacing = 1.2, -- Slightly wider spacing
		})

		-- Animate: start transparent, fade in, then enlarge and fade out
		task.spawn(function()
			-- Set initial transparency (fade in effect)
			for _, child in textFrame:GetDescendants() do
				if child:IsA("TextLabel") then
					child.TextTransparency = 1
					local stroke = child:FindFirstChildOfClass("UIStroke")
					if stroke then
						stroke.Transparency = 1
					end
				end
			end

			-- Fade in
			local fadeInTime = 0.2
			local startTime = tick()
			while tick() - startTime < fadeInTime do
				local alpha = (tick() - startTime) / fadeInTime
				for _, child in textFrame:GetDescendants() do
					if child:IsA("TextLabel") then
						child.TextTransparency = 1 - alpha
						local stroke = child:FindFirstChildOfClass("UIStroke")
						if stroke then
							stroke.Transparency = 1 - alpha
						end
					end
				end
				task.wait()
			end

			-- Ensure fully visible
			for _, child in textFrame:GetDescendants() do
				if child:IsA("TextLabel") then
					child.TextTransparency = 0
					local stroke = child:FindFirstChildOfClass("UIStroke")
					if stroke then
						stroke.Transparency = 0
					end
				end
			end

			-- Hold briefly
			task.wait(0.3)

			-- Enlarge and fade out
			local fadeOutTime = 0.25
			startTime = tick()
			while tick() - startTime < fadeOutTime do
				local alpha = (tick() - startTime) / fadeOutTime
				for _, child in textFrame:GetDescendants() do
					if child:IsA("TextLabel") then
						child.TextTransparency = alpha
						child.TextSize = 52 * (1 + alpha * 0.8) -- Enlarge to 1.8x
						local stroke = child:FindFirstChildOfClass("UIStroke")
						if stroke then
							stroke.Transparency = alpha
						end
					end
				end
				task.wait()
			end

			-- Cleanup
			if billboardGui.Parent then
				billboardGui:Destroy()
			end
			if footAnchor.Parent then
				footAnchor:Destroy()
			end
		end)
	end

	-- Timeline (at 60fps):
	-- Frame 0-39: Normal TimeScale (1), particles enabled
	-- Frame 40: TimeScale instantly set to 0 (freeze)
	-- Frame 46: TimeScale set back to 1, then disable particles

	local frame40Time = 40 / 60  -- 0.667 seconds
	local frame46Time = 46 / 60  -- 0.767 seconds

	-- At frame 40: Set TimeScale to 0 (instant freeze)
	task.delay(frame40Time, function()
		if not loadClone or not loadClone.Parent then return end

		for _, particle in particles do
			if particle and particle.Parent then
				particle.TimeScale = 0
			end
		end
	end)

	-- At frame 46: Set TimeScale back to 1, then disable
	task.delay(frame46Time, function()
		if not loadClone or not loadClone.Parent then return end

		for _, particle in particles do
			if particle and particle.Parent then
				particle.TimeScale = 1
				particle.Enabled = false
			end
		end
	end)

	-- Cleanup after effect completes
	task.delay(3, function()
		if loadClone and loadClone.Parent then
			loadClone:Destroy()
		end
	end)
end

--[[
	PostureBreak - Visual effect when posture is broken (guard break)
	Red crack effect with screen shake and highlight
]]
function Base.PostureBreak(Target: Model, Invoker: Model?)
	if not Target or not Target:FindFirstChild("HumanoidRootPart") then
		return
	end

	local hrp = Target.HumanoidRootPart

	-- Use existing Guardbreak VFX if available, otherwise create custom effect
	local guardbreakVFX = Replicated.Assets.VFX:FindFirstChild("Guardbreak")
	if guardbreakVFX then
		local eff = guardbreakVFX:Clone()
		eff.CFrame = hrp.CFrame
		eff.Parent = workspace.World.Visuals

		for _, v in eff:GetDescendants() do
			if v:IsA("ParticleEmitter") then
				v:Emit(v:GetAttribute("EmitCount") or 15)
			end
		end

		Debris:AddItem(eff, 4.5)
	end

	-- Add red crack highlight effect (posture broken indication)
	local highlight = Instance.new("Highlight")
	highlight.Name = "PostureBreakHighlight"
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.FillColor = Color3.fromRGB(255, 50, 50)
	highlight.FillTransparency = 0.3
	highlight.OutlineTransparency = 0
	highlight.OutlineColor = Color3.fromRGB(255, 0, 0)
	highlight.Parent = Target

	-- Flash and fade highlight
	local highlightTInfo = TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	task.delay(0.15, function()
		local hTween = TweenService:Create(highlight, highlightTInfo, {
			OutlineTransparency = 1,
			FillTransparency = 1,
		})
		hTween:Play()
		hTween.Completed:Connect(function()
			highlight:Destroy()
		end)
	end)

	-- Strong screen shake for local player
	if Player and Player.Character == Target then
		CamShake:ShakeOnce({
			Magnitude = 15,
			Damp = 0.0001,
			Frequency = 20,
			Influence = Vector3.new(0.6, 1, 0.6),
			Falloff = 50,
		})
	else
		-- Smaller shake for witnessing posture break
		CamShake:ShakeOnce({
			Magnitude = 5,
			Damp = 0.0001,
			Frequency = 15,
			Influence = Vector3.new(0.3, 0.5, 0.3),
			Falloff = 40,
		})
	end

	-- Play sound effect
	local breakSound = SFX:FindFirstChild("GuardBreak") or SFX:FindFirstChild("Impact")
	if breakSound then
		local sound = breakSound:Clone()
		sound.Parent = hrp
		sound:Play()
		Debris:AddItem(sound, 3)
	end
end

--[[
	CounterHit - Visual effect when interrupting an enemy's attack
	Yellow flash with "COUNTER" text popup
]]
function Base.CounterHit(Target: Model, Invoker: Model?)
	if not Target or not Target:FindFirstChild("HumanoidRootPart") then
		return
	end

	local hrp = Target.HumanoidRootPart
	local head = Target:FindFirstChild("Head")

	-- Yellow highlight flash
	local highlight = Instance.new("Highlight")
	highlight.Name = "CounterHitHighlight"
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.FillColor = Color3.fromRGB(255, 220, 50)
	highlight.FillTransparency = 0.4
	highlight.OutlineTransparency = 0
	highlight.OutlineColor = Color3.fromRGB(255, 200, 0)
	highlight.Parent = Target

	-- Flash and fade highlight quickly
	local highlightTInfo = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	task.delay(0.1, function()
		local hTween = TweenService:Create(highlight, highlightTInfo, {
			OutlineTransparency = 1,
			FillTransparency = 1,
		})
		hTween:Play()
		hTween.Completed:Connect(function()
			highlight:Destroy()
		end)
	end)

	-- Create "COUNTER" text billboard
	if head then
		local billboardGui = Instance.new("BillboardGui")
		billboardGui.Name = "CounterHitText"
		billboardGui.Adornee = head
		billboardGui.Size = UDim2.fromOffset(200, 50)
		billboardGui.StudsOffset = Vector3.new(0, 3.5, 0)
		billboardGui.AlwaysOnTop = true
		billboardGui.MaxDistance = 80
		billboardGui.Parent = Player and Player:FindFirstChild("PlayerGui")

		local textLabel = Instance.new("TextLabel")
		textLabel.Name = "CounterText"
		textLabel.BackgroundTransparency = 1
		textLabel.Size = UDim2.fromScale(1, 1)
		textLabel.Position = UDim2.fromScale(0.5, 0.5)
		textLabel.AnchorPoint = Vector2.new(0.5, 0.5)
		textLabel.Font = Enum.Font.GothamBold
		textLabel.Text = "COUNTER"
		textLabel.TextColor3 = Color3.fromRGB(255, 220, 50)
		textLabel.TextStrokeColor3 = Color3.fromRGB(100, 80, 0)
		textLabel.TextStrokeTransparency = 0
		textLabel.TextSize = 0 -- Start at 0 for punch-in
		textLabel.TextTransparency = 0
		textLabel.Parent = billboardGui

		-- Punch-in animation
		local punchInInfo = TweenInfo.new(0.08, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		local punchInTween = TweenService:Create(textLabel, punchInInfo, {
			TextSize = 32
		})
		punchInTween:Play()

		-- Float up and fade out
		task.delay(0.3, function()
			if not billboardGui.Parent then return end

			local fadeInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			local fadeTween = TweenService:Create(textLabel, fadeInfo, {
				TextTransparency = 1,
				TextStrokeTransparency = 1,
			})
			local moveTween = TweenService:Create(billboardGui, fadeInfo, {
				StudsOffset = Vector3.new(0, 5, 0)
			})
			fadeTween:Play()
			moveTween:Play()

			fadeTween.Completed:Connect(function()
				billboardGui:Destroy()
			end)
		end)
	end

	-- Small screen shake for impact feel
	CamShake:ShakeOnce({
		Magnitude = 4,
		Damp = 0.0001,
		Frequency = 18,
		Influence = Vector3.new(0.4, 0.6, 0.4),
		Falloff = 35,
	})

	-- Play counter hit sound
	local hitSound = SFX:FindFirstChild("CounterHit") or SFX:FindFirstChild("CriticalHit") or SFX:FindFirstChild("Hit")
	if hitSound then
		local sound = hitSound:Clone()
		sound.Parent = hrp
		sound.PlaybackSpeed = 1.2 -- Slightly higher pitch for counter
		sound:Play()
		Debris:AddItem(sound, 2)
	end
end

--[[
	ArmorAbsorb - Visual effect when CounterArmor absorbs a hit
	White/blue flash to indicate armor absorbed the stun
]]
function Base.ArmorAbsorb(Target: Model)
	if not Target or not Target:FindFirstChild("HumanoidRootPart") then
		return
	end

	-- White/blue highlight flash to indicate armor
	local highlight = Instance.new("Highlight")
	highlight.Name = "ArmorAbsorbHighlight"
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.FillColor = Color3.fromRGB(200, 220, 255)
	highlight.FillTransparency = 0.5
	highlight.OutlineTransparency = 0
	highlight.OutlineColor = Color3.fromRGB(150, 200, 255)
	highlight.Parent = Target

	-- Quick flash and fade
	local highlightTInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	task.delay(0.05, function()
		local hTween = TweenService:Create(highlight, highlightTInfo, {
			OutlineTransparency = 1,
			FillTransparency = 1,
		})
		hTween:Play()
		hTween.Completed:Connect(function()
			highlight:Destroy()
		end)
	end)

	-- Subtle screen shake
	CamShake:ShakeOnce({
		Magnitude = 2,
		Damp = 0.0001,
		Frequency = 15,
		Influence = Vector3.new(0.3, 0.4, 0.3),
		Falloff = 30,
	})
end

return Base
