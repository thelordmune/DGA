if not game.Loaded then game.Loaded:Wait() end
local replicatedStorage = game:GetService("ReplicatedStorage")
local bridges = require(replicatedStorage.Modules.Bridges)



local isReserved = game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0
local Success, Server = xpcall(require, function(Error)
	print('Server Runtime Error | Server Initialization Failed \nError: '.. Error)
end, script.Parent:WaitForChild("Server"))
if not Success then return end;

local Modules = script.Parent:WaitForChild("Server"):GetChildren();
for __ = 1, #Modules do
	local Module = Modules[__]
	if Module:IsA("ModuleScript") then
		local Req;
		local Success, Error = xpcall(function()
			Req = require(Module)
		end, function(Error)
			print("Server - Failed Require: ".. Module.Name .. "\n"..Error)
		end)

		if Success and Req then
			Server.Modules[Module.Name] = Req;
		end
	end
end

game:BindToClose(function()
	if game:GetService("RunService"):IsStudio() then return end;
end)

game:GetService("Players").PlayerAdded:Connect(function(player)
	print("a player has joined")
end)

