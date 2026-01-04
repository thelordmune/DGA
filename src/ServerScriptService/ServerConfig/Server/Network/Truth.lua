local ServerStorage = game:GetService("ServerStorage")
local Replicated = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local Utilities = require(Replicated.Modules.Utilities)
local Library = require(Replicated.Modules.Library)
local Packets = require(Replicated.Modules.Packets)
local Visuals = require(Replicated.Modules.Visuals)
local bridges = require(Replicated.Modules.Bridges)
local SFX = Replicated.Assets.SFX
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")

local NetworkModule = {}
local Server = require(script.Parent.Parent)
NetworkModule.__index = NetworkModule
local self = setmetatable({}, NetworkModule)

-- Store original positions for return teleport
local originalPositions = {}

-- Get original position for a player (called after dialogue ends)
NetworkModule.GetOriginalPosition = function(Player)
	if Player and Player.UserId then
		return originalPositions[Player.UserId]
	end
	return nil
end

-- Clear original position after return teleport
NetworkModule.ClearOriginalPosition = function(Player)
	if Player and Player.UserId then
		originalPositions[Player.UserId] = nil
	end
end

-- Return player to original position (called after Truth dialogue ends)
NetworkModule.ReturnPlayer = function(Player)
	local Character = Player.Character
	if not Character then return false end

	local root = Character:FindFirstChild("HumanoidRootPart")
	if not root then return false end

	local originalCFrame = originalPositions[Player.UserId]
	if not originalCFrame then return false end

	-- Request streaming around destination before teleporting
	local success, err = pcall(function()
		Player:RequestStreamAroundAsync(originalCFrame.Position)
	end)
	if not success then
		warn("[Truth] Failed to stream around destination:", err)
	end

	-- Teleport back
	root.CFrame = originalCFrame
	originalPositions[Player.UserId] = nil

	return true
end

-- Listen for TruthReturn bridge (called after dialogue consequence effects)
bridges.TruthReturn:Connect(function(Player)
	NetworkModule.ReturnPlayer(Player)
end)

-- FMA Brotherhood Truth quotes - expanded for chaotic effect
local TRUTH_QUOTES = {
	"One is all, all is one.",
	"The truth lies within.",
	"You dare to open the gate?",
	"What will you sacrifice?",
	"Equivalent exchange.",
	"I am what you call the world.",
	"I am the universe.",
	"I am God.",
	"I am Truth.",
	"I am all.",
	"I am one.",
	"And I am also... you.",
	"This is what you wanted, isn't it?",
	"The portal of truth opens.",
	"What lies beyond is forbidden.",
	"You cannot gain without sacrifice.",
	"Alchemist... you have seen too much.",
	"There is no equivalent exchange for a human soul.",
	"The gate demands payment.",
	"You sought forbidden knowledge.",
	"Hubris.",
	"Arrogance.",
	"The law of conservation.",
	"Nothing is ever truly gained.",
	"Everything comes at a cost.",
	"You cannot create something from nothing.",
	"The world flows...",
	"...and so do you.",
	"Do you see it now?",
	"The truth is cruel.",
	"Reality bends.",
	"Time stops.",
	"Space folds.",
	"I have always been here.",
	"I will always be here.",
	"Waiting.",
	"Watching.",
	"Knowing.",
}

