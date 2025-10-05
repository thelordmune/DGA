--!strict 
type NpcData = {
	getState: (Model) -> Folder,
	Setting: {
		SpecialAnimationType: string
	}
}

type ActionData = {
	condition: () -> boolean,
	action: () -> string?
}

local function getEquippedWeapon(Character: Model, mainconfig: NpcData): string | boolean | nil
	if not Character then 
		return 
	end 
	
	local weaponsList = {"Sword","Mace","Gauntlet"}

	local statesFolder = mainconfig.getState(Character) :: Folder
	
	local hasWeapon = Character:FindFirstChild("HasWeapon")  :: ObjectValue
	if hasWeapon:IsA("ObjectValue") and hasWeapon.Value 
		and hasWeapon.Value.Parent ~= nil and string.find(hasWeapon.Value.Name,"Sword") 
	then
		for _,weaponType in weaponsList do
			return if hasWeapon.Value.Parent ~= nil and string.find(hasWeapon.Value.Name,weaponType) then weaponType
				else "Sword"
		end 
	end

	return false
end

return function(npc: Model, mainConfig: NpcData)
	local hasSpecialAnimationType = mainConfig.Setting.SpecialAnimationType ~= nil and true or false
	local actions: {ActionData} = {
		{
			condition = function(): boolean
				return npc:FindFirstChild("HasWeapon") ~= nil
			end,
			action = function(): string?
				local weaponType = getEquippedWeapon(npc,mainConfig)
				return `{hasSpecialAnimationType and `{mainConfig.Setting.SpecialAnimationType}{weaponType}Block` or `{weaponType}Block`}`

			end
		},
		{
			condition = function(): boolean return true end,
			action = function(): string?
				return `{hasSpecialAnimationType and `{mainConfig.Setting.SpecialAnimationType}Block` or "Block"}` 
			end
		}
	}

	for _, action in actions do
		if action.condition() then
			return action.action()
		end
	end
		
	return "Block"
end