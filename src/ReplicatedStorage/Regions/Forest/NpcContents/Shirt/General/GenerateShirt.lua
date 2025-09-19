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
	local gender = "Male"--mainConfig.Gender or "Male"
	local isBlack = false--mainConfig.IsBlack or false

	local maxAttempts: number = 5
	local currentAttempt: number = 0

	repeat
		currentAttempt += 1
		local shirtId = getRandomShirtId(gender, isBlack)
		local success, model = pcall(InsertService.LoadAsset, InsertService, shirtId)

		if success and model then
			local shirt = model:FindFirstChildWhichIsA("Shirt")
			if shirt then
				shirt.Name = "CharacterShirt"
				shirt.Parent = npc
				model:Destroy()
				return true
			end
			model:Destroy()
		else
			warn(`Failed to load shirt asset: {shirtId} (Attempt {currentAttempt}/{maxAttempts})`)
		end
		task.wait(0.1) -- Small delay between attempts
	until currentAttempt >= maxAttempts

	warn("All attempts to load shirt failed")
	return false
end