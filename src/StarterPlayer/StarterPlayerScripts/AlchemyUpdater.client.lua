-- Client script to handle alchemy updates from AlchemyChanger parts
-- This script should be placed in StarterPlayer/StarterPlayerScripts

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

-- Wait for the Client system to load
local Client = require(ReplicatedStorage:WaitForChild("Client"))

-- Wait for the UpdateAlchemy RemoteEvent
local updateAlchemyRemote = ReplicatedStorage:WaitForChild("UpdateAlchemy")

-- Function to update client alchemy and refresh hotbar
local function updateClientAlchemy(newAlchemy)
    print("Client: Updating alchemy to:", newAlchemy)
    
    -- Update the client's alchemy variable
    Client.Alchemy = newAlchemy
    
    -- Wait a moment for the client to process the change
    task.wait(0.1)
    
    -- Update the hotbar with new alchemy moves
    if Client.Interface and Client.Interface.Stats then
        Client.Interface.Stats.LoadAlchemyMoves()
        print("Client: Refreshed alchemy hotbar moves for:", newAlchemy)
    else
        warn("Client: Could not find Stats interface to update alchemy moves")
    end
end

-- Listen for alchemy updates from the server
updateAlchemyRemote.OnClientEvent:Connect(updateClientAlchemy)

print("AlchemyUpdater client script loaded")
