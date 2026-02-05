local ReplicatedStorage = game:GetService("ReplicatedStorage")
local jecs = require(ReplicatedStorage.Modules.Imports.jecs)
local ref = require(ReplicatedStorage.Modules.ECS.jecs_ref)
local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)
local world = require(ReplicatedStorage.Modules.ECS.jecs_world)
local Global = require(ReplicatedStorage.Modules.Shared.Global)
local Passives = require(ReplicatedStorage.Modules.Shared.Passives)

local PassiveManager = {}

function PassiveManager.addPassive(entity, passiveName, passiveCategory)
    if not entity then return end

    local passiveData = nil
    if passiveCategory and Passives[passiveCategory] and Passives[passiveCategory][passiveName] then
        passiveData = Passives[passiveCategory][passiveName]
    else
        for category, passives in pairs(Passives) do
            if passives[passiveName] then
                passiveData = passives[passiveName]
                break
            end
        end
    end

    if not passiveData then
        warn("Passive not found:", passiveName)
        return
    end

    if not world:has(entity, comps.PassiveHolder) then
        world:add(entity, comps.PassiveHolder)
    end

    if not world:has(entity, comps.Passive) then
        world:add(entity, comps.Passive)
    end

    local passives = world:get(entity, comps.Passive) or {}
    
    table.insert(passives, {
        name = passiveData.name,
        description = passiveData.description,
        cooldown = passiveData.cooldown
    })
    
    world:set(entity, comps.Passive, passives)
end

function PassiveManager.hasPassive(plr, entity, passiveName)
    if not plr then
        return false
    end

    local pdata = Global.GetData(plr)

    if not table.find(pdata.Passives, passiveName) then
        return false
    end

    if not world:has(entity, comps.Passive) then
        return false
    end

    local passives = world:get(entity, comps.Passive)
    for _, passive in pairs(passives) do
        if passive.name == passiveName then
            return true
        end
    end

    return false
end

return PassiveManager