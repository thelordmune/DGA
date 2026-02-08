--[[
	Loading Screen (ReplicatedFirst - runs IMMEDIATELY on join)

	- Locks camera to Workspace.Loadings.Loading.Cam facing Hisoka
	- Animated HxH intro: bars, tiled bg, emblem dissolve, fact cycling
	- Preloads all game assets (VFX, animations, sounds, images)
	- DepthOfField effect during loading, tweened back after
	- Skip button appears only after background fade-out
	- Outro sequence then restores camera to character
	- No external dependencies (no Fusion, no CSystem)
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ContentProvider = game:GetService("ContentProvider")
local Lighting = game:GetService("Lighting")
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

print("[LoadingScreen] ReplicatedFirst script started")

-- Remove the default Roblox loading screen so ours is visible
game:GetService("ReplicatedFirst"):RemoveDefaultLoadingScreen()

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Set the global flag IMMEDIATELY so other scripts know loading is active
_G.LoadingScreenActive = true

-- Hide default Roblox UI
pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false) end)
pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false) end)
pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false) end)
pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, false) end)
pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.EmotesMenu, false) end)

print("[LoadingScreen] UI setup starting")

--------------------------------------------------------------------------------
-- DepthOfField: set loading values (instant, no yields)
--------------------------------------------------------------------------------
local depthOfField = Lighting:FindFirstChildOfClass("DepthOfFieldEffect")
local originalFarIntensity, originalInFocusRadius
if depthOfField then
	originalFarIntensity = depthOfField.FarIntensity
	originalInFocusRadius = depthOfField.InFocusRadius
	depthOfField.FarIntensity = 1
	depthOfField.InFocusRadius = 12.355
end

--------------------------------------------------------------------------------
-- Camera lock: resolve in background, enforce every frame
-- The lockedCFrame is set once the Loadings folder replicates.
-- The RenderStepped connection starts IMMEDIATELY and will begin
-- enforcing the lock as soon as lockedCFrame is computed.
--------------------------------------------------------------------------------
local lockedCFrame = nil -- set by the background resolver thread
local cameraKeepConn = RunService.RenderStepped:Connect(function()
	local cam = workspace.CurrentCamera
	if cam and lockedCFrame then
		cam.CameraType = Enum.CameraType.Scriptable
		cam.CFrame = lockedCFrame
	end
end)

-- Immediately try to set camera to scriptable to prevent default camera behavior
do
	local cam = workspace.CurrentCamera
	if cam then
		cam.CameraType = Enum.CameraType.Scriptable
	end
end

