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
			Stun = 0.4,
            },
            Description = "Lunge yourself at the enemy piercing your blade through their skin.",
            ["HitTime"] = {36/71}
        },
    },
    ["Guns"] = {
        ["Shell Piercer"] = {
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
            ["HitTime"] = {20/50}
        },
        ["Strategist Combination"] = {
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
            ["HitTimes"] = {16/275, 56/275, 130/275, 135/275, 170/275, 175/275, 180/275, 185/275, 190/275, 195/275, 200/275, 205/275, 210/275, 215/275, 220/275, 225/275}
        },
        ["Inverse Rainstorm"] = {
            ["DamageTable"] = {
            BlockBreak = false,
			Damage = 3.5,
			PostureDamage = 5,
			LightKnockback = false,
			M2 = false,
			FX = Replicated.Assets.VFX.Blood.Attachment,
			Stun = 0.4,
            },
        }
    },
    ["Fist"] = {
        ["Downslam Kick"] = {
             ["DamageTable"] = {
            BlockBreak = false,
			Damage = 9,
			PostureDamage = 20,
			LightKnockback = false,
			M2 = false,
			FX = Replicated.Assets.VFX.Blood.Attachment,
			Stun = 0.4,
            },
            Description = "Lunge yourself at the enemy piercing your blade through their skin.",
            ["HitTime"] = {10/74, 33/74, 33/38}
        },
        ["Axe Kick"] = {
            ["DamageTable"] = {
            BlockBreak = true,
			Damage = 7,
			PostureDamage = 15,
			LightKnockback = false,
			M2 = false,
			FX = Replicated.Assets.VFX.Blood.Attachment,
			Stun = 0.4,
            },
            Description = "Lunge yourself at the enemy piercing your blade through their skin.",
            ["HitTime"] = {24/49}
        },
    }
}

return Table