local Controller = {}; local Client = require(script.Parent.Parent);
Controller.__index = Controller;
local self = setmetatable({}, Controller);

local UI = Client.UI;

Controller.TestFunction = function()
	
end

return Controller;