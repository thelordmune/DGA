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
	local gender = "Male"--mainConfig.Gender or "Male"
	local isBlack = false--mainConfig.IsBlack or false

	local maxAttempts: number = 5
	local currentAttempt: number = 0

	repeat
		currentAttempt += 1
		local pantsId = getRandomPantsId(gender, isBlack)
		local success, model = pcall(InsertService.LoadAsset, InsertService, pantsId)

		if success and model then
			local pants: Pants = model:FindFirstChildWhichIsA("Pants")
			if pants then
				pants.Name = "CharacterPants"
				pants.Parent = npc
				model:Destroy()
				return true
			end
			model:Destroy()
		else
			warn(`Failed to load pants asset: {pantsId} (Attempt {currentAttempt}/{maxAttempts})`)
		end
		task.wait(0.1) -- Small delay between attempts
	until currentAttempt >= maxAttempts

	warn("All attempts to load pants failed")
	return false
end