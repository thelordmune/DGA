--[[
	Modernized NPC System using jecs-utils ref

	This system now uses the new ref system to track NPCs.
	Observers handle spawn/despawn events automatically.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)
local world = require(ReplicatedStorage.Modules.ECS.jecs_world)
local RefManager = require(ReplicatedStorage.Modules.ECS.jecs_ref_manager)
local Players = game:GetService("Players")

-- Function to initialize NPC entity with all components
local function initializeNPCEntity(npcModel: Model): number
	-- Use new ref system with initializer function
	local entity = RefManager.entity(npcModel, function(e)
		-- Set all NPC components
		world:set(e, comps.Character, npcModel)
		world:set(e, comps.Mob, true)
		world:set(e, comps.Health, {current = 175, max = 175, tick = 0.5, tickspeed = 0.1})
		world:set(e, comps.Energy, {current = 100, tick = 0.5, tickspeed = 0.1})
		world:set(e, comps.Combat, { weapon = "Fist", equipped = true, animation = "Fist" })
		world:set(e, comps.Attacking, {duration = 0, value = false})
		world:set(e, comps.Stun, {duration = 0, value = false})
		world:set(e, comps.NoRotate, {duration = 0, value = false})
		world:set(e, comps.Dashing, false)
		world:set(e, comps.Blocking, {duration = 0, value = false})
		world:set(e, comps.Carrying, {target = nil, value = false})
		world:set(e, comps.BeingGripped, false)
		world:set(e, comps.BeingCarried, false)
		world:set(e, comps.DeathLocation, CFrame.new(0,0,0))
		world:set(e, comps.Knocked, {duration = 0, value = false})
		world:set(e, comps.IFrame, {duration = 0, value = false})
		world:set(e, comps.Sprinting, false)
		world:set(e, comps.Ragdoll, {duration = 0, value = false})
		world:set(e, comps.CantMove, {duration = 0, value = false})
		world:set(e, comps.Dead, false)
		world:set(e, comps.Weapon, {name = "Fist", type = "Fist"})
		world:set(e, comps.Swing, 1)
		world:set(e, comps.WallRunning, false)
		world:set(e, comps.Sliding, false)
		world:set(e, comps.NoJump, {duration = 0, value = false})
		world:set(e, comps.ToSpeed, 0)
		world:set(e, comps.KeysLogged, 1)
		world:set(e, comps.Light, {duration = 0, value = false})
		world:set(e, comps.NoDash, {duration = 0, value = false})
		world:set(e, comps.LastHit, 0)
		world:set(e, comps.CritCD, {duration = 0, value = false})
		world:set(e, comps.Heavy, {duration = 0, value = false})
		world:set(e, comps.IgnoreParry, {duration = 0, value = false})
		world:set(e, comps.NoHurt, {duration = 0, value = false})
		world:set(e, comps.Damage, 0)
		world:set(e, comps.ParryTick, {duration = 0, value = false})
		world:set(e, comps.ParryStun, {duration = 0, value = false})
		world:set(e, comps.InAir, false)
		world:set(e, comps.Utility, {duration = 0, value = false})
		world:set(e, comps.Victim, nil)
		world:set(e, comps.Action, {duration = 0, value = false})
		world:set(e, comps.BlockBar, {Value = 100, MaxValue = 100})
		world:set(e, comps.BBRegen, {duration = 0, value = false})
		world:set(e, comps.BlockBroken, false)
		world:set(e, comps.Armor, {duration = 0, armortype = "None", value = false})
		world:set(e, comps.QDC, {duration = 0, value = false})
		world:set(e, comps.NoRagdoll, false)
		world:set(e, comps.Locked, {duration = 0, value = false})

		print("[Mobs] Initialized NPC:", npcModel.Name, "Entity:", e)
	end)

	return entity
end

return {
	run = function(world)
		-- Skip if more than 1 player (temporary restriction)
		if #Players:GetPlayers() > 1 then return end

		-- Scan for new NPCs in workspace
		for _, descendant in workspace.World.Live:GetDescendants() do
			if descendant:IsA("Model") and not Players:GetPlayerFromCharacter(descendant) then
				-- Check if NPC already has an entity
				local existingEntity = RefManager.entity.find(descendant)

				if not existingEntity then
					-- Initialize new NPC
					initializeNPCEntity(descendant)
				end
			end
		end
	end,

	settings = {
		phase = "Heartbeat",
		depends_on = {},
		server_only = true
	}
}