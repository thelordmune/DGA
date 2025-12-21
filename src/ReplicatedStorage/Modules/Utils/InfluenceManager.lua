--[[
	InfluenceManager

	Handles the Influence/Reputation system including:
	- Pickpocketing wanderer NPCs
	- Reputation tracking (-100 to +100)
	- Wanted level management
	- Guard spawning for criminals
	- NPC flee behavior for bad reputation
	- Jail sentencing

	Reputation Thresholds:
	- Criminal: -100 to -50 (NPCs flee, guards attack on sight)
	- Suspicious: -49 to -20 (Some NPCs nervous)
	- Neutral: -19 to +19 (Default)
	- Respected: +20 to +49 (Better prices, more dialogue options)
	- Honored: +50 to +100 (Special quests, NPC assistance)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local InfluenceManager = {}

-- Constants
InfluenceManager.PICKPOCKET_COOLDOWN = 5 -- Seconds between pickpocket attempts
InfluenceManager.PICKPOCKET_SUCCESS_CHANCE = 0.6 -- 60% base success rate
InfluenceManager.PICKPOCKET_REPUTATION_LOSS = 5 -- Reputation lost per pickpocket
InfluenceManager.PICKPOCKET_FAIL_REPUTATION_LOSS = 10 -- Extra loss on failure
InfluenceManager.GUARD_SPAWN_THRESHOLD = 3 -- Pickpockets before guards spawn
InfluenceManager.JAIL_TIME_PER_CRIME = 30 -- Seconds of jail per crime level

-- Loot tables by occupation
InfluenceManager.LOOT_TABLES = {
	["State Alchemist"] = {
		money = {min = 50, max = 200},
		items = {"Alchemy Notes", "Research Journal", "Philosopher's Stone Fragment"},
		itemChance = 0.15,
	},
	["Soldier"] = {
		money = {min = 20, max = 80},
		items = {"Military Rations", "Ammo Pouch", "Dog Tags"},
		itemChance = 0.2,
	},
	["Military Police"] = {
		money = {min = 30, max = 100},
		items = {"Handcuffs", "Wanted Poster", "Badge"},
		itemChance = 0.1,
	},
	["Intelligence Agent"] = {
		money = {min = 40, max = 150},
		items = {"Coded Message", "Secret Documents", "Spy Gadget"},
		itemChance = 0.25,
	},
	["Automail Engineer"] = {
		money = {min = 60, max = 180},
		items = {"Automail Parts", "Precision Tools", "Oil Can"},
		itemChance = 0.3,
	},
	["Merchant"] = {
		money = {min = 100, max = 300},
		items = {"Rare Goods", "Trade License", "Gold Coin"},
		itemChance = 0.35,
	},
	["Blacksmith"] = {
		money = {min = 40, max = 120},
		items = {"Metal Ingot", "Smithing Hammer", "Blade Fragment"},
		itemChance = 0.25,
	},
	["Doctor"] = {
		money = {min = 50, max = 150},
		items = {"Medical Supplies", "Medicine Bottle", "Surgical Tools"},
		itemChance = 0.3,
	},
	["Librarian"] = {
		money = {min = 10, max = 50},
		items = {"Rare Book", "Ancient Scroll", "Research Notes"},
		itemChance = 0.4,
	},
	["Farmer"] = {
		money = {min = 5, max = 30},
		items = {"Fresh Produce", "Seeds", "Farm Tools"},
		itemChance = 0.2,
	},
}

-- Default loot for unknown occupations
InfluenceManager.DEFAULT_LOOT = {
	money = {min = 10, max = 50},
	items = {"Pocket Watch", "Handkerchief", "Loose Change"},
	itemChance = 0.1,
}

-- Reputation tier thresholds
InfluenceManager.REPUTATION_TIERS = {
	{ name = "Criminal", min = -100, max = -50, fleeChance = 0.8 },
	{ name = "Suspicious", min = -49, max = -20, fleeChance = 0.3 },
	{ name = "Neutral", min = -19, max = 19, fleeChance = 0 },
	{ name = "Respected", min = 20, max = 49, fleeChance = 0 },
	{ name = "Honored", min = 50, max = 100, fleeChance = 0 },
}

-- Get reputation tier from value
function InfluenceManager.getReputationTier(reputation: number): {name: string, fleeChance: number}
	reputation = math.clamp(reputation or 0, -100, 100)

	for _, tier in ipairs(InfluenceManager.REPUTATION_TIERS) do
		if reputation >= tier.min and reputation <= tier.max then
			return tier
		end
	end

	return InfluenceManager.REPUTATION_TIERS[3] -- Default to Neutral
end

-- Check if NPC should flee from player based on reputation
function InfluenceManager.shouldNPCFlee(reputation: number): boolean
	local tier = InfluenceManager.getReputationTier(reputation)
	return math.random() < tier.fleeChance
end

-- Calculate pickpocket success chance
function InfluenceManager.calculateSuccessChance(playerData, npcOccupation: string): number
	local baseChance = InfluenceManager.PICKPOCKET_SUCCESS_CHANCE

	-- Reduce chance based on how many times player has pickpocketed
	local attemptPenalty = (playerData.Influence.PickpocketCount or 0) * 0.02
	baseChance = baseChance - attemptPenalty

	-- Military occupations are harder to pickpocket
	local militaryOccupations = {"State Alchemist", "Soldier", "Military Police", "Intelligence Agent"}
	for _, occ in ipairs(militaryOccupations) do
		if occ == npcOccupation then
			baseChance = baseChance - 0.15
			break
		end
	end

	return math.clamp(baseChance, 0.1, 0.9) -- Min 10%, max 90%
end

-- Generate loot from pickpocket
function InfluenceManager.generateLoot(occupation: string): {money: number, item: string?}
	local lootTable = InfluenceManager.LOOT_TABLES[occupation] or InfluenceManager.DEFAULT_LOOT

	-- Calculate money
	local money = math.random(lootTable.money.min, lootTable.money.max)

	-- Check for item drop
	local item = nil
	if math.random() < lootTable.itemChance then
		item = lootTable.items[math.random(1, #lootTable.items)]
	end

	return {
		money = money,
		item = item,
	}
end

-- Calculate jail time based on crimes
function InfluenceManager.calculateJailTime(influence): number
	local baseTime = InfluenceManager.JAIL_TIME_PER_CRIME
	local wantedLevel = influence.WantedLevel or 0
	local crimesCommitted = influence.CrimesCommitted or 0

	-- More crimes = longer jail time
	local time = baseTime + (crimesCommitted * 10) + (wantedLevel * 20)

	return math.clamp(time, 30, 300) -- 30 seconds to 5 minutes max
end

-- Check if guards should spawn on player
function InfluenceManager.shouldSpawnGuards(influence): boolean
	local pickpocketCount = influence.SuccessfulPickpockets or 0
	local wantedLevel = influence.WantedLevel or 0

	-- Spawn guards if pickpocket threshold reached or wanted level high
	return pickpocketCount >= InfluenceManager.GUARD_SPAWN_THRESHOLD or wantedLevel >= 2
end

-- Server-side functions (only run on server)
if RunService:IsServer() then
	local Global = require(ReplicatedStorage.Modules.Shared.Global)

	-- Perform pickpocket attempt
	function InfluenceManager.attemptPickpocket(player, npcId: string, npcOccupation: string)
		local playerData = Global.GetData(player)
		if not playerData then
			return false, "Player data not found", nil
		end

		-- Check cooldown
		local now = os.time()
		local lastPickpocket = playerData.Influence.LastCrimeTime or 0
		if now - lastPickpocket < InfluenceManager.PICKPOCKET_COOLDOWN then
			return false, "Too soon to pickpocket again", nil
		end

		-- Calculate success
		local successChance = InfluenceManager.calculateSuccessChance(playerData, npcOccupation)
		local success = math.random() < successChance

		-- Update player data
		Global.SetData(player, function(data)
			if not data.Influence then
				data.Influence = {
					Reputation = 0,
					PickpocketCount = 0,
					SuccessfulPickpockets = 0,
					CrimesCommitted = 0,
					JailTime = 0,
					LastCrimeTime = 0,
					WantedLevel = 0,
					GuardsSpawnedOn = 0,
				}
			end

			data.Influence.PickpocketCount = (data.Influence.PickpocketCount or 0) + 1
			data.Influence.LastCrimeTime = now
			data.Influence.CrimesCommitted = (data.Influence.CrimesCommitted or 0) + 1

			if success then
				data.Influence.SuccessfulPickpockets = (data.Influence.SuccessfulPickpockets or 0) + 1
				data.Influence.Reputation = math.clamp(
					(data.Influence.Reputation or 0) - InfluenceManager.PICKPOCKET_REPUTATION_LOSS,
					-100,
					100
				)
			else
				-- Failed pickpocket is worse for reputation
				data.Influence.Reputation = math.clamp(
					(data.Influence.Reputation or 0) - InfluenceManager.PICKPOCKET_REPUTATION_LOSS - InfluenceManager.PICKPOCKET_FAIL_REPUTATION_LOSS,
					-100,
					100
				)
				-- Increase wanted level on failure
				data.Influence.WantedLevel = math.min((data.Influence.WantedLevel or 0) + 1, 5)
			end

			-- Update alignment (pickpocketing is evil)
			data.Alignment = math.clamp((data.Alignment or 0) - 3, -100, 100)

			return data
		end)

		local loot = nil
		if success then
			loot = InfluenceManager.generateLoot(npcOccupation)

			-- Add money to player
			Global.SetData(player, function(data)
				data.Stats.Money = (data.Stats.Money or 0) + loot.money
				return data
			end)
		end

		-- Check if guards should spawn
		local updatedData = Global.GetData(player)
		local shouldSpawn = InfluenceManager.shouldSpawnGuards(updatedData.Influence)

		return success, success and "Pickpocket successful!" or "You were caught!", loot, shouldSpawn
	end

	-- Update NPC relationship after pickpocket
	function InfluenceManager.setNPCHostile(player, npcId: string)
		local RelationshipManager = require(ReplicatedStorage.Modules.Utils.RelationshipManager)

		Global.SetData(player, function(data)
			if not data.NPCRelationships then
				data.NPCRelationships = {}
			end

			-- Set relationship to minimum (enemy)
			if data.NPCRelationships[npcId] then
				data.NPCRelationships[npcId].value = 0
			else
				data.NPCRelationships[npcId] = {
					value = 0,
					name = "Unknown",
					occupation = "Civilian",
					personality = "Hostile",
					appearance = nil,
				}
			end

			return data
		end)
	end

	-- Send player to jail
	function InfluenceManager.jailPlayer(player, duration: number?)
		local playerData = Global.GetData(player)
		if not playerData then return false end

		local jailTime = duration or InfluenceManager.calculateJailTime(playerData.Influence)

		-- Update player data
		Global.SetData(player, function(data)
			data.Influence.JailTime = jailTime
			-- Reset wanted level after jailing
			data.Influence.WantedLevel = 0
			return data
		end)

		-- Get random jail cell
		local jailFolder = workspace.World:FindFirstChild("AreaSpawns")
		local jailCells = jailFolder and jailFolder:FindFirstChild("Jail")

		if jailCells then
			local cells = jailCells:GetChildren()
			if #cells > 0 then
				local randomCell = cells[math.random(1, #cells)]
				if randomCell:IsA("BasePart") then
					local character = player.Character
					if character then
						local hrp = character:FindFirstChild("HumanoidRootPart")
						if hrp then
							hrp.CFrame = randomCell.CFrame + Vector3.new(0, 3, 0)
						end
					end
				end
			end
		end

		return true, jailTime
	end

	-- Sync influence data to client
	function InfluenceManager.syncToClient(player)
		local Bridges = require(ReplicatedStorage.Modules.Bridges)
		local playerData = Global.GetData(player)

		if playerData and playerData.Influence then
			Bridges.UpdateInfluence:FireTo(player, {
				reputation = playerData.Influence.Reputation or 0,
				wantedLevel = playerData.Influence.WantedLevel or 0,
				jailTime = playerData.Influence.JailTime or 0,
			})
		end

		-- Also sync money
		if playerData and playerData.Stats then
			Bridges.UpdateMoney:FireTo(player, {
				money = playerData.Stats.Money or 0,
			})
		end
	end
end

return InfluenceManager
