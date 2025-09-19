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

	["Deconstruct"] = {
		["DamageTable"] = {
			BlockBreak = false,
			Damage = 3.5,
			PostureDamage = 5,
			LightKnockback = false,
			M2 = false,
			FX = Replicated.Assets.VFX.Blood.Attachment,
			Stun = 0.2,
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
				Stun = 0.25,
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
				Damage = 3.5,
				PostureDamage = 5,
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
			["HitTimes"] = {14/83, 43/84, 55/84, 69/84, 83/84},
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
