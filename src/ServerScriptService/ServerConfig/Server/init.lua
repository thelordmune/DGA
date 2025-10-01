local Server = {}

print("=== SERVER MODULE BEING CREATED ===")
print("Stack trace:", debug.traceback())
print("Server table address:", tostring(Server))

--// Services Cache
Server.Service = setmetatable({}, { --> if you reference a service not already initialized, it'll cache it
	__index = function(self, Name)
		local Service = game:GetService(Name)
		self[Name] = Service
		return Service
	end,
})

Server.Service.Players 			 = game:GetService("Players"); --> these setup below are so I can enjoy auto fill in script editor :P
Server.Service.RunService 		 = game:GetService("RunService");
Server.Service.TweenService 	 = game:GetService("TweenService");
Server.Service.ServerStorage 	 = game:GetService("ServerStorage");
Server.Service.ReplicatedStorage = game:GetService("ReplicatedStorage");
Server.Service.CollectionService = game:GetService("CollectionService");

local Replicated = game:GetService("ReplicatedStorage")
Server.Library   = require(Replicated.Modules:WaitForChild("Library"));
Server.Packets   = require(Replicated.Modules:WaitForChild("Packets"));
Server.Utilities = require(Replicated.Modules:WaitForChild("Utilities"));
Server.Visuals   = require(Replicated.Modules:WaitForChild("Visuals"))

Server.Modules	= {};
Server.Entities = {};
Server.Players  = {};

print("=== SERVER MODULE INITIALIZED ===")
print("Server.Modules address:", tostring(Server.Modules))
print("Returning Server module")

return Server

