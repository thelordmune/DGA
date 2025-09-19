local SKIN_COLORS = {
	Regular = {
		Color3.fromRGB(255, 229, 204),
		Color3.fromRGB(246, 221, 197),
		Color3.fromRGB(215, 197, 154),
		Color3.fromRGB(199, 172, 120),
		Color3.fromRGB(255, 204, 153),
		Color3.fromRGB(255, 176, 131),
		Color3.fromRGB(234, 184, 146),
	},
	Black = {
		Color3.fromRGB(204, 142, 105),
		Color3.fromRGB(218, 133, 65),
		Color3.fromRGB(160, 95, 53),
		Color3.fromRGB(124, 92, 70),
		Color3.fromRGB(108, 88, 75),
		Color3.fromRGB(90, 76, 66),
		Color3.fromRGB(86, 66, 54),
		Color3.fromRGB(105, 64, 40),
		Color3.fromRGB(143, 76, 42),
		Color3.fromRGB(106, 57, 9),
		Color3.fromRGB(170, 85, 0),
	}
}

local function getRandomSkinColor(isBlack: boolean): BrickColor
	local colorPool = SKIN_COLORS[isBlack and "Black" or "Regular"]
	return colorPool[math.random(1, #colorPool)]
end

return function(npc: Model, mainConfig)
	if not npc then 
		return false
	end

	local isBlack = false--mainConfig.IsBlack or false

	local bodyColors = npc:FindFirstChild("Body Colors") :: BodyColors or Instance.new("BodyColors") :: BodyColors
	bodyColors.Name = "Body Colors"
	bodyColors.Parent = npc

	local skinColor = getRandomSkinColor(isBlack)
	for _, bodyPartEnum in Enum.BodyPart:GetEnumItems() do
		bodyColors[`{bodyPartEnum.Name}Color3`] = skinColor
	end
end