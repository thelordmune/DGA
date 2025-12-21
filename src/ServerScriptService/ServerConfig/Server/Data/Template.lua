return {
	--// Information
	["Weapon"] = "Fist",
	["Alchemy"] = "Flame",
	["Inventory"] = {},
	["Emotes"] = {},
	["Passives"] = {"Kinetic Redirection"},

	["Appearance"] = {
		["Character"] = {},
		["Accessories"] = {},
		["Vanity"] = {},
		["Outfit"] = 1,
		["Hair"] = { R = 0, G = 0, B = 0 },
		["Skin"] = { R = 0, G = 0, B = 0 },
		["Eyes"] = { R = 0, G = 0, B = 0 },
		["Energy"] = { R = 0, G = 0, B = 0 },
	},

	["Stats"] = {
		["Elo"] = 0,
		["Kills"] = 0,
		["Deaths"] = 0,
		["Money"] = 0,
		["Damage"] = 0,
		["Energy"] = 100,
		["Posture"] = 60,  -- Greatly reduced from 100 to 30
		["Health"] = 100,
		["Armor"] = 0,
		["Speed"] = 1,
	},
	["FirstJoin"] = true,
	["Customization"] = {
		["Gender"] = "Male",

		["EyeColor"] = { R = 0, G = 0, B = 0 },
		["HairColor"] = { H = 0, S = 0, V = 0 },
		["EyebrowColor"] = { R = 0, G = 0, B = 0 },

		["SkinColor"] = "Cool yellow",

		["Hair"] = "",

		["Outfit"] = 0,
	},
	["Quests"] = {
		CurrentQuest = "",
		QuestsCompleted = {},
		QuestsTaken = {},
	},

	-- NPC Relationship System
	-- Tracks relationship progress with wandering NPCs
	-- Once a player reaches "Friend" tier (40+), the NPC's appearance is locked for that player
	["NPCRelationships"] = {
		-- Format: ["NPC_UniqueID"] = {
		--   value = 0-100 (relationship value)
		--   name = "Heinrich" (NPC's name when befriended)
		--   occupation = "Blacksmith" (NPC's occupation when befriended)
		--   personality = "Friendly" (NPC's personality when befriended)
		--   appearance = { (locked once Friend tier reached)
		--     outfitId = 1,
		--     race = "Amestrian",
		--     gender = "Male",
		--     hairId = 12345678,
		--     skinColor = "Brick yellow"
		--   }
		-- }
	},

	-- Influence System (reputation/notoriety)
	-- Tracks player's standing with NPCs and guards
	["Influence"] = {
		Reputation = 0, -- -100 (criminal) to +100 (respected)
		PickpocketCount = 0, -- Total pickpocket attempts
		SuccessfulPickpockets = 0, -- Successful pickpockets
		CrimesCommitted = 0, -- Total crimes
		JailTime = 0, -- Current jail sentence (seconds)
		LastCrimeTime = 0, -- Timestamp of last crime
		WantedLevel = 0, -- 0-5, increases with crimes
		GuardsSpawnedOn = 0, -- Times guards have been spawned on player
	},

	["Squad"] = {
		Name = "",
		Members = {},
		Leader = "",
		Officers = {},
		Active = false
	},

	["Clan"] = "",
	["FL_Name"] = { ["First"] = "", ["Last"] = "" },
	["Level"] = 1,
	["Experience"] = 0,
	["TotalExperience"] = 0,
	["Alignment"] = 0,
	["Denomination"] = "",
	["Title"] = "Civilian",
	["Build"] = {
		Potency = 0,
		Knowledge = 0,
		Vibrance = 0,
		Strange = 0,
		Dexerity = 0,
	},
	Injury = "None",
	Innate = "Survival Instincts"
}
