--!strict
-- Nen Indicator Component
-- Displays the active nen ability above the character's head using BillboardGui
-- Also plays KANJI VFX effect when ability changes
-- Text fades in with diverge effect and fades out after a delay

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Fusion = require(ReplicatedStorage.Modules.Fusion)
local TextPlus = require(ReplicatedStorage.Modules.Utils.Text)

local Children, scoped, peek = Fusion.Children, Fusion.scoped, Fusion.peek

-- Animation settings
local FADE_IN_DURATION = 0.4
local DISPLAY_DURATION = 2.0
local FADE_OUT_DURATION = 0.6
local DIVERGE_OFFSET = 20 -- Pixels to diverge from center
local SHAKE_INTENSITY = 8 -- Pixels to shake
local SHAKE_DURATION = 0.5 -- Duration of shake effect

-- Colors for each ability
local AbilityColors = {
	Ten = Color3.fromRGB(100, 200, 255),   -- Light blue
	Zetsu = Color3.fromRGB(100, 100, 100), -- Gray
	Ren = Color3.fromRGB(255, 100, 100),   -- Red
	Hatsu = Color3.fromRGB(255, 200, 50),  -- Gold
	En = Color3.fromRGB(50, 150, 255),     -- Deep blue
	Ken = Color3.fromRGB(200, 200, 200),   -- Silver
	Gyo = Color3.fromRGB(255, 50, 150),    -- Magenta
	Ryu = Color3.fromRGB(255, 150, 0),     -- Orange
}

-- Display names for abilities (just the ability name)
local AbilityDisplayNames = {
	Ten = "Ten",
	Zetsu = "Zetsu",
	Ren = "Ren",
	Hatsu = "Hatsu",
	En = "En",
	Ken = "Ken",
	Gyo = "Gyo",
	Ryu = "Ryu",
}

-- Display names for deactivation
local AbilityDeactivateNames = {
	Ten = "Ten",
	Zetsu = "Zetsu",
	Ren = "Ren",
	Hatsu = "Hatsu",
	En = "En",
	Ken = "Ken",
	Gyo = "Gyo",
	Ryu = "Ryu",
}

-- Play KANJI VFX effect with ability color
local function playKanjiVFX(character, abilityName)
	local kanjiTemplate = ReplicatedStorage:FindFirstChild("Assets")
		and ReplicatedStorage.Assets:FindFirstChild("VFX")
		and ReplicatedStorage.Assets.VFX:FindFirstChild("KANJI")

	if not kanjiTemplate then
		warn("[NenIndicator] KANJI VFX not found at ReplicatedStorage.Assets.VFX.KANJI")
		return
	end

	local head = character:FindFirstChild("Head")
	if not head then return end

	local kanji = kanjiTemplate:Clone()
	kanji.Parent = workspace.World and workspace.World.Visuals or workspace

	-- Get ability color
	local color = AbilityColors[abilityName] or Color3.fromRGB(255, 255, 255)

	-- Position above head
	if kanji:IsA("BasePart") then
		kanji.CFrame = head.CFrame * CFrame.new(0, 3, 0)
		kanji.Anchored = true

		-- Recolor the part itself if it has a color property
		if kanji:IsA("MeshPart") or kanji:IsA("Part") then
			kanji.Color = color
		end
	elseif kanji:IsA("Model") then
		kanji:PivotTo(head.CFrame * CFrame.new(0, 3, 0))
	end

	-- Recolor all particle emitters and emit
	for _, v in kanji:GetDescendants() do
		if v:IsA("ParticleEmitter") then
			-- Apply ability color to particles
			if v:GetAttribute("Color") ~= false then -- Allow opt-out with Color = false attribute
				v.Color = ColorSequence.new(color)
			end
			local emitCount = v:GetAttribute("EmitCount") or 5
			v:Emit(emitCount)
		elseif v:IsA("PointLight") or v:IsA("SpotLight") or v:IsA("SurfaceLight") then
			-- Recolor lights too
			v.Color = color
		elseif v:IsA("BasePart") then
			-- Recolor mesh parts
			v.Color = color
		elseif v:IsA("Decal") or v:IsA("Texture") then
			-- Tint decals/textures
			v.Color3 = color
		end
	end

	-- Clean up after delay
	task.delay(2, function()
		kanji:Destroy()
	end)