-- Resolve the camera target in a separate thread (doesn't block UI creation)
task.spawn(function()
	print("[LoadingScreen] Camera resolver started")

	-- Wait for game to be loaded first so workspace objects exist
	if not game:IsLoaded() then
		print("[LoadingScreen] Waiting for game.Loaded...")
		game.Loaded:Wait()
	end
	print("[LoadingScreen] Game is loaded, finding Loadings folder...")

	-- Try to find Loadings folder - it may already exist or may need to replicate
	local loadingsFolder = workspace:FindFirstChild("Loadings")
	if not loadingsFolder then
		print("[LoadingScreen] Loadings not found yet, using WaitForChild...")
		loadingsFolder = workspace:WaitForChild("Loadings", 30)
	end
	if not loadingsFolder then
		warn("[LoadingScreen] Could not find Workspace.Loadings after 30s!")
		return
	end
	print("[LoadingScreen] Found Loadings:", loadingsFolder:GetFullName())

	local loadingFolder = loadingsFolder:FindFirstChild("Loading")
	if not loadingFolder then
		loadingFolder = loadingsFolder:WaitForChild("Loading", 30)
	end
	if not loadingFolder then
		warn("[LoadingScreen] Could not find Workspace.Loadings.Loading!")
		return
	end
	print("[LoadingScreen] Found Loading:", loadingFolder:GetFullName())

	-- Force-stream the area around the Loading folder so Cam/Hisoka parts load in
	-- (they won't appear with StreamingEnabled unless we request them)
	local streamTarget = loadingFolder:FindFirstChildWhichIsA("BasePart")
	if streamTarget then
		print("[LoadingScreen] Requesting stream around:", streamTarget.Position)
		player:RequestStreamAroundAsync(streamTarget.Position)
	else
		-- No parts yet - try to find any descendant BasePart or use the folder's origin
		local anyPart = loadingFolder:FindFirstChildWhichIsA("BasePart", true)
		if anyPart then
			print("[LoadingScreen] Requesting stream around descendant:", anyPart.Position)
			player:RequestStreamAroundAsync(anyPart.Position)
		else
			-- Folder exists but has no parts yet - wait for one, then stream
			print("[LoadingScreen] No parts in Loading yet, waiting for first child...")
			local firstChild = loadingFolder.ChildAdded:Wait()
			if firstChild:IsA("BasePart") then
				print("[LoadingScreen] Requesting stream around first child:", firstChild.Position)
				player:RequestStreamAroundAsync(firstChild.Position)
			elseif firstChild:IsA("Model") then
				local modelPart = firstChild:FindFirstChildWhichIsA("BasePart", true)
				if modelPart then
					print("[LoadingScreen] Requesting stream around model part:", modelPart.Position)
					player:RequestStreamAroundAsync(modelPart.Position)
				end
			end
		end
	end
	print("[LoadingScreen] Stream request complete")

	-- Debug: list all children currently in the Loading folder
	local children = loadingFolder:GetChildren()
	print("[LoadingScreen] Loading folder has", #children, "children:")
	for _, child in children do
		print("  -", child.Name, "(" .. child.ClassName .. ")")
	end

	local camPart = loadingFolder:FindFirstChild("Cam")
	if not camPart then
		print("[LoadingScreen] Cam not found yet, waiting...")
		camPart = loadingFolder:WaitForChild("Cam", 30)
	end
	if not camPart then
		warn("[LoadingScreen] Could not find Cam part after 30s!")
		return
	end
	print("[LoadingScreen] Found Cam:", camPart:GetFullName(), "Position:", camPart.Position)

	-- Stream around the Cam position to make sure Hisoka loads in too
	player:RequestStreamAroundAsync(camPart.Position)

	-- Find Hisoka model to look at
	local hisoka = loadingFolder:FindFirstChild("Hisoka")
	if not hisoka then
		print("[LoadingScreen] Hisoka not found yet, waiting...")
		hisoka = loadingFolder:WaitForChild("Hisoka", 30)
	end

	if hisoka then
		print("[LoadingScreen] Found Hisoka:", hisoka:GetFullName())
		-- Find the target point to look at (HRP > UpperTorso > Torso > PrimaryPart > model origin)
		local lookTarget
		if hisoka:IsA("Model") then
			lookTarget = hisoka:FindFirstChild("HumanoidRootPart")
				or hisoka:FindFirstChild("UpperTorso")
				or hisoka:FindFirstChild("Torso")
				or hisoka.PrimaryPart
			if lookTarget then
				lookTarget = lookTarget.Position
			else
				lookTarget = hisoka:GetBoundingBox().Position
			end
		else
			lookTarget = hisoka.Position
		end
		-- Use Cam part's position, look AT Hisoka's torso
		lockedCFrame = CFrame.new(camPart.Position, lookTarget)
		print("[LoadingScreen] Camera locked: Cam pos ->", camPart.Position, "Looking at ->", lookTarget)
	else
		-- Fallback: just use the Cam part's own CFrame
		warn("[LoadingScreen] Could not find Hisoka, using Cam CFrame directly")
		lockedCFrame = camPart.CFrame
	end
end)

--------------------------------------------------------------------------------
-- Palette / Fonts / Config
--------------------------------------------------------------------------------

local BLACK = Color3.fromRGB(0, 0, 0)
local WHITE = Color3.fromRGB(255, 255, 255)
local SILVER = Color3.fromRGB(200, 210, 230)
local ORANGE = Color3.fromRGB(255, 165, 0)
local DARK_ORANGE = Color3.fromRGB(180, 100, 0)
local EMBLEM_TINT = Color3.fromRGB(243, 255, 250)
local SUBTLE_GRAY = Color3.fromRGB(45, 45, 50)

local JURA_BOLD_ITALIC = Font.new("rbxasset://fonts/families/Jura.json", Enum.FontWeight.Bold, Enum.FontStyle.Italic)
local JURA_REGULAR = Font.new("rbxasset://fonts/families/Jura.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)
local JURA_BOLD = Font.new("rbxasset://fonts/families/Jura.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)

local FUN_FACTS = {
	"Some doors only open for those who have already walked through them.",
	"The island remembers what the sea forgets.",
	"A price was paid before you arrived. The balance remains unsettled.",
	"There are 627 known species on the Dark Continent. Only 5 have names.",
	"The last person to reach the World Tree's peak never came back down.",
	"Every Nen ability leaves a scar on the aura. Most users never notice.",
	"Meteor City has no records, but the city itself never forgets a face.",
	"The Phantom Troupe's coin always lands the same way. Nobody asks why.",
	"Three examiners have died during the Hunter Exam. Two of them were applicants first.",
	"Ging hid something inside Greed Island. Not even the creators know what.",
	"There is a 13th Zodiac seat. It has always been empty.",
	"Nanika does not grant wishes. It completes transactions.",
	"The Zoldyck front gate weighs 256 tons. It was designed to keep something in.",
	"If you can read this, your Nen nodes are already open.",
	"The condition was met before the ability was named.",
}

-- Timeline: INTRO (slowed down for smoother pacing)
local BARS_START           = 0
local BARS_DURATION        = 1.8
local FLASH_TIME           = 5.5
local FACT_LABEL_START     = 6.2
local FACT_START           = 6.6
local FACT_DURATION        = 0.9
local BAR_TEXT_START       = 1.0
local BAR_TEXT_STAGGER     = 0.06
local BAR_TEXT_FADE_DUR    = 0.2
local BAR_BOB_AMPLITUDE    = 1.5
local BAR_BOB_SPEED        = 1.8
local BAR_BOB_SPREAD       = 0.5
local BAR_SHIMMER_INTERVAL = 3.5
local BAR_SHIMMER_DELAY    = 0.035
local BAR_SHIMMER_HOLD     = 0.12
local FACT_DISPLAY_DURATION  = 5.0
local FACT_FADE_OUT_DURATION = 0.5
local FACT_FADE_IN_DURATION  = 0.6
local FACT_SHIMMER_SPEED    = 1.5
local TILE_MIN_SIZE = 0.05
local TILE_MAX_SIZE = 0.12
local TILE_SPEED    = 0.04
local BG_FADE_OUT_DURATION = 0.8
local EMBLEM_SPIN_SPEED = 25
local EMBLEM_DISSOLVE_START = 4.5
local EMBLEM_DISSOLVE_DURATION = 0.7

-- Timeline: OUTRO
-- Phase 1: Fade out all text/UI elements
local OUTRO_FADE_FACTS       = 0.0
local OUTRO_FADE_FACTS_DUR   = 0.4
-- Phase 2: Transition to white background
local OUTRO_WHITE_BG         = 0.3
local OUTRO_WHITE_BG_DUR     = 0.6
-- Phase 3: Show emblem centered on white
local OUTRO_EMBLEM_FADE      = 0.6
local OUTRO_EMBLEM_FADE_DUR  = 0.5
-- Phase 4: Emblem grows + fades out together, camera releases mid-fade
local OUTRO_EMBLEM_GROW      = 1.2
local OUTRO_EMBLEM_GROW_DUR  = 0.8
local OUTRO_FADEOUT           = 1.5
local OUTRO_FADEOUT_DUR       = 0.7
local OUTRO_HIDE             = 2.3

--------------------------------------------------------------------------------
-- Easing
--------------------------------------------------------------------------------

local function easeOutCubic(t) return 1 - (1 - t) ^ 3 end
local function easeInQuad(t) return t * t end
local function easeInOutCubic(t)
	if t < 0.5 then return 4 * t * t * t
	else return 1 - (-2 * t + 2) ^ 3 / 2 end
end

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local function buildDissolveSequence(dissolveT)
	local centerFade = math.clamp(dissolveT * 2, 0, 1)
	local edgeFade = math.clamp((dissolveT - 0.3) / 0.7, 0, 1)
	return NumberSequence.new({
		NumberSequenceKeypoint.new(0, edgeFade),
		NumberSequenceKeypoint.new(0.25, math.max(edgeFade, centerFade)),
		NumberSequenceKeypoint.new(0.501, 1),
		NumberSequenceKeypoint.new(0.75, math.max(edgeFade, centerFade)),
		NumberSequenceKeypoint.new(0.92, 0.0875 + edgeFade * 0.9125),
		NumberSequenceKeypoint.new(1, edgeFade),
	})
end

-- Simple spring implementation (no Fusion dependency)
local function createSpring(initial, speed, damping)
	local target = initial
	local position = initial
	local velocity = 0
	return {
		set = function(_, v) target = v end,
		get = function(_)
			return position
		end,
		update = function(_, dt)
			local displacement = target - position
			local springForce = displacement * speed * speed
			local dampingForce = velocity * 2 * damping * speed
			local acceleration = springForce - dampingForce
			velocity = velocity + acceleration * dt
			position = position + velocity * dt
			return position
		end,
	}
end

local function createCharLabels(parent, text, font, size, color, startX, startY, charWidth)
	local data = {}
	for i = 1, #text do
		local ch = text:sub(i, i)
		local xPos = startX + (i - 1) * charWidth
		local label = Instance.new("TextLabel")
		label.Name = "Char_" .. i
		label.Position = UDim2.fromOffset(xPos, startY)
		label.Size = UDim2.fromOffset(charWidth, size + 6)
		label.BackgroundTransparency = 1
		label.Text = ch
		label.TextColor3 = color
		label.TextTransparency = 1
		label.TextSize = size
		label.FontFace = font
		label.TextXAlignment = Enum.TextXAlignment.Center
		label.TextYAlignment = Enum.TextYAlignment.Center
		label.Parent = parent
		table.insert(data, { label = label, baseX = xPos, baseY = startY })
	end
	return data
end

--------------------------------------------------------------------------------
-- Build UI (raw Instances, no Fusion)
--------------------------------------------------------------------------------

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "LoadingScreen"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.DisplayOrder = 100
screenGui.IgnoreGuiInset = true
screenGui.Parent = playerGui

local mainFrame = Instance.new("Frame")
mainFrame.Name = "HxHIntro"
mainFrame.Size = UDim2.fromScale(1, 1)
mainFrame.BackgroundColor3 = BLACK
mainFrame.BackgroundTransparency = 0
mainFrame.BorderSizePixel = 0
mainFrame.ClipsDescendants = true
mainFrame.Parent = screenGui

-- Tiled background
local tiledBg = Instance.new("ImageLabel")
tiledBg.Name = "TiledBackground"
tiledBg.Size = UDim2.fromScale(1, 1)
tiledBg.BackgroundTransparency = 1
tiledBg.BorderSizePixel = 0
tiledBg.Image = "rbxassetid://93299157578715"
tiledBg.ScaleType = Enum.ScaleType.Tile
tiledBg.TileSize = UDim2.fromScale(TILE_MIN_SIZE, TILE_MIN_SIZE)
tiledBg.ImageTransparency = 0
tiledBg.ZIndex = 1
tiledBg.Parent = mainFrame

local bgGradient = Instance.new("UIGradient")
bgGradient.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, ORANGE), ColorSequenceKeypoint.new(1, WHITE) })
bgGradient.Parent = tiledBg

-- Center emblem
local emblem = Instance.new("ImageLabel")
emblem.Name = "CenterEmblem"
emblem.AnchorPoint = Vector2.new(0.5, 0.5)
emblem.Position = UDim2.fromScale(0.5, 0.5)
emblem.Size = UDim2.fromOffset(372, 256)
emblem.BackgroundTransparency = 1
emblem.BorderSizePixel = 0
emblem.Image = "rbxassetid://73782201305317"
emblem.ImageTransparency = 0
emblem.ZIndex = 2
emblem.Parent = mainFrame

local emblemGradient = Instance.new("UIGradient")
emblemGradient.Name = "EmblemGradient"
emblemGradient.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, EMBLEM_TINT), ColorSequenceKeypoint.new(1, EMBLEM_TINT) })
emblemGradient.Rotation = -180
emblemGradient.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0),
	NumberSequenceKeypoint.new(0.501, 1),
	NumberSequenceKeypoint.new(0.92, 0.0875),
	NumberSequenceKeypoint.new(1, 0),
})
emblemGradient.Parent = emblem

