
local function randominRange(min, max)
	return min + math.random() * (max - min)
end

-- Adjusted for darker mesh texture - increased saturation and value to compensate
local ishsaturationMin, ishsaturationMax = 0.65, 0.85  -- Higher saturation for more vibrant red
local ishvalueMin, ishvalueMax = 0.55, 0.75  -- Higher value to compensate for mesh darkening
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
		[1] = {shirt = "rbxassetid://8525392490", pants = "rbxassetid://8525395069", outfit = 1}; -- alchemist
		[2] = {shirt = "rbxassetid://7986412801", pants = "rbxassetid://7986441333", outfit = 2}; -- rudeus
		[3] = {shirt = "rbxassetid://6777629858", pants = "rbxassetid://6777631239", outfit = 3}; -- grey suit
		[4] = {shirt = "rbxassetid://6855117739", pants = "rbxassetid://6855125900", outfit = 4}; -- suspenders
		[5] = {shirt = "rbxassetid://6856418131", pants = "rbxassetid://6856421445", outfit = 5}; -- tan tux
		[6] = {shirt = "rbxassetid://8054365458", pants = "rbxassetid://8054371588", outfit = 6}; -- brown jacket


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