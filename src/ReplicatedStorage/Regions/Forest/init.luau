local Forest = {
	Modules = {}
}

for _, child in script:GetDescendants() do
	if child:IsA("ModuleScript") then
		Forest.Modules[child.Name] = require(child)
	end
end

return Forest.Modules