-- Screen flash
local screenFlash = Instance.new("Frame")
screenFlash.Name = "ScreenFlash"
screenFlash.Size = UDim2.fromScale(1, 1)
screenFlash.BackgroundColor3 = WHITE
screenFlash.BackgroundTransparency = 1
screenFlash.BorderSizePixel = 0
screenFlash.ZIndex = 50
screenFlash.Parent = mainFrame

-- Top bar
local topBar = Instance.new("Frame")
topBar.Name = "TopBar"
topBar.AnchorPoint = Vector2.new(0.5, 0)
topBar.Position = UDim2.new(0.5, 0, 0, -90)
topBar.Size = UDim2.new(1, 0, 0, 90)
topBar.BackgroundColor3 = BLACK
topBar.BackgroundTransparency = 0
topBar.BorderSizePixel = 0
topBar.ZIndex = 10
topBar.ClipsDescendants = true
topBar.Parent = mainFrame

local topAccent = Instance.new("Frame")
topAccent.Name = "Accent"
topAccent.AnchorPoint = Vector2.new(0, 1)
topAccent.Position = UDim2.fromScale(0, 1)
topAccent.Size = UDim2.new(1, 0, 0, 1)
topAccent.BackgroundColor3 = ORANGE
topAccent.BackgroundTransparency = 0.6
topAccent.BorderSizePixel = 0
topAccent.Parent = topBar

local topTextContainer = Instance.new("Frame")
topTextContainer.Name = "LoadingTextContainer"
topTextContainer.AnchorPoint = Vector2.new(0, 0.5)
topTextContainer.Position = UDim2.new(0, 20, 0.5, 0)
topTextContainer.Size = UDim2.fromOffset(200, 30)
topTextContainer.BackgroundTransparency = 1
topTextContainer.ZIndex = 12
topTextContainer.Parent = topBar

-- ETA label on the right side of the top bar
local etaLabel = Instance.new("TextLabel")
etaLabel.Name = "ETALabel"
etaLabel.AnchorPoint = Vector2.new(1, 0.5)
etaLabel.Position = UDim2.new(1, -20, 0.5, 0)
etaLabel.Size = UDim2.fromOffset(120, 20)
etaLabel.BackgroundTransparency = 1
etaLabel.Text = ""
etaLabel.TextColor3 = ORANGE
etaLabel.TextTransparency = 1
etaLabel.TextSize = 12
etaLabel.FontFace = JURA_REGULAR
etaLabel.TextXAlignment = Enum.TextXAlignment.Right
etaLabel.ZIndex = 12
etaLabel.Parent = topBar

