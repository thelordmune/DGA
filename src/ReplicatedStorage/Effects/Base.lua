-- Services
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Replicated = game:GetService("ReplicatedStorage")

-- Modules
local Misc = require(script.Parent.Misc)
local Utilities = require(Replicated.Modules.Utilities)
local Debris = Utilities.Debris
local EmitModule = require(game.ReplicatedStorage.Modules.Utils.EmitModule)

-- Variables
local Player = Players.LocalPlayer
local VFX = Replicated:WaitForChild("Assets").VFX
local SFX = Replicated:WaitForChild("Assets").SFX
local CamShake = require(Replicated.Modules.Utils.CamShake)

local Fusion = require(Replicated.Modules.Fusion)
local Children, scoped, peek, out = Fusion.Children, Fusion.scoped, Fusion.peek, Fusion.Out

local ref = require(Replicated.Modules.ECS.jecs_ref)

local TInfo = TweenInfo.new(0.35, Enum.EasingStyle.Circular, Enum.EasingDirection.Out, 0)

-- Store original trail WidthScale values (so they persist across multiple dashes)
local originalTrailWidths = {}

local Base = {}

-- ============================================
-- CHRONO NPC MODEL RESOLUTION
-- Resolves server-side model references to client clones for VFX
-- ============================================

-- Check if a model is inside any NpcRegistryCamera
local function isInNpcRegistryCamera(inst)
	if typeof(inst) ~= "Instance" then return false end
	local parent = inst.Parent
	while parent do
		if parent.Name == "NpcRegistryCamera" then
			return true
		end
		parent = parent.Parent
	end
	return false
end

-- Helper to get client clone for a Chrono NPC
-- Server sends model references from its NpcRegistryCamera
-- The client has its own NpcRegistryCamera with clones - we need to resolve to those
local function resolveChronoModel(model: Model?): Model
	if not model or typeof(model) ~= "Instance" then return model end

	-- Player characters are never Chrono NPCs
	if model:IsA("Model") and Players:GetPlayerFromCharacter(model) then
		return model
	end

	-- Only resolve Model instances
	if not model:IsA("Model") then return model end

	-- If the model is NOT inside a NpcRegistryCamera, it's a normal model
	if not isInNpcRegistryCamera(model) then
		return model
	end

	-- Model is inside a NpcRegistryCamera - find the client's own camera (tagged ClientOwned)
	local clientCamera = nil
	for _, child in workspace:GetChildren() do
		if child.Name == "NpcRegistryCamera" and child:IsA("Camera") and child:GetAttribute("ClientOwned") then
			clientCamera = child
			break
		end
	end

	-- Try ChronoId attribute
	local chronoId = model:GetAttribute("ChronoId")
	if chronoId and clientCamera then
		local clientClone = clientCamera:FindFirstChild(tostring(chronoId), true)
		if clientClone and clientClone:IsA("Model") then
			return clientClone
		end
	end

	-- Fallback: try by name
	if clientCamera and model.Name then
		local byName = clientCamera:FindFirstChild(model.Name, true)
		if byName and byName:IsA("Model") then
			return byName
		end
	end

	return model
end

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
	-- Resolve Chrono NPC models to client clones
	Character = resolveChronoModel(Character)
	if not Character or not Character:FindFirstChild("HumanoidRootPart") then return end

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
	-- Resolve Chrono NPC models to client clones
	Character = resolveChronoModel(Character)
	if not Character or not Character:FindFirstChild("HumanoidRootPart") then return end

	for i, v in pairs(Replicated.Assets.VFX.PerfectDodge2:GetChildren()) do
		local Clone = v:Clone()
		Clone:Emit(Clone:GetAttribute("EmitCount"))
		Clone.Parent = Character.HumanoidRootPart

		Debris:AddItem(Clone, Clone.Lifetime.Max)
	end
end

