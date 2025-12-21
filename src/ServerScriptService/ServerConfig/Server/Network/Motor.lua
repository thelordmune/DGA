local Replicated = game:GetService("ReplicatedStorage")
local Library = require(Replicated.Modules.Library)
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local HttpService = game:GetService("HttpService")

-- ECS imports
local world = require(Replicated.Modules.ECS.jecs_world)
local comps = require(Replicated.Modules.ECS.jecs_components)

local NetworkModule = {}
local Server = require(script.Parent.Parent)
NetworkModule.__index = NetworkModule
local self = setmetatable({}, NetworkModule)

local activeTweens = {}

local function cleanUp()
	for _, t in pairs(activeTweens) do
		t:Cancel()
	end
	activeTweens = {}
end

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
	local Animation = Replicated.Assets.Animations.Misc.Alchemy

	if Server.Library.StateCount(Character.Actions) or Server.Library.StateCount(Character.Stuns) then
		return
	end

	-- For NPCs, skip the PlayerObject.Keys check
	local canUseSkill = isNPC or (PlayerObject and PlayerObject.Keys)

	if canUseSkill and not Server.Library.CheckCooldown(Character, "Motor") then
		-- Only set Keys for real players
		if not isNPC and PlayerObject and PlayerObject.Keys then
			PlayerObject.Keys["Motor"] = not Data.Held
		end
		if not Data.Held then
			cleanUp()
			Server.Library.SetCooldown(Character, "Motor", 30)
			Server.Library.StopAllAnims(Character)

			local Alchemy = Library.PlayAnimation(Character, Animation)
			if not Alchemy then
				return
			end

			Alchemy.Looped = false

			-- Set character states
			Server.Library.TimedState(Character.Actions, "Motor", Alchemy.Length)
			Server.Library.TimedState(Character.Stuns, "NoRotate", Alchemy.Length)
			Server.Library.TimedState(Character.Speeds, "AlcSpeed-0", Alchemy.Length)
			Server.Library.TimedState(Character.Speeds, "Jump-50", Alchemy.Length)

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
						Arguments = { Character, Data.Duration or 0 },
					})

					if Data.Duration and Data.Duration >= 0.2 then
						Server.Visuals.Ranged(Character.HumanoidRootPart.Position, 300, {
							Module = "Base",
							Function = "Stall",
							Arguments = { Character, Data.Duration },
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

					-- Show transmute VFX
					Server.Visuals.Ranged(Character.HumanoidRootPart.Position, 300, {
						Module = "Base",
						Function = "Transmute",
						Arguments = { Character, -10 },
					})

					-- Get motorcycle model
					local motorcycleTemplate = Replicated.Assets.Models.MotorCycle
					if not motorcycleTemplate then
						warn("Motorcycle model not found!")
						return
					end

					-- Clone the motorcycle
					local motorcycle = motorcycleTemplate:Clone()

					-- Generate unique ID for this motorcycle
					local motorcycleId = "Motorcycle_" .. HttpService:GenerateGUID(false)

					-- Set up motorcycle name
					motorcycle.Name = motorcycleId

					-- Calculate spawn position (10 studs in front of player)
					local spawnCFrame = Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, -10)
					motorcycle:PivotTo(spawnCFrame)

					-- Set attributes for client-side detection
					motorcycle:SetAttribute("Interactable", true)
					motorcycle:SetAttribute("ObjectId", motorcycleId)
					motorcycle:SetAttribute("PromptText", "Interact")
					motorcycle:SetAttribute("InteractionHandler", "Motorcycle")

					motorcycle.Parent = workspace

					-- Create ECS entity for server-side tracking
					local motorcycleEntity = world:entity()
					world:set(motorcycleEntity, comps.Interactable, {
						objectId = motorcycleId,
						promptText = "Interact",
						handlerName = "Motorcycle",
						model = motorcycle
					})
					world:set(motorcycleEntity, comps.Model, motorcycle)

					-- Collect all mesh parts from front and back models
					local allParts = {}
					for _, model in ipairs(motorcycle:GetChildren()) do
						if model:IsA("Model") and (model.Name == "Front" or model.Name == "Back") then
							for _, part in ipairs(model:GetDescendants()) do
								if part:IsA("MeshPart") then
									table.insert(allParts, {
										Part = part,
										OriginalCFrame = part.CFrame,
										OriginalTransparency = part.Transparency
									})
									-- Set initial state (invisible and offset below)
									part.Transparency = 1
									part.CFrame = part.CFrame * CFrame.new(0, -5, 0)
								end
							end
						end
					end

					-- Staggered fade-in effect for each part
					local tweenInfo = TweenInfo.new(
						0.8, -- Duration
						Enum.EasingStyle.Quad,
						Enum.EasingDirection.Out
					)

					for i, partData in ipairs(allParts) do
						-- Stagger each part's animation
						task.delay((i - 1) * .35, function()
							local tween = TweenService:Create(partData.Part, tweenInfo, {
								CFrame = partData.OriginalCFrame,
								Transparency = partData.OriginalTransparency
							})
							tween:Play()
							table.insert(activeTweens, tween)
						end)
					end

					-- Camera shake effect
					Server.Visuals.FireClient(Player, {
						Module = "Base",
						Function = "Shake",
						Arguments = {
							"Once",
							{ 6, 11, 0, 0.7, Vector3.new(1.1, 2, 1.1), Vector3.new(0.34, 0.25, 0.34) },
						},
					})
				end
			end)

			-- Animation cleanup
			local animEndConn
			animEndConn = Alchemy.Stopped:Connect(function()
				if kfConn then
					kfConn:Disconnect()
					kfConn = nil
				end
				if animEndConn then
					animEndConn:Disconnect()
					animEndConn = nil
				end
			end)
		end
	end
end

return NetworkModule