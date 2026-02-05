local Visuals = {}

local Players = game:GetService("Players")

local Packets = require(script.Parent:WaitForChild("Packets"))

-- Check if a model instance is inside a NpcRegistryCamera (Chrono NPC)
local function isInNpcRegistryCamera(inst)
	if typeof(inst) ~= "Instance" then return false end
	local parent = inst.Parent
	while parent do
		if parent.Name == "NpcRegistryCamera" then
			return true
		end
		parent = parent.Parent
	end
	return false
end

-- Replace Chrono NPC model references in packet Arguments with marker tables
-- so the client can resolve them to its own clones (bypasses Instance ref issues)
local function resolvePacketArguments(packet)
	if not packet.Arguments then return packet end
	for i, arg in packet.Arguments do
		if typeof(arg) == "Instance" and arg:IsA("Model") and not Players:GetPlayerFromCharacter(arg) then
			if isInNpcRegistryCamera(arg) then
				local chronoId = arg:GetAttribute("ChronoId") or arg:GetAttribute("NPC_ID")
				if chronoId then
					packet.Arguments[i] = { _chronoMarker = true, _chronoId = chronoId, _name = arg.Name }
				end
			end
		end
	end
	return packet
end

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

	Packets.Visuals.sendToList(resolvePacketArguments(Packet), InRange)
end

Visuals.FireClient = function(Player: Player, Packet: {})
	Packets.Visuals.sendTo(resolvePacketArguments(Packet), Player)
end

Visuals.FireClients = function(PlayersToSendTo: {}, Packet)
	Packets.Visuals.sendToList(resolvePacketArguments(Packet), PlayersToSendTo)
end

Visuals.FireAllClients = function(Packet: {})
	Packets.Visuals.sendToAll(resolvePacketArguments(Packet))
end

return Visuals