function Base.Block(Character: Model)
	-- Resolve Chrono NPC models to client clones
	Character = resolveChronoModel(Character)
	if not Character or not Character:FindFirstChild("HumanoidRootPart") then return end

	local BlockAttachment = VFX.Blocked.Attachment:Clone()
	BlockAttachment.Parent = Character.HumanoidRootPart

	Misc.Emit(BlockAttachment)
end

function Base.CriticalIndicator(Character: Model)
	-- Resolve Chrono NPC models to client clones
	Character = resolveChronoModel(Character)
	if not Character or not Character:FindFirstChild("HumanoidRootPart") then return end

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

function Base.Parry(Character: Model, Target, Distance)
	-- Resolve Chrono NPC models to client clones
	Character = resolveChronoModel(Character)
	Target = resolveChronoModel(Target)
	if not Character or not Character:FindFirstChild("HumanoidRootPart") then return end

	-- Clone the entire Parry part and position it slightly in front of the character
	local Parry = VFX.Parry:Clone()
	Parry.CFrame = Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, -2)
	Parry.Parent = workspace.World.Visuals

	for _, v in pairs(Parry:GetDescendants()) do
		if v:IsA("ParticleEmitter") then
			v:Emit(v:GetAttribute("EmitCount"))
		elseif v:IsA("PointLight") then
			coroutine.wrap(function()
				TweenService:Create(v, TweenInfo.new(0.1), { Brightness = 8 }):Play()
				task.wait(0.5)
				TweenService:Create(v, TweenInfo.new(0.5), { Brightness = 0 }):Play()
			end)()
		end
	end

	Debris:AddItem(Parry, 6)
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
	-- Resolve Chrono NPC models to client clones
	Character = resolveChronoModel(Character)
	if not Character or not Character:FindFirstChild("HumanoidRootPart") then return end

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

