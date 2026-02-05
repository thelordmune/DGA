local Replicated = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local isServer = RunService:IsServer()

if isServer then
	-- Server-side quest module
	local ref = require(Replicated.Modules.ECS.jecs_ref)
	local world = require(Replicated.Modules.ECS.jecs_world)
	local comps = require(Replicated.Modules.ECS.jecs_components)
	local InventoryManager = require(Replicated.Modules.Utils.InventoryManager)

	return {
		Start = function(player)
			if not player then
				warn("[Sam Quest] Start called without valid player!")
				return
			end

			local playerEntity = ref.get("player", player)
			if not playerEntity then
				warn("[Sam Quest] Player entity not found!")
				return
			end

			-- Set quest as active
			world:set(playerEntity, comps.ActiveQuest, {
				npcName = "Sam",
				questName = "Nen Awakening",
				progress = {
					stage = 1,
					completed = false,
					description = "Head to the meditation point and use the sacred cup to awaken your Nen.",
					cupUsed = false,
				},
				startTime = os.clock(),
			})

			-- Give the player the Cup item
			local cupIcon = "rbxassetid://71291612556381" -- Default icon, can be changed
			local success, slot = InventoryManager.addItem(
				playerEntity,
				"Sacred Cup",
				"quest_item",
				1,
				true, -- single use
				"A sacred cup given by Sam. Drink from it at the meditation point to awaken your Nen.",
				cupIcon,
				"legendary"
			)

			if success then
				print("[Sam Quest] Cup added to player inventory at slot:", slot)
			else
				warn("[Sam Quest] Failed to add Cup to inventory!")
			end

			print("[Sam Quest] Nen Awakening quest started for", player.Name)
		end,

		-- Called when player uses the cup at the meditation point
		OnCupUsed = function(player)
			local playerEntity = ref.get("player", player)
			if not playerEntity then return end

			local activeQuest = world:get(playerEntity, comps.ActiveQuest)
			if not activeQuest or activeQuest.questName ~= "Nen Awakening" then return end

			-- Update quest progress
			world:set(playerEntity, comps.ActiveQuest, {
				npcName = "Sam",
				questName = "Nen Awakening",
				progress = {
					stage = 2,
					completed = true,
					description = "You have awakened your Nen! Return to Sam.",
					cupUsed = true,
				},
				startTime = activeQuest.startTime,
			})

			-- Remove the cup from inventory
			InventoryManager.removeItem(playerEntity, "Sacred Cup", 1)

			print("[Sam Quest] Cup used! Nen awakening complete for", player.Name)
		end,
	}
