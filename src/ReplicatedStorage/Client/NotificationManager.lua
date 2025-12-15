--[[
	Notification Manager
	
	Handles displaying inventory notifications at the bottom right of the screen.
	Notifications are queued and displayed one at a time with smooth animations.
	
	Usage:
		local NotificationManager = require(ReplicatedStorage.Client.NotificationManager)
		
		-- Show a skill notification
		NotificationManager.ShowSkill("Fireball")
		
		-- Show an item notification
		NotificationManager.ShowItem("Health Potion")
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Fusion = require(ReplicatedStorage.Modules.Fusion)

local scoped = Fusion.scoped
local NotificationComp = require(ReplicatedStorage.Client.Components.NotificationComp)

local Player = Players.LocalPlayer

local NotificationManager = {}

-- Active notifications tracking
local activeNotifications = {} -- Array of {scope, frame, slot}
local notificationQueue = {}
local notificationContainer = nil
local MAX_NOTIFICATIONS = 5
local NOTIFICATION_HEIGHT = 30 -- Height + spacing (smaller for text-only)
local SPAWN_DELAY = 0.2 -- Delay between spawning notifications
local isSpawning = false -- Prevent multiple spawns at once

-- Initialize the notification container
local function initializeContainer()
	if notificationContainer then return end

	-- Create a ScreenGui for notifications
	notificationContainer = Instance.new("ScreenGui")
	notificationContainer.Name = "NotificationContainer"
	notificationContainer.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	notificationContainer.ResetOnSpawn = false
	notificationContainer.Parent = Player.PlayerGui

	-- Create a frame to hold notifications at bottom right
	local holderFrame = Instance.new("Frame")
	holderFrame.Name = "NotificationHolder"
	holderFrame.BackgroundTransparency = 1
	holderFrame.AnchorPoint = Vector2.new(1, 1)
	holderFrame.Position = UDim2.fromScale(0.98, 0.95)
	holderFrame.Size = UDim2.fromOffset(320, 500)
	holderFrame.Parent = notificationContainer

	---- print("[NotificationManager] Container initialized")
end

-- Find an available slot (0-4)
local function findAvailableSlot()
	for slot = 0, MAX_NOTIFICATIONS - 1 do
		local slotTaken = false
		for _, notif in ipairs(activeNotifications) do
			if notif.slot == slot then
				slotTaken = true
				break
			end
		end
		if not slotTaken then
			return slot
		end
	end
	return nil
end

-- Remove a notification from active list
local function removeNotification(notifData)
	for i, notif in ipairs(activeNotifications) do
		if notif == notifData then
			table.remove(activeNotifications, i)
			break
		end
	end
end

-- Show the next notification in the queue
local function showNextNotification()
	-- Prevent multiple spawns at once
	if isSpawning then
		return
	end

	-- Check if we have room for more notifications
	if #activeNotifications >= MAX_NOTIFICATIONS then
		return
	end

	-- Check if there are queued notifications
	if #notificationQueue == 0 then
		return
	end

	isSpawning = true

	-- Get the next notification
	local notif = table.remove(notificationQueue, 1)

	-- Find available slot
	local slot = findAvailableSlot()
	if not slot then
		-- Put it back in queue if no slot available
		table.insert(notificationQueue, 1, notif)
		isSpawning = false
		return
	end

	---- print("[NotificationManager] Showing notification:", notif.type, notif.name, "in slot", slot)

	-- Create a new scope for this notification
	local notifScope = scoped(Fusion, {
		Notification = NotificationComp
	})

	-- Get the holder frame
	local holderFrame = notificationContainer:FindFirstChild("NotificationHolder")

	if not holderFrame then
		warn("[NotificationManager] Holder frame not found!")
		notifScope:doCleanup()
		isSpawning = false
		return
	end

	-- Create the notification
	local notifFrame = notifScope:Notification({
		notifType = notif.type,
		itemName = notif.name,
		Parent = holderFrame,
		slot = slot,
		onComplete = function()
			---- print("[NotificationManager] Notification complete for slot", slot)

			-- Find and remove this notification from active list
			local notifData = nil
			for _, n in ipairs(activeNotifications) do
				if n.slot == slot then
					notifData = n
					break
				end
			end

			if notifData then
				removeNotification(notifData)

				-- Cleanup scope
				if notifData.scope then
					notifData.scope:doCleanup()
				end
			end

			-- Try to show next notification after a small delay
			task.wait(0.1)
			showNextNotification()
		end
	})

	-- Track this notification
	table.insert(activeNotifications, {
		scope = notifScope,
		frame = notifFrame,
		slot = slot
	})

	-- Wait before allowing next spawn
	task.wait(SPAWN_DELAY)
	isSpawning = false

	-- Try to show another notification
	showNextNotification()
end

-- Add a notification to the queue
local function queueNotification(notifType, itemName)
	table.insert(notificationQueue, {
		type = notifType,
		name = itemName
	})
	
	---- print("[NotificationManager] Queued notification:", notifType, itemName, "Queue size:", #notificationQueue)
	
	-- Try to show it
	showNextNotification()
end

-- Public API

-- Show a skill notification
function NotificationManager.ShowSkill(skillName)
	initializeContainer()
	queueNotification("Skill", skillName)
end

-- Show an item notification
function NotificationManager.ShowItem(itemName)
	initializeContainer()
	queueNotification("Item", itemName)
end

-- Show a quest notification
function NotificationManager.ShowQuest(questName)
	initializeContainer()
	queueNotification("Quest", questName)
end

-- Clear all notifications (useful for cleanup)
function NotificationManager.ClearAll()
	notificationQueue = {}

	-- Cleanup all active notifications
	for _, notifData in ipairs(activeNotifications) do
		if notifData.scope then
			notifData.scope:doCleanup()
		end
	end
	activeNotifications = {}

	if notificationContainer then
		notificationContainer:Destroy()
		notificationContainer = nil
	end

	---- print("[NotificationManager] Cleared all notifications")
end

-- Initialize on require
initializeContainer()

---- print("[NotificationManager] Loaded")

return NotificationManager

