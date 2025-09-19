local Server = require(script.Parent);
local replicatedStorage = game:GetService("ReplicatedStorage")

export type PlayerObject = {
	Player	  : Player?;
	Character : Model;

	Profile   : {};
	Data 	  : {};
	Signals   : {};

	Keys : {
		Attack : boolean;
		Dash   : boolean;
		Block  : boolean;
		Critical : boolean;
		Construct : boolean
	};

	Entity : {};
}

if not game.Loaded then game.Loaded:Wait() end;

local PlayerClass = {};
PlayerClass.__index = PlayerClass;

PlayerClass.Get = function(Player: Player)
	if Server.Players[Player] then 
		return Server.Players[Player] 
	end;
end

PlayerClass.Remove = function(Player: Player)
	if Server.Players[Player] then
		setmetatable(Server.Players[Player], nil);
		Server.Players[Player] = nil;
		Server.Modules["Data"]:RemoveData(Player);
	end
end

PlayerClass.Init = function(Player: Player) : PlayerObject
	if Server.Players[Player] then return Server.Players[Player] end;
	local self = setmetatable({}, PlayerClass)

	self.Player  = Player;
	self.Profile = Server.Modules["Data"]:LoadData(Player);
	self.Data 	 = self.Profile.Data;
	Server.Players[Player] = self;
	
	self.Player:SetAttribute("Weapon", self.Data.Weapon)
	task.wait(3)

	Player:LoadCharacter();
	Server.Service["RunService"].Heartbeat:Wait();
	self.Character = self.Player.Character;
	self.Entity = Server.Modules["Entities"].Init(Player.Character);
	
	self.Keys = { --> Keys Held Down On Server;
		Attack = false;
		Critical = false;
		Dash   = false;
		Block  = false;
		Construct = false
	};

	Player:GetPropertyChangedSignal("Character"):Connect(function()
		if Player and Player.Character then 
			Server.Service["RunService"].Heartbeat:Wait();
			self.Character = self.Player.Character;
			self.Entity = Server.Modules["Entities"].Init(self.Player.Character) 
		end;
	end)

	
	return self;
end

for _, v in next, Server.Service.Players:GetPlayers() do
	task.spawn(PlayerClass.Init, v)
end

Server.Service.Players.PlayerAdded:Connect(PlayerClass.Init)
Server.Service.Players.PlayerRemoving:Connect(PlayerClass.Remove)

return PlayerClass
