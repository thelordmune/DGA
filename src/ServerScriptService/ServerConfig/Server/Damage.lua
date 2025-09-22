local DamageService = {}
local Server = require(script.Parent)
DamageService.__index = DamageService
local Replicated = game:GetService("ReplicatedStorage")
local Visuals = require(Replicated.Modules.Visuals)
local Library = require(Replicated.Modules.Library)
local Utilities = require(Replicated.Modules.Utilities)
local Debris = Utilities.Debris
local Voxbreaker = require(Replicated.Modules.Voxel)
local RunService = game:GetService("RunService")
local self = setmetatable({}, DamageService)
local world = require(Replicated.Modules.ECS.jecs_world)
local ref = require(Replicated.Modules.ECS.jecs_ref)
local comps = require(Replicated.Modules.ECS.jecs_components)
local Global = require(Replicated.Modules.Shared.Global)

-- D:\iv\src\ReplicatedStorage\Modules\ECS\jecs_world.luau

DamageService.Tag = function(Invoker: Model, Target: Model, Table: {})
	local Entity, TargetEntity = Server.Modules.Entities.Get(Invoker), Server.Modules.Entities.Get(Target)
	if not Entity or not TargetEntity then
		return
	end

	local Player, TargetPlayer
	local InvokerWeapon, TargetWeapon
	local pData
	local tData

	if Entity.Player then
		Player = Entity.Player
		pData = Global.GetData(Player)
	end
	if TargetEntity.Player then
		TargetPlayer = TargetEntity.Player
		tData = Global.GetData(TargetPlayer)
	end

	if Player then
		InvokerWeapon = Player:GetAttribute("Weapon")
	else
		InvokerWeapon = Invoker:GetAttribute("Weapon")
	end

	if TargetPlayer then
		local tentity = ref.get("player", TargetPlayer)
		TargetWeapon = TargetPlayer:GetAttribute("Weapon")
		if not world:get(tentity, comps.InCombat) then
			world:set(tentity, comps.InCombat, { value = true, duration = 40 })
			Visuals.FireClient(TargetPlayer, {
				Module = "Base",
				Function = "InCombat",
				Arguments = { TargetPlayer, world:get(tentity, comps.InCombat).value },
			})
		end
	else
		TargetWeapon = Target:GetAttribute("Weapon")
	end

	-- if TargetPlayer and not world:get then
	-- 	world:set
	-- 	print("in combat for " .. Target.Name)
	-- 	Visuals.FireClient(TargetPlayer, {
	-- 		Module = "Base",
	-- 		Function = "InCombat",
	-- 		Arguments = { Target },
	-- 	})
	-- end

	local function DealStun()
		if not Table.NoStunAnim then
			Library.PlayAnimation(
				Target,
				Replicated.Assets.Animations.Hit:GetChildren()[Random.new():NextInteger(
					1,
					#Replicated.Assets.Animations.Hit:GetChildren()
				)]
			)
		end

		Library.TimedState(Target.Stuns, "DamageStun", Table.Stun)
		Library.TimedState(Target.Speeds, "DamageSpeedSet4", Table.Stun)
	end

	local function Parried()
		-- Apply stun IMMEDIATELY when parry is detected
		Library.StopAllAnims(Invoker)
		Library.TimedState(Invoker.Speeds, "ParrySpeedSet4", 1.2)
		Library.TimedState(Invoker.Stuns, "ParryStun", 1.2)

		if not Table.NoParryAnimation then
			for _, v in script.Parent.Callbacks.Parry:GetChildren() do
				if v:IsA("ModuleScript") and tData and table.find(tData.Passives, v.Name) then
					print("found passive for" .. v.Name)
					local func = require(v)
					func(world, Player, TargetPlayer, Table)
				end
			end
			Library.ResetCooldown(Target, "Parry")
			Library.PlaySound(
				Target,
				Replicated.Assets.SFX.Parries:GetChildren()[Random.new():NextInteger(
					1,
					#Replicated.Assets.SFX.Parries:GetChildren()
				)]
			)

			Invoker.Posture.Value += Table.Damage and Table.Damage / 5 or 1
			Target.Posture.Value -= Table.Damage and Table.Damage / 4 or 1

			local Distance = (Target.HumanoidRootPart.Position - Invoker.HumanoidRootPart.Position).Magnitude

			local ParriedAnims = Replicated.Assets.Animations:FindFirstChild("Parried"):GetChildren()

			local ParriedAnimation =
				Library.PlayAnimation(Invoker, ParriedAnims[Random.new():NextInteger(1, #ParriedAnims)])

			ParriedAnimation.Priority = Enum.AnimationPriority.Action2

			local ParriedAnimation2 =
				Library.PlayAnimation(Target, ParriedAnims[Random.new():NextInteger(1, #ParriedAnims)])

			ParriedAnimation2.Priority = Enum.AnimationPriority.Action3

			Visuals.Ranged(
				Target.HumanoidRootPart.Position,
				300,
				{ Module = "Base", Function = "Parry", Arguments = { Target, Invoker, Distance } }
			)

			if Table.M1 or Table.M2 then
				if Player then
					Server.Packets.Bvel.sendTo({ Character = Invoker, Name = "RemoveBvel" }, Player)
				else
				end
			end
		end
	end

	local function BlockBreak()
		-- Immediately reset posture to 0 to prevent double triggering
		Target.Posture.Value = 0

		Server.Library.StopAllAnims(Target)

		local Animation = Library.PlayAnimation(
			Target,
			Replicated.Assets.Animations.Guardbreak:GetChildren()[Random.new():NextInteger(
				1,
				#Replicated.Assets.Animations.Guardbreak:GetChildren()
			)]
		)
		Animation.Priority = Enum.AnimationPriority.Action3

		-- Apply stun and other effects
		Server.Library.TimedState(Target.Stuns, "BlockBreakStun", 4.5)
		Server.Library.TimedState(Target.Actions, "BlockBreak", 4.5)
		Server.Library.TimedState(Target.Speeds, "BlockBreakSpeedSet3", 4.5)

		-- Play sound effect
		local sound = Replicated.Assets.SFX.Extra.Guardbreak:Clone()
		sound.Parent = Target.HumanoidRootPart
		sound:Play()
		Debris:AddItem(sound, sound.TimeLength)

		-- Visual effects
		Visuals.Ranged(
			Target.HumanoidRootPart.Position,
			300,
			{ Module = "Base", Function = "Guardbreak", Arguments = { Target } }
		)
	end

	local function DealDamage()
		Table.Damage = Table.Damage

		local kineticEnergy = Invoker:GetAttribute("KineticEnergy")
		local kineticExpiry = Invoker:GetAttribute("KineticExpiry")
		local bonusDamage = 0

		if kineticEnergy and kineticExpiry then
			if os.clock() < kineticExpiry then
				bonusDamage = kineticEnergy * 0.5
				Table.Damage = Table.Damage + bonusDamage
				if not Table.Stun then
					Table.Stun = 2
				end

				Invoker:SetAttribute("KineticEnergy", nil)
				Invoker:SetAttribute("KineticExpiry", nil)
			elseif os.clock() >= kineticExpiry then
				Invoker:SetAttribute("KineticEnergy", nil)
				Invoker:SetAttribute("KineticExpiry", nil)
			end
		else
		end

		if Table.M1 and not Table.SFX then
			Library.PlaySound(
				Target,
				Replicated.Assets.SFX.Hits.Blood:GetChildren()[Random.new():NextInteger(
					1,
					#Replicated.Assets.SFX.Hits.Blood:GetChildren()
				)]
			)
		elseif Table.SFX then
			Library.PlaySound(
				Target,
				Replicated.Assets.SFX.Hits[Table.SFX]:GetChildren()[Random.new():NextInteger(
					1,
					#Replicated.Assets.SFX.Hits[Table.SFX]:GetChildren()
				)]
			)
		end

		print("Damage.Tag called - Target:", Target.Name, "IsNPC:", Target:GetAttribute("IsNPC"))

		if Target:GetAttribute("IsNPC") then
        -- Log the attack for NPC aggression system
        local damageLog = Target:FindFirstChild("Damage_Log")
        if not damageLog then
            damageLog = Instance.new("Folder")
            damageLog.Name = "Damage_Log"
            damageLog.Parent = Target
        end

        -- Create attack record
        local attackRecord = Instance.new("ObjectValue")
        attackRecord.Name = "Attack_" .. os.clock()
        attackRecord.Value = Invoker
        attackRecord.Parent = damageLog

        -- Clean up old attack records (keep only last 5)
        local records = damageLog:GetChildren()
        if #records > 5 then
            for i = 1, #records - 5 do
                records[i]:Destroy()
            end
        end

        -- Set recently attacked state using the character's IFrames (which is a StringValue)
        -- local iFrames = Target:FindFirstChild("IFrames")
        -- if iFrames and iFrames:IsA("StringValue") then
        --     Library.TimedState(iFrames, "RecentlyAttacked", 2) -- Short window just for aggression trigger
        --     Library.TimedState(iFrames, "Damaged", 1) -- Very short immediate reaction
        --     print("Set RecentlyAttacked and Damaged states for NPC:", Target.Name)
        -- else
        --     print("Warning: Could not find IFrames StringValue for NPC:", Target.Name)
        -- end

        -- print("NPC", Target.Name, "was attacked by", Invoker.Name, "- logging for aggression system")

        -- Note: Original NPC damage handling removed as Server.Modules.NPC doesn't exist
        -- The aggression system will handle NPC behavior through the behavior trees
    end

		if pData then
			Target.Humanoid.Health -= Table.Damage + pData.Stats.Damage
			--[[print(
				"Total damage dealt:",
				Table.Damage + pData.Stats.Damage,
				"(Base:",
				Table.Damage,
				"+ Player Stats:",
				pData.Stats.Damage,
				"+ Kinetic:",
				bonusDamage,
				")"
			)]]
			Table.Damage = Table.Damage - bonusDamage
		else
			Target.Humanoid.Health -= Table.Damage
			print("Total damage dealt:", Table.Damage, "(+ Kinetic:", bonusDamage, ")")
		end
	end

	local function Status()
		local proc_chance = Table.Status.ProcChance
		local procdmg = Table.Status.ProcDmg
		local proctick = Table.Status.Tick
		local duration = Table.Status.Duration

		local burningentities = {}

		math.randomseed(os.clock())

		local randomnumber = math.random()

		local function applyStatus()
			if burningentities[Target] then
				return
			end
			Visuals.Ranged(Target.HumanoidRootPart.Position, 300, {
				Module = "Misc",
				Function = "EnableStatus",
				Arguments = { Target, Table.Status.Name, Table.Status.Duration },
			})
			burningentities[Target] = {
				dura = duration,
				connection = nil,
			}

			burningentities[Target].connection = game:GetService("RunService").PostSimulation:Connect(function(dt)
				local data = burningentities[Target]
				if not data then
					return
				end

				data.dura = data.dura - dt

				if data.dura % proctick < dt then
					Target.Humanoid.Health -= procdmg
				end
			end)
		end
		if randomnumber <= proc_chance then
			applyStatus()
		end
	end

	local function LightKnockback()
		if TargetPlayer then
			print("light kb")
			Server.Packets.Bvel.sendTo({ Character = Target, Name = "BaseBvel" }, TargetPlayer)
		else
		end
	end

	local function handleWallbang()
		print("handling wallbang")
		local raycastParams = RaycastParams.new()
		raycastParams.FilterType = Enum.RaycastFilterType.Exclude
		raycastParams.FilterDescendantsInstances = { Target, workspace.World.Live }
		local eroot = Target.HumanoidRootPart
		local root = Invoker.HumanoidRootPart
		local direction = (eroot.Position - root.Position).Unit
		local connection
		local cooldown = false
		local triggerDistance = 5

		connection = RunService.Heartbeat:Connect(function(dt)
			if not Target.Parent then
				print("table parent is nil")
				connection:Disconnect()
				return
			end

			local result =
				workspace:Raycast(Target.HumanoidRootPart.Position, direction * triggerDistance, raycastParams)

			if result and result.Instance and not cooldown then
				local part = result.Instance
				if part.Parent == workspace.Transmutables then
					local sound = Replicated.Assets.SFX.Hits.Wallbang:Clone()
					sound.Parent = Target.HumanoidRootPart
					sound:Play()
					Debris:AddItem(sound, sound.TimeLength)
					cooldown = true
					Table.Damage = Table.Damage * 1.2
					local Position = result.Position
					Visuals.Ranged(
						Target.HumanoidRootPart.Position,
						300,
						{ Module = "Base", Function = "Wallbang", Arguments = { Position } }
					)

					local parts = Voxbreaker:VoxelizePart(part, 10, 15)
					for _, v in ipairs(parts) do
						if v:IsA("BasePart") then
							v.Anchored = false
							v.CanCollide = true

							local debrisDir = (v.Position - result.Position).Unit
							local debrisVel = Instance.new("BodyVelocity")
							debrisVel.Velocity = (
								debrisDir
								+ Vector3.new(
									(math.random() - 0.5) * 0.3,
									math.random() * 1.5,
									(math.random() - 0.5) * 10
								)
							)
								* 60
								* 0.3

							debrisVel.MaxForce = Vector3.new(math.huge, 0, math.huge)
							debrisVel.Parent = v
							Debris:AddItem(debrisVel, 0.5)
							Debris:AddItem(v, 8 + math.random() * 4)
						end
					end

					task.delay(0.2, function()
						cooldown = false
					end)
				end
			end
		end)

		Debris:AddItem(connection, 0.25)
	end

	local function Knockback()
		if Target then
			Library.StopAllAnims(Target)
			local Animation = Library.PlayAnimation(Target, Replicated.Assets.Animations.Misc.KnockbackStun)
			Animation.Priority = Enum.AnimationPriority.Action3
			Server.Packets.Bvel.sendToAll({ Character = Invoker, Name = "KnockbackBvel", Targ = Target })
			print("knocking back")
			handleWallbang()
		end
	end

	local function HandleBlock()
		local Blocks = Server.Service.ReplicatedStorage.Assets.Animations.Weapons[TargetWeapon]
			:FindFirstChild("Blocks")
			:GetChildren()

		local Animation = Library.PlayAnimation(Target, Blocks[Random.new():NextInteger(1, #Blocks)])
		Animation.Priority = Enum.AnimationPriority.Action3
		--CombatUtility.SwingCancel(Character,BlockJanitor,Animation)

		local BlockedSounds =
			Server.Service.ReplicatedStorage.Assets.SFX.Weapons[TargetWeapon]:FindFirstChild("Blocked"):GetChildren()

		local Sound = Library.PlaySound(Target, BlockedSounds[Random.new():NextInteger(1, #BlockedSounds)])
		Target.Posture.Value += Table.Damage / 3

		if Target.Posture.Value >= Target.Posture.MaxValue then
			print("block broken")
			BlockBreak()
			return
		end

		if TargetPlayer then
			Server.Packets.Bvel.sendTo({ Character = Target, Name = "BaseBvel" }, TargetPlayer)
		else
		end

		Visuals.Ranged(
			Target.HumanoidRootPart.Position,
			300,
			{ Module = "Base", Function = "Block", Arguments = { Target } }
		)
	end

	--if Table.BlockBreak

	-- Check for specific immunity states, but don't block all damage for NPCs with minor states
	if Library.StateCheck(Target.IFrames, "Dodge") then
		Library.RemoveState(Target.IFrames, "Dodge")
		print("Dodge")

		Visuals.Ranged(
			Target.HumanoidRootPart.Position,
			300,
			{ Module = "Base", Function = "PerfectDodge", Arguments = { Target } }
		)
		return
	end

	-- Check immunity frames - different logic for NPCs vs Players
	local isNPC = Target:GetAttribute("IsNPC")
	if isNPC then
		-- For NPCs, only block damage if they have actual immunity states, not minor states like "RecentlyAttacked"
		if Library.StateCheck(Target.IFrames, "IFrame") or Library.StateCheck(Target.IFrames, "ForceField") then
			return
		end
		-- Allow damage through for states like "RecentlyAttacked", "Damaged", etc.
	else
		-- For players, maintain original behavior - block all IFrame states
		if Library.StateCount(Target.IFrames) then
			return
		end
	end

	--if Library.StateCheck(Target.Actions, "M2") and Library.StateCheck(Invoker.Actions,"M2") and not Library.CheckCooldown(Invoker,"Clash") and not Library.CheckCooldown(Target,"Clash") then
	--	Clash()
	--	return
	--end

	if Library.StateCheck(Target.Frames, "Parry") and not Table.NoParry then
		Parried()
		return
	end

	if
		Library.StateCheck(Target.Frames, "Blocking")
		and not Library.StateCheck(Target.Frames, "Parry")
		and not ((Target.HumanoidRootPart.CFrame:Inverse() * Invoker.HumanoidRootPart.CFrame).Z > 1)
	then
		HandleBlock(Target, Invoker)

		if Library.StateCheck(Target.Frames, "Blocking") then
			return
		end
	end

	if Table.Stun then
		DealStun()

		-- Give NPCs brief immunity after taking stun to prevent spam
		if Target:GetAttribute("IsNPC") then
			Library.TimedState(Target.IFrames, "IFrame", 0.3)
		end
	end

	if Table.FX then
		-- if Table.FX.Parent.Name == "Flame" then
		-- 	Visuals.Ranged(
		-- 		Target.HumanoidRootPart.Position,
		-- 		300,
		-- 		{ Module = "Misc", Function = "EnableEffect", Arguments = { Target, Table.FX } }
		-- 	)
		-- end
		Visuals.Ranged(
			Target.HumanoidRootPart.Position,
			300,
			{ Module = "Misc", Function = "DoEffect", Arguments = { Target, Table.FX } }
		)
	end

	if Table.Knockback then
		print("knocking abck")
		Knockback()
	end

	if Table.LightKnockback then
		LightKnockback()
	end

	if Table.Damage then
		DealDamage()

		-- Give NPCs brief immunity after taking damage to prevent spam
		if Target:GetAttribute("IsNPC") then
			Library.TimedState(Target.IFrames, "IFrame", 0.2)
		end
	end

	if Table.Status then
		Status()
	end

	if Table then
		print(Table)
	end
end

return DamageService
