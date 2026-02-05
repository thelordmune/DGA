--[[
	Example Quest Module
	
	This is a template showing how to create a quest with both server-side
	and client-side logic, including stage-specific waypoint markers.
	
	Server-side: Handles quest progression, validation, rewards
	Client-side: Handles UI, waypoint markers, visual feedback
]]

local Replicated = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local isServer = RunService:IsServer()

if isServer then
	-- ============================================================
	-- SERVER-SIDE QUEST LOGIC
	-- ============================================================
	
	local ref = require(Replicated.Modules.ECS.jecs_ref)
	local world = require(Replicated.Modules.ECS.jecs_world)
	local comps = require(Replicated.Modules.ECS.jecs_components)
	
	return {
		-- Called when player accepts the quest
		Start = function(player)
			if not player then
				warn("[Example Quest] Start called without valid player!")
				return
			end
			
			local playerEntity = ref.get("player", player)
			if not playerEntity then
				warn("[Example Quest] Player entity not found!")
				return
			end
			
			-- Get current stage (if resuming quest)
			local currentStage = 1
			if world:has(playerEntity, comps.ActiveQuest) then
				local activeQuest = world:get(playerEntity, comps.ActiveQuest)
				if activeQuest.progress and activeQuest.progress.stage then
					currentStage = activeQuest.progress.stage
				end
			end
			
			print(`[Example Quest] Starting quest at stage {currentStage}`)
			
			-- Set up quest data based on stage
			if currentStage == 1 then
				world:set(playerEntity, comps.ActiveQuest, {
					npcName = "ExampleNPC",
					questName = "Example Quest",
					progress = {
						stage = 1,
						completed = false,
						description = "Go to the first location.",
					},
					startedTime = os.clock(),
				})
			elseif currentStage == 2 then
				world:set(playerEntity, comps.ActiveQuest, {
					npcName = "ExampleNPC",
					questName = "Example Quest",
					progress = {
						stage = 2,
						completed = false,
						description = "Go to the second location.",
					},
					startedTime = os.clock(),
				})
			end
		end,
		
		-- Called when player completes the quest
		Complete = function(player, questName, choice)
			print(`[Example Quest] Quest completed with choice: {choice}`)
			-- Add any server-side completion logic here
		end,
		
		-- Custom function to advance to next stage
		AdvanceStage = function(player, newStage)
			local playerEntity = ref.get("player", player)
			if not playerEntity then return end
			
			if world:has(playerEntity, comps.ActiveQuest) then
				local activeQuest = world:get(playerEntity, comps.ActiveQuest)
				activeQuest.progress.stage = newStage
				
				-- Update description based on stage
				if newStage == 2 then
					activeQuest.progress.description = "Go to the second location."
				elseif newStage == 3 then
					activeQuest.progress.description = "Return to the NPC."
				end
				
				world:set(playerEntity, comps.ActiveQuest, activeQuest)
			end
		end,
	}
	
else
	-- ============================================================
	-- CLIENT-SIDE QUEST LOGIC
	-- ============================================================
	
	return {
		-- Called when a quest stage starts
		OnStageStart = function(stage, questData)
			print(`[Example Quest Client] 🎯 Stage {stage} started`)
			
			local QuestHandler = require(Replicated.Client.QuestHandler)
			
			if stage == 1 then
				-- Stage 1: Go to first location
				local location1 = Workspace:FindFirstChild("QuestLocation1", true)
				
				if location1 then
					QuestHandler.CreateWaypoint(location1, "First Location", {
						color = Color3.fromRGB(255, 215, 0), -- Gold
						heightOffset = 10,
						maxDistance = 1000,
					})
					print("[Example Quest Client] ✅ Created waypoint for Location 1")
				else
					warn("[Example Quest Client] ⚠️ Could not find QuestLocation1")
				end
				
			elseif stage == 2 then
				-- Stage 2: Go to second location
				local location2 = Workspace:FindFirstChild("QuestLocation2", true)
				
				if location2 then
					QuestHandler.CreateWaypoint(location2, "Second Location", {
						color = Color3.fromRGB(100, 200, 255), -- Blue
						heightOffset = 10,
						maxDistance = 1000,
					})
					print("[Example Quest Client] ✅ Created waypoint for Location 2")
				else
					warn("[Example Quest Client] ⚠️ Could not find QuestLocation2")
				end
				
			elseif stage == 3 then
				-- Stage 3: Return to NPC
				local npc = Workspace.World.Dialogue:FindFirstChild("ExampleNPC")
				
				if npc then
					QuestHandler.CreateWaypoint(npc, "Return to NPC", {
						color = Color3.fromRGB(143, 255, 143), -- Green
						heightOffset = 5,
						maxDistance = 500,
					})
					print("[Example Quest Client] ✅ Created waypoint for NPC")
				end
			end
		end,
		
		-- Called every frame while on a stage (use sparingly!)
		OnStageUpdate = function(stage, questData)
			-- Example: Check if player is near objective
			-- Only use this if you need frame-by-frame checks
			-- Most logic should be in OnStageStart or triggered by events
			
			--[[
			local Players = game:GetService("Players")
			local player = Players.LocalPlayer
			local character = player.Character
			
			if character and character.PrimaryPart then
				local objective = Workspace:FindFirstChild("QuestLocation1", true)
				if objective then
					local distance = (character.PrimaryPart.Position - objective.Position).Magnitude
					
					if distance < 10 then
						-- Player reached objective
						-- Trigger next stage via server
					end
				end
			end
			]]
		end,
		
		-- Called when leaving a stage
		OnStageEnd = function(stage, questData)
			print(`[Example Quest Client] ✅ Stage {stage} ended`)
			-- Markers are automatically cleaned up by QuestHandler
			-- Add any custom cleanup here if needed
		end,
		
		-- Called when the quest is completed
		OnQuestComplete = function(questData)
			print("[Example Quest Client] 🎉 Quest completed!")
			-- Add celebration effects, sounds, etc.
		end,
	}
end