NetworkModule.EndPoint = function(Player, Data)
	local Character = Player.Character

	if not Character then
		return
	end

	-- Check if this is an NPC (no Player instance) or a real player
	local isNPC = typeof(Player) ~= "Instance" or not Player:IsA("Player")

	-- For players, check equipped status
	if not isNPC and not Character:GetAttribute("Equipped") then
		return
	end

	local PlayerObject = Server.Modules["Players"].Get(Player)
	local Animation = Replicated.Assets.Animations.Misc.Alchemy -- Using the Construct animation

	local root = Character:FindFirstChild("HumanoidRootPart")

	if Server.Library.StateCount(Character.Actions) or Server.Library.StateCount(Character.Stuns) then
		return
	end

	-- For NPCs, skip the PlayerObject.Keys check
	local canUseSkill = isNPC or (PlayerObject and PlayerObject.Keys)

	if canUseSkill and not Server.Library.CheckCooldown(Character, "Truth") then
		Server.Library.SetCooldown(Character, "Truth", 60) -- 60 second cooldown
		Server.Library.StopAllAnims(Character)

		local Alchemy = Library.PlayAnimation(Character, Animation)
		Alchemy.Looped = false

		repeat task.wait() until Alchemy.Length > 0

		local TRUTH_DURATION = 8 -- Total sequence duration

		Server.Library.TimedState(Character.Actions, "Truth", TRUTH_DURATION)
		Server.Library.TimedState(Character.Speeds, "AlcSpeed-0", TRUTH_DURATION)
		Server.Library.TimedState(Character.Speeds, "Jump-50", TRUTH_DURATION)
		Server.Library.TimedState(Character.Stuns, "NoRotate", TRUTH_DURATION)

		-- Get the Truth spawn location
		local truthSpawn = workspace:FindFirstChild("World")
		if truthSpawn then
			truthSpawn = truthSpawn:FindFirstChild("AreaSpawns")
			if truthSpawn then
				truthSpawn = truthSpawn:FindFirstChild("Truth")
			end
		end

		local kfConn
		kfConn = Alchemy.KeyframeReached:Connect(function(key)
			if key == "Clap" then
				-- Play Truth Clap sound (from Truth SFX folder)
				local truthClap = Replicated.Assets.SFX.Truth:FindFirstChild("Clap")
				if truthClap then
					local clapSound = truthClap:Clone()
					clapSound.Parent = Character.HumanoidRootPart
					clapSound:Play()
					Debris:AddItem(clapSound, clapSound.TimeLength)
				end

				-- Play Transporting sound at the same time as clap
				local transporting = Replicated.Assets.SFX.Truth:FindFirstChild("Transporting")
				if transporting then
					local transportSound = transporting:Clone()
					transportSound.Parent = Character.HumanoidRootPart
					transportSound:Play()
					Debris:AddItem(transportSound, transportSound.TimeLength)
				end

				-- Trigger clap VFX
				Server.Visuals.Ranged(Character.HumanoidRootPart.Position, 300, {
					Module = "Base",
					Function = "Clap",
					Arguments = { Character }
				})

				-- ═══════════════════════════════════════════════════════════════════════════
				-- VFX POSITIONING - Transmute circle effect
				-- Arguments: { Character, Distance, Height }
				-- Distance: 0 = directly on player, negative = behind, positive = in front
				-- Height: relative to HumanoidRootPart (which is ~3 studs above ground)
				--         So Height = -3 puts it at ground level, Height = 0 is at waist
				-- ═══════════════════════════════════════════════════════════════════════════
				local VFX_DISTANCE = 0    -- Directly under player (no forward/back offset)
				local VFX_HEIGHT = 2     -- Slightly below waist level (closer to ground)

				Server.Visuals.Ranged(Character.HumanoidRootPart.Position, 300, {
					Module = "Base",
					Function = "Transmute",
					Arguments = { Character, VFX_DISTANCE, VFX_HEIGHT }
				})

				-- ═══════════════════════════════════════════════════════════════════════════
				-- EYE POSITIONING - The Truth eye rising from ground
				-- startY: Where the eye starts (underground)
				-- targetY: Where the eye rises to (final position)
				-- Both are OFFSETS relative to player's Y position (root.Position.Y)
				-- ═══════════════════════════════════════════════════════════════════════════
				local EYE_START_OFFSET = 0   -- Start 2 studs below player position
				local EYE_TARGET_OFFSET = 3   -- Rise to 3 studs ABOVE player position

				task.spawn(function()
					local eyeModel = Replicated.Assets.Models:FindFirstChild("Eye")
					if eyeModel then
						local eye = eyeModel:Clone()
						--local eyeRoot = eye:FindFirstChild("HumanoidRootPart") or eye.PrimaryPart or eye:FindFirstChildWhichIsA("BasePart")

						if eye then
							-- Position under player, starting below ground
							local playerPos = root.Position
							local startY = playerPos.Y + EYE_START_OFFSET
							local targetY = playerPos.Y + EYE_TARGET_OFFSET

							-- Set initial position (underground)
								eye.CFrame = CFrame.new(playerPos.X, startY, playerPos.Z)

							-- Make all parts transparent initially and disable collision
							for _, part in eye:GetDescendants() do
								if part:IsA("BasePart") then
									part.CanCollide = false
									part.Anchored = true
									part:SetAttribute("OriginalTransparency", part.Transparency)
									part.Transparency = 1
								end
							end

							eye.Parent = workspace.World.Visuals

							-- Rise and fade in over 1.5 seconds
							local riseDuration = 1.5
							local riseSteps = 30

							for i = 1, riseSteps do
								task.wait(riseDuration / riseSteps)
								local progress = i / riseSteps
								local currentY = startY + (targetY - startY) * progress

								-- Move eye up
									eye.CFrame = CFrame.new(playerPos.X, currentY, playerPos.Z)

								-- Fade in parts
								for _, part in eye:GetDescendants() do
									if part:IsA("BasePart") then
										local origTransparency = part:GetAttribute("OriginalTransparency") or 0
										part.Transparency = 1 - (progress * (1 - origTransparency))
									end
								end
							end

							-- Keep eye visible during sequence, then fade out before teleport
							task.delay(TRUTH_DURATION - 3, function()
								if eye and eye.Parent then
									-- Fade out over 1 second
									local fadeSteps = 20
									for i = 1, fadeSteps do
										task.wait(1 / fadeSteps)
										local progress = i / fadeSteps
										for _, part in eye:GetDescendants() do
											if part:IsA("BasePart") then
												local origTransparency = part:GetAttribute("OriginalTransparency") or 0
												part.Transparency = origTransparency + (1 - origTransparency) * progress
											end
										end
									end
									eye:Destroy()
								end
							end)
						end
					end
				end)

				-- Store original position for return teleport
				originalPositions[Player.UserId] = root.CFrame

				-- Start the Truth sequence for the player (client-side effects)
				Server.Visuals.FireClient(Player, {
					Module = "Base",
					Function = "TruthSequence",
					Arguments = {
						Character,
						TRUTH_QUOTES,
						truthSpawn and truthSpawn.Position or nil,
						TRUTH_DURATION
					}
				})

				-- Add white highlight to player that fades in (instead of turning body parts neon)
				task.delay(0.5, function()
					if not Character then return end

					-- Create highlight that fades in
					local highlight = Instance.new("Highlight")
					highlight.Name = "TruthHighlight"
					highlight.FillColor = Color3.new(1, 1, 1)
					highlight.OutlineColor = Color3.new(1, 1, 1)
					highlight.FillTransparency = 1 -- Start invisible
					highlight.OutlineTransparency = 1
					highlight.DepthMode = Enum.HighlightDepthMode.Occluded
					highlight.Parent = Character

					-- Fade in the highlight over 1 second
					local fadeInSteps = 20
					for i = 1, fadeInSteps do
						task.wait(1 / fadeInSteps)
						local progress = i / fadeInSteps
						highlight.FillTransparency = 1 - (progress * 0.7) -- Max 0.3 transparency (70% visible)
						highlight.OutlineTransparency = 1 - (progress * 0.5)
					end

					-- Keep highlight until near end of sequence, then fade out
					task.delay(TRUTH_DURATION - 3, function()
						if highlight and highlight.Parent then
							-- Fade out over 1 second
							local fadeOutSteps = 20
							for i = 1, fadeOutSteps do
								task.wait(1 / fadeOutSteps)
								local progress = i / fadeOutSteps
								highlight.FillTransparency = 0.3 + (progress * 0.7)
								highlight.OutlineTransparency = 0.5 + (progress * 0.5)
							end
							highlight:Destroy()
						end
					end)
				end)

				-- Server-side: Turn ALL nearby parts neon white
				task.spawn(function()
					local position = root.Position
					local range = 200 -- Large range to catch everything

					-- Raycast down to find the floor part(s) the player is standing on
					local floorParts = {}
					local rayParams = RaycastParams.new()
					rayParams.FilterDescendantsInstances = {Character}
					rayParams.FilterType = Enum.RaycastFilterType.Exclude

					-- Cast multiple rays to find floor parts in the area under the player
					local rayOffsets = {
						Vector3.new(0, 0, 0),
						Vector3.new(3, 0, 0),
						Vector3.new(-3, 0, 0),
						Vector3.new(0, 0, 3),
						Vector3.new(0, 0, -3),
						Vector3.new(3, 0, 3),
						Vector3.new(-3, 0, -3),
						Vector3.new(3, 0, -3),
						Vector3.new(-3, 0, 3),
					}

					for _, offset in ipairs(rayOffsets) do
						local rayOrigin = position + offset + Vector3.new(0, 2, 0)
						local rayResult = workspace:Raycast(rayOrigin, Vector3.new(0, -10, 0), rayParams)
						if rayResult and rayResult.Instance then
							floorParts[rayResult.Instance] = true
							-- Also add parent model parts to be safe
							local parent = rayResult.Instance.Parent
							if parent and parent:IsA("Model") then
								for _, child in parent:GetChildren() do
									if child:IsA("BasePart") then
										floorParts[child] = true
									end
								end
							end
						end
					end

					-- Collect all parts to transform
					local partsToTransform = {}

					-- Get all BaseParts in workspace (including all descendants)
					for _, obj in workspace:GetDescendants() do
						-- Include all BasePart subclasses (Part, MeshPart, UnionOperation, WedgePart, etc.)
						if obj:IsA("BasePart") and not obj:IsA("Terrain") then
							local success, distance = pcall(function()
								return (obj.Position - position).Magnitude
							end)

							if success and distance and distance <= range then
								-- Skip player character, already processed, spawns
								local shouldSkip = false

								-- Check if it's part of a character (player or NPC)
								if obj:IsDescendantOf(Character) then
									shouldSkip = true
								end

								-- Check if it's part of ANY player's character
								for _, player in Players:GetPlayers() do
									if player.Character and obj:IsDescendantOf(player.Character) then
										shouldSkip = true
										break
									end
								end

								-- Skip spawn points
								if obj.Name:lower():match("spawn") then
									shouldSkip = true
								end

								-- Skip if already processed
								if obj:GetAttribute("TruthProcessed") then
									shouldSkip = true
								end

								-- Skip fully transparent parts (invisible collision boxes)
								if obj.Transparency >= 1 then
									shouldSkip = true
								end

								-- Skip floor parts that player is standing on
								if floorParts[obj] then
									shouldSkip = true
								end

								if not shouldSkip then
									local origColor, origMaterial, origTransparency
									local canModify = pcall(function()
										origColor = obj.Color
										origMaterial = obj.Material
										origTransparency = obj.Transparency
									end)

									if canModify and origColor then
										table.insert(partsToTransform, {
											part = obj,
											originalColor = origColor,
											originalMaterial = origMaterial,
											originalTransparency = origTransparency,
											distance = distance
										})
									end
								end
							end
						end
					end

					-- Sort by distance (closer parts transform first)
					table.sort(partsToTransform, function(a, b)
						return a.distance < b.distance
					end)

					-- Transform ALL parts - turn neon white, then fly away and fade
					for _, data in ipairs(partsToTransform) do
						local part = data.part
						if part and part.Parent then
							part:SetAttribute("TruthProcessed", true)

							-- Store original properties for restoration
							local origAnchored = part.Anchored
							local origCanCollide = part.CanCollide
							local origCFrame = part.CFrame

							-- Faster stagger - transform quickly spreading outward
							local delayTime = (data.distance / range) * 1.5

							task.delay(delayTime, function()
								if part and part.Parent then
									pcall(function()
										-- Change material to Neon first
										part.Material = Enum.Material.Neon

										-- Tween to white
										local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
										local tween = TweenService:Create(part, tweenInfo, {
											Color = Color3.new(1, 1, 1)
										})
										tween:Play()

										-- After turning white, make parts fly away and fade
										task.delay(0.5, function()
											if part and part.Parent then
												pcall(function()
													-- Disable collision so parts don't interact
													part.CanCollide = false

													-- Unanchor to allow physics/movement
													part.Anchored = false

													-- Apply upward/outward force to make parts fly away
													local direction = (part.Position - position).Unit
													if direction.Magnitude == 0 then
														direction = Vector3.new(math.random() - 0.5, 1, math.random() - 0.5).Unit
													end
													local flyForce = direction * math.random(20, 50) + Vector3.new(0, math.random(30, 60), 0)

													-- Use BodyVelocity for smooth flying effect
													local bodyVel = Instance.new("BodyVelocity")
													bodyVel.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
													bodyVel.Velocity = flyForce
													bodyVel.Parent = part
													Debris:AddItem(bodyVel, 2) -- Remove after 2 seconds

													-- Fade out the part
													local fadeInfo = TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
													local fadeTween = TweenService:Create(part, fadeInfo, {
														Transparency = 1
													})
													fadeTween:Play()
												end)
											end
										end)
									end)
								end
							end)

							-- Restore parts after sequence ends
							task.delay(TRUTH_DURATION - 0.5, function()
								if part and part.Parent then
									pcall(function()
										-- Stop any body movers
										for _, child in part:GetChildren() do
											if child:IsA("BodyMover") then
												child:Destroy()
											end
										end

										-- Restore original properties
										part.Anchored = origAnchored
										part.CanCollide = origCanCollide
										part.CFrame = origCFrame

										-- Fade back in and restore color/material
										local restoreInfo = TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
										local restoreTween = TweenService:Create(part, restoreInfo, {
											Transparency = data.originalTransparency,
											Color = data.originalColor
										})
										restoreTween:Play()
										restoreTween.Completed:Connect(function()
											if part and part.Parent then
												pcall(function()
													part.Material = data.originalMaterial
													part:SetAttribute("TruthProcessed", nil)
												end)
											end
										end)
									end)
								end
							end)
						end
					end

					-- Teleport the player to Truth's room
					task.wait(TRUTH_DURATION - 0.5)
					if truthSpawn and Character and Character:FindFirstChild("HumanoidRootPart") then
						Character.HumanoidRootPart.CFrame = CFrame.new(truthSpawn.Position + Vector3.new(0, 3, 0))

						-- Play Area and Theme sounds on client
						Visuals.FireClient(Player, {
							Module = "Base",
							Function = "TruthRoomSounds",
							Arguments = { Character }
						})
					end
				end)

				-- Disconnect after handling
				if kfConn then
					kfConn:Disconnect()
				end
			end
		end)
	end
end

return NetworkModule
