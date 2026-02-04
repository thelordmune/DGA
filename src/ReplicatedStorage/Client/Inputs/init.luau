local Inputs = {}; local Client = require(script.Parent);
Inputs.__index = Inputs;
local self = setmetatable({}, Inputs)

Inputs.InputModules = {};

local function ContextAction(ActionName, InputState, InputObject)
	local Index = table.find(Client.CurrentInput, ActionName)

	local InputFunction
	if InputState == Enum.UserInputState.Begin then
		InputFunction = self.InputModules[ActionName].InputBegan;
		if not Index then table.insert(Client.CurrentInput, Index) end;
	elseif InputState == Enum.UserInputState.End then
		InputFunction = self.InputModules[ActionName].InputEnded;
		if Index then table.remove(Client.CurrentInput, Index) end;
	elseif InputState == Enum.UserInputState.Change then
		InputFunction = self.InputModules[ActionName].InputChanged;
	end

	if InputFunction then
		InputFunction(InputObject, Client);
	end

	return Enum.ContextActionResult.Pass;
end

-- Load all input modules
for _, Module in script:GetChildren() do
	if Module:IsA("ModuleScript") then
		self.InputModules[Module.Name] = {}
		for Index, Function in require(Module) do
			self.InputModules[Module.Name][tostring(Index)] = Function;
		end
	end
end

-- Function to bind all input actions (called on init and respawn)
Inputs.BindAllActions = function()
	for ModuleName, _ in pairs(self.InputModules) do
		local KeyCode = Client.Settings.KeyBinds[ModuleName];
		if KeyCode then
			-- Unbind first to avoid duplicate bindings
			Client.Service["ContextActionService"]:UnbindAction(ModuleName);
			-- Then bind
			Client.Service["ContextActionService"]:BindAction(ModuleName, ContextAction, false, KeyCode);
		end
	end
end

-- Initial binding
Inputs.BindAllActions()

return Inputs