local NetworkModule = {}; local Server = require(script.Parent.Parent);
NetworkModule.__index = NetworkModule
local self = setmetatable({}, NetworkModule)

NetworkModule.EndPoint = function(Player, Data)
	-- DISABLED: Snapshot collection disabled since reconciliation system is disabled
	-- This was causing rubberbanding during velocity-based movement
	-- The client still sends position data but we don't store it for anti-exploit checks

	--[[ ORIGINAL CODE (DISABLED)
	local Time = workspace:GetServerTimeNow()
	local Ping = Player:GetNetworkPing()

	local PlayerObject = Server.Modules["Players"].Get(Player)
	if PlayerObject and PlayerObject.Entity and PlayerObject.Character then
		local LocalCF = CFrame.new(Data.Position) * CFrame.fromOrientation(Data.Orientation.X, Data.Orientation.Y, Data.Orientation.Z)
		local LocalVel = Data.AssemblyLinearVelocity * Ping

		local Snapshot = {};
		Snapshot.CFrame = LocalCF + LocalVel
		Snapshot.Time = Time;

		table.insert(PlayerObject.Entity.Snapshots, Snapshot)
		if #PlayerObject.Entity.Snapshots > 4 then
			table.remove(PlayerObject.Entity.Snapshots, 1)
		end
	end
	]]--
end

return NetworkModule;
