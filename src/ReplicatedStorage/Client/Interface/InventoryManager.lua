local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Modules.Fusion)
local InventoryComponent = require(ReplicatedStorage.Client.Components.Inventory)
local ref = require(ReplicatedStorage.Modules.ECS.jecs_ref)

local InventoryManager = {}
InventoryManager.__index = InventoryManager

local instance = nil

function InventoryManager.GetInstance()
	if not instance then
		instance = InventoryManager.new()
	end
	return instance
end

function InventoryManager.new()
	local self = setmetatable({}, InventoryManager)

	self.scope = Fusion.scoped(Fusion, {})
	self.isVisible = self.scope:Value(false)
	self.inventoryGui = nil
	self.keybindSetup = false
	self.entity = nil

	return self
end

function InventoryManager:Initialize()
	---- print("[Inventory] Initializing...")

	-- Disable default Roblox backpack
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
		---- print("[Inventory] Disabled default Roblox backpack")
	end)

	-- Clean up old UI if it exists (for respawns)
	if self.inventoryGui and self.inventoryGui.Parent then
		self.inventoryGui:Destroy()
		self.inventoryGui = nil
	end

	-- Create the inventory UI
	self:CreateUI()

	-- Set up keybind (only once)
	if not self.keybindSetup then
		self:SetupKeybind()
		self.keybindSetup = true
	end

	---- print("[Inventory] Initialized successfully")
end

function InventoryManager:CreateUI()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	-- Get player entity
	self.entity = ref.get("local_player")
	if not self.entity then
		warn("[Inventory] Could not get player entity!")
		return
	end

	-- Create ScreenGui for inventory
	self.inventoryGui = self.scope:New "ScreenGui" {
		Name = "InventoryGui",
		Parent = playerGui,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 15,
	}

	-- Create the inventory using the component
	InventoryComponent(self.scope, {
		Parent = self.inventoryGui,
		entity = self.entity,
		started = self.isVisible,
	})

	---- print("[Inventory] UI created")
end

function InventoryManager:SetupKeybind()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		
		-- Check for backtick/grave accent key (`)
		if input.KeyCode == Enum.KeyCode.Backquote then
			self:Toggle()
		end
	end)
	
	---- print("[Inventory] Keybind setup complete (` key)")
end

function InventoryManager:Toggle()
	local newState = not Fusion.peek(self.isVisible)
	self.isVisible:set(newState)
	---- print("[Inventory] Toggled:", newState and "Visible" or "Hidden")
end

function InventoryManager:Show()
	self.isVisible:set(true)
end

function InventoryManager:Hide()
	self.isVisible:set(false)
end

function InventoryManager:Destroy()
	if self.scope then
		self.scope:doCleanup()
	end
	if self.inventoryGui then
		self.inventoryGui:Destroy()
	end
	instance = nil
end

return InventoryManager