end

return function()
	local scope = scoped(Fusion, {})
	
	local currentAbility = scope:Value(nil) -- Current ability name or nil
	local visible = scope:Value(false)
	
	local player = Players.LocalPlayer
	local character = player.Character or player.CharacterAdded:Wait()
	local head = character:WaitForChild("Head", 5)
	
	if not head then
		warn("[NenIndicator] Could not find character head")
		return nil
	end
	
	-- Create text frame for TextPlus
	local textFrame = scope:New("Frame")({
		Name = "NenTextFrame",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(200, 40),
		Position = UDim2.fromScale(0.5, 0.3), -- Aligned with kanji position
		AnchorPoint = Vector2.new(0.5, 0.5),
	})

	-- Create BillboardGui
	local billboardGui = scope:New("BillboardGui")({
		Name = "NenIndicator",
		Adornee = head,
		Size = UDim2.fromOffset(200, 100), -- Taller to accommodate text above kanji
		StudsOffset = Vector3.new(0, 3, 0), -- Same Y offset as kanji (3 studs above head)
		AlwaysOnTop = true,
		MaxDistance = 100,
		
		[Children] = {
			textFrame,
		},
	})
	
	billboardGui.Parent = player.PlayerGui

	-- Animation helper: Fade in with diverge effect
	local function animateTextIn(frame)
		task.wait(0.05) -- Wait for TextPlus to render

		local characters = {}
		for _, child in frame:GetChildren() do
			if child:IsA("ImageLabel") or child:IsA("TextLabel") then
				table.insert(characters, child)
			elseif child:IsA("Folder") then
				for _, char in child:GetChildren() do
					if char:IsA("ImageLabel") or char:IsA("TextLabel") then
						table.insert(characters, char)
					end
				end
			end
		end

		-- Sort by X position for diverge effect
		table.sort(characters, function(a, b)
			return a.Position.X.Offset < b.Position.X.Offset
		end)

		local centerIndex = math.ceil(#characters / 2)

		for i, char in characters do
			-- Start invisible and offset from center
			local originalPos = char.Position
			local divergeAmount = (i - centerIndex) * 3 -- Pixels offset based on distance from center

			-- Set initial transparency and build tween goal based on object type
			local tweenGoal = { Position = originalPos }
			if char:IsA("ImageLabel") then
				char.ImageTransparency = 1
				tweenGoal.ImageTransparency = 0
			elseif char:IsA("TextLabel") then
				char.TextTransparency = 1
				tweenGoal.TextTransparency = 0
			end
			char.Position = originalPos + UDim2.fromOffset(-divergeAmount, 10)

			-- Tween in with fade and slide
			local tween = TweenService:Create(char, TweenInfo.new(FADE_IN_DURATION, Enum.EasingStyle.Back, Enum.EasingDirection.Out), tweenGoal)
			tween:Play()

			task.wait(0.02) -- Stagger each character
		end
	end

	-- Animation helper: Fade out with diverge effect
	local function animateTextOut(frame, callback)
		local characters = {}
		for _, child in frame:GetChildren() do
			if child:IsA("ImageLabel") or child:IsA("TextLabel") then
				table.insert(characters, child)
			elseif child:IsA("Folder") then
				for _, char in child:GetChildren() do
					if char:IsA("ImageLabel") or char:IsA("TextLabel") then
						table.insert(characters, char)
					end
				end
			end
		end

		-- Sort by X position
		table.sort(characters, function(a, b)
			return a.Position.X.Offset < b.Position.X.Offset
		end)

		local centerIndex = math.ceil(#characters / 2)
		local tweenCount = #characters
		local completedCount = 0

		for i, char in characters do
			local divergeAmount = (i - centerIndex) * 5

			-- Build tween goal based on object type
			local tweenGoal = { Position = char.Position + UDim2.fromOffset(divergeAmount, -15) }
			if char:IsA("ImageLabel") then
				tweenGoal.ImageTransparency = 1
			elseif char:IsA("TextLabel") then
				tweenGoal.TextTransparency = 1
			end

			local tween = TweenService:Create(char, TweenInfo.new(FADE_OUT_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.In), tweenGoal)
			tween:Play()
			tween.Completed:Connect(function()
				completedCount = completedCount + 1
				if completedCount >= tweenCount and callback then
					callback()
				end
			end)

			task.wait(0.015)
		end

		-- Fallback cleanup if no characters
		if tweenCount == 0 and callback then
			callback()
		end
	end

	-- Track animation state
	local animationThread = nil
	local lastAbility = nil

	-- Animation helper: Shake effect for exhaustion
	local function animateShake(frame, callback)
		local originalPosition = frame.Position
		local shakeCount = 10
		local shakeDuration = SHAKE_DURATION / shakeCount

		task.spawn(function()
			for i = 1, shakeCount do
				local offsetX = (math.random() - 0.5) * 2 * SHAKE_INTENSITY
				local offsetY = (math.random() - 0.5) * 2 * SHAKE_INTENSITY
				frame.Position = originalPosition + UDim2.fromOffset(offsetX, offsetY)
				task.wait(shakeDuration)
			end
			frame.Position = originalPosition
			if callback then
				callback()
			end
		end)
	end

	-- Helper function to show text with animation
	local function showAbilityText(displayText, color, useShake)
		-- Clear existing text
		for _, child in textFrame:GetChildren() do
			child:Destroy()
		end

		visible:set(true)

		TextPlus.Create(textFrame, displayText, {
			Font = Font.new("rbxasset://fonts/families/Sarpanch.json", Enum.FontWeight.Bold),
			Size = 24,
			Color = color,
			StrokeSize = 2,
			StrokeColor = Color3.fromRGB(0, 0, 0),
			StrokeTransparency = 0.3,
			XAlignment = "Center",
			YAlignment = "Center",
		})

		-- Animate text in, then schedule fade out
		animationThread = task.spawn(function()
			animateTextIn(textFrame)

			-- Apply shake effect if requested (for exhaustion)
			if useShake then
				animateShake(textFrame, nil)
			end

			task.wait(DISPLAY_DURATION)

			-- Fade out and clear
			animateTextOut(textFrame, function()
				for _, child in textFrame:GetChildren() do
					child:Destroy()
				end
				visible:set(false)
			end)
		end)
	end

	scope:Observer(currentAbility):onChange(function()
		local ability = peek(currentAbility)

		if ability ~= lastAbility then
			local previousAbility = lastAbility
			lastAbility = ability

			-- Cancel any pending animation
			if animationThread then
				task.cancel(animationThread)
				animationThread = nil
			end

			-- Clear existing text
			for _, child in textFrame:GetChildren() do
				child:Destroy()
			end

			if ability then
				-- Activating a new ability
				local color = AbilityColors[ability] or Color3.fromRGB(255, 255, 255)
				local displayText = AbilityDisplayNames[ability] or ability

				-- Play KANJI VFX
				local char = player.Character
				if char then
					playKanjiVFX(char, ability)
				end

				showAbilityText(displayText, color)
			elseif previousAbility then
				-- Deactivating - show deactivation message for the previous ability
				local color = AbilityColors[previousAbility] or Color3.fromRGB(150, 150, 150)
				local displayText = AbilityDeactivateNames[previousAbility] or previousAbility

				showAbilityText(displayText, color)
			else
				visible:set(false)
			end
		end
	end)

	-- Update adornee when character respawns
	player.CharacterAdded:Connect(function(newCharacter)
		local newHead = newCharacter:WaitForChild("Head", 5)
		if newHead and billboardGui then
			billboardGui.Adornee = newHead
		end
	end)

	-- Return API for external control
	return {
		scope = scope,
		billboardGui = billboardGui,
		currentAbility = currentAbility,

		setAbility = function(abilityName)
			currentAbility:set(abilityName)
		end,

		getAbility = function()
			return peek(currentAbility)
		end,

		-- Show "NEN EXHAUSTED" with shake effect
		showExhausted = function()
			-- Cancel any pending animation
			if animationThread then
				task.cancel(animationThread)
				animationThread = nil
			end

			-- Reset ability state
			lastAbility = nil
			currentAbility:set(nil)

			-- Show exhausted message with red color and shake
			local exhaustedColor = Color3.fromRGB(255, 50, 50) -- Red for exhaustion
			showAbilityText("NEN EXHAUSTED", exhaustedColor, true) -- true = use shake
		end,

		cleanup = function()
			scope:doCleanup()
		end,
	}
end

