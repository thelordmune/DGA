--[[
    ClockUI Module

    Initializes and mounts the Clock UI component to display
    the current time of day in the top-left corner of the screen.
]]

local ClockUI = {}
local CSystem = require(script.Parent)

local ReplicatedStorage = CSystem.Service.ReplicatedStorage
local Players = CSystem.Service.Players

local Fusion = require(ReplicatedStorage.Modules.Fusion)
local Clock = require(ReplicatedStorage.Client.Components.Clock)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Initialize
task.spawn(function()
	local scope = Fusion.scoped(Fusion, {
		Clock = Clock,
	})

	local clockGui = Instance.new("ScreenGui")
	clockGui.Name = "ClockUI"
	clockGui.ResetOnSpawn = false
	clockGui.IgnoreGuiInset = true
	clockGui.DisplayOrder = 5
	clockGui.Parent = playerGui

	scope:Clock({
		Parent = clockGui,
	})
end)

return ClockUI
