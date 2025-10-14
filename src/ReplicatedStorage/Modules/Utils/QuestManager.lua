local ReplicatedStorage = game:GetService("ReplicatedStorage")
local jecs = require(ReplicatedStorage.Modules.Imports.jecs)
local ref = require(ReplicatedStorage.Modules.ECS.jecs_ref)
local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)
local world = require(ReplicatedStorage.Modules.ECS.jecs_world)
local NotificationManager = require(ReplicatedStorage.Client.NotificationManager)

local QuestManager = {}

function QuestManager.acceptQuest(player, npcname, questName)
	local playerEntity = ref.get("local_player", player)

	if not playerEntity then
		warn("[QuestManager] No player entity found for", player)
		return
	end

	if world:has(playerEntity, comps.ActiveQuest) then
		local activeQuest = world:get(playerEntity, comps.ActiveQuest)
		if activeQuest.npcName == npcname and activeQuest.questName == questName then
			warn("[QuestManager] Quest already accepted")
			return
		end
	end

	if not world:has(playerEntity, comps.QuestHolder) then
		world:add(playerEntity, comps.QuestHolder)
	end

	-- Set ActiveQuest directly on client for immediate UI updates
	-- Server will also set this when it processes QuestAccepted
	world:set(playerEntity, comps.ActiveQuest, {
		npcName = npcname,
		questName = questName,
		startTime = os.clock(),
		progress = {},
	})

	-- Also set QuestAccepted so server knows to process it
	world:set(playerEntity, comps.QuestAccepted, {
		npcName = npcname,
		questName = questName,
		acceptedAt = os.clock(),
	})

	print("[QuestManager] Quest accepted on client:", npcname, questName)

	-- Show quest notification
	NotificationManager.ShowQuest(questName)
end

function QuestManager.getActiveQuests(player)
	local playerEntity = ref.get("player", player)  -- Fixed: Use "player" instead of "local_player"
	if not playerEntity or not world:contains(playerEntity) then
		return {}
	end

	if not world:has(playerEntity, comps.ActiveQuest) then
		return {}
	end

	local activeQuest = world:get(playerEntity, comps.ActiveQuest)
	return { activeQuest }
end

function QuestManager.hasActiveQuest(player, npcname, questName)
    local playerEntity = ref.get("player", player)  -- Fixed: Use "player" instead of "local_player"
    if not playerEntity or not world:contains(playerEntity) then
        return false
    end

    if not world:has(playerEntity, comps.ActiveQuest) then
        return false
    end

    local activeQuest = world:get(playerEntity, comps.ActiveQuest)
    return activeQuest.npcName == npcname and activeQuest.questName == questName
end

function QuestManager.completedQuest(player, npcName, questName)
    local playerEntity = ref.get("local_player", player)
    if not playerEntity or not world:contains(playerEntity) then
        return
    end

    if not world:has(playerEntity, comps.CompletedQuest) then
        return
    end

    local activeQuest = world:get(playerEntity, comps.ActiveQuest)
    if activeQuest.npcName ~= npcName and activeQuest.questName ~= questName then
        return false
    end

    world:set(playerEntity, comps.CompletedQuest, {
        npcName = npcName,
        questName = questName,
        completedTime = os.clock(),
    })

    world:remove(playerEntity, comps.ActiveQuest)
    if world:has(playerEntity, comps.QuestData) then
        world:remove(playerEntity, comps.QuestData)
    end

    return true
end

function QuestManager.getAllActiveQuests()
    local activeQuests = {}

    for entity in world:query(comps.ActiveQuest, comps.Player):iter() do
        local activeQuest = world:get(entity, comps.ActiveQuest)
        local player = world:get(entity, comps.Player)
        table.insert(activeQuests, {
            player = player,
            quest = activeQuest,
        })
    end

    return activeQuests
end

return QuestManager
