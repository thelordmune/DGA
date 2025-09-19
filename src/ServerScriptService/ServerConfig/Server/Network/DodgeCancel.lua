local NetworkModule = {}; local Server = require(script.Parent.Parent);
NetworkModule.__index = NetworkModule
local self = setmetatable({}, NetworkModule)

local Replicated = game:GetService("ReplicatedStorage");
local Utilities  = require(Replicated.Modules.Utilities);
local Library    = require(Replicated.Modules.Library);
local Packets    = require(Replicated.Modules.Packets);
local Visuals    = require(Replicated.Modules.Visuals);

NetworkModule.EndPoint = function(Player, Data)
	local Character = Player.Character
	if not Character then return end
	if Library.CheckCooldown(Character, "DodgeCancel") then return end;
	
	local Entity = Server.Modules["Entities"].Get(Character);
	if Entity and Entity.Character and Entity.Character:FindFirstChild("IFrames") then
		Library.SetCooldown(Character, "DodgeCancel", 3.5)
		Library.ResetCooldown(Character, "Dodge")
		Library.RemoveState(Entity.Character.IFrames, "Dodge");
		Server.Visuals.Ranged(Character.HumanoidRootPart.Position, 300, {Module = "Base", Function = "RollCancel", Arguments = {Character}})
		
		--> fire dash visual effects
	end	
end

return NetworkModule;