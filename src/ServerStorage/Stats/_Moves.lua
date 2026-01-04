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

	["Truth"] = {
		["DamageTable"] = {
			BlockBreak = false,
			Damage = 0, -- This move doesn't deal damage, it teleports
			PostureDamage = 0,
			LightKnockback = false,
			M2 = false,
			Stun = 0,
		},
	},

	["Deconstruct"] = {
		["DamageTable"] = {
			BlockBreak = false,
			Damage = 3.5,
			PostureDamage = 5,
			LightKnockback = false,
			M2 = false,
			FX = Replicated.Assets.VFX.Blood.Attachment,
			Stun = 0.2,
			-- Junction system: 10% chance arm removal
			Junction = "RandomArm",
			JunctionChance = 0.10,
		},
	},
	["Alchemic Assault"] = {
		["DamageTable"] = {
			BlockBreak = true,
			Damage = 10,
			PostureDamage = 25,
			LightKnockback = false,
			Launch = "Mid",
			M2 = false,
			FX = Replicated.Assets.VFX.Blood.Attachment,
			Stun = 0.2,
		},
	},

	["Stone Lance"] = {
		["DamageTable"] = {
			BlockBreak = true,
			Damage = 10,
			PostureDamage = 25,
			LightKnockback = false,
			Launch = "High",
			M2 = false,
			FX = Replicated.Assets.VFX.Blood.Attachment,
			Stun = 0.6,
			["Hittimes"] = {17/72, 46/72}
		},
	},
	["Flame"] = {
		["DamageTable1"] = {
			BlockBreak = false,
			Damage = 3.5,
			PostureDamage = 5,
			LightKnockback = false,
			M2 = false,
			FX = Replicated.Assets.VFX.Flame.Attachment,
			Stun = 0.15,
		},
		["ExplosionM1"] = {
			BlockBreak = false,
			Damage = 5.5,
			PostureDamage = 10,
			LightKnockback = false,
			M2 = false,
			FX = Replicated.Assets.VFX.Flame.Attachment,
			Stun = 0.35,
			Status = {
				ProcChance = 0.5,
				ProcDmg = 1.1,
				Tick = 0.3,
				Duration = 3,
				Name = "Flame",
			},
		},
		["Firestorm"] = {
			["HitTimes"] = { 28 / 229, 125 / 229, 146 / 229, 167 / 229, 188 / 229, 200 / 229 },
			["DamageTableStart"] = {
				BlockBreak = true,
				Damage = 5,
				PostureDamage = 25,
				LightKnockback = false,
				M2 = false,
				FX = Replicated.Assets.VFX.Flame.Attachment,
				Stun = 1.5, -- Increased stun to ensure rapid fire hits connect
			},
			["DamageTableRapid"] = {
				BlockBreak = false,
				Damage = 2,
				PostureDamage = 4,
				LightKnockback = false,
				M2 = false,
				FX = Replicated.Assets.VFX.Flame.Attachment,
				Stun = 0.25,
			},
			["DamageTableEnd"] = {
				BlockBreak = false,
				Damage = 4,
				PostureDamage = 4,
				LightKnockback = false,
				M2 = false,
				FX = Replicated.Assets.VFX.Flame.Attachment,
				Stun = 0.25,
			},
			["Hitboxes"] = {
				[1] = {
					["HitboxSize"] = Vector3.new(5,5,5),
					["HitboxOffset"] = CFrame.new(0, 0, -3),
				},

				[2] = {
					["HitboxSize"] = Vector3.new(7,7,7),
					["HitboxOffset"] = CFrame.new(0, 0, -10),
				},

				[3] = {
					["HitboxSize"] = Vector3.new(10, 10, 10),
					["HitboxOffset"] = CFrame.new(0, 0, -7),
				},
			},
		},
		["Cinder"] = {
			["Hitboxes"] = {
				[1] = {
					["HitboxSize"] = Vector3.new(15,10,30),
					["HitboxOffset"] = CFrame.new(0, 0, -15),
				},
			},
			["DamageTable"] = {
				BlockBreak = false,
				Damage = 1.5,  -- Greatly reduced from 3.5 to 1.5
				PostureDamage = 3,  -- Reduced from 5 to 3
				LightKnockback = false,
				M2 = false,
				FX = Replicated.Assets.VFX.Flame.Attachment,
				Stun = 0.1,
			},
		},
	},
	["Stone"] = {
		["DamageTable1"] = {
			BlockBreak = false,
			Damage = 3.5,
			PostureDamage = 5,
			LightKnockback = false,
			M2 = false,
			FX = Replicated.Assets.VFX.RunningHit.Attachment,
			Stun = 0.15,
		},
		["ExplosionM1"] = {
			BlockBreak = false,
			Damage = 5.5,
			PostureDamage = 10,
			LightKnockback = false,
			M2 = false,
			FX = Replicated.Assets.VFX.Flame.Attachment,
			Stun = 0.35,
			Status = {
				ProcChance = 0.5,
				ProcDmg = 1.1,
				Tick = 0.3,
				Duration = 3,
				Name = "Flame",
			},
		},
		["Cascade"] = {
			["HitTimes"] = {14/83, 43/84, 55/84, 69/84, 83/84, 95/84, 107/84},  -- Added 2 additional rows (total 7 hit times for 5 rows)
			["Hitboxes"] = {
				[1] = {
					["HitboxSize"] = Vector3.new(10,10,10),
					["HitboxOffset"] = CFrame.new(0, 0, -5),
				},
			},
			["Rapid"] = {
				BlockBreak = true,
				Damage = 8,
				PostureDamage = 14,
				LightKnockback = false,
				M2 = false,
				FX = Replicated.Assets.VFX.RunningHit.Attachment,
				Stun = 0.3,
			},
		},
	},
}

return Table
