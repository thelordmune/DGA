local Customs = {}
local Server = require(script.Parent)
local StateManager = require(game:GetService("ReplicatedStorage").Modules.ECS.StateManager)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local world = require(ReplicatedStorage.Modules.ECS.jecs_world)
local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)
local ref = require(ReplicatedStorage.Modules.ECS.jecs_ref)
local RefManager = require(ReplicatedStorage.Modules.ECS.jecs_ref_manager)
local Players = game:GetService("Players")

Customs.__index = Customs

-- Helper to set combat animation attribute for Chrono NPC replication
-- Same as Combat.lua - replicates animations to client clones
local NPC_MODEL_CACHE = ReplicatedStorage:FindFirstChild("NPC_MODEL_CACHE")

local function setNPCCombatAnim(character: Model, weapon: string, animType: string, animName: string, speed: number?)
	-- Only set attribute for NPCs (not players) that have a ChronoId
	if Players:GetPlayerFromCharacter(character) then
		return -- Skip players
	end

	local chronoId = character:GetAttribute("ChronoId")
	if not chronoId then
		return -- Not a Chrono NPC
	end

	local animSpeed = speed or 1
	local timestamp = workspace:GetServerTimeNow()
	local animData = `{weapon}|{animType}|{animName}|{animSpeed}|{timestamp}`

	character:SetAttribute("NPCCombatAnim", animData)

	if not NPC_MODEL_CACHE then
		NPC_MODEL_CACHE = ReplicatedStorage:FindFirstChild("NPC_MODEL_CACHE")
	end
	if NPC_MODEL_CACHE then
		local cacheModel = NPC_MODEL_CACHE:FindFirstChild(tostring(chronoId))
		if cacheModel then
			cacheModel:SetAttribute("NPCCombatAnim", animData)
		end
	end
end

-- Flame alchemy weapon removed - Hunter x Hunter Nen system will replace this

-- ECS-based combat state helpers (same as Combat.lua)
local function getEntityECS(character: Model): number?
	local player = Players:GetPlayerFromCharacter(character)
	if player then
		return ref.get("player", player)
	end
	return RefManager.entity.find(character)
end

local function getCombatState(character: Model): {combo: number, lastHitTime: number, swingConnection: RBXScriptConnection?}
	local entity = getEntityECS(character)
	if not entity then
		return { combo = 0, lastHitTime = 0, swingConnection = nil }
	end

	local state = world:get(entity, comps.CombatState)
	if not state then
		state = { combo = 0, lastHitTime = 0, swingConnection = nil }
		world:set(entity, comps.CombatState, state)
	end

	return state
end

local function setCombatState(character: Model, state: {combo: number?, lastHitTime: number?, swingConnection: RBXScriptConnection?})
	local entity = getEntityECS(character)
	if not entity then return end

	local current = getCombatState(character)

	-- Merge provided state with current
	if state.combo ~= nil then current.combo = state.combo end
	if state.lastHitTime ~= nil then current.lastHitTime = state.lastHitTime end
	if state.swingConnection ~= nil then current.swingConnection = state.swingConnection end

	world:set(entity, comps.CombatState, current)
end

Customs.Trail = function(Character: Model, State: boolean)
	if State then
		for _, v in pairs(Character:GetDescendants()) do
			if v:GetAttribute("WeaponTrail") then
				v.Enabled = true
			end
		end
	else
		for _, v in pairs(Character:GetDescendants()) do
			if v:GetAttribute("WeaponTrail") then
				v.Enabled = false
			end
		end
	end
end

