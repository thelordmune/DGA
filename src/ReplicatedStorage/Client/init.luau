local Replicated = game:GetService("ReplicatedStorage")
local start = require(Replicated.Modules.ECS.jecs_start)

-- ECS State Accessors for unified state management
local StateAccessors = require(Replicated.Modules.ECS.StateAccessors)

-- Internal state storage (accessed via metatable)
local SystemInternal = {}

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
System.UI.ResetOnSpawn = false; -- Prevent UI from being destroyed on death
System.UI.Parent = System.Player.PlayerGui;

System.Character = nil;
System.Humanoid  = nil;
System.Animator  = nil;
System.Root 	 = nil;

System.Weapon = "Scythe";
-- Alchemy removed - Hunter x Hunter Nen system will replace this

-- Legacy StringValue references (for backwards compatibility during migration)
-- These will be removed once all code uses StateManager directly
System.Speeds   = nil;
System.Statuses = nil;
System.Stuns	= nil;
System.Actions  = nil;
System.Energy  = nil;
System.Posture  = nil;

-- ============================================
-- ECS-BACKED STATE (via StateAccessors)
-- These properties are backed by ECS components for single source of truth.
-- Reads and writes go through StateAccessors automatically.
-- ============================================

-- Internal storage for non-ECS state (RunAnim, RunAtk)
SystemInternal.RunAnim = nil
SystemInternal.RunAtk = false

-- ECS-backed state getter functions
function System.GetInAir(): boolean
	if not System.Character then return false end
	return StateAccessors.IsInAir(System.Character)
end

function System.GetDodging(): boolean
	if not System.Character then return false end
	return StateAccessors.IsDodging(System.Character)
end

function System.GetRunning(): boolean
	if not System.Character then return false end
	return StateAccessors.IsRunning(System.Character)
end

function System.GetSliding(): boolean
	if not System.Character then return false end
	return StateAccessors.IsSliding(System.Character)
end

function System.GetWallRunning(): boolean
	if not System.Character then return false end
	return StateAccessors.IsWallRunning(System.Character)
end

function System.GetLedgeClimbing(): boolean
	if not System.Character then return false end
	return StateAccessors.IsLedgeClimbing(System.Character)
end

function System.GetLeaping(): boolean
	if not System.Character then return false end
	return StateAccessors.IsLeaping(System.Character)
end

function System.GetLeapLanding(): boolean
	if not System.Character then return false end
	return StateAccessors.IsLeapLanding(System.Character)
end

-- ECS-backed state setter functions
function System.SetInAir(value: boolean)
	if System.Character then
		StateAccessors.SetInAir(System.Character, value)
	end
end

function System.SetDodging(value: boolean)
	if System.Character then
		StateAccessors.SetDodging(System.Character, value)
	end
end

function System.SetRunning(value: boolean)
	if System.Character then
		StateAccessors.SetRunning(System.Character, value)
	end
end

function System.SetSliding(value: boolean)
	if System.Character then
		StateAccessors.SetSliding(System.Character, value)
	end
end

function System.SetWallRunning(value: boolean)
	if System.Character then
		StateAccessors.SetWallRunning(System.Character, value)
	end
end

function System.SetLedgeClimbing(value: boolean)
	if System.Character then
		StateAccessors.SetLedgeClimbing(System.Character, value)
	end
end

function System.SetLeaping(value: boolean)
	if System.Character then
		StateAccessors.SetLeaping(System.Character, value)
	end
end

function System.SetLeapLanding(value: boolean)
	if System.Character then
		StateAccessors.SetLeapLanding(System.Character, value)
	end
end

