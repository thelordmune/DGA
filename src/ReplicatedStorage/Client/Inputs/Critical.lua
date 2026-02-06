local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InputModule = {}
InputModule.__index = InputModule
local self = setmetatable({}, InputModule)

self.LastInput = os.clock()

-- For Chrono NPC clones, attributes are on the NPC_MODEL_CACHE model, not the clone
local function getKnockbackAttackerUserId(model, isChronoClone)
	if not isChronoClone then
		return model:GetAttribute("KnockbackAttackerUserId")
	end
	-- Clone name is the ChronoId string
	local cache = ReplicatedStorage:FindFirstChild("NPC_MODEL_CACHE")
	if not cache then return nil end
	local cacheModel = cache:FindFirstChild(model.Name)
	if not cacheModel then return nil end
	return cacheModel:GetAttribute("KnockbackAttackerUserId")
end

-- Check if there's a valid knockback follow-up target
local function findKnockbackTarget(Client)
	local localPlayer = Players.LocalPlayer
	if not localPlayer then return nil end
	if not Client.Character or not Client.Character:FindFirstChild("HumanoidRootPart") then return nil end

	local userId = localPlayer.UserId
	local myRoot = Client.Character.HumanoidRootPart
	local lookDir = myRoot.CFrame.LookVector

	-- Search workspace.World.Live for knocked-back targets matching our userId
	local worldLive = workspace:FindFirstChild("World")
	worldLive = worldLive and worldLive:FindFirstChild("Live")

	local searchLocations = {}
	local isChronoLocation = {}
	if worldLive then
		table.insert(searchLocations, worldLive)
		isChronoLocation[worldLive] = false
	end

	-- Also search client Chrono camera for NPC targets
	for _, child in ipairs(workspace:GetChildren()) do
		if child.Name == "NpcRegistryCamera" and child:IsA("Camera") and child:GetAttribute("ClientOwned") then
			table.insert(searchLocations, child)
			isChronoLocation[child] = true
			break
		end
	end

	for _, location in ipairs(searchLocations) do
		local isChrono = isChronoLocation[location]
		for _, model in ipairs(location:GetChildren()) do
			if model:IsA("Model") and model ~= Client.Character then
				local attackerUserId = getKnockbackAttackerUserId(model, isChrono)
				if attackerUserId == userId then
					local targetRoot = model:FindFirstChild("HumanoidRootPart")
					if targetRoot then
						-- Facing check: must be roughly facing the target
						local toTarget = (targetRoot.Position - myRoot.Position).Unit
						if lookDir:Dot(toTarget) > 0 then
							return model
						end
					end
				end
			end
		end
	end

	return nil
end

InputModule.InputBegan = function(_, Client)
	-- Check for knockback follow-up opportunity before normal M2
	local knockbackTarget = findKnockbackTarget(Client)
	if knockbackTarget then
		-- Send follow-up packet instead of normal Critical
		Client.Packets.KnockbackFollowUp.send()
	else
		-- Normal M2 critical attack
		Client.Packets.Critical.send({Held = true, State = Client.InAir})
	end
	self.LastInput = os.clock()
end

InputModule.InputEnded = function(_, Client)
	Client.Packets.Critical.send({Held = false})
end

InputModule.InputChanged = function()

end

return InputModule
