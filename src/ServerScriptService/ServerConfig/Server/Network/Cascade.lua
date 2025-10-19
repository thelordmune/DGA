local ServerStorage = game:GetService("ServerStorage")
local Replicated = game:GetService("ReplicatedStorage")
local Server
local Utilities = require(Replicated.Modules.Utilities)
local Library = require(Replicated.Modules.Library)
local Packets = require(Replicated.Modules.Packets)
local Visuals = require(Replicated.Modules.Visuals)
local Voxbreaker = require(Replicated.Modules.Voxel)
local SFX = Replicated.Assets.SFX
local WeaponStats = require(ServerStorage.Stats._Weapons)
local Moves = require(ServerStorage.Stats._Moves)
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local RunService = game:GetService("RunService")

local NetworkModule = {}
local Server = require(script.Parent.Parent)
NetworkModule.__index = NetworkModule
local self = setmetatable({}, NetworkModule)

local activeConnections = {}
local activeTweens = {}

local function cleanUp()
	for _, conn in pairs(activeConnections) do
		conn:Disconnect()
	end
	activeConnections = {}

	for _, t in pairs(activeTweens) do
		t:Cancel()
	end
	activeTweens = {}
end

NetworkModule.EndPoint = function(Player, Data)
	local Character = Player.Character

	if not Character then
		return
	end

	-- Check if this is an NPC (no Player instance) or a real player
	local isNPC = typeof(Player) ~= "Instance" or not Player:IsA("Player")

	-- For players, check equipped status
	if not isNPC and not Character:GetAttribute("Equipped") then
		return
	end

	local PlayerObject = Server.Modules["Players"].Get(Player)
	local Animation = Replicated.Assets.Animations.Abilities.Stone[script.Name]
	local Hitbox = Server.Modules.Hitbox
	local Entity = Server.Modules["Entities"].Get(Character)

	local root = Character:FindFirstChild("HumanoidRootPart")

	if Server.Library.StateCount(Character.Actions) or Server.Library.StateCount(Character.Stuns) then
		return
	end

	-- For NPCs, skip the PlayerObject.Keys check
	local canUseSkill = isNPC or (PlayerObject and PlayerObject.Keys)

	if canUseSkill and not Server.Library.CheckCooldown(Character, "Cascade") then
		cleanUp()
		Server.Library.SetCooldown(Character, "Cascade", 8) -- Increased from 3 to 8 seconds
		Server.Library.StopAllAnims(Character)

		local Alchemy = Library.PlayAnimation(Character, Animation)
		Alchemy.Looped = false
		-- Alchemy:Play()

		local animlength = Alchemy.Length

		local hittimes = {}
		for i, fraction in Moves.Stone.Cascade.HitTimes do
			hittimes[i] = fraction * animlength
		end

		Server.Library.TimedState(Character.Actions, "Cascade", Alchemy.Length)
		Server.Library.TimedState(Character.Stuns, "NoRotate", Alchemy.Length)
		Server.Library.TimedState(Character.Stuns, "AlcJump-0", Alchemy.Length)  -- Prevent jumping during Cascade
		Server.Library.TimedState(Character.Speeds, "AlcSpeed-0", Alchemy.Length)

		task.delay(hittimes[1], function()
			Server.Visuals.Ranged(Character.HumanoidRootPart.Position, 300, {
				Module = "Base",
				Function = "Cascade",
				Arguments = { Character, "Start" },
			})
		end)
		task.delay(hittimes[2], function()
			Server.Visuals.Ranged(Character.HumanoidRootPart.Position, 300, {
				Module = "Base",
				Function = "Cascade",
				Arguments = { Character, "Summon" },
			})
		end)

		local Spikes = Replicated.Assets.VFX.Spikes:Clone()
		Spikes.Parent = workspace.World.Visuals

		for i = 3, #hittimes do
            task.delay(hittimes[i], function()
                -- Calculate which row to spawn (i-2 because we start at index 3)
                local rowIndex = i - 2
                local rowName = "Row" .. rowIndex

                -- print("Spawning", rowName, "at hittime", i, "delay:", hittimes[i])

                -- Get the row folder from cloned Spikes
                local rowFolder = Spikes:FindFirstChild(rowName)
                if not rowFolder then
                    warn("Row folder not found:", rowName)
                    return
                end

                -- Get the Model inside the row folder
                local rowModel = rowFolder:FindFirstChild("Model")
                if not rowModel then
                    warn("Model not found in:", rowName)
                    return
                end

                -- print("Found row model:", rowModel.Name, "with", #rowModel:GetChildren(), "spikes")

                -- Calculate spawn position in front of player - each row further out
                local baseDistance = (1.5 + (rowIndex * 5)) --rowIndex == 1 and 3 or  -- First row further back
                local targetY = rowIndex == 1 and -2 or 0 -- First row lower than others
                local startCFrame = Character.HumanoidRootPart.CFrame
                    * CFrame.new(0, -8, -baseDistance)
                    * CFrame.Angles(0, math.rad(180), 0)
                local targetCFrame = Character.HumanoidRootPart.CFrame
                    * CFrame.new(0, targetY, -baseDistance)
                    * CFrame.Angles(0, math.rad(180), 0)

                -- print("Spawn CFrame for", rowName, ":", startCFrame, "distance:", baseDistance)

                -- Clone the entire row model
                local spikeRow = rowModel:Clone()
                spikeRow.Parent = workspace.World.Visuals

                -- Position the row underground initially
                spikeRow:SetPrimaryPartCFrame(startCFrame)

                -- Animate with RenderStepped - more aggressive
                local startTime = tick()
                local duration = 0.2
                local connection
                connection = RunService.Heartbeat:Connect(function()
                    local elapsed = tick() - startTime
                    local alpha = math.min(elapsed / duration, 1)
                    
                    -- More aggressive ease out function
                    alpha = 1 - (1 - alpha)^4
                    
                    local currentCFrame = startCFrame:Lerp(targetCFrame, alpha)
                    spikeRow:SetPrimaryPartCFrame(currentCFrame)
                    
                    if alpha >= 1 then
                        connection:Disconnect()
                    end
                end)
                
                table.insert(activeConnections, connection)

                -- print("Animation started for row:", rowName)

                -- Do damage when spikes emerge
                task.delay(0.1, function()
                    -- print("Checking for damage targets around row:", rowName)

                    -- Check damage for each spike in the row
                    for _, spike in pairs(spikeRow:GetChildren()) do
                        if spike:IsA("MeshPart") then
                            local HitTargets = Hitbox.SpatialQuery(
                                Character,
                                Vector3.new(4, 8, 4), -- Spike hitbox size
                                spike.CFrame,
                                false
                            )

                            -- print("Found", #HitTargets, "targets for spike:", spike.Name)
                            for _, Target in pairs(HitTargets) do
                                -- print("Damaging target:", Target.Name, "with spike:", spike.Name)
                                Server.Modules.Damage.Tag(Character, Target, Moves.Stone.Cascade["Rapid"])
                            end
                        end
                    end
                end)

                -- Clean up row after a few seconds
                Debris:AddItem(spikeRow, 5)
                -- print("Row cleanup scheduled for:", rowName)

                -- print("Finished spawning", rowName)
            end)
        end
	end
end

return NetworkModule
