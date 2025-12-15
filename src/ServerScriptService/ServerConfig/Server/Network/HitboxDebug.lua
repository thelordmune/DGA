--[[
	HitboxDebug Server Handler
	
	Receives hitbox visualization toggle from client and stores it per-player.
	When enabled, all hitboxes for that player's moves will be visualized.
]]

local HitboxDebug = {}
local Server = require(script.Parent.Parent)

-- Store hitbox debug state per player
local PlayerDebugStates = {}

HitboxDebug.EndPoint = function(Player: Player, Data: {Enabled: boolean})
	-- Store the debug state for this player
	PlayerDebugStates[Player] = Data.Enabled
	
	print(`[HitboxDebug] Player {Player.Name} set hitbox visualization to: {Data.Enabled}`)
end

-- Helper function for other scripts to check if a player has hitbox debug enabled
HitboxDebug.IsEnabled = function(Player: Player): boolean
	return PlayerDebugStates[Player] == true
end

-- Clean up when player leaves
game:GetService("Players").PlayerRemoving:Connect(function(Player)
	PlayerDebugStates[Player] = nil
end)

return HitboxDebug