--[[
	PostureBreak - Visual effect when posture is broken (guard break)
	Red crack effect with screen shake and highlight
]]
function Base.PostureBreak(Target: Model, Invoker: Model?)
	-- Resolve Chrono NPC models to client clones
	Target = resolveChronoModel(Target)
	Invoker = resolveChronoModel(Invoker)
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
	CamShake({
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

function Base.FeintFlash(Character: Model)
	Character = resolveChronoModel(Character)
	if not Character then return end

	-- Quick white highlight flash to indicate feint
	local highlight = Instance.new("Highlight")
	highlight.Name = "FeintHighlight"
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.FillColor = Color3.fromRGB(255, 255, 255)
	highlight.FillTransparency = 0.3
	highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
	highlight.OutlineTransparency = 0
	highlight.Parent = Character

	-- Rapid fade out
	task.delay(0.05, function()
		local tween = TweenService:Create(highlight, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			FillTransparency = 1,
			OutlineTransparency = 1,
		})
		tween:Play()
		tween.Completed:Connect(function()
			highlight:Destroy()
		end)
	end)
end

-- Knockback hit VFX: kbhit in front of torso + kbSmoke at feet (later half)
function Base.KnockbackVFX(Character: Model)
	Character = resolveChronoModel(Character)
	if not Character then return end

	local root = Character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	-- kbhit: position in front of the target's torso and emit immediately
	local kbhitTemplate = VFX:FindFirstChild("kbhit")
	if kbhitTemplate then
		local kbhit = kbhitTemplate:Clone()
		kbhit.CFrame = root.CFrame * CFrame.new(0, 0, -2) -- 2 studs in front of torso
		kbhit.Parent = workspace

		-- Weld to root so it follows the character
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = kbhit
		weld.Parent = kbhit

		Base.Emit(kbhit)
		Debris:AddItem(kbhit, 2)
	end

	-- kbSmoke: position at feet, enable during the later half of knockback (after 0.6s)
	local kbSmokeTemplate = VFX:FindFirstChild("kbSmoke")
	if kbSmokeTemplate then
		local kbSmoke = kbSmokeTemplate:Clone()
		kbSmoke.CFrame = root.CFrame * CFrame.new(0, -2.5, 0) -- At feet level
		kbSmoke.Parent = workspace

		-- Weld to root so it follows
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = kbSmoke
		weld.Parent = kbSmoke

		-- Disable all emitters initially
		for _, emitter in ipairs(kbSmoke:GetDescendants()) do
			if emitter:IsA("ParticleEmitter") then
				emitter.Enabled = false
			end
		end

		-- Enable during later half of knockback (0.6s in of 1.267s total)
		task.delay(0.6, function()
			if not kbSmoke or not kbSmoke.Parent then return end
			for _, emitter in ipairs(kbSmoke:GetDescendants()) do
				if emitter:IsA("ParticleEmitter") then
					emitter.Enabled = true
				end
			end
		end)

		-- Disable and cleanup after knockback ends
		task.delay(1.267, function()
			if not kbSmoke or not kbSmoke.Parent then return end
			for _, emitter in ipairs(kbSmoke:GetDescendants()) do
				if emitter:IsA("ParticleEmitter") then
					emitter.Enabled = false
				end
			end
		end)

		Debris:AddItem(kbSmoke, 3)
	end
end

-- Follow-up VFX indicator: replaces the old Highlight-based indicator
function Base.KnockbackFollowUpVFX(Character: Model, Duration: number?)
	Character = resolveChronoModel(Character)
	if not Character then return end

	local root = Character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	-- Remove any existing follow-up VFX
	local existing = root:FindFirstChild("FollowUpVFX")
	if existing then existing:Destroy() end

	local followUpTemplate = VFX:FindFirstChild("FollowUp")
	if not followUpTemplate then return end

	local followUp = followUpTemplate:Clone()
	followUp.Name = "FollowUpVFX"
	followUp.CFrame = root.CFrame
	followUp.Parent = root

	-- Weld to root
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = followUp
	weld.Parent = followUp

	-- Enable all emitters
	for _, emitter in ipairs(followUp:GetDescendants()) do
		if emitter:IsA("ParticleEmitter") then
			emitter.Enabled = true
		end
	end

	-- Remove after duration
	local dur = Duration or 1.267
	task.delay(dur, function()
		if followUp and followUp.Parent then
			-- Disable emitters first for clean fadeout
			for _, emitter in ipairs(followUp:GetDescendants()) do
				if emitter:IsA("ParticleEmitter") then
					emitter.Enabled = false
				end
			end
			Debris:AddItem(followUp, 2)
		end
	end)
end

--------------------------------------------------------------------------------
-- Absolute Focus VFX
-- Aura burst when player reaches 100% focus
--------------------------------------------------------------------------------
function Base.AbsoluteFocusVFX(Character: Model)
	-- Resolve Chrono NPC models if needed
	Character = resolveChronoModel(Character)
	if not Character then return end

	local root = Character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	-- Look for Focus aura VFX in Assets
	local auraTemplate = VFX:FindFirstChild("Focus") and VFX.Focus:FindFirstChild("AbsoluteAura")

	if auraTemplate then
		local aura = auraTemplate:Clone()
		if aura:IsA("BasePart") then
			aura.CFrame = root.CFrame
			aura.Anchored = true
		elseif aura:IsA("Model") then
			aura:PivotTo(root.CFrame)
		elseif aura:IsA("Attachment") then
			aura.Parent = root
		end

		if not aura:IsA("Attachment") then
			aura.Parent = workspace.World and workspace.World.Visuals or workspace
		end

		-- Emit all particles
		for _, emitter in aura:GetDescendants() do
			if emitter:IsA("ParticleEmitter") then
				emitter:Emit(emitter:GetAttribute("EmitCount") or 20)
			end
		end

		-- Cleanup
		Debris:AddItem(aura, 3)
	end

	-- Camera shake for nearby players
	CamShake({
		Location = root.Position,
		Magnitude = 8,
		Damp = 0.0001,
		Frequency = 15,
		Influence = Vector3.new(0.5, 0.8, 0.5),
		Falloff = 60,
	})
end

return Base
