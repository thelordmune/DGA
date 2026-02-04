local Server = require(script.Parent);

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

	-- Set up CharacterAdded listener BEFORE LoadCharacter to catch the initial spawn
	-- This ensures PlayerClass.Character is set immediately when the character spawns
	local characterAddedConnection
	characterAddedConnection = Player.CharacterAdded:Connect(function(character)
		self.Character = character
		print(`[Players.lua] Character set immediately on spawn: {character.Name}`)
	end)

	task.wait(3)

	print(`[Players.lua] Loading character for {Player.Name}...`)
	Player:LoadCharacter();
	Server.Service["RunService"].Heartbeat:Wait();

	-- Ensure self.Character is set (in case CharacterAdded fired before connection was made)
	if not self.Character then
		self.Character = self.Player.Character
	end
	print(`[Players.lua] Character loaded: {self.Character.Name}, Parent: {self.Character.Parent:GetFullName()}`)
	self.Entity = Server.Modules["Entities"].Init(Player.Character);

	-- Load appearance immediately after character is set up
	-- This ensures appearance loads on first spawn, not just on reset
	local Appearance = require(script.Parent.Entities.Appearance)
	print(`[Players.lua] Loading appearance for {Player.Name}...`)
	Appearance.Load(Player)
	print(`[Players.lua] Appearance loaded for {Player.Name}`)

	-- Note: Inventory sync is handled by playerloader.luau after it sets up
	-- the Inventory and Hotbar ECS components. We can't sync here because
	-- those components don't exist yet.
	
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
			-- Load appearance on respawn as well
			local Appearance = require(script.Parent.Entities.Appearance)
			Appearance.Load(Player)

			-- Note: Inventory sync is handled by playerloader.luau's CharacterAdded handler
			-- which fires after this and sets up fresh inventory components before syncing
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
