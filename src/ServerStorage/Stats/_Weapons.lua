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
		["Endlag"] = { 30 / 60, 27 / 60, 30 / 60, 40 / 60, 28 / 60 },  -- Increased for more readable pacing
		["HitTimes"] = { 21.7 / 60, 21.7 / 60, 24.3 / 60, 26.9 / 60, 20.9 / 60 },
		["SoundTimes"] = {},
		["Speed"] = 0.75,  -- Slower animations for readability
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
			Stun = 0.85, -- Increased for more readable pacing
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
			["Endlag"] = 0.9, -- Increased for more readable pacing
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
			Knockback = true,
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
		["Endlag"] = { 34 / 60, 30 / 60, 34 / 60, 36 / 60, 42 / 60, 28/60 }, -- Increased for more readable pacing
		["HitTimes"] = { 25 / 60, 25 / 60, 28 / 60, 31 / 60, 24 / 60, 25/60 },
		["SoundTimes"] = {},
		["Speed"] = 0.75,  -- Slower animations for readability
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
			Stun = 0.85, -- Increased for more readable pacing
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
			["Endlag"] = 0.9, -- Increased for more readable pacing
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
			Knockback = true,
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
		["Endlag"] = { 28 / 60, 28 / 60, 28 / 60, 40 / 60 }, -- Increased for more readable pacing
		["HitTimes"] = { 24 / 60, 24 / 60, 24 / 60, 24 / 60 },
		["SoundTimes"] = {},
		["Speed"] = 0.8,  -- Slower animations for readability
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
			Knockback = true,
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
		["Endlag"] = { 30 / 60, 26 / 60, 30 / 60, 40 / 60, 28 / 60 }, -- Increased for more readable pacing
		["HitTimes"] = { 25 / 60, 25 / 60, 28 / 60, 31 / 60, 24 / 60 },
		["SoundTimes"] = {},
		["Speed"] = 0.8,  -- Slower animations for readability
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
			["Endlag"] = 0.9, -- Increased for more readable pacing
			["Velocity"] = true,
		},

		["LastTable"] = {
			Damage = 10,
			PostureDamage = 20,
			Knockback = true,
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
		["Endlag"] = { 34 / 60, 30 / 60, 34 / 60, 42 / 60, 32 / 60 }, -- Increased for more readable pacing
		["HitTimes"] = { 25 / 60, 25 / 60, 28 / 60, 31 / 60, 24 / 60 },
		["SoundTimes"] = {},
		["Speed"] = 0.75,  -- Slower animations for readability
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
			Stun = 0.85, -- Increased for more readable pacing
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
			["Endlag"] = 0.9, -- Increased for more readable pacing
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
			Knockback = true,
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
		["Endlag"] = { 28 / 60, 32 / 60, 40 / 60, 40 / 60, 36 / 60 },  -- Increased for more readable pacing
		["HitTimes"] = { 16 / 60, 18 / 60, 22 / 60, 28 / 60, 32 / 60 },
		["SoundTimes"] = {},
		["Exception"] = true,
		["Speed"] = 0.75,  -- Slower animations for readability
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
			Stun = 0.85, -- Increased for more readable pacing
			SFX = "Guns",
		},
		["LastTable"] = {
			Damage = 5,
			PostureDamage = 30,
			Knockback = true,
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
			["Endlag"] = 0.9, -- Increased for more readable pacing
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
		["MaxCombo"] = 4,
		-- Endlag = end frame + linger time, increased for more readable pacing
		["Endlag"] = { 33 / 60, 30 / 60, 31 / 60, 48 / 60 },
		-- HitTimes = start frame (when hitbox begins)
		["HitTimes"] = { 18 / 60, 15 / 60, 16 / 60, 20 / 60 },
		["SoundTimes"] = {},
		["Speed"] = 1,
		["M1Speed"] = "M1Speed8",
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
				-- m1 4 (final): f20-f24 (4 frames) + 2 linger = 6 frames duration
				["HitboxSize"] = Vector3.new(9, 10, 14),  -- Final hit has larger hitbox
				["HitboxOffset"] = CFrame.new(0, 0, -5),
				["HitboxDuration"] = 6 / 60,
			},
		},

		["M1Table"] = {
			Damage = 8,  -- Higher damage per hit due to slower speed
			PostureDamage = 7,
			LightKnockback = true,
			M1 = true,
			FX = Replicated.Assets.VFX.Blood.Attachment,
			Stun = 0.8,
		},

		["Critical"] = {
			["DamageTable"] = {
				BlockBreak = true,
				Damage = 14,
				PostureDamage = 12,
				Knockback = true,
				M2 = true,
				FX = Replicated.Assets.VFX.Blood.Attachment,
				Stun = 0.9,
			},
			["HitTable"] = {},
			["WaitTime"] = 46 / 60,  -- Frame 46 is when hitbox activates
			["Endlag"] = 54 / 60,  -- Animation ends at frame 54
			["Velocity"] = false,  -- No velocity, character is locked
			["CritHitbox"] = {
				["HitboxSize"] = Vector3.new(8, 9, 16),  -- Longer forward reach
				["HitboxOffset"] = CFrame.new(0, 0, -8),  -- 8 studs forward
			},
		},
		["SpecialCrit"] = true,  -- Triggers SpecialCritScythe VFX function

		["LastTable"] = {
			Damage = 12,
			PostureDamage = 10,
			Knockback = true,
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
			PostureDamage = 10,
			Knockback = true,
			FX = Replicated.Assets.VFX.Blood.Attachment,
			Stun = 0.8,
		},

		["Aerial"] = {
			["DamageTable"] = {
				Damage = 14,
				PostureDamage = 12,
				Knockback = true,
				M1 = true,
				FX = Replicated.Assets.VFX.Blood.Attachment,
				Stun = 1.0,
			},
			["PauseTime"] = 0.3,                  -- Pause animation after 0.3s (before attack frame)
			["HitTimeAfterResume"] = 6 / 60,      -- 6 frames after landing to check hitbox
			["Endlag"] = 28 / 60,                  -- Recovery after landing hit
			["LandingHitboxSize"] = Vector3.new(14, 10, 14),  -- Large circular landing hitbox
			["LandingHitboxOffset"] = CFrame.new(0, -2, -2),  -- Centered below and slightly forward
		},

		["Slashes"] = true,
		["Trail"] = true,
	},
}

return Table
