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
			},
			["Slash2"] = {
				BlockBreak = false,
				Damage = 4,
				PostureDamage = 5,
				LightKnockback = false,
				M2 = false,
				FX = Replicated.Assets.VFX.Blood.Attachment,
				Stun = 0.4,
			},
			["Slash3"] = {
				BlockBreak = true,
				Damage = 6,
				PostureDamage = 5,
				LightKnockback = false,
				M2 = false,
				FX = Replicated.Assets.VFX.Blood.Attachment,
				Stun = 0.4,
			},
			["HitTimes"] = {25/120, 29/120, 38/120, 51/120, 52/120, 54/120, 79/120, 83/120, 89/120}
			-- startslash, startdrag1, enddrag1, startdrag2, startslash and swingwooo, enddrag2, startslash, startdrag3, enddrag3
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
			
            },
			["HitTimes"] = {1/89, 18/89, 25/89, 50/89}
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
            },
            Description = "Lunge yourself at the enemy piercing your blade through their skin.",
            ["HitTime"] = {10/75, 20/75, 37/75, 49/75}
		}
    }
}

return Table