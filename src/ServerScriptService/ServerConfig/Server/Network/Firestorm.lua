local ServerStorage = game:GetService("ServerStorage")
local Replicated = game:GetService("ReplicatedStorage")
local Utilities = require(Replicated.Modules.Utilities)
local Library = require(Replicated.Modules.Library)
local Packets = require(Replicated.Modules.Packets)
local Visuals = require(Replicated.Modules.Visuals)
local WeaponStats = require(ServerStorage.Stats._Weapons)
local Moves = require(ServerStorage.Stats._Moves)

local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

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
	local Animation = Replicated.Assets.Animations.Abilities.Flame[script.Name]

	if Server.Library.StateCount(Character.Actions) or Server.Library.StateCount(Character.Stuns) then
		return
	end

	local Hitbox = Server.Modules.Hitbox
	local Entity = Server.Modules["Entities"].Get(Character)

	-- For NPCs, skip the PlayerObject.Keys check
	local canUseSkill = isNPC or (PlayerObject and PlayerObject.Keys)

	if canUseSkill and not Server.Library.CheckCooldown(Character, "Firestorm") then
		cleanUp()
		Server.Library.SetCooldown(Character, "Firestorm", 10) -- Increased from 5 to 10 seconds (powerful AOE)
		Server.Library.StopAllAnims(Character)

		local Alchemy = Library.PlayAnimation(Character, Animation)
		Alchemy.Looped = false
		-- Alchemy:Play()

		local animlength = Alchemy.Length

		local hittimes = {}
		for i, fraction in Moves.Flame.Firestorm.HitTimes do
			hittimes[i] = fraction * animlength
		end

		Server.Library.TimedState(Character.Actions, "Firestorm", Alchemy.Length)
		Server.Library.TimedState(Character.Stuns, "NoRotate", Alchemy.Length)
		Server.Library.TimedState(Character.Speeds, "AlcSpeed-0", Alchemy.Length)

		local vfxtime = hittimes[1] - .35

		task.delay(vfxtime, function()
			Server.Visuals.Ranged(Character.HumanoidRootPart.Position, 300, {
				Module = "Base",
				Function = "Firestorm",
				Arguments = { Character, "Start" },
			})
		end)

		task.delay(hittimes[1], function()
            local s = Replicated.Assets.SFX.Skills.Flame.Start:Clone()
            s.Parent = Character.HumanoidRootPart
            s:Play()
            Debris:AddItem(s, s.TimeLength)

			task.delay(.65, function()
			 local s2 = Replicated.Assets.SFX.Skills.Flame.FireSlash:Clone()
            s2.Parent = Character.HumanoidRootPart
			s2.Volume = 2.5
            s2:Play()
            Debris:AddItem(s2, s2.TimeLength)
			end)
			local HitTargets = Hitbox.SpatialQuery(Character, Moves.Flame.Firestorm["Hitboxes"][1]["HitboxSize"], Entity:GetCFrame() * Moves.Flame.Firestorm["Hitboxes"][1]["HitboxOffset"], false)
		
		for _, Target: Model in pairs(HitTargets) do
			Server.Modules.Damage.Tag(Character, Target, Moves.Flame.Firestorm["DamageTableStart"])
			--if not Target:GetAttribute("")
		end
            -- Visual effects
           
        end)
        
        task.delay(hittimes[2], function()
            local s = Replicated.Assets.SFX.Skills.Flame.Rapid:Clone()
            s.Parent = Character.HumanoidRootPart
            s:Play()
            Debris:AddItem(s, 1.074)
			local new = Replicated.Assets.SFX.Skills.Flame.RapidBG:Clone()
			new.Parent = Character.HumanoidRootPart
			new.Volume = 1.5
			new:Play()
			Debris:AddItem(new, new.TimeLength)
			local HitTargets = Hitbox.SpatialQuery(Character, Moves.Flame.Firestorm["Hitboxes"][2]["HitboxSize"], Entity:GetCFrame() * Moves.Flame.Firestorm["Hitboxes"][2]["HitboxOffset"], false)
		
		for _, Target: Model in pairs(HitTargets) do
			Server.Modules.Damage.Tag(Character, Target, Moves.Flame.Firestorm["DamageTableRapid"])
			--if not Target:GetAttribute("")
		end
        end)
        
        task.delay(hittimes[3], function()
            local s = Replicated.Assets.SFX.Skills.Flame.Rapid:Clone()
            s.Parent = Character.HumanoidRootPart
            s:Play()
            Debris:AddItem(s, 1.074)
			local new = Replicated.Assets.SFX.Skills.Flame.RapidBG:Clone()
			new.Parent = Character.HumanoidRootPart
			new.Volume = 1.5
			new:Play()
			Debris:AddItem(new, new.TimeLength)
			local HitTargets = Hitbox.SpatialQuery(Character, Moves.Flame.Firestorm["Hitboxes"][2]["HitboxSize"], Entity:GetCFrame() * Moves.Flame.Firestorm["Hitboxes"][2]["HitboxOffset"], false)
		
		for _, Target: Model in pairs(HitTargets) do
			Server.Modules.Damage.Tag(Character, Target, Moves.Flame.Firestorm["DamageTableRapid"])
			--if not Target:GetAttribute("")
		end
        end)
        
        task.delay(hittimes[4], function()
            local s = Replicated.Assets.SFX.Skills.Flame.Rapid:Clone()
            s.Parent = Character.HumanoidRootPart
            s:Play()
            Debris:AddItem(s, 1.074)
			local new = Replicated.Assets.SFX.Skills.Flame.RapidBG:Clone()
			new.Parent = Character.HumanoidRootPart
			new.Volume = 1.5
			new:Play()
			Debris:AddItem(new, new.TimeLength)
			local HitTargets = Hitbox.SpatialQuery(Character, Moves.Flame.Firestorm["Hitboxes"][2]["HitboxSize"], Entity:GetCFrame() * Moves.Flame.Firestorm["Hitboxes"][2]["HitboxOffset"], false)
		
		for _, Target: Model in pairs(HitTargets) do
			Server.Modules.Damage.Tag(Character, Target, Moves.Flame.Firestorm["DamageTableRapid"])
			--if not Target:GetAttribute("")
		end
        end)
        
        task.delay(hittimes[5], function()
            local s = Replicated.Assets.SFX.Skills.Flame.Rapid:Clone()
            s.Parent = Character.HumanoidRootPart
            s:Play()
            Debris:AddItem(s, 1.074)
			local new = Replicated.Assets.SFX.Skills.Flame.RapidBG:Clone()
			new.Parent = Character.HumanoidRootPart
			new.Volume = 1.5
			new:Play()
			Debris:AddItem(new, new.TimeLength)
			local HitTargets = Hitbox.SpatialQuery(Character, Moves.Flame.Firestorm["Hitboxes"][2]["HitboxSize"], Entity:GetCFrame() * Moves.Flame.Firestorm["Hitboxes"][2]["HitboxOffset"], false)
		
		for _, Target: Model in (HitTargets) do
			Server.Modules.Damage.Tag(Character, Target, Moves.Flame.Firestorm["DamageTableRapid"])
			--if not Target:GetAttribute("")
		end
        end)

        task.delay(hittimes[6] - .2, function()
            local s = Replicated.Assets.SFX.Skills.Flame.End1:Clone()
            s.Parent = Character.HumanoidRootPart
            s:Play()
            Debris:AddItem(s, s.TimeLength)
            
            task.delay(0.15, function()
                local s2 = Replicated.Assets.SFX.Skills.Flame.End2:Clone()
                s2.Parent = Character.HumanoidRootPart
                s2:Play()
                Debris:AddItem(s2, s2.TimeLength)
            end)
			local HitTargets = Hitbox.SpatialQuery(Character, Moves.Flame.Firestorm["Hitboxes"][3]["HitboxSize"], Entity:GetCFrame() * Moves.Flame.Firestorm["Hitboxes"][3]["HitboxOffset"], false)
		
		for _, Target: Model in (HitTargets) do
			Server.Modules.Damage.Tag(Character, Target, Moves.Flame.Firestorm["DamageTableEnd"])
			--if not Target:GetAttribute("")
		end
        end)
    end
end
return NetworkModule