Customs.Guns = function(Character, Entity, Weapon, Stats)
    local Hitbox = Server.Modules.Hitbox
    if Stats then
        -- Use ECS-based combat state
        local combatState = getCombatState(Character)

        if combatState.swingConnection then
            if StateManager.StateCheck(Character, "Speeds", "M1Speed13") then
                StateManager.RemoveState(Character, "Speeds", "M1Speed13")
            end
            combatState.swingConnection:Disconnect()
            combatState.swingConnection = nil
        end

        -- Reset combo if more than 2 seconds since last hit
        if os.clock() - combatState.lastHitTime > 2 then
            combatState.combo = 0
        end

        combatState.combo = combatState.combo + 1
        local Combo: number = combatState.combo
        local Cancel = false
        local Max = false
        combatState.lastHitTime = os.clock()

        -- Check if this is the last hit (combo 4)
        local IsDoubleHit = Combo == 4

        if IsDoubleHit then
            combatState.combo = 0  -- Reset combo after the double hit
            Max = true
        elseif combatState.combo >= Stats.MaxCombo then
            combatState.combo = 0
            Max = true
        end

        -- Save combat state
        setCombatState(Character, combatState)

        -- Use different endlag for double hit
        local endlagIndex = IsDoubleHit and 4 or Combo
        StateManager.TimedState(Character, "Actions", "M1" .. Combo, Stats["Endlag"][endlagIndex])
        StateManager.AddState(Character, "Speeds", "M1Speed13") -- Reduced walkspeed to 13 (16 + (-3)) for more consistent hitboxes

        local Swings = Server.Service.ReplicatedStorage.Assets.Animations.Weapons[Weapon].Swings
        local SwingAnimation = Character.Humanoid.Animator:LoadAnimation(Swings:FindFirstChild(Combo))
        SwingAnimation:Play(0.1)
		SwingAnimation:AdjustSpeed(Stats["Speed"])
        SwingAnimation.Priority = Enum.AnimationPriority.Action2

        -- Replicate animation to clients for Chrono NPCs
        setNPCCombatAnim(Character, Weapon, "Swings", tostring(Combo), Stats["Speed"])

        local Sound = Server.Library.PlaySound(
            Character,
            Server.Service.ReplicatedStorage.Assets.SFX.Weapons[Weapon].Swings[Random.new():NextInteger(1, 3)]
        )

		Server.Library.PlaySound(
			Character,
			Server.Service.ReplicatedStorage.Assets.SFX.Weapons[Weapon].Shells[Random.new():NextInteger(1, 2)]
		)

        if Stats["Trail"] then
            Customs.Trail(Character, true)
        end

        -- Store swing connection in ECS
        local swingConn
        swingConn = SwingAnimation.Stopped:Once(function()
            local currentState = getCombatState(Character)
            if currentState.swingConnection == swingConn then
                currentState.swingConnection = nil
                setCombatState(Character, currentState)
            end
            -- Remove M1Speed13
            if StateManager.StateCheck(Character, "Speeds", "M1Speed13") then
                StateManager.RemoveState(Character, "Speeds", "M1Speed13")
            end
            if Stats["Trail"] then
                Customs.Trail(Character, false)
            end
        end)
        combatState.swingConnection = swingConn
        setCombatState(Character, combatState)

        local stunDisconnect = StateManager.OnStunAddedOnce(Character, function(_stunName)
            stunDisconnect = nil
            -- Remove M1Speed13
            if StateManager.StateCheck(Character, "Speeds", "M1Speed13") then
                StateManager.RemoveState(Character, "Speeds", "M1Speed13")
            end
            if StateManager.StateCheck(Character, "Actions", "M1" .. Combo) then
                StateManager.RemoveState(Character, "Actions", "M1" .. Combo)
            end
            Sound:Stop()
            SwingAnimation:Stop(0.2)
            Cancel = true
        end)

        -- Wait for the first hit time
        task.wait(Stats["HitTimes"][Combo])
        if Cancel then return end

        if Stats["Slashes"] then
            Server.Visuals.Ranged(
                Character.HumanoidRootPart.Position,
                300,
                { Module = "Base", Function = "Slashes", Arguments = { Character, Weapon, Combo } }
            )
        end

        -- First hit (or only hit for non-double hits)
        local LeftGun = Character:FindFirstChild("LeftGun")
        local RightGun = Character:FindFirstChild("RightGun")
        Server.Visuals.Ranged(
            Character.HumanoidRootPart.Position,
            300,
            { Module = "Weapons", Function = "Shot", Arguments = { Character, Combo, LeftGun, RightGun } }
        )

        local HitTargets = Hitbox.SpatialQuery(
            Character,
            Stats["Hitboxes"][Combo]["HitboxSize"],
            Entity:GetCFrame() * Stats["Hitboxes"][Combo]["HitboxOffset"]
        )

        for _, Target: Model in pairs(HitTargets) do
            if IsDoubleHit then
                -- Use LastTable for the double hit
                Server.Modules.Damage.Tag(Character, Target, Stats["LastTable"])
            else
                Server.Modules.Damage.Tag(Character, Target, Stats["M1Table"])
            end
        end

        -- If this is the double hit, do the second hit after a small delay
        if IsDoubleHit and not Cancel then
            task.wait(0.1)  -- Small delay between the two hits

            -- Second hit of the double hit
            Server.Visuals.Ranged(
                Character.HumanoidRootPart.Position,
                300,
                { Module = "Weapons", Function = "Shot", Arguments = { Character, 2, LeftGun, RightGun } }
            )

            local SecondHitTargets = Hitbox.SpatialQuery(
                Character,
                Stats["Hitboxes"][5]["HitboxSize"],  -- Use the 5th hitbox for second hit
                Entity:GetCFrame() * Stats["Hitboxes"][5]["HitboxOffset"]
            )

            for _, Target: Model in pairs(SecondHitTargets) do
                Server.Modules.Damage.Tag(Character, Target, Stats["LastTable"])
            end
        end

        if stunDisconnect then stunDisconnect() end
    end
end

return Customs
