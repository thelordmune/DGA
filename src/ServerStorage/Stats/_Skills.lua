local Replicated = game:GetService("ReplicatedStorage")

local Table = {
    ["Spear"] = {
        ["Needle Thrust"] = {
            ["DamageTable"] = {
            BlockBreak = false,
			Damage = 3.5,
			PostureDamage = 5,
			LightKnockback = false,
			M2 = false,
			FX = Replicated.Assets.VFX.Blood.Attachment,
			Stun = 0.8, -- Increased from 0.4 to 0.8 for better NPC stun
			-- Junction System: Spear thrust can pierce limbs
			Junction = "Random",
			JunctionChance = 0.005, -- 0.5% - very rare
            },
            Description = "Lunge yourself at the enemy piercing your blade through their skin.",
            ["HitTime"] = {36/71}
        },

		["Grand Cleave"] = {
			["Slash1"] = {
				BlockBreak = false,
				Damage = 3.5,
				PostureDamage = 5,
				LightKnockback = false,
				M2 = false,
				FX = Replicated.Assets.VFX.Blood.Attachment,
				Stun = 0.4,
				Junction = "Random",
				JunctionChance = 0.005, -- 0.5% - very rare
			},
			["Slash2"] = {
				BlockBreak = false,
				Damage = 4,
				PostureDamage = 5,
				LightKnockback = false,
				M2 = false,
				FX = Replicated.Assets.VFX.Blood.Attachment,
				Stun = 0.4,
				Junction = "Random",
				JunctionChance = 0.005, -- 0.5% - very rare
			},
			["Slash3"] = {
				BlockBreak = true,
				Damage = 6,
				PostureDamage = 5,
				LightKnockback = false,
				M2 = false,
				FX = Replicated.Assets.VFX.Blood.Attachment,
				Stun = 0.4,
				Junction = "Random",
				JunctionChance = 0.01, -- 1% final hit
			},
			["HitTimes"] = {25/120, 29/120, 38/120, 51/120, 52/120, 54/120, 79/120, 83/120, 89/120}
			-- startslash, startdrag1, enddrag1, startdrag2, startslash and swingwooo, enddrag2, startslash, startdrag3, enddrag3
		},
		["WhirlWind"] = {
			["Slash1"] = {
				BlockBreak = true, -- Changed to true for guardbreak
				Damage = 3.5,
				PostureDamage = 5,
				LightKnockback = false,
				M2 = false,
				FX = Replicated.Assets.VFX.Blood.Attachment,
				Stun = 0.6,
				Junction = "Random",
				JunctionChance = 0.005, -- 0.5% - very rare
			},
			["Slash2"] = {
				BlockBreak = true,
				Damage = 4,
				PostureDamage = 5,
				LightKnockback = false,
				M2 = false,
				FX = Replicated.Assets.VFX.Blood.Attachment,
				Stun = 0.4,
				Junction = "Random",
				JunctionChance = 0.005, -- 0.5% - very rare
			},
			["Hittimes"] = {13/110, 16/110, 24/110, 25/110, 39/110, 56/110, 59/110}
    	},
		["Rapid Thrust"] = {
			["Slash1"] = {
				BlockBreak = true, -- Changed to true for guardbreak
				Damage = 3.5,
				PostureDamage = 5,
				LightKnockback = false,
				M2 = false,
				FX = Replicated.Assets.VFX.Blood.Attachment,
				Stun = 0.4,
				Junction = "Random",
				JunctionChance = 0.005, -- 0.5% - very rare
			},
			["Slash2"] = {
				BlockBreak = true,
				Damage = 4,
				PostureDamage = 5,
				LightKnockback = false,
				M2 = false,
				FX = Replicated.Assets.VFX.Blood.Attachment,
				Stun = 0.4,
				Junction = "Random",
				JunctionChance = 0.005, -- 0.5% - very rare
			},
			["Repeat"] = {
				BlockBreak = false,
				Damage = 1.5,
				PostureDamage = 5,
				LightKnockback = false,
				M2 = false,
				FX = Replicated.Assets.VFX.Blood.Attachment,
				Stun = 0.5,
				Junction = "Random",
				JunctionChance = 0.002, -- 0.2% per hit (many hits)
			},
			["Slam"] = {
				BlockBreak = true,
				Damage = 10,
				PostureDamage = 15,
				LightKnockback = false,
				M2 = false,
				FX = Replicated.Assets.VFX.Blood.Attachment,
				Stun = 0.3,
				Junction = "Random",
				JunctionChance = 0.01, -- 1% final slam
			},
			["Hittimes"] = {27/285, 77/285, 100/285, 115/285, 130/285, 145/285, 160/285, 175/285, 190/285, 205/285, 219/285, 223/285, 230/285, 238/285}
		},
		["Charged Thrust"] = {
			["Init"] = {
				BlockBreak = true, -- Changed to true for guardbreak
				Damage = 3.5,
				PostureDamage = 5,
				LightKnockback = false,
				M2 = false,
				FX = Replicated.Assets.VFX.Blood.Attachment,
				Stun = 1,
				Junction = "Random",
				JunctionChance = 0.005, -- 0.5% - very rare
			},
			["Pull"] = {
				BlockBreak = true,
				Damage = 4,
				PostureDamage = 5,
				LightKnockback = false,
				M2 = false,
				FX = Replicated.Assets.VFX.Blood.Attachment,
				Stun = 1,
				Junction = "Random",
				JunctionChance = 0.01, -- 1% final hit
			},
			["Hittimes"] = {18/90, 30/90}
		}
		},
    ["Guns"] = {
        ["Shell Piercer"] = {
            ["DamageTable"] = {
            BlockBreak = true, -- Now breaks guard
			Damage = 3.5,
			PostureDamage = 5,
			LightKnockback = false,
			M2 = false,
			FX = Replicated.Assets.VFX.Blood.Attachment,
			Stun = 1.2, -- Increased from 0.4 for better stun
			Junction = "Random",
			JunctionChance = 0.005, -- 0.5% - very rare
            },
            Description = "Lunge yourself at the enemy piercing your blade through their skin.",
            ["HitTime"] = {20/50}
        },
        ["Strategist Combination"] = {
            ["Sweep"] = {
            BlockBreak = false,
			NoBlock = false, -- Cannot be blocked during combo
			Damage = 3.5,
			PostureDamage = 5,
			LightKnockback = false,
			M2 = false,
			FX = Replicated.Assets.VFX.Blood.Attachment,
			Stun = 0.4,
			Junction = "RandomLeg",
			JunctionChance = 0.005, -- 0.5% - very rare
            },
            ["Up"] = {
            BlockBreak = false,
			NoBlock = true, -- Cannot be blocked during combo
			Damage = 3.5,
			PostureDamage = 5,
			LightKnockback = false,
			M2 = false,
			FX = Replicated.Assets.VFX.Blood.Attachment,
			Stun = 0.4,
			Junction = "Random",
			JunctionChance = 0.005, -- 0.5% - very rare
            },
            ["Down"] = {
            BlockBreak = false,
			NoBlock = true, -- Cannot be blocked during combo
			Damage = 3.5,
			PostureDamage = 5,
			LightKnockback = false,
			M2 = false,
			FX = Replicated.Assets.VFX.Blood.Attachment,
			Stun = 0.4,
			Junction = "Random",
			JunctionChance = 0.005, -- 0.5% - very rare
            },
            ["groundye"] = {
            BlockBreak = false,
			NoBlock = true, -- Cannot be blocked during combo
			Damage = 3.5,
			PostureDamage = 5,
			LightKnockback = false,
			M2 = false,
			FX = Replicated.Assets.VFX.Blood.Attachment,
			Stun = 0.4,
			Junction = "RandomLeg",
			JunctionChance = 0.005, -- 0.5% - very rare
            },
            ["LFire"] = {
            BlockBreak = false,
			NoBlock = true,
			Damage = .5,
			PostureDamage = 5,
			LightKnockback = false,
			M2 = false,
			FX = Replicated.Assets.VFX.Blood.Attachment,
			Stun = 0.4,
			Junction = "Random",
			JunctionChance = 0.002, -- 0.2% per bullet
            },
            ["RFire"] = {
            BlockBreak = false,
			NoBlock = true,
			Damage = .5,
			PostureDamage = 5,
			LightKnockback = false,
			M2 = false,
			FX = Replicated.Assets.VFX.Blood.Attachment,
			Stun = 0.4,
			Junction = "Random",
			JunctionChance = 0.002, -- 0.2% per bullet
            },

            Description = "Lunge yourself at the enemy piercing your blade through their skin.",
            ["HitTimes"] = {16/275, 56/275, 130/275, 135/275, 170/275, 175/275, 180/275, 185/275, 190/275, 195/275, 200/275, 205/275, 210/275, 215/275, 220/275, 225/275}
        },
        ["Inverse Slide"] = {
            ["DamageTable"] = {
            BlockBreak = false,
			Damage = 1.5,
			PostureDamage = 3,
			LightKnockback = false,
			M2 = false,
			FX = Replicated.Assets.VFX.Blood.Attachment,
			Stun = 0.4,
			Junction = "RandomLeg",
			JunctionChance = 0.005, -- 0.5% - very rare
            },
			["HitTimes"] = {1/89, 18/89, 25/89, 50/89}
        },
		["Tapdance"] = {
			["Hit"] = {
				BlockBreak = false,
			Damage = 1.5,
			PostureDamage = 3,
			LightKnockback = false,
			M2 = false,
			FX = Replicated.Assets.VFX.Blood.Attachment,
			Stun = 0.2,
			Junction = "RandomLeg",
			JunctionChance = 0.005, -- 0.5% - very rare
			},
			["FinalHit"] = {
				BlockBreak = false,
			Damage = 8,
			PostureDamage = 13,
			LightKnockback = false,
			M2 = false,
			FX = Replicated.Assets.VFX.Blood.Attachment,
			Stun = 0.4,
			Junction = "RandomLeg",
			JunctionChance = 0.01, -- 1% final hit
			},
			["Hittimes"] = {20/100, 45/100, 58/100, 68/100}
		},
		["Hellraiser"] = {
			["Hit"] = {
				BlockBreak = false,
			Damage = 1.5,
			PostureDamage = 3,
			LightKnockback = false,
			M2 = false,
			FX = Replicated.Assets.VFX.Blood.Attachment,
			Stun = 0.45,
			Junction = "Random",
			JunctionChance = 0.005, -- 0.5% - very rare
			},
			["FinalHit"] = {
			BlockBreak = false,
			Damage = 8,
			PostureDamage = 13,
			LightKnockback = false,
			Knockback = true,
			M2 = false,
			FX = Replicated.Assets.VFX.Blood.Attachment,
			Stun = 0.6,
			Status = {
				ProcChance = .99,
				ProcDmg = 2.5,
				Tick = 0.3,
				Duration = 4.5,
				Name = "Flame",
			},
			Junction = "Random",
			JunctionChance = 0.01, -- 1% final hit
			},
			["Hittimes"] = {32/89, 59/89, 62/89}

		}
    },
    ["Fist"] = {
        ["Downslam Kick"] = {
             ["DamageTable"] = {
            BlockBreak = true, -- Changed to true for guardbreak
			Damage = 9,
			PostureDamage = 20,
			LightKnockback = false,
			M2 = false,
			FX = Replicated.Assets.VFX.Blood.Attachment,
			Stun = 0.8, -- Increased from 0.4 to 0.8 for better NPC stun
			Junction = "Random",
			JunctionChance = 0.01, -- 1% powerful slam
            },
            Description = "Lunge yourself at the enemy piercing your blade through their skin.",
            ["HitTime"] = {10/74, 33/74, 33/38}
        },
        ["Axe Kick"] = {
            ["DamageTable"] = {
            BlockBreak = true,
			NoParry = true, -- Cannot be parried - prevents ragdoll/stun on parry
			Damage = 7,
			PostureDamage = 15,
			LightKnockback = false,
			M2 = false,
			FX = Replicated.Assets.VFX.Blood.Attachment,
			Stun = 0.8, -- Increased from 0.4 to 0.8 for better NPC stun
			Junction = "RandomLeg", -- Kick targets legs
			JunctionChance = 0.01, -- 1% powerful kick
            },
            Description = "Lunge yourself at the enemy piercing your blade through their skin.",
            ["HitTime"] = {21/49,27/49}
        },
		["Pincer Impact"] = {
			["DamageTable"] = {
			BlockBreak = false,
			NoParry = true, -- Cannot be parried - prevents stun on parry
			Damage = 9,
			PostureDamage = 20,
			LightKnockback = false,
			M2 = false,
			FX = Replicated.Assets.VFX.RunningHit.Attachment,
			Stun = 0, -- No stun on block for non-BF variant
			Junction = "RandomArm", -- Pincer targets arms
			JunctionChance = 0.01, -- 1% pincer
            },
			["BFDamageTable"] = {
			BlockBreak = true, -- BF variant breaks block
			NoParry = true, -- Cannot be parried - prevents stun on parry
			Damage = 15, -- Increased damage for BF variant
			PostureDamage = 35, -- Increased posture damage
			LightKnockback = false,
			M2 = false,
			FX = Replicated.Assets.VFX.RunningHit.Attachment,
			Stun = 2.5, -- Longer stun for BF variant
			Junction = "RandomArm", -- BF variant has slightly higher chance
			JunctionChance = 0.02, -- 2% for BF variant
            },
            Description = "Lunge yourself at the enemy piercing your blade through their skin.",
            ["HitTime"] = {20/189, 47/189, 90/189, 113/189, 55/189, 73/189}
		},
		["Triple Kick"] = {
			["DamageTable"] = {
			BlockBreak = false,
			Damage = 3.5,
			PostureDamage = 5,
			LightKnockback = false,
			M2 = false,
			FX = Replicated.Assets.VFX.Blood.Attachment,
			Stun = 0.4,
			Junction = "RandomLeg", -- Triple kick targets legs
			JunctionChance = 0.005, -- 0.5% per kick - very rare
            },
            Description = "Lunge yourself at the enemy piercing your blade through their skin.",
            ["HitTime"] = {10/75, 20/75, 37/75, 49/75}
		}
    }
}

return Table