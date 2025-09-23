local ServerStorage = game:GetService("ServerStorage")
local Replicated = game:GetService("ReplicatedStorage")
local Server 
local Utilities = require(Replicated.Modules.Utilities)
local Library = require(Replicated.Modules.Library)
local Packets = require(Replicated.Modules.Packets)
local Visuals = require(Replicated.Modules.Visuals)
local WeaponStats = require(ServerStorage.Stats._Weapons)

local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local NetworkModule = {}; local Server = require(script.Parent.Parent);
NetworkModule.__index = NetworkModule
local self = setmetatable({}, NetworkModule)

local activeConnections = {}
local activeTweens = {}

local function cleanUp()
	for _, conn in pairs(activeConnections) do
		conn:Disconnect()
	end
	activeConnections = {}

	for _, t in pairs(activeTweens) do
		t:Cancel()
	end
	activeTweens = {}
end

local function getFloorColor(character)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return nil end

	local rayOrigin = root.Position
	local rayDirection = Vector3.new(0, -10, 0)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = {character}
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude

	local raycastResult = workspace:Raycast(rayOrigin, rayDirection, raycastParams)
	if raycastResult then
		return raycastResult.Instance.Color
	end

	return nil
end

NetworkModule.EndPoint = function(Player, Data)
	print("fired construction wall")
	local Character = Player.Character

	if not Character or not Character:GetAttribute("Equipped") then return end

	local PlayerObject = Server.Modules["Players"].Get(Player)
	local Animation = Replicated.Assets.Animations.Misc.Alchemy

	if Server.Library.StateCount(Character.Actions) or Server.Library.StateCount(Character.Stuns) then return end

	if PlayerObject and PlayerObject.Keys and not Server.Library.CheckCooldown(Character, "Construct") then
		PlayerObject.Keys["Construct"] = not Data.Held
		if not Data.Held then
			cleanUp()
			Server.Library.SetCooldown(Character,"Construct",5)
			Server.Library.StopAllAnims(Character)

			local Alchemy = Library.PlayAnimation(Character, Animation)
			if not Alchemy then
				print("Failed to load Construct animation")
				return
			end

			Alchemy.Looped = false
			print("Construct animation loaded, Length:", Alchemy.Length)

			-- Get floor color for wall material
			local floorColor = getFloorColor(Character)
			local wallColor = floorColor or Color3.fromRGB(100, 150, 255)

			-- Set character states
			Server.Library.TimedState(Character.Actions, "Construct", Alchemy.Length)
			Server.Library.TimedState(Character.Stuns, "NoRotate", Alchemy.Length)
			Server.Library.TimedState(Character.Speeds, "AlcSpeed-0", Alchemy.Length)

			-- Track connections for cleanup
			local connections = {}

			local kfConn
			kfConn = Alchemy.KeyframeReached:Connect(function(key)
				if key == "Clap" then
					-- Play clap sound
					local s = Replicated.Assets.SFX.FMAB.Clap:Clone()
					s.Parent = Character.HumanoidRootPart
					s:Play()
					Debris:AddItem(s, s.TimeLength)

					-- Visual effects
					Server.Visuals.Ranged(Character.HumanoidRootPart.Position, 300, {
						Module = "Base", 
						Function = "Clap", 
						Arguments = {Character, Data.Duration}
					})

					if Data.Duration and Data.Duration >= 0.2 then
						Server.Visuals.Ranged(Character.HumanoidRootPart.Position, 300, {
							Module = "Base", 
							Function = "Stall", 
							Arguments = {Character, Data.Duration}
						})
						Alchemy:AdjustSpeed(0)
						task.delay(Data.Duration, function()
							Alchemy:AdjustSpeed(1)
						end)
					end
				end

				if key == "Touch" then
					-- Play transmutation sound
					local s = Replicated.Assets.SFX.FMAB.Transmute:Clone()
					s.Volume = 2
					s.Parent = Character.HumanoidRootPart
					s:Play()
					Debris:AddItem(s, s.TimeLength)

					Server.Visuals.Ranged(Character.HumanoidRootPart.Position, 300, {
						Module = "Base", 
						Function = "Transmute", 
						Arguments = {Character}
					})

					-- Create wall effect
					local part = Instance.new("Part")
					part.Name = "AbilityWall_" .. os.time()
					part.Anchored = true
					part.CanCollide = true
					part.Transparency = 1  -- Start fully transparent
					part.Material = Enum.Material.Plastic
					part.Color = wallColor
					part:SetAttribute("Id", HttpService:GenerateGUID(false))

					local baseSize = math.random(10, 15)
					local variation = math.random() * 0.5 + 0.75
					local width = baseSize * variation
					local height = baseSize * 2
					local depth = baseSize / 3 * variation
					part.Size = Vector3.new(width, height, depth)

					-- Calculate positions
					local playerLookVector = Character.HumanoidRootPart.CFrame.LookVector
					playerLookVector = Vector3.new(playerLookVector.X, 0, playerLookVector.Z).Unit
					local spawnDistance = 5
					local spawnOffset = Vector3.new(0, -3, 0)
					local targetPos = Character.HumanoidRootPart.Position + (playerLookVector * spawnDistance) + spawnOffset
					local startPos = targetPos - Vector3.new(0, height + 2, 0)  -- Start below ground

					-- Set initial position (fully hidden)
					part.CFrame = CFrame.new(startPos) * CFrame.fromMatrix(
						Vector3.new(),
						Vector3.new(playerLookVector.Z, 0, -playerLookVector.X),
						Vector3.new(0, 1, 0),
						playerLookVector
					)
					part.Parent = workspace  -- Parent before animation starts

					-- Use TweenService for smoother animation
					local riseTime = 0.8  -- seconds
					local tweenInfo = TweenInfo.new(
						riseTime,
						Enum.EasingStyle.Quad,
						Enum.EasingDirection.Out
					)

					local tween = TweenService:Create(part, tweenInfo, {
						CFrame = CFrame.new(targetPos) * CFrame.fromMatrix(
							Vector3.new(),
							Vector3.new(playerLookVector.Z, 0, -playerLookVector.X),
							Vector3.new(0, 1, 0),
							playerLookVector
						),
						Transparency = 0  -- Fully opaque at end
					})

					tween:Play()
					table.insert(activeTweens, tween)

					-- Move to transmutables folder when done
					tween.Completed:Connect(function()
						part.Parent = workspace.Transmutables
					end)

					--table.insert(activeConnections, connection)

					-- Camera shake effect
					Server.Visuals.FireClient(Player, {
						Module = "Base", 
						Function = "Shake", 
						Arguments = {"Once", { 6, 11, 0, 0.7, Vector3.new(1.1, 2, 1.1), Vector3.new(0.34, 0.25, 0.34) }}
					})
				end
			end)
			table.insert(activeConnections, kfConn)
			table.insert(connections, kfConn)

			-- PROPER ANIMATION CLEANUP - Fix looping issue
			local animEndConn
			animEndConn = Alchemy.Stopped:Connect(function()
				print("Construct animation stopped, cleaning up")
				-- Disconnect keyframe connection
				if kfConn then
					kfConn:Disconnect()
					kfConn = nil
				end
				-- Disconnect this connection
				if animEndConn then
					animEndConn:Disconnect()
					animEndConn = nil
				end
				-- Clean up from active connections
				for i, conn in ipairs(activeConnections) do
					if conn == kfConn then
						table.remove(activeConnections, i)
						break
					end
				end
				print("Construct animation cleanup complete")
			end)
			table.insert(connections, animEndConn)
		end
	end
end

return NetworkModule