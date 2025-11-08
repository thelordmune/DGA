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

	local queststage = 1

	-- Track spawned NPCs per player
	local spawnedInstructors = {} -- {[player] = npcModel}

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

			if world:get(playerEntity, comps.ActiveQuest).stage then
				queststage = world:get(playerEntity, comps.ActiveQuest).progress.stage
			end

			print("[Sam Quest] Quest stage:", queststage)

			if queststage == 1 then
				world:set(playerEntity, comps.ActiveQuest, {
					npcName = "Sam",
					questName = "Military Exam",
					progress = {
						stage = queststage,
						completed = false,
						description = "Head over to the central command center to begin your exam.",
					},
					startTime = os.clock(), -- Fixed: was startedTime
				})

				-- Start proximity monitoring for NPC spawning
				task.spawn(function()
					local character = player.Character or player.CharacterAdded:Wait()
					local hrp = character:WaitForChild("HumanoidRootPart", 10)
					if not hrp then
						warn("[Sam Quest] Player has no HumanoidRootPart!")
						return
					end

					-- Get the quest marker location
					local questMarker = Workspace.World.Quests.Sam:FindFirstChild("Marker", true)
					if not questMarker then
						warn("[Sam Quest] Quest marker not found!")
						return
					end

					local npcSpawned = false
					local proximityCheckConnection

					-- Check proximity every 0.5 seconds
					proximityCheckConnection = RunService.Heartbeat:Connect(function()
						if not character or not character.Parent then
							proximityCheckConnection:Disconnect()
							return
						end

						if not hrp or not hrp.Parent then
							proximityCheckConnection:Disconnect()
							return
						end

						-- Check if player still has the quest
						if not world:has(playerEntity, comps.ActiveQuest) then
							proximityCheckConnection:Disconnect()
							return
						end

						local activeQuest = world:get(playerEntity, comps.ActiveQuest)
						if activeQuest.npcName ~= "Sam" or activeQuest.questName ~= "Military Exam" then
							proximityCheckConnection:Disconnect()
							return
						end

						-- Check distance to marker (50 studs)
						local distance = (hrp.Position - questMarker.Position).Magnitude

						if distance <= 50 and not npcSpawned then
							npcSpawned = true
							print("[Sam Quest] Player within 50 studs of marker - spawning Tutorial Instructor!")

							-- Spawn the Tutorial Instructor NPC
							local npcSpawnPart = Workspace.World.Quests.Sam:FindFirstChild("Npc_Spawn", true)
							if not npcSpawnPart then
								warn("[Sam Quest] Npc_Spawn not found!")
								return
							end

							local spawnPos = npcSpawnPart.Position

							-- Load the TutorialInstructor NPC data
							local TutorialInstructorData = require(Replicated.Regions.Forest.Npcs.TutorialInstructor)

							-- Update spawn location
							TutorialInstructorData.DataToSendOverAndUdpate.Spawning.Locations = { spawnPos }
							TutorialInstructorData.Quantity = 1
							TutorialInstructorData.AlwaysSpawn = true

							-- Use the serializer to create NPC data
							local seralizer = require(Replicated.Seralizer)

							-- Prepare NPC file (same way guards are spawned)
							local regionName = "Forest"
							local regionContainer = Workspace.World.Live:FindFirstChild(regionName)
							if not regionContainer then
								regionContainer = Instance.new("Folder")
								regionContainer.Name = regionName
								regionContainer.Parent = Workspace.World.Live
							end

							local npcsContainer = regionContainer:FindFirstChild("NPCs")
							if not npcsContainer then
								npcsContainer = Instance.new("Folder")
								npcsContainer.Name = "NPCs"
								npcsContainer.Parent = regionContainer
							end

							-- Create NPC file
							local npcFile = Replicated.NpcFile:Clone()
							npcFile.Name = "TutorialInstructor"
							npcFile:SetAttribute("SetName", "TutorialInstructor")
							npcFile:SetAttribute("DefaultName", "TutorialInstructor")

							-- Create data folder
							local dataFolder = Instance.new("Folder")
							dataFolder.Name = "Data"
							seralizer.LoadTableThroughInstance(dataFolder, TutorialInstructorData.DataToSendOverAndUdpate)
							dataFolder.Parent = npcFile

							npcFile.Parent = npcsContainer

							print("[Sam Quest] Tutorial Instructor NPC file created!")

							-- Store reference
							spawnedInstructors[player] = npcFile

							-- Disconnect proximity check after spawning
							proximityCheckConnection:Disconnect()
						end
					end)
				end)
			end
		end,
	}
