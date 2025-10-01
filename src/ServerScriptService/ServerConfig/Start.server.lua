print("=== START.SERVER.LUA BEGINNING EXECUTION ===")
if not game.Loaded then game.Loaded:Wait() end
local replicatedStorage = game:GetService("ReplicatedStorage")
local bridges = require(replicatedStorage.Modules.Bridges)
print("=== START.SERVER.LUA: Bridges loaded ===")




local isReserved = game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0
local Success, Server = xpcall(require, function(Error)
	print('Server Runtime Error | Server Initialization Failed \nError: '.. Error)
end, script.Parent:WaitForChild("Server"))
if not Success then return end;

local Modules = script.Parent:WaitForChild("Server"):GetChildren();
print("=== START.SERVER.LUA: Loading Server.Modules ===")
for __ = 1, #Modules do
	local Module = Modules[__]
	print("Found child:", Module.Name, "Type:", Module.ClassName)
	if Module:IsA("ModuleScript") then
		print("  -> Is ModuleScript, requiring...")
		local Req;
		local Success, Error = xpcall(function()
			Req = require(Module)
		end, function(err)
			return debug.traceback(err)
		end)

		if Success and Req then
			Server.Modules[Module.Name] = Req;
			print("  -> Successfully loaded:", Module.Name)
		else
			warn("  -> Failed to load:", Module.Name)
			warn("  -> Error:", Error)
		end
	elseif Module:IsA("Folder") and Module:FindFirstChild("init") then
		print("  -> Is Folder with init.lua, requiring...")
		local Req;
		local Success, Error = xpcall(function()
			Req = require(Module)
		end, function(Error)
			print("Server - Failed Require: ".. Module.Name .. "\n"..Error)
		end)

		if Success and Req then
			Server.Modules[Module.Name] = Req;
			print("  -> Successfully loaded:", Module.Name)
		else
			print("  -> Failed to load:", Module.Name, "Error:", Error)
		end
	else
		print("  -> Skipping (not a ModuleScript or Folder with init)")
	end
end
print("=== Server.Modules loaded. Contents: ===")
for k, v in pairs(Server.Modules) do
	print("  Server.Modules." .. k .. ":", v)
end
print("=== END Server.Modules loading ===")

-- Store Server.Modules in _G so Actor VMs can access it
_G.ServerModules = Server.Modules
print("=== Stored Server.Modules in _G.ServerModules for Actor access ===")

game:BindToClose(function()
	if game:GetService("RunService"):IsStudio() then return end;
end)

game:GetService("Players").PlayerAdded:Connect(function(player)
	print("a player has joined")
end)

