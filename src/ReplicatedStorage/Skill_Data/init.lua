local Skill_Data = {Database = {}}

local Skills = script:GetDescendants()

for index = 1, #Skills do
	local Module = Skills[index];
	if not Module:IsA("ModuleScript") then
		continue
	end
	Skill_Data[Module.Name] = require(Module)
end

return Skill_Data