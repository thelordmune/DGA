local Replicated = game:GetService("ReplicatedStorage")
local start = require(Replicated.Modules.ECS.jecs_start)

local System = {}
System.Service = setmetatable({}, {
	__index = function(self, Name)
		local Service = game:GetService(Name)
		self[Name] = Service
		return Service
	end,
})

System.Service.Players			 = game:GetService("Players");
System.Service.RunService 		 = game:GetService("RunService");
System.Service.TweenService 	 = game:GetService("TweenService");
System.Service.PhysicsService 	 = game:GetService("PhysicsService")
System.Service.UserInputService  = game:GetService("UserInputService");
System.Service.CollectionService = game:GetService("CollectionService");
System.Service.ReplicatedStorage = game:GetService("ReplicatedStorage");

System.Player = System.Service.Players.LocalPlayer;

System.Modules 	   = {};
System.Environment = {};

System.Packets   = require(script.Parent.Modules:WaitForChild("Packets"));
System.Utilities = require(script.Parent.Modules:WaitForChild("Utilities"));
System.Library 	 = require(script.Parent.Modules:WaitForChild("Library"));
System.MetaData  = require(script.Parent.Modules:WaitForChild("MetaData"));

System.UI = script.Parent.Assets.GUI:WaitForChild("ScreenGui"):Clone();
System.UI.Parent = System.Player.PlayerGui;

System.Character = nil;
System.Humanoid  = nil;
System.Animator  = nil;
System.Root 	 = nil;

System.Weapon = "Guns";
System.Alchemy = "Flame";

System.Speeds   = nil;
System.Statuses = nil;
System.Stuns	= nil;
System.Actions  = nil;
System.Energy  = nil;
System.Posture  = nil;

System.InAir   = false;
System.Dodging = false;
System.Running = false;
System.RunAtk = false;

System.RunAnim = nil;

System.CurrentInput = {};

System.Settings = {
	AutoUse = true;
	AutoRun = false;
	LowGraphics = false;
	HideBlood = false;
	MuteMusic = false;

	KeyBinds = {},
	DefaultBinds = {
		Attack   = Enum.UserInputType.MouseButton1;
		Feint	 = Enum.UserInputType.MouseButton2;
		Critical = Enum.KeyCode.R;
		Jump     = Enum.KeyCode.Space;
		Block    = Enum.KeyCode.F;
		Dodge    = Enum.KeyCode.Q;
		Equip    = Enum.KeyCode.E;
		ZMove 	 = Enum.KeyCode.Z;
		XMove 	 = Enum.KeyCode.X;
		CMove 	 = Enum.KeyCode.C;
		Run      = Enum.KeyCode.LeftShift;

		Hotbar1 = Enum.KeyCode.One;
		Hotbar2 = Enum.KeyCode.Two;
		Hotbar3 = Enum.KeyCode.Three;
		Hotbar4 = Enum.KeyCode.Four;
		Hotbar5 = Enum.KeyCode.Five;
		Hotbar6 = Enum.KeyCode.Six;
		Hotbar7 = Enum.KeyCode.Seven;
		Hotbar8 = Enum.KeyCode.Eight;
		Hotbar9 = Enum.KeyCode.Nine;
		Hotbar0 = Enum.KeyCode.Zero;
	}
}

System.ResetBinds = function()
	System.Settings.KeyBinds = System.Settings.DefaultBinds;
end
System.ResetBinds()

return System
