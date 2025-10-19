local Networking = {}; local Server = require(script.Parent);
Networking.__index = Networking;
local self = setmetatable({}, Networking)

-- Store connections globally to prevent duplicates
if not _G.NetworkConnections then
    _G.NetworkConnections = {}
end

-- Clean up existing connections first
for name, connection in pairs(_G.NetworkConnections) do
    if connection and connection.disconnect then
        connection:disconnect()
    end
end
_G.NetworkConnections = {}

-- Set up new listeners
for _, Module in next, script:GetChildren() do
    if Module:IsA("ModuleScript") and not Module:HasTag("NetworkBlacklist") then
        local Required = require(Module);

        -- print("Setting up listener for:", Module.Name)

        -- Check if packet exists before trying to listen
        if not Server.Packets[Module.Name] then
            warn("No packet defined for:", Module.Name, "- Skipping listener setup")
            local packetNames = {}
            for name in pairs(Server.Packets or {}) do
                table.insert(packetNames, name)
            end
            warn("Available packets:", table.concat(packetNames, ", "))
        else
            local connection = Server.Packets[Module.Name].listen(function(Data, Player)
                Required.EndPoint(Player, Data)
            end)

            -- Store the connection for cleanup
            _G.NetworkConnections[Module.Name] = connection
        end
    end
end

return Networking