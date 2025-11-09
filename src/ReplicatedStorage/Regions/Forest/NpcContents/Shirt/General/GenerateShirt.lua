--!strict
local InsertService = game:GetService "InsertService"
local SHIRT_DATA = {
	Male = {
		Regular = {
			16912251792
		},
		--Black = {
		--}
	},
	Female = {
		Regular = {
			16912251792
		},
		--Black = {
		--}
	}
}
local function getRandomShirtId(gender: string, isBlack: boolean): number
	local shirtPool = SHIRT_DATA[gender][isBlack and "Black" or "Regular"]
	return shirtPool[math.random(1, #shirtPool)]
end

return function(npc: Model, mainConfig: { [string]: any })
	if not npc then
		return false
	end

	-- DISABLED: InsertService.LoadAsset() is destroying HumanoidRootPart
	-- Keep the default shirt that comes with the Bandit model
	-- TODO: Fix InsertService loading to not corrupt NPCs

	return true
end