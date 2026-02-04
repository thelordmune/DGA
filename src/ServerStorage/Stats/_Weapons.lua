-- Services

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local Replicated = game:GetService("ReplicatedStorage")
local Library = require(Replicated.Modules.Library)
local Visuals = require(Replicated.Modules.Visuals)
local Packets = require(Replicated.Modules.Packets)
local Server = require(ServerScriptService.ServerConfig.Server)
local StateManager = require(Replicated.Modules.ECS.StateManager)

local Table = {

	["Fist"] = {
		["MaxCombo"] = 4,
		["Endlag"] = { 26 / 60, 23 / 60, 26 / 60, 35 / 60, 25 / 60 },  -- Final hit (4) endlag reduced for faster recovery
		["HitTimes"] = { 21.7 / 60, 21.7 / 60, 24.3 / 60, 26.9 / 60, 20.9 / 60 },  -- Adjusted for 1.15x speed
		["SoundTimes"] = {},
		["Speed"] = 0.85,  -- Reduced from 1 to 0.85 for slower attacks
		["Hitboxes"] = {
			[1] = {
				["HitboxSize"] = Vector3.new(7,9,9),  -- Increased for better hit detection
				["HitboxOffset"] = CFrame.new(0, 0, -4),
			},

			[2] = {
				["HitboxSize"] = Vector3.new(7,9,9),  -- Increased for better hit detection
				["HitboxOffset"] = CFrame.new(0, 0, -4),
			},

			[3] = {
				["HitboxSize"] = Vector3.new(7,9,9),  -- Increased for better hit detection
				["HitboxOffset"] = CFrame.new(0, 0, -4),
			},

			[4] = {
				["HitboxSize"] = Vector3.new(7,9,9),  -- Increased for better hit detection
				["HitboxOffset"] = CFrame.new(0, 0, -4),
			},
		},

		["M1Table"] = {
			Damage = 5,
			PostureDamage = 7,
			LightKnockback = true,
			M1 = true,
			FX = Replicated.Assets.VFX.RunningHit.Attachment,
			Stun = 0.7, -- Reduced from 1.2 to allow faster combat flow
		},

		["Critical"] = {
			["DamageTable"] = {
				BlockBreak = true,
				Damage = 10,
				PostureDamage = 20,
				Knockback = true, -- Changed from LightKnockback to Knockback for full knockback animation
				M2 = true,
				FX = Replicated.Assets.VFX.RunningHit.Attachment,
				Stun = 0.7,
			},
			["HitTable"] = {},
			["WaitTime"] = 20 / 60,
			["Endlag"] = 0.7, -- Reduced from 1 for faster combat
			["Velocity"] = true,
			["OldCustomFunction"] = function(Character: Model, Entity)
				local Player: Player

				if Entity.Player then
					Player = Entity.Player
				end

				local DamageTable = {
					BlockBreak = true,
					Damage = 10,
					PostureDamage = 20,
					LightKnockback = true,
					M2 = true,
					FX = Replicated.Assets.VFX.Blood.Attachment,
					Stun = 0.7,
				}

				local Cancel = false
				local SwingAnimation =
					Library.PlayAnimation(Character, Replicated.Assets.Animations.Weapons.Fist.Critical)

				SwingAnimation.Stopped:Once(function()
					Server.Modules.Combat.Trail(Character, false)
				end)

				Server.Modules.Combat.Trail(Character, true)

				local m2StunDisconnect = StateManager.OnStunAddedOnce(Character, function(_stunName)
					m2StunDisconnect = nil
					Cancel = true

					if Player then
						Packets.Bvel.sendTo({ Character = Character, Name = "RemoveBvel" }, Player)
					end

					if StateManager.StateCheck(Character, "Actions", "M2") then
						StateManager.RemoveState(Character, "Actions", "M2")
					end

					if StateManager.StateCheck(Character, "Speeds", "M2SpeedSet8") then
						StateManager.RemoveState(Character, "Speeds", "M2SpeedSet8")
					end

					Library.SetCooldown(Character, "Critical", 5)

					SwingAnimation:AdjustSpeed(0.1)
					SwingAnimation:Stop(0.2)
				end)

				-- // 8/60 start movement
				-- // stop at the first hit hmm

				if Player then
					Packets.Bvel.sendTo({ Character = Character, Name = "FistBvel" }, Player)
				end

				StateManager.TimedState(Character, "Speeds", "M2SpeedSet8", 71 / 60)
				StateManager.TimedState(Character, "Actions", "M2", 98 / 60)

				if Cancel then
					return
				end

				task.wait(31 / 60)

				local Size = Vector3.new(5, 7, 8)
				local Offset = CFrame.new(0, 0, -4)

				local HitTargets = Server.Hitbox.SpatialQuery(Character, Size, Entity:GetCFrame() * Offset)

				for _, Target: Model in pairs(HitTargets) do
					Server.Damage.Tag(Character, Target, DamageTable)
					--if not Target:GetAttribute("")
				end

				if Player then
					Visuals.FireClient(
						Player,
						{ Module = "Misc", Function = "CameraShake", Arguments = { "RightSmall" } }
					)
				end

				if Cancel then
					return
				end

				task.wait(40 / 60)

				Library.SetCooldown(Character, "Critical", 5)

				StateManager.TimedState(Character, "Speeds", "M2SpeedSet6", 27 / 60) -- Changed from 0 to 6 for faster combat

				if Player then
					Visuals.FireClient(Player, { Module = "Misc", Function = "CameraShake", Arguments = { "Small" } })
				end

				local HitTargets = Server.Hitbox.SpatialQuery(Character, Size, Entity:GetCFrame() * Offset)

				for _, Target: Model in pairs(HitTargets) do
					Server.Damage.Tag(Character, Target, DamageTable)
					--if not Target:GetAttribute("")
				end

				if Cancel then
					return
				end

				if m2StunDisconnect then m2StunDisconnect() end
			end,
		},

		["LastTable"] = {
			Damage = 10,
			PostureDamage = 20,
			LightKnockback = true,
			M1 = true,
		},

		["RunningAttack"] = {
			Linger = 2 / 60,
			StartVelocity = 0 / 60,
			EndVelocity = 25 / 60,
			TweenTime = 15 / 60,
			DelayToTween = 10 / 60,
			HitTime = 50 / 60,
			Endlag = 57 / 60,
		},
		["RATable"] = {
			Damage = 10,
			PostureDamage = 20,
			Knockback = true,
			FX = Replicated.Assets.VFX.RunningHit.Attachment,
			Stun = 0.7,
		},

		["Slashes"] = true,

		["Trail"] = true,
	},

	["Spear"] = {
		["MaxCombo"] = 5,
		["Endlag"] = { 30 / 60, 26 / 60, 30 / 60, 32 / 60, 38 / 60, 24/60 }, -- Final hit (5) endlag reduced for faster recovery
		["HitTimes"] = { 25 / 60, 25 / 60, 28 / 60, 31 / 60, 24 / 60, 25/60 },
		["SoundTimes"] = {},
		["Speed"] = 0.85,  -- Reduced for slower attacks
		["Hitboxes"] = {
			[1] = {
				["HitboxSize"] = Vector3.new(6, 8, 10),  -- Increased from (5,7,8) for more consistent hits
				["HitboxOffset"] = CFrame.new(0, 0, -4),
			},

			[2] = {
				["HitboxSize"] = Vector3.new(6, 8, 10),  -- Increased from (5,7,8) for more consistent hits
				["HitboxOffset"] = CFrame.new(0, 0, -4),
			},

			[3] = {
				["HitboxSize"] = Vector3.new(6, 8, 10),  -- Increased from (5,7,8) for more consistent hits
				["HitboxOffset"] = CFrame.new(0, 0, -4),
			},

			[4] = {
				["HitboxSize"] = Vector3.new(6, 8, 10),  -- Increased from (5,7,8) for more consistent hits
				["HitboxOffset"] = CFrame.new(0, 0, -4),
			},
			[5] = {
				["HitboxSize"] = Vector3.new(6, 8, 10),  -- Increased from (5,7,8) for more consistent hits
				["HitboxOffset"] = CFrame.new(0, 0, -4),
			},
		},

		["M1Table"] = {
			Damage = 6, -- Nerfed from 10 to 8
			PostureDamage = 50,
			LightKnockback = true,
			M1 = true,
			FX = Replicated.Assets.VFX.Blood.Attachment,
			Stun = 0.7, -- Reduced from 1.2 to allow faster combat flow
		},

		["Critical"] = {
			["DamageTable"] = {
				BlockBreak = true,
				Damage = 10,
				PostureDamage = 20,
				Knockback = true, -- Changed from LightKnockback to Knockback for full knockback animation
				M2 = true,
				FX = Replicated.Assets.VFX.RunningHit.Attachment,
				Stun = 0.5,
			},
			["HitTable"] = {},
			["WaitTime"] = 20 / 60,
			["Endlag"] = 0.7, -- Reduced from 1 for faster combat
			["Velocity"] = true,
			["OldCustomFunction"] = function(Character: Model, Entity)
				local Player: Player

				if Entity.Player then
					Player = Entity.Player
				end

				local DamageTable = {
					BlockBreak = true,
					Damage = 10,
					PostureDamage = 20,
					LightKnockback = true,
					M2 = true,
					FX = Replicated.Assets.VFX.Blood.Attachment,
					Stun = 0.7,
				}

				local Cancel = false
				local SwingAnimation =
					Library.PlayAnimation(Character, Replicated.Assets.Animations.Weapons.Fist.Critical)

				SwingAnimation.Stopped:Once(function()
					Server.Modules.Combat.Trail(Character, false)
				end)

				Server.Modules.Combat.Trail(Character, true)

				local m2StunDisconnect = StateManager.OnStunAddedOnce(Character, function(_stunName)
					m2StunDisconnect = nil
					Cancel = true

					if Player then
						Packets.Bvel.sendTo({ Character = Character, Name = "RemoveBvel" }, Player)
					end

					if StateManager.StateCheck(Character, "Actions", "M2") then
						StateManager.RemoveState(Character, "Actions", "M2")
					end

					if StateManager.StateCheck(Character, "Speeds", "M2SpeedSet8") then
						StateManager.RemoveState(Character, "Speeds", "M2SpeedSet8")
					end

					Library.SetCooldown(Character, "Critical", 5)

					SwingAnimation:AdjustSpeed(0.1)
					SwingAnimation:Stop(0.2)
				end)

				-- // 8/60 start movement
				-- // stop at the first hit hmm

				if Player then
					Packets.Bvel.sendTo({ Character = Character, Name = "FistBvel" }, Player)
				end

				StateManager.TimedState(Character, "Speeds", "M2SpeedSet8", 71 / 60)
				StateManager.TimedState(Character, "Actions", "M2", 98 / 60)

				if Cancel then
					return
				end

				task.wait(31 / 60)

				local Size = Vector3.new(5, 7, 8)
				local Offset = CFrame.new(0, 0, -4)

				local HitTargets = Server.Hitbox.SpatialQuery(Character, Size, Entity:GetCFrame() * Offset)

				for _, Target: Model in pairs(HitTargets) do
					Server.Damage.Tag(Character, Target, DamageTable)
					--if not Target:GetAttribute("")
				end

				if Player then
					Visuals.FireClient(
						Player,
						{ Module = "Misc", Function = "CameraShake", Arguments = { "RightSmall" } }
					)
				end

				if Cancel then
					return
				end

				task.wait(40 / 60)

				Library.SetCooldown(Character, "Critical", 5)

				StateManager.TimedState(Character, "Speeds", "M2SpeedSet6", 27 / 60) -- Changed from 0 to 6 for faster combat

				if Player then
					Visuals.FireClient(Player, { Module = "Misc", Function = "CameraShake", Arguments = { "Small" } })
				end

				local HitTargets = Server.Hitbox.SpatialQuery(Character, Size, Entity:GetCFrame() * Offset)

				for _, Target: Model in pairs(HitTargets) do
					Server.Damage.Tag(Character, Target, DamageTable)
					--if not Target:GetAttribute("")
				end

				if Cancel then
					return
				end

				if m2StunDisconnect then m2StunDisconnect() end
			end,
		},

		["LastTable"] = {
			Damage = 10,
			PostureDamage = 20,
			LightKnockback = true,
			M1 = true,
		},

		["RunningAttack"] = {
			Linger = 2 / 60,
			StartVelocity = 0 / 60,
			EndVelocity = 25 / 60,
			TweenTime = 15 / 60,
			DelayToTween = 10 / 60,
			HitTime = 50 / 60,
			Endlag = 57 / 60,
		},
		["RATable"] = {
			Damage = 15,
			PostureDamage = 20,
			Knockback = true,
			FX = Replicated.Assets.VFX.RunningHit.Attachment,
			Stun = 0.7,
		},

		["Slashes"] = false,

		["Trail"] = true,
	},

	["Augment"] = {
		["MaxCombo"] = 4,
		["Endlag"] = { 23 / 60, 23 / 60, 23 / 60, 35 / 60 }, -- Final hit (4) endlag reduced for faster recovery
		["HitTimes"] = { 24 / 60, 24 / 60, 24 / 60, 24 / 60 },
		["SoundTimes"] = {},
		["Hitboxes"] = {
			[1] = {
				["HitboxSize"] = Vector3.new(5, 7, 6.5),
				["HitboxOffset"] = CFrame.new(0, 0, -3),
			},

			[2] = {
				["HitboxSize"] = Vector3.new(5, 7, 6.5),
				["HitboxOffset"] = CFrame.new(0, 0, -3),
			},

			[3] = {
				["HitboxSize"] = Vector3.new(5, 7, 6.5),
				["HitboxOffset"] = CFrame.new(0, 0, -3),
			},

			[4] = {
				["HitboxSize"] = Vector3.new(5, 7, 6.5),
				["HitboxOffset"] = CFrame.new(0, 0, -3),
			},
		},

		["M1Table"] = {
			Damage = 8,
			PostureDamage = 15,
			LightKnockback = true,
			M1 = true,
			FX = Replicated.Assets.VFX.Blood.Attachment,
			Stun = 0.7,
		},

		["Critical"] = {
			["DamageTable"] = {
				BlockBreak = true,  -- Added BlockBreak to make critical guardbreak
				Damage = 8,
				PostureDamage = 15,
				Knockback = true, -- Changed from LightKnockback to Knockback for full knockback animation
				M1 = true,
				FX = Replicated.Assets.VFX.Blood.Attachment,
				Stun = 0.7,
			},
			["WaitTime"] = 27 / 60,
			["Endlag"] = 35 / 60,
			["Velocity"] = true,
			["HitTable"] = {},
			["OldCustomFunction"] = function(Character: Model, Entity)
				local Player: Player

				if Entity.Player then
					Player = Entity.Player
				end

				local DamageTable = {
					BlockBreak = true,
					Damage = 10,
					PostureDamage = 20,
					LightKnockback = true,
					M1 = true,
					FX = Replicated.Assets.VFX.Blood.Attachment,
					Stun = 0.7,
				}

				local Cancel = false
				local SwingAnimation =
					Library.PlayAnimation(Character, Replicated.Assets.Animations.Weapons.Fist.Critical)

				SwingAnimation.Stopped:Once(function()
					Server.Modules.Combat.Trail(Character, false)
				end)

				Server.Modules.Combat.Trail(Character, true)

				local m2StunDisconnect = StateManager.OnStunAddedOnce(Character, function(_stunName)
					m2StunDisconnect = nil
					Cancel = true

					if Player then
						Packets.Bvel.sendTo({ Character = Character, Name = "RemoveBvel" }, Player)
					end

					if StateManager.StateCheck(Character, "Actions", "M2") then
						StateManager.RemoveState(Character, "Actions", "M2")
					end

					if StateManager.StateCheck(Character, "Speeds", "M2SpeedSet8") then
						StateManager.RemoveState(Character, "Speeds", "M2SpeedSet8")
					end

					Library.SetCooldown(Character, "Critical", 5)

					SwingAnimation:AdjustSpeed(0.1)
					SwingAnimation:Stop(0.2)
				end)

				-- // 8/60 start movement
				-- // stop at the first hit hmm

				if Player then
					Packets.Bvel.sendTo({ Character = Character, Name = "FistBvel" }, Player)
				end

				StateManager.TimedState(Character, "Speeds", "M2SpeedSet8", 71 / 60)
				StateManager.TimedState(Character, "Actions", "M2", 98 / 60)

				if Cancel then
					return
				end

				task.wait(31 / 60)

				local Size = Vector3.new(5, 7, 8)
				local Offset = CFrame.new(0, 0, -4)

				local HitTargets = Server.Hitbox.SpatialQuery(Character, Size, Entity:GetCFrame() * Offset)

				for _, Target: Model in pairs(HitTargets) do
					Server.Damage.Tag(Character, Target, DamageTable)
					--if not Target:GetAttribute("")
				end

				if Player then
					Visuals.FireClient(
						Player,
						{ Module = "Misc", Function = "CameraShake", Arguments = { "RightSmall" } }
					)
				end

				if Cancel then
					return
				end

				task.wait(40 / 60)

				Library.SetCooldown(Character, "Critical", 5)

				StateManager.TimedState(Character, "Speeds", "M2SpeedSet6", 27 / 60) -- Changed from 0 to 6 for faster combat

				if Player then
					Visuals.FireClient(Player, { Module = "Misc", Function = "CameraShake", Arguments = { "Small" } })
				end

				local HitTargets = Server.Hitbox.SpatialQuery(Character, Size, Entity:GetCFrame() * Offset)

				for _, Target: Model in pairs(HitTargets) do
					Server.Damage.Tag(Character, Target, DamageTable)
					--if not Target:GetAttribute("")
				end

				if Cancel then
					return
				end

				if m2StunDisconnect then m2StunDisconnect() end
			end,
		},

		["LastTable"] = {
			Damage = 10,
			PostureDamage = 20,
			LightKnockback = true,
			M1 = true,
		},

		["RunningAttack"] = {
			Linger = 2 / 60,
			StartVelocity = 0 / 60,
			EndVelocity = 25 / 60,
			TweenTime = 15 / 60,
			DelayToTween = 10 / 60,
			HitTime = 19 / 60,
			Endlag = 39 / 60,
			DelayedBvel = 15 / 60,
		},
	},

	["Flame"] = {
		["MaxCombo"] = 4,
		["Endlag"] = { 26 / 60, 22 / 60, 26 / 60, 35 / 60, 24 / 60 }, -- Final hit (4) endlag reduced for faster recovery
		["HitTimes"] = { 25 / 60, 25 / 60, 28 / 60, 31 / 60, 24 / 60 },
		["SoundTimes"] = {},
		["Hitboxes"] = {
			[1] = {
				["HitboxSize"] = Vector3.new(5, 7, 8),
				["HitboxOffset"] = CFrame.new(0, 0, -4),
			},

			[2] = {
				["HitboxSize"] = Vector3.new(5, 7, 8),
				["HitboxOffset"] = CFrame.new(0, 0, -4),
			},

			[3] = {
				["HitboxSize"] = Vector3.new(5, 7, 8),
				["HitboxOffset"] = CFrame.new(0, 0, -4),
			},

			[4] = {
				["HitboxSize"] = Vector3.new(5, 7, 8),
				["HitboxOffset"] = CFrame.new(0, 0, -4),
			},
		},

		["M1Table"] = {
			Damage = 4,
			PostureDamage = 20,
			LightKnockback = true,
			M1 = true,
			FX = Replicated.Assets.VFX.RunningHit.Attachment,
			Stun = 0.7,
		},

		["Critical"] = {
			["DamageTable"] = {
				BlockBreak = true,
				Damage = 10,
				PostureDamage = 20,
				Knockback = true, -- Changed from LightKnockback to Knockback for full knockback animation
				M2 = true,
				FX = Replicated.Assets.VFX.RunningHit.Attachment,
				Stun = 0.7,
			},
			["HitTable"] = {},
			["WaitTime"] = 20 / 60,
			["Endlag"] = 0.7, -- Reduced from 1 for faster combat
			["Velocity"] = true,
		},

		["LastTable"] = {
			Damage = 10,
			PostureDamage = 20,
			LightKnockback = true,
			M1 = true,
		},

		["RunningAttack"] = {
			Linger = 2 / 60,
			StartVelocity = 0 / 60,
			EndVelocity = 25 / 60,
			TweenTime = 15 / 60,
			DelayToTween = 10 / 60,
			HitTime = 50 / 60,
			Endlag = 57 / 60,
		},
		["RATable"] = {
			Damage = 15,
			PostureDamage = 20,
			Knockback = true,
			FX = Replicated.Assets.VFX.RunningHit.Attachment,
			Stun = 0.7,
		},

		["Exception"] = true,
	},
	["Stone"] = {
		["MaxCombo"] = 4,
		["Endlag"] = { 30 / 60, 26 / 60, 30 / 60, 38 / 60, 28 / 60 }, -- Final hit (4) endlag reduced for faster recovery
		["HitTimes"] = { 25 / 60, 25 / 60, 28 / 60, 31 / 60, 24 / 60 },
		["SoundTimes"] = {},
		["Speed"] = 0.85,  -- Reduced for slower attacks
		["Hitboxes"] = {
			[1] = {
				["HitboxSize"] = Vector3.new(6, 8, 10),  -- Increased from (5,7,8) for more consistent hits
				["HitboxOffset"] = CFrame.new(0, 0, -4),
			},

			[2] = {
				["HitboxSize"] = Vector3.new(6, 8, 10),  -- Increased from (5,7,8) for more consistent hits
				["HitboxOffset"] = CFrame.new(0, 0, -4),
			},

			[3] = {
				["HitboxSize"] = Vector3.new(6, 8, 10),  -- Increased from (5,7,8) for more consistent hits
				["HitboxOffset"] = CFrame.new(0, 0, -4),
			},

			[4] = {
				["HitboxSize"] = Vector3.new(6, 8, 10),  -- Increased from (5,7,8) for more consistent hits
				["HitboxOffset"] = CFrame.new(0, 0, -4),
			},
		},

		["M1Table"] = {
			Damage = 10,
			PostureDamage = 20,
			LightKnockback = true,
			M1 = true,
			FX = Replicated.Assets.VFX.RunningHit.Attachment,
			Stun = 0.7, -- Reduced from 1.3 to allow faster combat flow
		},

		["Critical"] = {
			["DamageTable"] = {
				BlockBreak = true,
				Damage = 10,
				PostureDamage = 20,
				Knockback = true, -- Changed from LightKnockback to Knockback for full knockback animation
				M2 = true,
				FX = Replicated.Assets.VFX.RunningHit.Attachment,
				Stun = 0.7,
			},
			["HitTable"] = {},
			["WaitTime"] = 30 / 60,
			["Endlag"] = 0.7, -- Reduced from 1 for faster combat
			["Velocity"] = true,
			["Sfx"] = {
				[1] = Replicated.Assets.SFX.Skills.StoneCrit.Smash,
				[2] = Replicated.Assets.SFX.Skills.StoneCrit.Electricity,
				[3] = Replicated.Assets.SFX.Skills.StoneCrit.Deconstruct,
			},
		},

		["LastTable"] = {
			Damage = 10,
			PostureDamage = 20,
			LightKnockback = true,
			M1 = true,
		},

		["RunningAttack"] = {
			Linger = 2 / 60,
			StartVelocity = 0 / 60,
			EndVelocity = 25 / 60,
			TweenTime = 15 / 60,
			DelayToTween = 10 / 60,
			HitTime = 50 / 60,
			Endlag = 57 / 60,
		},
		["RATable"] = {
			Damage = 15,
			PostureDamage = 20,
			Knockback = true,
			FX = Replicated.Assets.VFX.RunningHit.Attachment,
			Stun = 0.7,
		},

		["Exception"] = false,
		["SpecialCrit"] = true,
		["SpecialCritSound"] = true,
	},

	["Guns"] = {
		["MaxCombo"] = 3,
		["Endlag"] = { 24 / 60, 28 / 60, 35 / 60, 36 / 60, 32 / 60 },  -- Final hit (3) endlag reduced for faster recovery
		["HitTimes"] = { 16 / 60, 18 / 60, 22 / 60, 28 / 60, 32 / 60 },  -- Adjusted for 1.0x speed
		["SoundTimes"] = {},
		["Exception"] = true,
		["Speed"] = 0.85,  -- Reduced for slower attacks
		["Hitboxes"] = {
			[1] = {
				["HitboxSize"] = Vector3.new(6, 8, 10),  -- Increased from (5,7,8) for more consistent hits
				["HitboxOffset"] = CFrame.new(0, 0, -4),
			},
			[2] = {
				["HitboxSize"] = Vector3.new(6, 8, 10),  -- Increased from (5,7,8) for more consistent hits
				["HitboxOffset"] = CFrame.new(0, 0, -4),
			},
			[3] = {
				["HitboxSize"] = Vector3.new(6, 8, 10),  -- Increased from (5,7,8) for more consistent hits
				["HitboxOffset"] = CFrame.new(0, 0, -4),
			},
			[4] = {
				["HitboxSize"] = Vector3.new(6, 8, 10),  -- Increased from (5,7,8) for more consistent hits
				["HitboxOffset"] = CFrame.new(0, 0, -4),
			},
			[5] = {
				["HitboxSize"] = Vector3.new(6, 8, 10),  -- Increased from (5,7,8) for more consistent hits
				["HitboxOffset"] = CFrame.new(0, 0, -4),
			},
		},
		["M1Table"] = {
			Damage = 3.5,
			PostureDamage = 20,
			LightKnockback = true,
			M1 = true,
			FX = Replicated.Assets.VFX.RunningHit.Attachment,
			Stun = 0.7, -- Reduced from 1.2 to allow faster combat flow
			SFX = "Guns",
		},
		["LastTable"] = {
			Damage = 5,
			PostureDamage = 30,
			LightKnockback = true,
			M1 = true,
			FX = Replicated.Assets.VFX.RunningHit.Attachment,
			Stun = 0.8,
		},
		["Critical"] = {
			["DamageTable"] = {
				BlockBreak = true,
				Damage = 10,
				PostureDamage = 40,
				Knockback = true, -- Changed from LightKnockback to Knockback for full knockback animation
				M2 = true,
				FX = Replicated.Assets.VFX.RunningHit.Attachment,
				Stun = 1.0,
			},
			["HitTable"] = {},
			["WaitTime"] = 20 / 60,
			["Endlag"] = 0.7, -- Reduced from 1 for faster combat
			["Velocity"] = true,
		},

		["RunningAttack"] = {
			Linger = 2 / 60,
			StartVelocity = 0 / 60,
			EndVelocity = 25 / 60,
			TweenTime = 15 / 60,
			DelayToTween = 10 / 60,
			HitTime = 50 / 60,
			Endlag = 57 / 60,
		},
		["RATable"] = {
			Damage = 15,
			PostureDamage = 20,
			Knockback = true,
			FX = Replicated.Assets.VFX.RunningHit.Attachment,
			Stun = 0.7,
		},
	},

	["Scythe"] = {
		["MaxCombo"] = 5,
		-- Endlag = end frame + linger time (2 frames extra linger at end)
		-- m1 1: ends f21 + 2 linger = 23, m1 2: ends f18 + 2 = 20, m1 3: ends f19 + 2 = 21
		-- m1 4: ends f24 + 2 = 26, m1 5: endlag reduced for faster recovery
		["Endlag"] = { 23 / 60, 20 / 60, 21 / 60, 26 / 60, 38 / 60 },
		-- HitTimes = start frame (when hitbox begins)
		-- m1 1: f18, m1 2: f15, m1 3: f16, m1 4: f21, m1 5: f20
		["HitTimes"] = { 18 / 60, 15 / 60, 16 / 60, 21 / 60, 20 / 60 },
		["SoundTimes"] = {},
		["Speed"] = 1,  -- Normal speed, timing is controlled by frame data
		["Hitboxes"] = {
			[1] = {
				-- m1 1: f18-f21 (3 frames) + 2 linger = 5 frames duration
				["HitboxSize"] = Vector3.new(8, 9, 12),  -- Wide arc hitbox
				["HitboxOffset"] = CFrame.new(0, 0, -5),
				["HitboxDuration"] = 5 / 60,  -- Duration hitbox is active
			},
			[2] = {
				-- m1 2: f15-f18 (3 frames) + 2 linger = 5 frames duration
				["HitboxSize"] = Vector3.new(8, 9, 12),
				["HitboxOffset"] = CFrame.new(0, 0, -5),
				["HitboxDuration"] = 5 / 60,
			},
			[3] = {
				-- m1 3: f16-f19 (3 frames) + 2 linger = 5 frames duration
				["HitboxSize"] = Vector3.new(8, 9, 12),
				["HitboxOffset"] = CFrame.new(0, 0, -5),
				["HitboxDuration"] = 5 / 60,
			},
			[4] = {
				-- m1 4: f21-f24 (3 frames) + 2 linger = 5 frames duration
				["HitboxSize"] = Vector3.new(8, 9, 12),
				["HitboxOffset"] = CFrame.new(0, 0, -5),
				["HitboxDuration"] = 5 / 60,
			},
			[5] = {
				-- m1 5: f20-f24 (4 frames) + 2 linger = 6 frames duration
				["HitboxSize"] = Vector3.new(9, 10, 14),  -- Final hit has larger hitbox
				["HitboxOffset"] = CFrame.new(0, 0, -5),
				["HitboxDuration"] = 6 / 60,
			},
		},

		["M1Table"] = {
			Damage = 8,  -- Higher damage per hit due to slower speed
			PostureDamage = 25,
			LightKnockback = true,
			M1 = true,
			FX = Replicated.Assets.VFX.Blood.Attachment,
			Stun = 0.8,
		},

		["Critical"] = {
			["DamageTable"] = {
				BlockBreak = true,
				Damage = 14,
				PostureDamage = 35,
				Knockback = true,
				M2 = true,
				FX = Replicated.Assets.VFX.Blood.Attachment,
				Stun = 0.9,
			},
			["HitTable"] = {},
			["WaitTime"] = 46 / 60,  -- Frame 46 is when hitbox activates
			["Endlag"] = 54 / 60,  -- Animation ends at frame 54
			["Velocity"] = false,  -- No velocity, character is locked
		},
		["SpecialCrit"] = true,  -- Triggers SpecialCritScythe VFX function

		["LastTable"] = {
			Damage = 12,
			PostureDamage = 30,
			LightKnockback = true,
			M1 = true,
		},

		["RunningAttack"] = {
			Linger = 2 / 60,
			StartVelocity = 0 / 60,
			EndVelocity = 22 / 60,  -- Slightly slower forward movement
			TweenTime = 18 / 60,
			DelayToTween = 12 / 60,
			HitTime = 55 / 60,
			Endlag = 62 / 60,
		},
		["RATable"] = {
			Damage = 18,
			PostureDamage = 30,
			Knockback = true,
			FX = Replicated.Assets.VFX.Blood.Attachment,
			Stun = 0.8,
		},

		["Slashes"] = true,
		["Trail"] = true,
	},
}

return Table