-- Property name to getter/setter mapping for metatable
local ECS_STATE_PROPERTIES = {
	InAir = { get = System.GetInAir, set = System.SetInAir },
	Dodging = { get = System.GetDodging, set = System.SetDodging },
	Running = { get = System.GetRunning, set = System.SetRunning },
	Sliding = { get = System.GetSliding, set = System.SetSliding },
	WallRunning = { get = System.GetWallRunning, set = System.SetWallRunning },
	LedgeClimbing = { get = System.GetLedgeClimbing, set = System.SetLedgeClimbing },
	Leaping = { get = System.GetLeaping, set = System.SetLeaping },
	LeapLanding = { get = System.GetLeapLanding, set = System.SetLeapLanding },
}

-- Non-ECS properties stored in SystemInternal
local INTERNAL_PROPERTIES = {
	RunAnim = true,
	RunAtk = true,
	_Running = true, -- Simple boolean flag for running state (bypasses ECS for reliability)
}

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
		Critical = Enum.KeyCode.R;
		Jump     = Enum.KeyCode.Space;
		Block    = Enum.KeyCode.F;
		Dodge    = Enum.KeyCode.Q;
		Equip    = Enum.KeyCode.E;
		NenBasics = Enum.KeyCode.C; -- C key for Nen basics activation
		Z 	     = Enum.KeyCode.Z; -- Z key for casting sequence
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

		Leaderboard = Enum.KeyCode.Period;
		HitboxDebug = Enum.KeyCode.F2; -- F2 key for hitbox visualization toggle
		UIToggle = Enum.KeyCode.F1; -- F1 key to hide/show all UI
		StatMenu = Enum.KeyCode.M; -- M key for stat menu
	}
}

System.ResetBinds = function()
	System.Settings.KeyBinds = System.Settings.DefaultBinds;
end
System.ResetBinds()

-- Clear all client-side action states (called on knockback, stuns, ragdoll)
System.ClearClientActions = function()
	-- Use ECS-backed setters to clear all movement states
	System.SetDodging(false)
	System.SetRunning(false)
	SystemInternal.RunAtk = false
	System.SetSliding(false)
	System.SetWallRunning(false)
	System.SetLedgeClimbing(false)
	System.SetLeaping(false)
	System.SetLeapLanding(false)

	-- Cancel ECS action if character exists
	if System.Character then
		System.Library.CancelCurrentAction(System.Character)
		-- Also clear via StateAccessors for complete cleanup
		StateAccessors.ClearMovementStates(System.Character)
	end

	-- Stop running animation if playing
	if SystemInternal.RunAnim then
		SystemInternal.RunAnim:Stop()
		SystemInternal.RunAnim = nil
	end
end

-- Check if ANY action is in progress (unified check)
System.IsInAction = function()
	-- Use ECS-backed getters for state checks
	local StateManager = require(Replicated.Modules.ECS.StateManager)
	return System.GetDodging() or System.GetRunning() or System.GetSliding()
		or System.GetWallRunning() or System.GetLedgeClimbing() or System.GetLeaping()
		or (System.Character and StateManager.StateCount(System.Character, "Actions"))
end

-- ============================================
-- METATABLE PROXY FOR BACKWARDS COMPATIBILITY
-- Allows existing code using System.InAir, System.Dodging etc. to work
-- without modification while actually reading/writing ECS state.
-- ============================================

local SystemProxy = setmetatable({}, {
	__index = function(_, key)
		-- Check ECS-backed properties first
		local ecsProperty = ECS_STATE_PROPERTIES[key]
		if ecsProperty then
			return ecsProperty.get()
		end

		-- Check internal properties
		if INTERNAL_PROPERTIES[key] then
			return SystemInternal[key]
		end

		-- Fall back to System table
		return System[key]
	end,

	__newindex = function(_, key, value)
		-- Check ECS-backed properties first
		local ecsProperty = ECS_STATE_PROPERTIES[key]
		if ecsProperty then
			ecsProperty.set(value)
			return
		end

		-- Check internal properties
		if INTERNAL_PROPERTIES[key] then
			SystemInternal[key] = value
			return
		end

		-- Fall back to System table
		rawset(System, key, value)
	end,
})

return SystemProxy
