--[[
	Alchemy Updater Module

	Handles alchemy updates from AlchemyChanger parts.
	Listens for UpdateAlchemy RemoteEvent and refreshes the hotbar.
]]

local AlchemyUpdater = {}
local CSystem = require(script.Parent)

local ReplicatedStorage = CSystem.Service.ReplicatedStorage
local Players = CSystem.Service.Players

local player = Players.LocalPlayer

-- Initialize
task.spawn(function()
	-- Wait for the UpdateAlchemy RemoteEvent
	local updateAlchemyRemote = ReplicatedStorage:WaitForChild("UpdateAlchemy")

	-- Function to update client alchemy and refresh hotbar
	local function updateClientAlchemy(newAlchemy)
		-- Update the client's alchemy variable
		CSystem.Alchemy = newAlchemy

		-- Wait a moment for the client to process the change
		task.wait(0.1)

		-- Update the hotbar with new alchemy moves
		if CSystem.Interface and CSystem.Interface.Stats then
			CSystem.Interface.Stats.LoadAlchemyMoves()
		else
			warn("Client: Could not find Stats interface to update alchemy moves")
		end
	end

	-- Listen for alchemy updates from the server
	updateAlchemyRemote.OnClientEvent:Connect(updateClientAlchemy)
end)

return AlchemyUpdater
