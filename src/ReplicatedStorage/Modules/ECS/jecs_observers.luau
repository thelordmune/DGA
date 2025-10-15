--!strict
--[[
	ECS Observers Manager
	Centralizes all observers and monitors for the game
	
	This module sets up reactive observers for:
	- NPC spawning/despawning
	- Combat state changes
	- Quest state changes
	- State duration tracking
	- Player loading/unloading
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local world = require(script.Parent.jecs_world)
local comps = require(script.Parent.jecs_components)
local observers = require(script.Parent.observers)
local RefManager = require(script.Parent.jecs_ref_manager)
local Visuals = require(ReplicatedStorage.Modules.Visuals)
local Sift = require(ReplicatedStorage.Modules.Imports.Sift)

local ObserversManager = {}
ObserversManager.activeObservers = {}

--[[
	NPC Observers
]]
function ObserversManager.setupNPCObservers()
	print("[Observers] Setting up NPC observers...")
	
	-- Monitor NPC spawning
	local npcSpawnMonitor = observers.monitor(
		world:query(comps.Character, comps.Mob)
	)
	
	npcSpawnMonitor:added(function(entity)
		local character = world:get(entity, comps.Character)
		if character then
			print("[Observers] NPC spawned:", character.Name, "Entity:", entity)
			-- Store bidirectional reference
			RefManager.entity.set(character, entity)
		end
	end)
	
	npcSpawnMonitor:removed(function(entity)
		local character = world:get(entity, comps.Character)
		if character then
			print("[Observers] NPC despawned:", character.Name)
			RefManager.entity.delete(character)
		end
	end)
	
	table.insert(ObserversManager.activeObservers, npcSpawnMonitor)
	print("[Observers] ✅ NPC spawn monitor active")
end

--[[
	Combat State Observers
]]
function ObserversManager.setupCombatObservers()
	print("[Observers] Setting up combat observers...")
	
	-- Monitor InCombat state changes
	local combatMonitor = observers.monitor(
		world:query(comps.Character, comps.InCombat)
	)
	
	combatMonitor:added(function(entity)
		local inCombat = world:get(entity, comps.InCombat)
		if inCombat and inCombat.value then
			local character = world:get(entity, comps.Character)
			print("[Observers] Entity entered combat:", character and character.Name or entity)
			
			-- Notify client if it's a player
			local playerEntity = world:get(entity, comps.Player)
			if playerEntity then
				Visuals.FireClient(playerEntity, {
					Module = "Base",
					Function = "InCombat",
					Arguments = { playerEntity, true },
				})
			end
		end
	end)
	
	combatMonitor:removed(function(entity)
		local character = world:get(entity, comps.Character)
		print("[Observers] Entity left combat:", character and character.Name or entity)
		
		-- Notify client if it's a player
		local playerEntity = world:get(entity, comps.Player)
		if playerEntity then
			Visuals.FireClient(playerEntity, {
				Module = "Base",
				Function = "InCombat",
				Arguments = { playerEntity, false },
			})
		end
	end)
	
	table.insert(ObserversManager.activeObservers, combatMonitor)
	
	-- Monitor Stun state
	local stunMonitor = observers.monitor(
		world:query(comps.Character, comps.Stun)
	)
	
	stunMonitor:added(function(entity)
		local stun = world:get(entity, comps.Stun)
		if stun and stun.value then
			local character = world:get(entity, comps.Character)
			print("[Observers] Entity stunned:", character and character.Name or entity)
		end
	end)
	
	table.insert(ObserversManager.activeObservers, stunMonitor)
	
	-- Monitor Ragdoll state
	local ragdollMonitor = observers.monitor(
		world:query(comps.Character, comps.Ragdoll)
	)
	
	ragdollMonitor:added(function(entity)
		local ragdoll = world:get(entity, comps.Ragdoll)
		if ragdoll and ragdoll.value then
			local character = world:get(entity, comps.Character)
			print("[Observers] Entity ragdolled:", character and character.Name or entity)
		end
	end)
	
	table.insert(ObserversManager.activeObservers, ragdollMonitor)
	
	print("[Observers] ✅ Combat monitors active")
end

--[[
	Quest Observers
]]
function ObserversManager.setupQuestObservers()
	print("[Observers] Setting up quest observers...")
	
	-- Monitor quest acceptance
	local questAcceptedObserver = observers.observer(
		world:query(comps.QuestAccepted),
		function(entity)
			local questAccepted = world:get(entity, comps.QuestAccepted)
			print("[Observers] Quest accepted:", questAccepted.npcName, questAccepted.questName)
			
			-- Add QuestHolder component
			if not world:has(entity, comps.QuestHolder) then
				world:add(entity, comps.QuestHolder)
			end
			
			-- Convert to ActiveQuest
			world:set(entity, comps.ActiveQuest, {
				npcName = questAccepted.npcName,
				questName = questAccepted.questName,
				startTime = os.clock(),
				progress = {},
			})
			
			-- Load quest data
			local QuestData = require(ReplicatedStorage.Modules.Quests)
			local questData = QuestData[questAccepted.npcName] and QuestData[questAccepted.npcName][questAccepted.questName]
			if questData then
				world:set(entity, comps.QuestData, questData)
			end
			
			-- Remove QuestAccepted component
			world:remove(entity, comps.QuestAccepted)
			
			print("[Observers] Quest started for entity", entity)
		end
	)
	
	table.insert(ObserversManager.activeObservers, questAcceptedObserver)
	
	-- Monitor quest completion
	local questCompletedObserver = observers.observer(
		world:query(comps.CompletedQuest),
		function(entity)
			local completedQuest = world:get(entity, comps.CompletedQuest)
			print("[Observers] Quest completed:", completedQuest.npcName, completedQuest.questName)
			
			-- Schedule cleanup after 10 seconds
			task.delay(10, function()
				if world:contains(entity) and world:has(entity, comps.CompletedQuest) then
					world:remove(entity, comps.CompletedQuest)
					print("[Observers] Cleaned up completed quest for entity", entity)
				end
			end)
		end
	)
	
	table.insert(ObserversManager.activeObservers, questCompletedObserver)
	
	print("[Observers] ✅ Quest observers active")
end

--[[
	Player Observers
]]
function ObserversManager.setupPlayerObservers()
	print("[Observers] Setting up player observers...")
	
	-- Monitor player entities being created
	local playerMonitor = observers.monitor(
		world:query(comps.Character, comps.Player)
	)
	
	playerMonitor:added(function(entity)
		local player = world:get(entity, comps.Player)
		local character = world:get(entity, comps.Character)
		print("[Observers] Player entity created:", player and player.Name or "Unknown", "Entity:", entity)
		
		-- Store reference
		if character then
			RefManager.entity.set(character, entity)
		end
	end)
	
	playerMonitor:removed(function(entity)
		local player = world:get(entity, comps.Player)
		print("[Observers] Player entity removed:", player and player.Name or "Unknown")
	end)
	
	table.insert(ObserversManager.activeObservers, playerMonitor)
	
	print("[Observers] ✅ Player observers active")
end

--[[
	State Change Observers
	Monitor ECS state components for changes
]]
function ObserversManager.setupStateObservers()
	print("[Observers] Setting up state observers...")

	-- Monitor Actions state changes
	local actionsMonitor = observers.monitor(
		world:query(comps.Character, comps.StateActions)
	)

	actionsMonitor:added(function(entity)
		local character = world:get(entity, comps.Character)
		local states = world:get(entity, comps.StateActions)
		-- print(`[State Observer] Actions added to {character.Name}: {table.concat(states, ", ")}`)
	end)

	table.insert(ObserversManager.activeObservers, actionsMonitor)

	-- Monitor Stuns state changes
	local stunsMonitor = observers.monitor(
		world:query(comps.Character, comps.StateStuns)
	)

	stunsMonitor:added(function(entity)
		local character = world:get(entity, comps.Character)
		local states = world:get(entity, comps.StateStuns)
		-- print(`[State Observer] Stuns added to {character.Name}: {table.concat(states, ", ")}`)
	end)

	table.insert(ObserversManager.activeObservers, stunsMonitor)

	print("[Observers] ✅ State observers active")
end

--[[
	Cooldown Observers
	Monitor cooldown component for changes
]]
function ObserversManager.setupCooldownObservers()
	print("[Observers] Setting up cooldown observers...")

	-- Monitor cooldown additions
	local cooldownMonitor = observers.monitor(
		world:query(comps.Character, comps.Cooldowns)
	)

	cooldownMonitor:added(function(entity)
		local character = world:get(entity, comps.Character)
		local cooldowns = world:get(entity, comps.Cooldowns)
		-- print(`[Cooldown Observer] Cooldowns added to {character.Name}`)
	end)

	table.insert(ObserversManager.activeObservers, cooldownMonitor)

	print("[Observers] ✅ Cooldown observers active")
end

--[[
	Initialize all observers
]]
function ObserversManager.init()
	print("[Observers] 🎯 Initializing observer system...")

	ObserversManager.setupNPCObservers()
	ObserversManager.setupCombatObservers()
	ObserversManager.setupQuestObservers()
	ObserversManager.setupPlayerObservers()
	ObserversManager.setupStateObservers()
	ObserversManager.setupCooldownObservers()

	print(`[Observers] ✅ Initialized {#ObserversManager.activeObservers} observers/monitors`)
end

--[[
	Cleanup all observers
]]
function ObserversManager.cleanup()
	print("[Observers] Cleaning up all observers...")
	for _, observer in ipairs(ObserversManager.activeObservers) do
		if observer.disconnect then
			observer:disconnect()
		end
	end
	table.clear(ObserversManager.activeObservers)
	print("[Observers] ✅ All observers cleaned up")
end

return ObserversManager

