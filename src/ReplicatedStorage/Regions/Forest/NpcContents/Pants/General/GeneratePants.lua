--!strict
local InsertService = game:GetService "InsertService"
local PANTS_DATA = {
	Male = {
		Regular = {
			16912252835
		},
		--Black = {
		--}
	},
	Female = {
		Regular = {
			16912252835
		},
		--Black = {
		--}
	}
}
local function getRandomPantsId(gender: string, isBlack: boolean): number
	local pantsPool = PANTS_DATA[gender][isBlack and "Black" or "Regular"]
	return pantsPool[math.random(1, #pantsPool)]
end

return function(npc: Model, mainConfig: { [string]: any })
	if not npc then
		return false
	end

	-- DISABLED: InsertService.LoadAsset() is destroying HumanoidRootPart
	-- Keep the default pants that come with the Bandit model
	-- TODO: Fix InsertService loading to not corrupt NPCs

	return true
end