else
	-- Client-side quest module
	local Players = game:GetService("Players")
	local player = Players.LocalPlayer

	-- Tutorial state tracking
	local tutorialStage = 0
	local proximityConnection = nil
	local tutorialComplete = false

	return {
		-- Called when a quest stage starts
		OnStageStart = function(stage, questData)
			print(`[Sam Quest Client] 🎯 Stage {stage} started`)
			print(`[Sam Quest Client] 📊 Current tutorialStage before reset: {tutorialStage}`)

			local QuestHandler = require(Replicated.Client.QuestHandler)
			local VPNotiManager = require(Replicated.Client.VPNotiManager)

			if stage == 1 then
				-- Stage 1: Go to the quest location
				local commandCenter = workspace.World.Quests.Sam:FindFirstChild("Marker", true)

				if commandCenter then
					QuestHandler.CreateWaypoint(commandCenter, "Tutorial", {
						color = Color3.fromRGB(255, 215, 0), -- Gold
						heightOffset = 10,
						maxDistance = 1000,
					})
					print("[Sam Quest Client] ✅ Created waypoint for quest location at", commandCenter.Position)

					-- Disconnect any existing proximity connection first
					if proximityConnection then
						proximityConnection:Disconnect()
						proximityConnection = nil
						print("[Sam Quest Client] 🔌 Disconnected old proximity connection")
					end

					-- Start proximity monitoring for tutorial
					tutorialStage = 0
					tutorialComplete = false
					print(`[Sam Quest Client] 🔄 Reset tutorialStage to: {tutorialStage}`)

					task.spawn(function()
						local character = player.Character or player.CharacterAdded:Wait()
						local hrp = character:WaitForChild("HumanoidRootPart", 10)
						if not hrp then
							warn("[Sam Quest Client] ⚠️ No HumanoidRootPart found!")
							return
						end

						print("[Sam Quest Client] 🔍 Starting proximity monitoring...")

						-- Monitor proximity to marker
						local lastPrintTime = 0
						proximityConnection = RunService.Heartbeat:Connect(function()
							if not character or not character.Parent or not hrp or not hrp.Parent then
								if proximityConnection then
									proximityConnection:Disconnect()
								end
								return
							end

							local distance = (hrp.Position - commandCenter.Position).Magnitude

							-- Debug print every 2 seconds
							local currentTime = tick()
							if currentTime - lastPrintTime >= 2 then
								print(`[Sam Quest Client] 📏 Distance to marker: {math.floor(distance)} studs (tutorialStage: {tutorialStage})`)
								print(`[Sam Quest Client] 🔍 Condition check: distance <= 20 = {distance <= 20}, tutorialStage == 0 = {tutorialStage == 0}`)
								lastPrintTime = currentTime
							end

							-- When player reaches the marker, start tutorial
							if distance <= 20 and tutorialStage == 0 then
								tutorialStage = 1
								print("[Sam Quest Client] 🎓 Starting tutorial sequence - Player within 20 studs!")

								-- Get Sam NPC model from viewports
								local samModel = Replicated.Assets.Viewports:FindFirstChild("Sam")
								if not samModel then
									warn("[Sam Quest Client] ⚠️ Sam model not found in Viewports!")
									return
								end

								-- Show the UI once with no auto-hide
								VPNotiManager.Show({
									npc = samModel,
									text = "Welcome to the Military Exam! I'll teach you the basics of combat.",
									duration = 0, -- No auto-hide, we'll control progression manually
								})

								-- Wait a bit for player to read
								task.wait(3)

								-- Tutorial progression system
								local UserInputService = game:GetService("UserInputService")
								local StateManager = require(Replicated.Modules.Utils.StateManager)

								-- Stage 2: Dash
								VPNotiManager.UpdateText("First, learn to dash. Press Q to dash forward!")
								tutorialStage = 2

								-- Wait for player to dash
								local dashedConnection
								dashedConnection = character:WaitForChild("States"):WaitForChild("Actions").ChildAdded:Connect(function(child)
									if child.Name == "Dashing" then
										dashedConnection:Disconnect()
										task.wait(0.5)

										-- Stage 3: Attack
										VPNotiManager.UpdateText("Good! Now attack! Left click to perform basic attacks.")
										tutorialStage = 3

										-- Wait for player to attack
										local attackedConnection
										attackedConnection = character:WaitForChild("States"):WaitForChild("Actions").ChildAdded:Connect(function(child2)
											if child2.Name:match("M1") or child2.Name:match("Attack") then
												attackedConnection:Disconnect()
												task.wait(0.5)

												-- Stage 4: Block
												VPNotiManager.UpdateText("Next, blocking. Hold F to block attacks.")
												tutorialStage = 4

												-- Wait for player to block
												local blockConnection
												blockConnection = character:WaitForChild("States"):WaitForChild("Actions").ChildAdded:Connect(function(child3)
													if child3.Name == "Blocking" then
														blockConnection:Disconnect()
														task.wait(0.5)

														-- Stage 5: Parry (optional, just show it)
														VPNotiManager.UpdateText("Great! You can also press F to parry incoming attacks at the right moment.")
														tutorialStage = 5
														task.wait(3)

														-- Stage 6: Alchemy
														VPNotiManager.UpdateText("Finally, alchemy. Press G then Z to spawn an alchemy wall!")
														tutorialStage = 6

														-- Wait for player to use alchemy
														local alchemyConnection
														alchemyConnection = character:WaitForChild("States"):WaitForChild("Actions").ChildAdded:Connect(function(child4)
															if child4.Name:match("Alchemy") or child4.Name:match("Wall") then
																alchemyConnection:Disconnect()
																task.wait(0.5)

																-- Stage 7: Complete
																VPNotiManager.UpdateText("Excellent! Alchemy lets you manipulate elements. Experiment with different combinations!")
																tutorialStage = 7
																tutorialComplete = true

																task.wait(4)
																VPNotiManager.Hide()
																print("[Sam Quest Client] ✅ Tutorial complete!")
															end
														end)
													end
												end)
											end
										end)
									end
								end)
							end
						end)
					end)
				else
					warn("[Sam Quest Client] ⚠️ Could not find quest marker in workspace")
				end

			elseif stage == 2 then
				-- Stage 2: Return to Sam
				local samNPC = Workspace.World.Dialogue:FindFirstChild("Sam")

				if samNPC then
					QuestHandler.CreateWaypoint(samNPC, "Return to Sam", {
						color = Color3.fromRGB(143, 255, 143), -- Green
						heightOffset = 5,
						maxDistance = 500,
					})
					print("[Sam Quest Client] ✅ Created waypoint for Sam NPC")
				else
					warn("[Sam Quest Client] ⚠️ Could not find Sam NPC")
				end
			end
		end,

		-- Called every frame while on a stage (optional, use sparingly)
		OnStageUpdate = function(stage, questData)
			-- Tutorial progression is handled in OnStageStart
		end,

		-- Called when leaving a stage
		OnStageEnd = function(stage, questData)
			print(`[Sam Quest Client] ✅ Stage {stage} ended`)

			-- Cleanup proximity connection
			if proximityConnection then
				proximityConnection:Disconnect()
				proximityConnection = nil
			end

			-- Hide any active VPNoti
			local VPNotiManager = require(Replicated.Client.VPNotiManager)
			VPNotiManager.Hide()
		end,

		-- Called when the quest is completed
		OnQuestComplete = function(questData)
			print("[Sam Quest Client] 🎉 Quest completed!")

			-- Cleanup
			if proximityConnection then
				proximityConnection:Disconnect()
				proximityConnection = nil
			end

			local VPNotiManager = require(Replicated.Client.VPNotiManager)
			VPNotiManager.Hide()
		end,
	}
end
