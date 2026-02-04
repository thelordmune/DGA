local module = {}
for _, moduleScript in script:GetChildren() do
	if moduleScript:IsA("ModuleScript") then
		module[moduleScript.Name] = require(moduleScript)
	end
end
return module