-- Bottom bar
local bottomBar = Instance.new("Frame")
bottomBar.Name = "BottomBar"
bottomBar.AnchorPoint = Vector2.new(0.5, 1)
bottomBar.Position = UDim2.new(0.5, 0, 1, 90)
bottomBar.Size = UDim2.new(1, 0, 0, 90)
bottomBar.BackgroundColor3 = BLACK
bottomBar.BackgroundTransparency = 0
bottomBar.BorderSizePixel = 0
bottomBar.ZIndex = 10
bottomBar.ClipsDescendants = true
bottomBar.Parent = mainFrame

local bottomAccent = Instance.new("Frame")
bottomAccent.Name = "Accent"
bottomAccent.Position = UDim2.fromScale(0, 0)
bottomAccent.Size = UDim2.new(1, 0, 0, 1)
bottomAccent.BackgroundColor3 = ORANGE
bottomAccent.BackgroundTransparency = 0.6
bottomAccent.BorderSizePixel = 0
bottomAccent.Parent = bottomBar

local bottomTextContainer = Instance.new("Frame")
bottomTextContainer.Name = "DestTextContainer"
bottomTextContainer.AnchorPoint = Vector2.new(0, 0.5)
bottomTextContainer.Position = UDim2.new(0, 20, 0.5, 0)
bottomTextContainer.Size = UDim2.fromOffset(350, 30)
bottomTextContainer.BackgroundTransparency = 1
bottomTextContainer.ZIndex = 12
bottomTextContainer.Parent = bottomBar

-- Fact area
local factArea = Instance.new("Frame")
factArea.Name = "FactArea"
factArea.AnchorPoint = Vector2.new(0.5, 1)
factArea.Position = UDim2.new(0.5, 0, 1, -100)
factArea.Size = UDim2.new(0.75, 0, 0, 65)
factArea.BackgroundTransparency = 1
factArea.ZIndex = 5
factArea.Parent = mainFrame

local dykLabel = Instance.new("TextLabel")
dykLabel.Name = "DidYouKnowLabel"
dykLabel.AnchorPoint = Vector2.new(0.5, 0)
dykLabel.Position = UDim2.new(0.5, 0, 0, 0)
dykLabel.Size = UDim2.new(0.5, 0, 0, 18)
dykLabel.BackgroundTransparency = 1
dykLabel.Text = "Did you know?"
dykLabel.TextColor3 = DARK_ORANGE
dykLabel.TextTransparency = 1
dykLabel.TextSize = 14
dykLabel.FontFace = JURA_REGULAR
dykLabel.TextXAlignment = Enum.TextXAlignment.Center
dykLabel.Parent = factArea

local separator = Instance.new("Frame")
separator.Name = "Separator"
separator.AnchorPoint = Vector2.new(0.5, 0)
separator.Position = UDim2.new(0.5, 0, 0, 20)
separator.Size = UDim2.new(0.15, 0, 0, 1)
separator.BackgroundColor3 = DARK_ORANGE
separator.BackgroundTransparency = 0.5
separator.BorderSizePixel = 0
separator.Parent = factArea

