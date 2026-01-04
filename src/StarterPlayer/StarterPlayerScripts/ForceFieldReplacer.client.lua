--[[
	ForceField Replacer

	Replaces the default Roblox ForceField effect with a white Highlight effect.
	This runs on the client to handle the visual replacement smoothly.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

-- Configuration
local HIGHLIGHT_COLOR = Color3.fromRGB(255, 255, 255) -- White
local HIGHLIGHT_OUTLINE = Color3.fromRGB(200, 200, 200) -- Slightly gray outline
local HIGHLIGHT_TRANSPARENCY = 0.7

-- Function to replace ForceField with Highlight
local function replaceForceField(forceField)
	if not forceField:IsA("ForceField") then return end

	local character = forceField.Parent
	if not character then return end

	-- Create white highlight
	local highlight = Instance.new("Highlight")
	highlight.Name = "SpawnProtectionHighlight"
	highlight.Adornee = character
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.FillColor = HIGHLIGHT_COLOR
	highlight.FillTransparency = HIGHLIGHT_TRANSPARENCY
	highlight.OutlineColor = HIGHLIGHT_OUTLINE
	highlight.OutlineTransparency = 0.3
	highlight.Parent = character

	-- Hide the ForceField effect by disabling it
	forceField.Visible = false

	-- When ForceField is destroyed, fade out and remove highlight
	local destroyConnection
	destroyConnection = forceField.Destroying:Connect(function()
		destroyConnection:Disconnect()

		-- Fade out the highlight
		local fadeOut = TweenService:Create(highlight, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			FillTransparency = 1,
			OutlineTransparency = 1,
		})
		fadeOut:Play()
		fadeOut.Completed:Connect(function()
			highlight:Destroy()
		end)
	end)

	-- Also handle if ForceField parent changes (removed from character)
	local ancestryConnection
	ancestryConnection = forceField.AncestryChanged:Connect(function(_, newParent)
		if not newParent then
			ancestryConnection:Disconnect()
			if destroyConnection then
				destroyConnection:Disconnect()
			end

			-- Fade out the highlight
			if highlight and highlight.Parent then
				local fadeOut = TweenService:Create(highlight, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					FillTransparency = 1,
					OutlineTransparency = 1,
				})
				fadeOut:Play()
				fadeOut.Completed:Connect(function()
					if highlight and highlight.Parent then
						highlight:Destroy()
					end
				end)
			end
		end
	end)
end

-- Function to watch a character for ForceFields
local function watchCharacter(character)
	if not character then return end

	-- Check for existing ForceFields
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("ForceField") then
			replaceForceField(child)
		end
	end

	-- Watch for new ForceFields being added
	character.ChildAdded:Connect(function(child)
		if child:IsA("ForceField") then
			replaceForceField(child)
		end
	end)
end

-- Watch local player's characters
if player.Character then
	watchCharacter(player.Character)
end

player.CharacterAdded:Connect(watchCharacter)
