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
	local cache = ReplicatedStorage:FindFirstChild("NPC_MODEL_CACHE")
	if not cache then return nil end
	local cacheModel = cache:FindFirstChild(model.Name)
	if not cacheModel then return nil end
	return cacheModel:GetAttribute("KnockbackAttackerUserId")
end

-- Check if there's a valid knockback follow-up target
local function findKnockbackTarget(Client)
	local localPlayer = Players.LocalPlayer
	if not localPlayer then
		print("[KBFollowUp] No LocalPlayer")
		return nil
	end
	if not Client.Character or not Client.Character:FindFirstChild("HumanoidRootPart") then
		print("[KBFollowUp] No character or HRP")
		return nil
	end

	local userId = localPlayer.UserId
	local myRoot = Client.Character.HumanoidRootPart
	local lookDir = myRoot.CFrame.LookVector

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

	print(`[KBFollowUp] Searching {#searchLocations} locations, userId={userId}`)

	for _, location in ipairs(searchLocations) do
		local isChrono = isChronoLocation[location]
		for _, model in ipairs(location:GetChildren()) do
			if model:IsA("Model") and model ~= Client.Character then
				local attackerUserId = getKnockbackAttackerUserId(model, isChrono)
				if attackerUserId then
					print(`[KBFollowUp] Found model {model.Name} isChrono={isChrono} attackerUserId={attackerUserId} (need {userId})`)
				end
				if attackerUserId == userId then
					local targetRoot = model:FindFirstChild("HumanoidRootPart")
					if targetRoot then
						local toTarget = (targetRoot.Position - myRoot.Position).Unit
						local dot = lookDir:Dot(toTarget)
						print(`[KBFollowUp] Dot product: {dot}`)
						if dot > 0 then
							print(`[KBFollowUp] FOUND TARGET: {model.Name}`)
							return model
						else
							print(`[KBFollowUp] Not facing target (dot={dot})`)
						end
					else
						print(`[KBFollowUp] Model {model.Name} has no HumanoidRootPart`)
					end
				end
			end
		end
	end

	print("[KBFollowUp] No valid target found")
	return nil
end

InputModule.InputBegan = function(_, Client)
	-- M2 during left/right dash = cancel with CancelLeft/CancelRight animation
	if Client.Dodging and Client.DashDirection then
		local dir = Client.DashDirection
		if dir == "Left" or dir == "Right" then
			Client.Modules['Movement'].CancelDashWithAnimation("Cancel" .. dir)
			return
		end
	end

	local knockbackTarget = findKnockbackTarget(Client)
	if knockbackTarget then
		Client.Packets.KnockbackFollowUp.send()
	end
	self.LastInput = os.clock()
end

InputModule.InputEnded = function(_, Client)
end

InputModule.InputChanged = function()

end

return InputModule