local currentFactIdx = math.random(1, #FUN_FACTS)

local factLabel = Instance.new("TextLabel")
factLabel.Name = "FactText"
factLabel.AnchorPoint = Vector2.new(0.5, 0)
factLabel.Position = UDim2.new(0.5, 0, 0, 26)
factLabel.Size = UDim2.new(1, 0, 0, 40)
factLabel.BackgroundTransparency = 1
factLabel.Text = FUN_FACTS[currentFactIdx]
factLabel.TextColor3 = WHITE
factLabel.TextTransparency = 1
factLabel.TextSize = 18
factLabel.FontFace = JURA_BOLD_ITALIC
factLabel.TextXAlignment = Enum.TextXAlignment.Center
factLabel.TextWrapped = true
factLabel.Parent = factArea

local factShimmerGradient = Instance.new("UIGradient")
factShimmerGradient.Name = "FactShimmer"
factShimmerGradient.Color = ColorSequence.new(WHITE)
factShimmerGradient.Parent = factLabel

-- Skip button (hidden initially)
local skipButton = Instance.new("TextButton")
skipButton.Name = "SkipButton"
skipButton.AnchorPoint = Vector2.new(1, 1)
skipButton.Position = UDim2.new(1, -20, 1, -105)
skipButton.Size = UDim2.fromOffset(70, 26)
skipButton.BackgroundColor3 = Color3.fromRGB(20, 20, 22)
skipButton.BackgroundTransparency = 1
skipButton.BorderSizePixel = 0
skipButton.Text = "SKIP \226\150\184"
skipButton.TextColor3 = ORANGE
skipButton.TextTransparency = 1
skipButton.TextSize = 11
skipButton.FontFace = JURA_BOLD
skipButton.ZIndex = 20
skipButton.Visible = false
skipButton.Parent = mainFrame

local skipCorner = Instance.new("UICorner")
skipCorner.CornerRadius = UDim.new(0, 4)
skipCorner.Parent = skipButton

local skipStroke = Instance.new("UIStroke")
skipStroke.Color = SUBTLE_GRAY
skipStroke.Thickness = 1
skipStroke.Transparency = 1
skipStroke.Parent = skipButton

print("[LoadingScreen] UI elements created")

-- Prevent ScreenGui from being disabled or destroyed during loading
local enabledConn
enabledConn = screenGui:GetPropertyChangedSignal("Enabled"):Connect(function()
	if not screenGui.Enabled and _G.LoadingScreenActive then
		screenGui.Enabled = true
	end
end)

-- If something destroys/reparents our ScreenGui, re-parent it back
local parentConn
parentConn = screenGui.AncestryChanged:Connect(function(_, newParent)
	if _G.LoadingScreenActive and newParent ~= playerGui then
		screenGui.Parent = playerGui
	end
end)

--------------------------------------------------------------------------------
-- Animation State
--------------------------------------------------------------------------------

local animTime = 0
local barProgressSpring = createSpring(0, 8, 1)
local barHeightSpring = createSpring(1, 10, 0.85)
local barColorSpring = createSpring(0, 12, 0.9)
local barTransSpring = createSpring(0, 14, 0.9)
local flashSpring = createSpring(0, 30, 1)
local emblemScaleSpring = createSpring(1, 12, 0.6)

local mainBgFading = false
local mainBgFadeStart = 0
local MAIN_BG_FADE_DURATION = 0.5

local bgTileT = 0
local bgTileDir = 1
local bgFadingOut = false
local bgFadeStart = 0
local bgGone = false

local emblemGone = false
local emblemAngle = 0

local flashFired = false
local factFadeDone = false
local dykFadeDone = false

local factCyclePhase = "visible"
local factCycleTimer = 0
local factCycleReady = false

local factShimmerLast = 0
local factShimmerActive = false

local topBarCharData = {}
local bottomBarCharData = {}
local barTextCreated = false
local topBarFadesDone = false
local bottomBarFadesDone = false

local topShimmerLast = 0
local topShimmerActive = false
local bottomShimmerLast = 0
local bottomShimmerActive = false

local skipVisible = false
local loadingComplete = false

-- Preload progress tracking for ETA
local preloadTotal = 0
local preloadDoneCount = 0
local preloadStartTime = 0
local preloadActive = false
local etaVisible = false

local outroActive = false
local outroTime = 0
local outroDone = false
local outroFactsFaded = false
local outroBarsClosed = false
local outroEmblemShown = false
local outroEmblemGrown = false
local outroFadedOut = false
local outroFlashed = false

--------------------------------------------------------------------------------
-- Outro trigger
--------------------------------------------------------------------------------

local cameraReleased = false

local function releaseCamera()
	if cameraReleased then return end
	cameraReleased = true
	if cameraKeepConn then
		cameraKeepConn:Disconnect()
		cameraKeepConn = nil
	end
	lockedCFrame = nil
	local cam = workspace.CurrentCamera
	if cam then
		-- Reassign CameraSubject to the current character's Humanoid
		-- (the original subject may reference a destroyed character from respawn)
		local currentChar = player.Character
		if currentChar then
			local humanoid = currentChar:FindFirstChildOfClass("Humanoid")
			if humanoid then
				cam.CameraSubject = humanoid
			end
		end
		cam.CameraType = Enum.CameraType.Custom
	end
end

local function triggerOutro()
	if outroActive then return end
	outroActive = true
	outroTime = 0
	factCycleReady = false
end

skipButton.Activated:Connect(function()
	if skipVisible then
		triggerOutro()
	end
end)

--------------------------------------------------------------------------------
-- Preload assets (runs in background) - waits for EVERYTHING
--------------------------------------------------------------------------------

task.delay(2, function()
	print("[LoadingScreen] Preload thread started")

	-- 1) Wait for game to be loaded
	if not game:IsLoaded() then
		print("[LoadingScreen] Preload: waiting for game.Loaded...")
		game.Loaded:Wait()
	end
	print("[LoadingScreen] Preload: game loaded, waiting for character...")

	-- 2) Wait for character to fully exist
	local character = player.Character or player.CharacterAdded:Wait()
	character:WaitForChild("HumanoidRootPart", 30)
	character:WaitForChild("Humanoid", 30)
	print("[LoadingScreen] Preload: character ready")

	-- 3) Wait for character appearance (with timeout)
	if not player:HasAppearanceLoaded() then
		print("[LoadingScreen] Preload: waiting for appearance...")
		local appearanceLoaded = false
		local conn
		conn = player.CharacterAppearanceLoaded:Connect(function()
			appearanceLoaded = true
			if conn then conn:Disconnect() end
		end)
		-- Timeout after 10 seconds
		local waited = 0
		while not appearanceLoaded and waited < 10 do
			task.wait(0.5)
			waited += 0.5
		end
		if conn then conn:Disconnect() end
		if not appearanceLoaded then
			warn("[LoadingScreen] Preload: appearance load timed out, continuing anyway")
		end
	end
	print("[LoadingScreen] Preload: appearance done, collecting assets...")

	-- 4) Collect assets to preload (prioritize important ones)
	local assetsToPreload = {}

	-- ReplicatedStorage.Assets (UI, animations, VFX, SFX)
	local uiAssets = ReplicatedStorage:FindFirstChild("Assets")
	if uiAssets then
		for _, asset in uiAssets:GetDescendants() do
			if asset:IsA("ImageLabel") or asset:IsA("ImageButton") or asset:IsA("Decal")
				or asset:IsA("Animation") or asset:IsA("Sound")
				or asset:IsA("ParticleEmitter") or asset:IsA("Beam") or asset:IsA("Trail")
				or asset:IsA("Texture") or asset:IsA("MeshPart") or asset:IsA("SpecialMesh") then
				table.insert(assetsToPreload, asset)
			end
		end
	end
	print("[LoadingScreen] Preload: collected", #assetsToPreload, "from Assets")

	-- NPC model cache templates
	local npcCache = ReplicatedStorage:FindFirstChild("NPC_MODEL_CACHE")
	if npcCache then
		for _, npc in npcCache:GetDescendants() do
			if npc:IsA("MeshPart") or npc:IsA("SpecialMesh") or npc:IsA("Decal")
				or npc:IsA("Animation") or npc:IsA("Sound") then
				table.insert(assetsToPreload, npc)
			end
		end
	end
	print("[LoadingScreen] Preload: collected", #assetsToPreload, "total after NPC cache")

	-- Character model itself
	for _, part in character:GetDescendants() do
		if part:IsA("MeshPart") or part:IsA("SpecialMesh") or part:IsA("Decal")
			or part:IsA("ShirtGraphic") or part:IsA("Shirt") or part:IsA("Pants") then
			table.insert(assetsToPreload, part)
		end
	end
	print("[LoadingScreen] Preload: collected", #assetsToPreload, "total after character")

	-- 5) Preload with progress tracking and timeout
	preloadTotal = #assetsToPreload
	preloadDoneCount = 0
	preloadStartTime = tick()
	preloadActive = true
	print("[LoadingScreen] Preloading", preloadTotal, "assets...")

	local preloadDone = false
	if preloadTotal > 0 then
		task.spawn(function()
			pcall(function()
				ContentProvider:PreloadAsync(assetsToPreload, function(_contentId, _status)
					preloadDoneCount += 1
				end)
			end)
			preloadDone = true
		end)
		-- Wait up to 15 seconds for preload, then continue regardless
		local waited = 0
		while not preloadDone and waited < 15 do
			task.wait(0.5)
			waited += 0.5
		end
		if not preloadDone then
			warn("[LoadingScreen] Preload timed out after 15s, continuing anyway")
		end
	end
	preloadActive = false

	print("[LoadingScreen] Preloading complete!")
	loadingComplete = true
end)

--------------------------------------------------------------------------------
-- Wait 1 second before starting the animation (user-requested delay)
--------------------------------------------------------------------------------
task.wait(3)
print("[LoadingScreen] Starting animation loop")

--------------------------------------------------------------------------------
-- Animation Loop
--------------------------------------------------------------------------------

local connection = RunService.Heartbeat:Connect(function(dt)
	animTime = animTime + dt

	-- Update springs
	local barP = barProgressSpring:update(dt)
	local barH = barHeightSpring:update(dt)
	local barC = barColorSpring:update(dt)
	local barT = barTransSpring:update(dt)
	local flashV = flashSpring:update(dt)
	local emblemS = emblemScaleSpring:update(dt)

	-- Apply bar spring values (skip during outro - outro controls bar transparency directly)
	if not outroActive then
		local barHeight = math.round(90 * barH)
		local barColor = BLACK:Lerp(WHITE, math.clamp(barC, 0, 1))
		local accentTrans = math.max(0.6 + 0.4 * math.clamp(barC, 0, 1), barT)

		topBar.Position = UDim2.new(0.5, 0, 0, -90 + 90 * barP)
		topBar.Size = UDim2.new(1, 0, 0, barHeight)
		topBar.BackgroundColor3 = barColor
		topBar.BackgroundTransparency = barT
		topAccent.BackgroundTransparency = accentTrans

		bottomBar.Position = UDim2.new(0.5, 0, 1, -90 * barP + 90)
		bottomBar.Size = UDim2.new(1, 0, 0, barHeight)
		bottomBar.BackgroundColor3 = barColor
		bottomBar.BackgroundTransparency = barT
		bottomAccent.BackgroundTransparency = accentTrans
	end

	-- Flash
	screenFlash.BackgroundTransparency = 1 - flashV

	-- Emblem size
	emblem.Size = UDim2.fromOffset(math.round(372 * emblemS), math.round(256 * emblemS))

	-- Emblem gradient rotation
	local spinSpeed = outroActive and (EMBLEM_SPIN_SPEED * 2) or EMBLEM_SPIN_SPEED
	emblemAngle = emblemAngle + dt * spinSpeed
	emblemGradient.Rotation = emblemAngle % 360

	--------------------------------------------------------------------
	-- OUTRO MODE
	-- Clean sequence: fade text -> white bg + emblem -> emblem grows -> flash -> done
	--------------------------------------------------------------------
	if outroActive then
		outroTime = outroTime + dt

		-- 1) Fade out all text/UI elements (facts, bar text, ETA, skip button)
		if not outroFactsFaded then
			local t = math.clamp((outroTime - OUTRO_FADE_FACTS) / OUTRO_FADE_FACTS_DUR, 0, 1)
			local eased = easeInQuad(t)
			factLabel.TextTransparency = eased
			dykLabel.TextTransparency = eased
			separator.BackgroundTransparency = 0.5 + 0.5 * eased
			for _, data in topBarCharData do data.label.TextTransparency = eased end
			for _, data in bottomBarCharData do data.label.TextTransparency = eased end
			etaLabel.TextTransparency = eased
			skipButton.TextTransparency = eased
			skipButton.BackgroundTransparency = 0.1 + 0.9 * eased
			if t >= 1 then outroFactsFaded = true end
		end

		-- 2) Transition everything to a clean white background
		if outroTime >= OUTRO_WHITE_BG and not outroBarsClosed then
			local t = math.clamp((outroTime - OUTRO_WHITE_BG) / OUTRO_WHITE_BG_DUR, 0, 1)
			local eased = easeInOutCubic(t)
			-- Make the main frame background go white and fully opaque
			mainFrame.BackgroundColor3 = BLACK:Lerp(WHITE, eased)
			mainFrame.BackgroundTransparency = 0
			-- Hide the bars by making them transparent
			topBar.BackgroundTransparency = eased
			bottomBar.BackgroundTransparency = eased
			topAccent.BackgroundTransparency = 0.6 + 0.4 * eased
			bottomAccent.BackgroundTransparency = 0.6 + 0.4 * eased
			if t >= 1 then outroBarsClosed = true end
		end

		-- 3) Show emblem centered on the white background
		if outroTime >= OUTRO_EMBLEM_FADE and not outroEmblemShown then
			local t = math.clamp((outroTime - OUTRO_EMBLEM_FADE) / OUTRO_EMBLEM_FADE_DUR, 0, 1)
			local eased = easeOutCubic(t)
			emblem.Visible = true
			emblem.ZIndex = 40
			emblem.ImageTransparency = 1 - eased
			-- Use a solid gradient (no dissolve pattern) for clean look
			emblemGradient.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(0.501, 1),
				NumberSequenceKeypoint.new(0.92, 0.0875),
				NumberSequenceKeypoint.new(1, 0),
			})
			if t >= 1 then outroEmblemShown = true end
		end

		-- 4) Emblem enlarges
		if outroTime >= OUTRO_EMBLEM_GROW and not outroEmblemGrown then
			local t = math.clamp((outroTime - OUTRO_EMBLEM_GROW) / OUTRO_EMBLEM_GROW_DUR, 0, 1)
			emblemScaleSpring:set(1 + easeInQuad(t) * 2.5)
			if t >= 1 then outroEmblemGrown = true end
		end

		-- 5) Fade out the entire screen smoothly (emblem + white bg fade together)
		if outroTime >= OUTRO_FADEOUT and not outroFadedOut then
			local t = math.clamp((outroTime - OUTRO_FADEOUT) / OUTRO_FADEOUT_DUR, 0, 1)
			local eased = easeInQuad(t)
			mainFrame.BackgroundTransparency = eased
			emblem.ImageTransparency = eased
			-- Release camera mid-fade so the transition is hidden behind the fading white
			if t >= 0.3 and not outroFlashed then
				outroFlashed = true
				releaseCamera()
			end
			if t >= 1 then outroFadedOut = true end
		end

		if outroTime >= OUTRO_HIDE and not outroDone then
			outroDone = true
			mainFrame.Visible = false
		end

		return -- skip intro logic
	end

	--------------------------------------------------------------------
	-- INTRO MODE
	--------------------------------------------------------------------

	-- Bars slide in
	if animTime >= BARS_START then
		barProgressSpring:set(math.clamp((animTime - BARS_START) / BARS_DURATION, 0, 1))
	end

	-- Bar text creation
	if not barTextCreated and animTime >= 0.2 then
		topBarCharData = createCharLabels(topTextContainer, "Loading", JURA_REGULAR, 14, ORANGE, 0, 0, 10)
		bottomBarCharData = createCharLabels(bottomTextContainer, "Destination: Testplace", JURA_REGULAR, 14, ORANGE, 0, 0, 10)
		barTextCreated = true
	end

	-- Top bar text fade in
	if barTextCreated and not topBarFadesDone then
		local allDone = true
		for i, data in topBarCharData do
			local ls = BAR_TEXT_START + (i - 1) * BAR_TEXT_STAGGER
			local p = math.clamp((animTime - ls) / BAR_TEXT_FADE_DUR, 0, 1)
			data.label.TextTransparency = 1 - easeOutCubic(p)
			if p < 1 then allDone = false end
		end
		if allDone and #topBarCharData > 0 then topBarFadesDone = true end
	end

	-- Bottom bar text fade in
	if barTextCreated and not bottomBarFadesDone then
		local allDone = true
		for i, data in bottomBarCharData do
			local ls = BAR_TEXT_START + (i - 1) * BAR_TEXT_STAGGER
			local p = math.clamp((animTime - ls) / BAR_TEXT_FADE_DUR, 0, 1)
			data.label.TextTransparency = 1 - easeOutCubic(p)
			if p < 1 then allDone = false end
		end
		if allDone and #bottomBarCharData > 0 then bottomBarFadesDone = true end
	end

	-- Bob
	if barTextCreated then
		for i, data in topBarCharData do
			local bobY = math.sin(animTime * BAR_BOB_SPEED * math.pi * 2 + (i - 1) * BAR_BOB_SPREAD) * BAR_BOB_AMPLITUDE
			data.label.Position = UDim2.fromOffset(data.baseX, data.baseY + bobY)
		end
		for i, data in bottomBarCharData do
			local bobY = math.sin(animTime * BAR_BOB_SPEED * math.pi * 2 + (i - 1) * BAR_BOB_SPREAD) * BAR_BOB_AMPLITUDE
			data.label.Position = UDim2.fromOffset(data.baseX, data.baseY + bobY)
		end
	end

	-- Top shimmer
	if topBarFadesDone then
		if not topShimmerActive and (animTime - topShimmerLast) >= BAR_SHIMMER_INTERVAL then
			topShimmerLast = animTime; topShimmerActive = true
		end
		if topShimmerActive then
			local elapsed = animTime - topShimmerLast
			local totalDur = #topBarCharData * BAR_SHIMMER_DELAY + BAR_SHIMMER_HOLD
			if elapsed > totalDur then
				topShimmerActive = false
				for _, data in topBarCharData do data.label.TextColor3 = ORANGE end
			else
				for i, data in topBarCharData do
					local cs = (i - 1) * BAR_SHIMMER_DELAY
					local ce = elapsed - cs
					if ce < 0 then data.label.TextColor3 = ORANGE
					elseif ce < BAR_SHIMMER_HOLD then
						data.label.TextColor3 = ORANGE:Lerp(SILVER, math.sin((ce / BAR_SHIMMER_HOLD) * math.pi))
					else data.label.TextColor3 = ORANGE end
				end
			end
		end
	end

	-- Bottom shimmer
	if bottomBarFadesDone then
		if not bottomShimmerActive and (animTime - bottomShimmerLast) >= BAR_SHIMMER_INTERVAL then
			bottomShimmerLast = animTime; bottomShimmerActive = true
		end
		if bottomShimmerActive then
			local elapsed = animTime - bottomShimmerLast
			local totalDur = #bottomBarCharData * BAR_SHIMMER_DELAY + BAR_SHIMMER_HOLD
			if elapsed > totalDur then
				bottomShimmerActive = false
				for _, data in bottomBarCharData do data.label.TextColor3 = ORANGE end
			else
				for i, data in bottomBarCharData do
					local cs = (i - 1) * BAR_SHIMMER_DELAY
					local ce = elapsed - cs
					if ce < 0 then data.label.TextColor3 = ORANGE
					elseif ce < BAR_SHIMMER_HOLD then
						data.label.TextColor3 = ORANGE:Lerp(SILVER, math.sin((ce / BAR_SHIMMER_HOLD) * math.pi))
					else data.label.TextColor3 = ORANGE end
				end
			end
		end
	end

	-- ETA label update
	if preloadActive and preloadTotal > 0 and topBarFadesDone then
		-- Fade in the ETA label
		if not etaVisible then
			etaVisible = true
		end
		etaLabel.TextTransparency = etaLabel.TextTransparency + (0 - etaLabel.TextTransparency) * math.min(1, dt * 6)

		local progress = preloadDoneCount / preloadTotal
		local elapsed = tick() - preloadStartTime
		if preloadDoneCount > 5 and elapsed > 0.5 then
			local rate = preloadDoneCount / elapsed
			local remaining = (preloadTotal - preloadDoneCount) / rate
			-- Smooth the display: show seconds, minimum "< 1s"
			if remaining < 1 then
				etaLabel.Text = string.format("%d%% \194\183 < 1s", math.floor(progress * 100))
			else
				etaLabel.Text = string.format("%d%% \194\183 ~%ds", math.floor(progress * 100), math.ceil(remaining))
			end
		else
			etaLabel.Text = string.format("%d%%", math.floor(progress * 100))
		end
	elseif loadingComplete and etaVisible then
		etaLabel.Text = "100%"
		-- Fade out after loading completes
		etaLabel.TextTransparency = etaLabel.TextTransparency + (1 - etaLabel.TextTransparency) * math.min(1, dt * 4)
	end

	-- Tiled background
	if not bgGone then
		bgTileT = bgTileT + (dt * TILE_SPEED * bgTileDir)
		if bgTileT >= 1 then bgTileT = 1; bgTileDir = -1
		elseif bgTileT <= 0 then bgTileT = 0; bgTileDir = 1 end
		tiledBg.TileSize = UDim2.fromScale(
			TILE_MIN_SIZE + (TILE_MAX_SIZE - TILE_MIN_SIZE) * bgTileT,
			TILE_MIN_SIZE + (TILE_MAX_SIZE - TILE_MIN_SIZE) * bgTileT
		)

		if bgFadingOut then
			local fadeT = math.clamp((animTime - bgFadeStart) / BG_FADE_OUT_DURATION, 0, 1)
			tiledBg.ImageTransparency = 1 - (1 - fadeT) * (1 - fadeT)
			if fadeT >= 1 then
				tiledBg.Visible = false
				bgGone = true

				-- Show skip button now
				if not skipVisible then
					skipVisible = true
					skipButton.Visible = true
					TweenService:Create(skipButton, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
						TextTransparency = 0, BackgroundTransparency = 0.1,
					}):Play()
					TweenService:Create(skipStroke, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
						Transparency = 0.5,
					}):Play()
				end
			end
		end
	end

	-- Main bg fade to transparent
	if mainBgFading then
		local fadeT = math.clamp((animTime - mainBgFadeStart) / MAIN_BG_FADE_DURATION, 0, 1)
		mainFrame.BackgroundTransparency = 1 - (1 - fadeT) * (1 - fadeT)
		if fadeT >= 1 then mainBgFading = false end
	end

	-- Emblem dissolve
	if not emblemGone then
		if animTime >= EMBLEM_DISSOLVE_START then
			local dissolveT = math.clamp((animTime - EMBLEM_DISSOLVE_START) / EMBLEM_DISSOLVE_DURATION, 0, 1)
			emblemGradient.Transparency = buildDissolveSequence(easeInQuad(dissolveT))
			if dissolveT > 0.7 then emblem.ImageTransparency = (dissolveT - 0.7) / 0.3 end
			if dissolveT >= 1 then emblem.Visible = false; emblemGone = true end
		end
	end

	-- Screen flash + trigger fades
	if animTime >= FLASH_TIME and not flashFired then
		flashFired = true
		flashSpring:set(0.6)
		task.delay(0.05, function() flashSpring:set(0) end)
		bgFadingOut = true
		bgFadeStart = animTime
		mainBgFading = true
		mainBgFadeStart = animTime
	end

	-- DYK fade in
	if animTime >= FACT_LABEL_START and not dykFadeDone then
		local t = math.clamp((animTime - FACT_LABEL_START) / 0.4, 0, 1)
		dykLabel.TextTransparency = 1 - t
		if t >= 1 then dykFadeDone = true end
	end

	-- Fact fade in
	if animTime >= FACT_START and not factFadeDone then
		local t = math.clamp((animTime - FACT_START) / FACT_DURATION, 0, 1)
		factLabel.TextTransparency = 1 - t
		if t >= 1 then
			factFadeDone = true; factCycleReady = true
			factCycleTimer = 0; factCyclePhase = "visible"
		end
	end

	-- Fact cycling
	if factCycleReady then
		factCycleTimer = factCycleTimer + dt
		if factCyclePhase == "visible" then
			if factCycleTimer >= FACT_DISPLAY_DURATION then
				factCyclePhase = "fading_out"; factCycleTimer = 0
			end
		elseif factCyclePhase == "fading_out" then
			local t = math.clamp(factCycleTimer / FACT_FADE_OUT_DURATION, 0, 1)
			factLabel.TextTransparency = t
			if t >= 1 then
				currentFactIdx = currentFactIdx % #FUN_FACTS + 1
				factLabel.Text = FUN_FACTS[currentFactIdx]
				factCyclePhase = "fading_in"; factCycleTimer = 0
				factShimmerActive = false; factShimmerLast = 0
			end
		elseif factCyclePhase == "fading_in" then
			local t = math.clamp(factCycleTimer / FACT_FADE_IN_DURATION, 0, 1)
			factLabel.TextTransparency = 1 - t
			if t >= 1 then factCyclePhase = "visible"; factCycleTimer = 0 end
		end
	end

	-- Fact shimmer
	if factCycleReady and factCyclePhase == "visible" then
		local shimmerDelay = 1.5
		if factCycleTimer >= shimmerDelay then
			if not factShimmerActive and (factCycleTimer - shimmerDelay) < dt * 2 then
				factShimmerLast = animTime; factShimmerActive = true
			end
		end
		if factShimmerActive then
			local elapsed = animTime - factShimmerLast
			local sweepT = elapsed * FACT_SHIMMER_SPEED
			if sweepT > 1.3 then
				factShimmerGradient.Color = ColorSequence.new(WHITE)
				factShimmerActive = false
			else
				local center = math.clamp(sweepT, 0, 1)
				local halfW = 0.12
				local left = math.max(0, center - halfW)
				local right = math.min(1, center + halfW)
				local kps = {}
				if left > 0.001 then
					table.insert(kps, ColorSequenceKeypoint.new(0, WHITE))
					table.insert(kps, ColorSequenceKeypoint.new(math.max(0.001, left - 0.001), WHITE))
				end
				table.insert(kps, ColorSequenceKeypoint.new(left, WHITE))
				table.insert(kps, ColorSequenceKeypoint.new(math.clamp(center, left + 0.001, right - 0.001), SILVER))
				table.insert(kps, ColorSequenceKeypoint.new(right, WHITE))
				if right < 0.999 then
					table.insert(kps, ColorSequenceKeypoint.new(math.min(0.999, right + 0.001), WHITE))
					table.insert(kps, ColorSequenceKeypoint.new(1, WHITE))
				end
				if kps[1].Time > 0 then table.insert(kps, 1, ColorSequenceKeypoint.new(0, WHITE)) end
				if kps[#kps].Time < 1 then table.insert(kps, ColorSequenceKeypoint.new(1, WHITE)) end
				factShimmerGradient.Color = ColorSequence.new(kps)
			end
		end
	end

	-- Auto-trigger outro when loading finishes AND intro bg has faded out
	-- (bgGone means the tiled background has fully faded, so the intro played enough)
	if loadingComplete and bgGone and not outroActive then
		triggerOutro()
	end
end)

--------------------------------------------------------------------------------
-- Wait for outro to complete, then cleanup
--------------------------------------------------------------------------------

while not outroDone do
	task.wait(0.1)
end

connection:Disconnect()
if enabledConn then enabledConn:Disconnect() end
if parentConn then parentConn:Disconnect() end
-- Camera lock already released in triggerOutro(), but clean up just in case
if cameraKeepConn then cameraKeepConn:Disconnect() end
local cam = workspace.CurrentCamera
if cam and cam.CameraType ~= Enum.CameraType.Custom then
	cam.CameraType = Enum.CameraType.Custom
end

-- Tween DepthOfField back to original values
if depthOfField and originalFarIntensity and originalInFocusRadius then
	TweenService:Create(depthOfField, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		FarIntensity = originalFarIntensity,
		InFocusRadius = originalInFocusRadius,
	}):Play()
end

screenGui.Enabled = false
_G.LoadingScreenActive = false

-- Re-enable some default Roblox UI (keep Backpack and PlayerList disabled)
pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, true) end)
pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, true) end)
pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.EmotesMenu, true) end)

-- Cleanup UI
screenGui:Destroy()
