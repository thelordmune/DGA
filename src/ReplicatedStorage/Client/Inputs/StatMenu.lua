--[[
	Stat Menu (M Key)

	Opens/closes the stat menu which includes:
	- Player stats display
	- Attributes (Knowledge, Potency, Dexterity, Strange, Vibrance)
	- Skills/Passive tree
]]

local InputModule = {}
InputModule.__index = InputModule

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Fusion = require(ReplicatedStorage.Modules.Fusion)
local scoped = Fusion.scoped

-- Components
local StatMenuBackground = require(ReplicatedStorage.Client.Components.StatBackground)
local StatMenu = require(ReplicatedStorage.Client.Components.Stat)

-- State
local isOpen = false
local isAnimating = false -- Prevent double-toggle during animations
local currentScope = nil
local statMenuGui = nil

-- Animation state values (persistent across toggles)
local framein = nil
local animateElements = nil
local bgVisible = nil

local function openStatMenu()
	if isOpen or isAnimating then return end
	isOpen = true
	isAnimating = true

	-- Create a new Fusion scope with our components
	currentScope = scoped(Fusion, {
		StatMenuBackground = StatMenuBackground,
		StatMenu = StatMenu
	})

	-- Create the ScreenGui
	statMenuGui = Instance.new("ScreenGui")
	statMenuGui.Name = "StatMenuGui"
	statMenuGui.ResetOnSpawn = false
	statMenuGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	statMenuGui.DisplayOrder = 10
	statMenuGui.IgnoreGuiInset = true
	statMenuGui.Parent = playerGui

	-- Create animation state values
	framein = currentScope:Value(false)
	animateElements = currentScope:Value(false)
	bgVisible = currentScope:Value(true)

	-- Create background with visibility control
	currentScope:StatMenuBackground{
		Parent = statMenuGui,
		isVisible = bgVisible,
		OnComplete = function()
			-- Background animation completed first loop
		end
	}

	-- Create stat menu
	currentScope:StatMenu{
		Parent = statMenuGui,
		fade = framein,
		animateElements = animateElements,
	}

	-- Animate in
	task.spawn(function()
		task.wait(0.1)
		framein:set(true)
		task.wait(0.5)
		animateElements:set(true)
		isAnimating = false
	end)
end

local function closeStatMenu()
	if not isOpen or isAnimating then return end
	isAnimating = true

	-- Animate out by setting values to false (reverse order)
	if animateElements then
		animateElements:set(false)
	end

	-- Stagger the fade out
	task.spawn(function()
		task.wait(0.2)

		if framein then
			framein:set(false)
		end

		task.wait(0.1)

		if bgVisible then
			bgVisible:set(false)
		end

		-- Wait for animations to complete
		task.wait(0.5)

		-- Destroy the GUI
		if statMenuGui then
			statMenuGui:Destroy()
			statMenuGui = nil
		end

		-- Clean up Fusion scope
		if currentScope then
			currentScope:doCleanup()
			currentScope = nil
		end

		framein = nil
		animateElements = nil
		bgVisible = nil
		isOpen = false
		isAnimating = false
	end)
end

local function toggleStatMenu()
	if isOpen then
		closeStatMenu()
	else
		openStatMenu()
	end
end

InputModule.InputBegan = function()
	toggleStatMenu()
end

InputModule.InputEnded = function()
	-- Nothing to do on release
end

InputModule.InputChanged = function()
	-- Nothing to do on change
end

return InputModule
