local module = {}
for _, moduleScript in script:GetDescendants() do
	if moduleScript:IsA("ModuleScript") then
		module[moduleScript.Name] = require(moduleScript)
	end
end
return module
