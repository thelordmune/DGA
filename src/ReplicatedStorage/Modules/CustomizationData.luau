
local function randominRange(min, max)
	return min + math.random() * (max - min)
end

local ishsaturationMin, ishsaturationMax = 0.23852, 0.78735
local ishvalueMin, ishvalueMax = 0.24592, 0.59832
local ishrandomSaturation = randominRange(ishsaturationMin, ishsaturationMax)
local ishrandomValue = randominRange(ishvalueMin, ishvalueMax)

local amsaturationMin, amsaturationMax = 0.62549, 0.92585
local amvalueMin, amvalueMax = 0.6, 1
local amrandomSaturation = randominRange(amsaturationMin, amsaturationMax)
local amrandomValue = randominRange(amvalueMin, amvalueMax)


return {
	Races = {
		["Amestrian"] = {["variant1"] = "Brick yellow", ["variant2"] = "Light orange", ["variant3"] = "Nougat", Name = "Amestrian"},
		["Xing"] = {["variant1"] = "Pastel brown", ["variant2"] = "Fawn brown", ["variant3"] = "Burlap", Name = "Xing"},
		["Ishvalan"] = {["variant1"] = "Rust", ["variant2"] = "Burnt Sienna", ["variant3"] = "Reddish brown", Name = "Ishvalan"}
	};
	

	
	HairColor = {
		["Ishvalan"] = {Color3.fromHSV(0.99697,ishrandomSaturation,ishrandomValue)},
		["Xing"] = {Color3.fromHSV(0, 0, 0)},
		["Amestrian"] = {Color3.fromHSV(0.152972,amrandomSaturation,amrandomValue)}
 	};
	
	Clothes = {
		[1] = {shirt = "rbxassetid://16912251792", pants = "rbxassetid://16912252835", outfit = 1};
		[2] = {shirt = "rbxassetid://16912251792", pants = "rbxassetid://16912252835", outfit = 2}
	};
	
	Hair = {
		Male =	{
			{asset = game:GetService("ReplicatedStorage"):WaitForChild("Assets").Customization.Hair.Male.MHair1, hair = "MHair1"}
		},
		Female = {
			{asset = game:GetService("ReplicatedStorage"):WaitForChild("Assets").Customization.Hair.Female.FHair1, hair = "FHair1"}
		}
	};
	
	Face = {
		Male = {
			{assets = game:GetService("ReplicatedStorage"):WaitForChild("Assets").Customization.Face.Male}
		},
		Female = {
			{assets = game:GetService("ReplicatedStorage"):WaitForChild("Assets").Customization.Face.Female}
		}
	};
	
	FirstNames = {
		"Cedric",
		"Alden",
		"Raynor",
		"Renzo",
		"Wynne",
		"Magnus",
		"Oliver",
		"Elias",
		"Sterling",
		"Leland",
		"Corin",
		"Dorian",
		"Finnick",
		"Torin",
		"Kael",
		"Leona",
		"Gareth",
		"Cassian",
		"Davin",
		"Soren",
		"Vanya",
		"Orrin",
		"Darian",
		"Tyra",
		"Fallon",
		"Idris",
		"Sable",
		"Cedra",
		"Talia",
		"Marius"
	};
	LastNames = {
			"Ashford",
			"Fendrel",
			"Windgate",
			"Blackwood",
			"Ironhart",
			"Silverthorn",
			"Ashfield",
			"Stonebrook",
			"Valen",
			"Crowley",
			"Thornwell",
			"Lockridge",
			"Hawthorn",
			"Wycliffe",
			"Redmond",
			"Dunstan",
			"Caldwell",
			"Storme",
			"Fairborne",
			"Greystone",
			"Holloway",
			"Westfall",
			"Rooke",
			"Grimshaw",
			"Nightshade",
			"Wintermere",
			"Vandrell",
			"Braxton",
			"Greaves",
			"Thorne"
	}
}