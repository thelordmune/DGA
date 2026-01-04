local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Ragdoll = require(ReplicatedStorage.Modules.Utils.Ragdoll)

local module = {}

local function setupCharacter(character)
	if character:IsDescendantOf(workspace.World.Live) and not character:GetAttribute("NotActualRig") then
		Ragdoll:Setup(character)
		---- print(`[RagdollSetup] Successfully set up ragdoll for {character.Name}`)
	end
end

local function init()
	-- Wait a bit for the workspace to be ready
	task.wait(1)

	-- Setup ragdoll for all existing humanoid characters (NPCs)
	for _, character in CollectionService:GetTagged("Humanoids") do
		setupCharacter(character)
	end

	-- Setup ragdoll for all existing player characters
	for _, character in CollectionService:GetTagged("Players") do
		setupCharacter(character)
	end

	-- Setup ragdoll for new humanoid characters as they're added (NPCs)
	CollectionService:GetInstanceAddedSignal("Humanoids"):Connect(function(character)
		setupCharacter(character)
	end)

	-- Setup ragdoll for new player characters as they're added
	CollectionService:GetInstanceAddedSignal("Players"):Connect(function(character)
		setupCharacter(character)
	end)

	---- print("[RagdollSetup] Ragdoll system initialized")
end

task.spawn(init)

return module

