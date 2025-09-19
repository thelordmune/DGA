local Visuals = {}

local Players = game:GetService("Players")
local Replicated = game:GetService("ReplicatedStorage")

local Packets = require(script.Parent:WaitForChild("Packets"))

Visuals.Ranged = function(Position: Vector3, Range: number, Packet: {})
	local InRange = {}
	for _, Entity in workspace.World.Live:GetChildren() do
		if Entity:IsA("Model") then
			local PrimaryPart = Entity.PrimaryPart
			local Player = Players:GetPlayerFromCharacter(Entity)

			if Player and PrimaryPart then
				if (PrimaryPart.Position - Position).Magnitude <= Range then
					table.insert(InRange, Player)
				end
			end
		end
	end

	Packets.Visuals.sendToList(Packet, InRange)
end

Visuals.FireClient = function(Player: Player, Packet: {})
	Packets.Visuals.sendTo(Packet, Player)
end

Visuals.FireClients = function(PlayersToSendTo: {}, Packet)
	Packets.Visuals.sendToList(Packet, PlayersToSendTo)
end

Visuals.FireAllClients = function(Packet: {})
	Packets.Visuals.sendToAll(Packet)
end

return Visuals
