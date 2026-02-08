-- Truth Quest Module
-- Handles the "TruthPayment" action triggered when dialogue ends
-- Causes organ/limb loss and returns player to original position

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Visuals = require(ReplicatedStorage.Modules.Visuals)
local world = require(ReplicatedStorage.Modules.ECS.jecs_world)
local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)
local LimbManager = require(ReplicatedStorage.Modules.Utils.LimbManager)
local RefManager = require(ReplicatedStorage.Modules.ECS.jecs_ref_manager)
local Global = require(ReplicatedStorage.Modules.Shared.Global)
local bridges = require(ReplicatedStorage.Modules.Bridges)
local Ragdoll = require(ReplicatedStorage.Modules.Utils.Ragdoll)

local TruthQuest = {}

-- Organs that can be taken (debilitating effects)
local ORGANS = {
	{
		name = "LeftArm",
		message = "Your left arm crumbles to dust.",
		debuff = "You feel weaker... your strikes lack power."
	},
	{
		name = "RightArm",
		message = "Your right arm dissolves into nothing.",
		debuff = "Your grip falters... combat will be difficult."
	},
	{
		name = "LeftLeg",
		message = "Your left leg shatters like glass.",
		debuff = "Your movement is hindered... you limp forward."
	},
	{
		name = "RightLeg",
		message = "Your right leg is consumed by the void.",
		debuff = "You struggle to stand... balance is lost."
	},
}

-- Called when Truth dialogue triggers "TruthPayment" action
function TruthQuest.TruthPayment(Player)
	-- Only run on server
	if RunService:IsClient() then return end

	local Character = Player.Character
	if not Character then return end

	-- Get player entity for limb state
	local ref = RefManager.player
	local playerEntity = ref.get("player", Player)

	-- Get current limb state
	local limbState = nil
	if playerEntity then
		limbState = world:get(playerEntity, comps.LimbState)
	end

	if not limbState then
		limbState = LimbManager.GetDefaultLimbState()
	end

	-- Find an available limb to take
	local availableOrgans = {}
	for _, organ in ipairs(ORGANS) do
		if LimbManager.IsLimbAttached(limbState, organ.name) then
			table.insert(availableOrgans, organ)
		end
	end

	-- Pick a random available organ
	local chosenOrgan = nil
	if #availableOrgans > 0 then
		chosenOrgan = availableOrgans[math.random(#availableOrgans)]
	else
		-- All limbs already gone - pick a random one anyway for the message
		chosenOrgan = ORGANS[math.random(#ORGANS)]
	end

	-- Sever the limb if attached
	if LimbManager.IsLimbAttached(limbState, chosenOrgan.name) then
		local success = LimbManager.SeverLimb(Character, chosenOrgan.name)
		if success then
			-- Update limb state in ECS
			if chosenOrgan.name == "LeftArm" then limbState.leftArm = false
			elseif chosenOrgan.name == "RightArm" then limbState.rightArm = false
			elseif chosenOrgan.name == "LeftLeg" then limbState.leftLeg = false
			elseif chosenOrgan.name == "RightLeg" then limbState.rightLeg = false
			end

			limbState.bleedingStacks = limbState.bleedingStacks + 1

			if playerEntity then
				world:set(playerEntity, comps.LimbState, limbState)
			end

			-- Save to player data
			Global.SetData(Player, function(data)
				data.LimbState = limbState
				return data
			end)

			-- Trigger bleeding visual effect
			Visuals.Ranged(Character.HumanoidRootPart.Position, 300, {
				Module = "Misc",
				Function = "EnableStatus",
				Arguments = { Character, "Bleeding" },
			})
		end
	end

	-- Apply ragdoll for the knockback (2.5 seconds - until white fade starts)
		Ragdoll.Ragdoll(Character, 3.5)
	--Ragdoll.Ragdoll(Character, 3.5)

	-- Fire client-side effects (notification, screen effects, return teleport)
	Visuals.FireClient(Player, {
		Module = "Misc",
		Function = "TruthConsequence",
		Arguments = {
			Character,
			chosenOrgan.message,
			chosenOrgan.debuff,
		}
	})

	-- Wait for effects then return player to original position
	task.delay(4, function()
		-- Fire to client to stop Truth room sounds
		bridges.TruthReturn:Fire(Player)

		-- Return player to original position (server-side)
		local TruthNetwork = require(ServerScriptService.ServerConfig.Server.Network.Truth)
		TruthNetwork.ReturnPlayer(Player)
	end)
end

return TruthQuest
