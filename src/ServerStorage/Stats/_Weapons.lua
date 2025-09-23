-- Services

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local Replicated = game:GetService("ReplicatedStorage")
local Library = require(Replicated.Modules.Library)
local Visuals = require(Replicated.Modules.Visuals)
local Packets = require(Replicated.Modules.Packets)
local Server = require(ServerScriptService.ServerConfig.Server)

local Table = {

	["Fist"] = {
		["MaxCombo"] = 4,
		["Endlag"] = { 25.6 / 60, 22.4 / 60, 25.6 / 60, 28 / 60, 24 / 60 },  -- Adjusted for 1.25x speed (25% faster)
		["HitTimes"] = { 20 / 60, 20 / 60, 22.4 / 60, 24.8 / 60, 19.2 / 60 },  -- Adjusted for 1.25x speed (25% faster)
		["SoundTimes"] = {},
		["Speed"] = 1.25,  -- Increased fist M1 speed from default 1.0 to 1.25
		["Hitboxes"] = {
			[1] = {
				["HitboxSize"] = Vector3.new(3,5,5),
				["HitboxOffset"] = CFrame.new(0, 0, -4),
			},

			[2] = {
				["HitboxSize"] = Vector3.new(3,5,5),
				["HitboxOffset"] = CFrame.new(0, 0, -4),
			},

			[3] = {
				["HitboxSize"] = Vector3.new(3,5,5),
				["HitboxOffset"] = CFrame.new(0, 0, -4),
			},

			[4] = {
				["HitboxSize"] = Vector3.new(3,5,5),
				["HitboxOffset"] = CFrame.new(0, 0, -4),
			},
		},

		["M1Table"] = {
			Damage = 10,
			PostureDamage = 50,
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
				LightKnockback = true,
				M2 = true,
				FX = Replicated.Assets.VFX.RunningHit.Attachment,
				Stun = 0.7,
			},
			["HitTable"] = {},
			["WaitTime"] = 20 / 60,
			["Endlag"] = 1,
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

				Entity["M2Connection"] = Character.Stuns.Changed:Once(function()
					Entity["M2Connection"] = nil
					Cancel = true

					if Player then
						Packets.Bvel.sendTo({ Character = Character, Name = "RemoveBvel" }, Player)
					end

					if Library.StateCheck(Character.Actions, "M2") then
						Library.RemoveState(Character.Actions, "M2")
					end

					if Library.StateCheck(Character.Speeds, "M2SpeedSet8") then
						Library.RemoveState(Character.Speeds, "M2SpeedSet8")
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

				Library.TimedState(Character.Speeds, "M2SpeedSet8", 71 / 60)
				Library.TimedState(Character.Actions, "M2", 98 / 60)

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

				Library.TimedState(Character.Speeds, "M2SpeedSet0", 27 / 60)

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

				Entity["M2Connection"]:Disconnect()
				Entity["M2Connection"] = nil
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

		["Slashes"] = true,

		["Trail"] = true,
	},

	["Spear"] = {
		["MaxCombo"] = 5,
		["Endlag"] = { 32 / 60, 28 / 60, 32 / 60, 35 / 60, 30 / 60, 25/60 },
		["HitTimes"] = { 25 / 60, 25 / 60, 28 / 60, 31 / 60, 24 / 60, 25/60 },
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
			[5] = {
				["HitboxSize"] = Vector3.new(5, 7, 8),
				["HitboxOffset"] = CFrame.new(0, 0, -4),
			},
		},

		["M1Table"] = {
			Damage = 10,
			PostureDamage = 50,
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
				LightKnockback = true,
				M2 = true,
				FX = Replicated.Assets.VFX.RunningHit.Attachment,
				Stun = 0.7,
			},
			["HitTable"] = {},
			["WaitTime"] = 20 / 60,
			["Endlag"] = 1,
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

				Entity["M2Connection"] = Character.Stuns.Changed:Once(function()
					Entity["M2Connection"] = nil
					Cancel = true

					if Player then
						Packets.Bvel.sendTo({ Character = Character, Name = "RemoveBvel" }, Player)
					end

					if Library.StateCheck(Character.Actions, "M2") then
						Library.RemoveState(Character.Actions, "M2")
					end

					if Library.StateCheck(Character.Speeds, "M2SpeedSet8") then
						Library.RemoveState(Character.Speeds, "M2SpeedSet8")
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

				Library.TimedState(Character.Speeds, "M2SpeedSet8", 71 / 60)
				Library.TimedState(Character.Actions, "M2", 98 / 60)

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

				Library.TimedState(Character.Speeds, "M2SpeedSet0", 27 / 60)

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

				Entity["M2Connection"]:Disconnect()
				Entity["M2Connection"] = nil
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
		["Endlag"] = { 29 / 60, 29 / 60, 29 / 60, 32 / 60 },
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
				Damage = 8,
				PostureDamage = 15,
				LightKnockback = true,
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

				Entity["M2Connection"] = Character.Stuns.Changed:Once(function()
					Entity["M2Connection"] = nil
					Cancel = true

					if Player then
						Packets.Bvel.sendTo({ Character = Character, Name = "RemoveBvel" }, Player)
					end

					if Library.StateCheck(Character.Actions, "M2") then
						Library.RemoveState(Character.Actions, "M2")
					end

					if Library.StateCheck(Character.Speeds, "M2SpeedSet8") then
						Library.RemoveState(Character.Speeds, "M2SpeedSet8")
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

				Library.TimedState(Character.Speeds, "M2SpeedSet8", 71 / 60)
				Library.TimedState(Character.Actions, "M2", 98 / 60)

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

				Library.TimedState(Character.Speeds, "M2SpeedSet0", 27 / 60)

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

				Entity["M2Connection"]:Disconnect()
				Entity["M2Connection"] = nil
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
		["Endlag"] = { 32 / 60, 28 / 60, 32 / 60, 35 / 60, 30 / 60 },
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
			Damage = 10,
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
				LightKnockback = true,
				M2 = true,
				FX = Replicated.Assets.VFX.RunningHit.Attachment,
				Stun = 0.7,
			},
			["HitTable"] = {},
			["WaitTime"] = 20 / 60,
			["Endlag"] = 1,
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
	-- ["Guns"] = {
	-- 	["MaxCombo"] = 3,
	-- 	["Endlag"] = { 22 / 60, 25 / 60, 30 / 60, 35 / 60, 30 / 60 },
	-- 	["HitTimes"] = { 20 / 60, 22 / 60, 28 / 60, 26 / 60, 31 / 60 },
	-- 	["SoundTimes"] = {},
	-- 	["Hitboxes"] = {
	-- 		[1] = {
	-- 			["HitboxSize"] = Vector3.new(5, 7, 8),
	-- 			["HitboxOffset"] = CFrame.new(0, 0, -4),
	-- 		},

	-- 		[2] = {
	-- 			["HitboxSize"] = Vector3.new(5, 7, 8),
	-- 			["HitboxOffset"] = CFrame.new(0, 0, -4),
	-- 		},

	-- 		[3] = {
	-- 			["HitboxSize"] = Vector3.new(5, 7, 8),
	-- 			["HitboxOffset"] = CFrame.new(0, 0, -4),
	-- 		},

	-- 		[4] = {
	-- 			["HitboxSize"] = Vector3.new(5, 7, 8),
	-- 			["HitboxOffset"] = CFrame.new(0, 0, -4),
	-- 		},
	-- 	},
	-- 	["M1Table"] = {
	-- 		Damage = 10,
	-- 		PostureDamage = 20,
	-- 		LightKnockback = true,
	-- 		M1 = true,
	-- 		FX = Replicated.Assets.VFX.RunningHit.Attachment,
	-- 		Stun = 0.7,
	-- 		SFX = "Guns",
	-- 	},
	-- 	["Critical"] = {
	-- 		["DamageTable"] = {
	-- 			BlockBreak = true,
	-- 			Damage = 10,
	-- 			PostureDamage = 20,
	-- 			LightKnockback = true,
	-- 			M2 = true,
	-- 			FX = Replicated.Assets.VFX.RunningHit.Attachment,
	-- 			Stun = 0.7,
	-- 		},
	-- 		["HitTable"] = {},
	-- 		["WaitTime"] = 20 / 60,
	-- 		["Endlag"] = 1,
	-- 		["Velocity"] = true,
	-- 	},
	-- 	["LastTable"] = {
	-- 		Damage = 10,
	-- 		PostureDamage = 20,
	-- 		LightKnockback = true,
	-- 		M1 = true,
	-- 	},
	-- 	["RunningAttack"] = {
	-- 		Linger = 2 / 60,
	-- 		StartVelocity = 0 / 60,
	-- 		EndVelocity = 25 / 60,
	-- 		TweenTime = 15 / 60,
	-- 		DelayToTween = 10 / 60,
	-- 		HitTime = 50 / 60,
	-- 		Endlag = 57 / 60,
	-- 	},
	-- 	["RATable"] = {
	-- 		Damage = 15,
	-- 		PostureDamage = 20,
	-- 		Knockback = true,
	-- 		FX = Replicated.Assets.VFX.RunningHit.Attachment,
	-- 		Stun = 0.7,
	-- 	},
	-- 	["Exception"] = true,
	-- 	["Speed"] = 1.75,
	-- },
	["Stone"] = {
		["MaxCombo"] = 4,
		["Endlag"] = { 32 / 60, 28 / 60, 32 / 60, 35 / 60, 30 / 60 },
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
			Damage = 10,
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
				LightKnockback = true,
				M2 = true,
				FX = Replicated.Assets.VFX.RunningHit.Attachment,
				Stun = 0.7,
			},
			["HitTable"] = {},
			["WaitTime"] = 30 / 60,
			["Endlag"] = 1,
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
		["Endlag"] = { 29.3 / 60, 33.3 / 60, 40 / 60, 46.7 / 60, 40 / 60 },  -- Adjusted for 0.75x speed (25% slower)
		["HitTimes"] = { 20 / 60, 21.3 / 60, 26.7 / 60, 34.7 / 60, 41.3 / 60 },  -- Adjusted for 0.75x speed (25% slower)
		["SoundTimes"] = {},
		["Exception"] = true,
		["Speed"] = 0.75,  -- Nerfed gun M1 speed from 1.0 to 0.75
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
			[5] = {
				["HitboxSize"] = Vector3.new(5, 7, 8),
				["HitboxOffset"] = CFrame.new(0, 0, -4),
			},
		},
		["M1Table"] = {
			Damage = 3.5,
			PostureDamage = 20,
			LightKnockback = true,
			M1 = true,
			FX = Replicated.Assets.VFX.RunningHit.Attachment,
			Stun = 0.7,
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
				LightKnockback = true,
				M2 = true,
				FX = Replicated.Assets.VFX.RunningHit.Attachment,
				Stun = 1.0,
			},
			["HitTable"] = {},
			["WaitTime"] = 20 / 60,
			["Endlag"] = 1,
			["Velocity"] = true,
		},
	},
}

return Table