else
	-- Client-side quest module
	local Players = game:GetService("Players")
	local UserInputService = game:GetService("UserInputService")
	local TweenService = game:GetService("TweenService")
	local player = Players.LocalPlayer

	local world = require(Replicated.Modules.ECS.jecs_world)
	local comps = require(Replicated.Modules.ECS.jecs_components)
	local ref = require(Replicated.Modules.ECS.jecs_ref)

	-- State tracking
	local proximityConnection = nil
	local inputConnection = nil
	local isAtMeditationPoint = false
	local isUsingCup = false
	local cupModel = nil
	local drinkingAnimation = nil
	local animationTrack = nil

	-- Animation ID for drinking
	local DRINKING_ANIM_ID = "rbxassetid://93776491355159"

	-- Check if player has the cup in inventory
	local function hasCup()
		local playerEntity = ref.get("local_player") or ref.get("player", player)
		if not playerEntity then return false end

		if not world:has(playerEntity, comps.Inventory) then return false end

		local inventory = world:get(playerEntity, comps.Inventory)
		if not inventory or not inventory.items then return false end

		for _, item in pairs(inventory.items) do
			if item.name == "Sacred Cup" then
				return true
			end
		end
		return false
	end

	-- Spawn the cup on the floor in front of the player
	local function spawnCupOnFloor()
		local character = player.Character
		if not character then return nil end

		local hrp = character:FindFirstChild("HumanoidRootPart")
		if not hrp then return nil end

		-- Get cup model from ReplicatedStorage
		local cupTemplate = Replicated.Assets.Quest_Items:FindFirstChild("Cup")
		if not cupTemplate then
			warn("[Sam Quest Client] Cup model not found in ReplicatedStorage.Assets.Quest_Items!")
			return nil
		end

		-- Clone and position the cup
		local cup = cupTemplate:Clone()
		cup.Name = "NenCup"

		-- Position cup 3 studs in front of player, on the ground
		local lookVector = hrp.CFrame.LookVector
		local cupPosition = hrp.Position + (lookVector * 3) - Vector3.new(0, 2.5, 0) -- Ground level

		if cup:IsA("Model") then
			cup:PivotTo(CFrame.new(cupPosition))
		elseif cup:IsA("BasePart") then
			cup.Position = cupPosition
			cup.Anchored = true
		end

		cup.Parent = workspace.World.Live

		return cup
	end

	-- Play drinking animation (looped)
	local function playDrinkingAnimation()
		local character = player.Character
		if not character then return end

		local humanoid = character:FindFirstChild("Humanoid")
		if not humanoid then return end

		local animator = humanoid:FindFirstChildOfClass("Animator")
		if not animator then
			animator = Instance.new("Animator")
			animator.Parent = humanoid
		end

		-- Create animation instance
		if not drinkingAnimation then
			drinkingAnimation = Instance.new("Animation")
			drinkingAnimation.AnimationId = DRINKING_ANIM_ID
		end

		-- Load and play animation
		animationTrack = animator:LoadAnimation(drinkingAnimation)
		animationTrack.Looped = true
		animationTrack.Priority = Enum.AnimationPriority.Action
		animationTrack:Play()

		print("[Sam Quest Client] Drinking animation started (looped)")
	end

	-- Stop drinking animation
	local function stopDrinkingAnimation()
		if animationTrack then
			animationTrack:Stop()
			animationTrack:Destroy()
			animationTrack = nil
		end
	end

	-- Use the cup at the meditation point (Water Divination test)
	local function useCup()
		if isUsingCup then return end
		if not isAtMeditationPoint then return end
		if not hasCup() then
			print("[Sam Quest Client] Player doesn't have the cup!")
			return
		end

		isUsingCup = true
		print("[Sam Quest Client] Beginning Water Divination test...")

		local character = player.Character
		if not character then
			isUsingCup = false
			return
		end

		-- Spawn the cup on the floor in front of player
		cupModel = spawnCupOnFloor()

		-- Play the meditation/focus animation (looped)
		playDrinkingAnimation()

		-- Start the Nen Awakening visual effects sequence (pass cup model for highlight)
		local NenAwakeningEffects = require(Replicated.Client.NenAwakeningEffects)
		local nenType = NenAwakeningEffects.StartAwakening(character, cupModel)

		-- Wait for the full awakening sequence (20 seconds total)
		-- The awakening effects module handles all the visual timing
		task.wait(20)

		-- Stop the awakening effects
		NenAwakeningEffects.StopAwakening()

		-- Stop animation
		stopDrinkingAnimation()

		-- Remove cup model
		if cupModel then
			cupModel:Destroy()
			cupModel = nil
		end

		-- Notify server that cup was used via Packets system
		local Client = require(Replicated.Client)
		Client.Packets.Quests.send({
			Module = "Sam",
			Function = "OnCupUsed",
			Arguments = {},
		})

		-- Show final completion message with VPNoti
		local VPNotiManager = require(Replicated.Client.VPNotiManager)
		local samModel = Replicated.Assets.Viewports:FindFirstChild("Sam")
		if samModel and nenType then
			VPNotiManager.Show({
				npc = samModel,
				text = `Your Nen type is {nenType}! Return to Sam to learn more about your abilities.`,
				duration = 5,
			})
		end

		task.wait(5)
		VPNotiManager.Hide()

		isUsingCup = false
		print("[Sam Quest Client] Water Divination complete! Nen type:", nenType)
	end

	return {
		-- Called when a quest stage starts
		OnStageStart = function(stage, questData)
			print(`[Sam Quest Client] Stage {stage} started - Nen Awakening`)

			local QuestHandler = require(Replicated.Client.QuestHandler)
			local VPNotiManager = require(Replicated.Client.VPNotiManager)

			if stage == 1 then
				-- Stage 1: Go to the meditation point with the cup
				local meditationPoint = workspace.World.Quests.Sam:FindFirstChild("Marker", true)

				if meditationPoint then
					QuestHandler.CreateWaypoint(meditationPoint, "Meditation Point", {
						color = Color3.fromRGB(138, 43, 226), -- Purple (mystical)
						heightOffset = 10,
						maxDistance = 1000,
					})
					print("[Sam Quest Client] Created waypoint for meditation point")

					-- Cleanup existing connections
					if proximityConnection then
						proximityConnection:Disconnect()
						proximityConnection = nil
					end
					if inputConnection then
						inputConnection:Disconnect()
						inputConnection = nil
					end

					-- Reset state
					isAtMeditationPoint = false
					isUsingCup = false

					-- Start proximity monitoring
					task.spawn(function()
						local character = player.Character or player.CharacterAdded:Wait()
						local hrp = character:WaitForChild("HumanoidRootPart", 10)
						if not hrp then
							warn("[Sam Quest Client] No HumanoidRootPart found!")
							return
						end

						print("[Sam Quest Client] Starting proximity monitoring for meditation point...")

						-- Set up input listener for using the cup
						inputConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
							if gameProcessed then return end

							-- Check for hotbar keys (1-7) that might have the cup
							local hotbarKeys = {
								[Enum.KeyCode.One] = 1,
								[Enum.KeyCode.Two] = 2,
								[Enum.KeyCode.Three] = 3,
								[Enum.KeyCode.Four] = 4,
								[Enum.KeyCode.Five] = 5,
								[Enum.KeyCode.Six] = 6,
								[Enum.KeyCode.Seven] = 7,
							}

							local slotNumber = hotbarKeys[input.KeyCode]
							if slotNumber then
								print(`[Sam Quest Client] Hotbar key {slotNumber} pressed, isAtMeditationPoint: {isAtMeditationPoint}`)
								-- Check if player is at meditation point and has cup
								if isAtMeditationPoint and hasCup() then
									-- Check if the pressed slot has the cup using InventoryManager
									local playerEntity = ref.get("local_player") or ref.get("player", player)
									if playerEntity then
										local InventoryManager = require(Replicated.Modules.Utils.InventoryManager)
										local item = InventoryManager.getHotbarItem(playerEntity, slotNumber)
										print(`[Sam Quest Client] Hotbar slot {slotNumber} item:`, item and item.name or "nil")
										if item and item.name == "Sacred Cup" then
											useCup()
										else
											-- Debug: Show what's in each hotbar slot
											for i = 1, 7 do
												local hotbarItem = InventoryManager.getHotbarItem(playerEntity, i)
												if hotbarItem then
													print(`[Sam Quest Client] Hotbar {i}: {hotbarItem.name}`)
												end
											end
										end
									end
								end
							end
						end)

						-- Monitor proximity to meditation point
						proximityConnection = RunService.Heartbeat:Connect(function()
							if not character or not character.Parent or not hrp or not hrp.Parent then
								return
							end

							local distance = (hrp.Position - meditationPoint.Position).Magnitude
							local wasAtPoint = isAtMeditationPoint
							isAtMeditationPoint = distance <= 150 -- Within 150 studs of meditation point

							-- Show prompt when entering the area
							if isAtMeditationPoint and not wasAtPoint and not isUsingCup then
								if hasCup() then
									-- Get Sam model for VPNoti
									local samModel = Replicated.Assets.Viewports:FindFirstChild("Sam")
									if samModel then
										VPNotiManager.Show({
											npc = samModel,
											text = "You've reached the meditation point. Press the hotbar key for the Sacred Cup to begin the awakening ritual.",
											duration = 0,
										})
									end
									print("[Sam Quest Client] Player reached meditation point - Press cup hotbar key to use!")
								else
									print("[Sam Quest Client] Player at meditation point but doesn't have the cup!")
								end
							elseif not isAtMeditationPoint and wasAtPoint and not isUsingCup then
								VPNotiManager.Hide()
							end
						end)
					end)
				else
					warn("[Sam Quest Client] Could not find meditation point marker!")
				end

			elseif stage == 2 then
				-- Stage 2: Return to Sam after awakening
				local samNPC = Workspace.World.Dialogue:FindFirstChild("Sam")

				if samNPC then
					QuestHandler.CreateWaypoint(samNPC, "Return to Sam", {
						color = Color3.fromRGB(143, 255, 143), -- Green
						heightOffset = 5,
						maxDistance = 500,
					})
					print("[Sam Quest Client] Created waypoint to return to Sam")
				else
					warn("[Sam Quest Client] Could not find Sam NPC")
				end
			end
		end,

		-- Called when leaving a stage
		OnStageEnd = function(stage, questData)
			print(`[Sam Quest Client] Stage {stage} ended`)

			-- Cleanup connections
			if proximityConnection then
				proximityConnection:Disconnect()
				proximityConnection = nil
			end
			if inputConnection then
				inputConnection:Disconnect()
				inputConnection = nil
			end

			-- Stop animation if playing
			stopDrinkingAnimation()

			-- Remove cup model if exists
			if cupModel then
				cupModel:Destroy()
				cupModel = nil
			end

			-- Hide VPNoti
			local VPNotiManager = require(Replicated.Client.VPNotiManager)
			VPNotiManager.Hide()

			-- Reset state
			isAtMeditationPoint = false
			isUsingCup = false
		end,

		-- Called when the quest is completed
		OnQuestComplete = function(questData)
			print("[Sam Quest Client] Nen Awakening quest completed!")

			-- Final cleanup
			if proximityConnection then
				proximityConnection:Disconnect()
				proximityConnection = nil
			end
			if inputConnection then
				inputConnection:Disconnect()
				inputConnection = nil
			end

			stopDrinkingAnimation()

			if cupModel then
				cupModel:Destroy()
				cupModel = nil
			end

			local VPNotiManager = require(Replicated.Client.VPNotiManager)
			VPNotiManager.Hide()
		end,
	}
end
