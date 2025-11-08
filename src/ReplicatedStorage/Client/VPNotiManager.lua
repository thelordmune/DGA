--[[
	VPNoti Manager
	
	Handles displaying viewport notifications with NPC models and text.
	Used for tutorial messages and quest instructions.
	
	Usage:
		local VPNotiManager = require(ReplicatedStorage.Client.VPNotiManager)
		
		-- Show a viewport notification
		VPNotiManager.Show({
			npc = npcModel,
			text = "Press G then Z to spawn an alchemy wall!",
			duration = 5, -- optional, defaults to 5 seconds
			onComplete = function()
				print("Notification closed")
			end
		})
		
		-- Hide the current notification
		VPNotiManager.Hide()
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Fusion = require(ReplicatedStorage.Modules.Fusion)

local VPNotiManager = {}

-- State
local currentScope = nil
local currentUI = nil
local isShowing = false
local currentVisible = nil
local currentTextValue = nil
local currentOnComplete = nil

-- Initialize the component reference
local VPNotiComponent = require(ReplicatedStorage.Client.Components.VPNoti)

-- Show a viewport notification
function VPNotiManager.Show(config: {
	npc: Model?,
	text: string,
	duration: number?,
	onComplete: (() -> ())?
})
	print("[VPNotiManager] 📢 Show called with text:", config.text)

	-- Hide any existing notification first
	if isShowing then
		print("[VPNotiManager] Hiding existing notification")
		VPNotiManager.Hide()
		task.wait(0.5) -- Wait for fade out
	end

	local player = Players.LocalPlayer
	if not player then
		warn("[VPNotiManager] No local player found")
		return
	end

	local playerGui = player:WaitForChild("PlayerGui")

	-- Create new scope
	currentScope = Fusion.scoped(Fusion)

	-- Create visible state and text value
	currentVisible = currentScope:Value(false)
	currentTextValue = currentScope:Value(config.text or "")
	currentOnComplete = config.onComplete

	-- Get NPC model from ReplicatedStorage if string path provided
	local npcModel = config.npc
	if typeof(npcModel) == "string" then
		print("[VPNotiManager] Looking for NPC model:", config.npc)
		npcModel = ReplicatedStorage.Assets.Viewports:FindFirstChild(npcModel)
		if not npcModel then
			warn("[VPNotiManager] NPC model not found:", config.npc)
			return
		end
		print("[VPNotiManager] ✅ Found NPC model:", npcModel:GetFullName())
	elseif npcModel then
		print("[VPNotiManager] Using provided NPC model:", npcModel:GetFullName())
	else
		warn("[VPNotiManager] No NPC model provided")
	end

	-- Create the UI
	print("[VPNotiManager] Creating VPNoti UI component...")
	currentUI = VPNotiComponent(currentScope, {
		npc = npcModel,
		text = currentTextValue,
		visible = currentVisible,
		onComplete = config.onComplete,
		Parent = playerGui,
	})

	isShowing = true
	print("[VPNotiManager] ✅ VPNoti created, fading in...")

	-- Fade in
	task.wait(0.1)
	currentVisible:set(true)

	-- Auto-hide after duration
	local duration = config.duration or 5
	if duration > 0 then
		task.spawn(function()
			task.wait(duration)
			if isShowing then
				print("[VPNotiManager] Auto-hiding after", duration, "seconds")
				VPNotiManager.Hide()
				if config.onComplete then
					config.onComplete()
				end
			end
		end)
	end
end

-- Update the text of the current notification without recreating the UI
function VPNotiManager.UpdateText(newText: string)
	if not isShowing or not currentTextValue then
		warn("[VPNotiManager] Cannot update text - no notification is showing")
		return
	end

	print("[VPNotiManager] 📝 Updating text to:", newText)
	currentTextValue:set(newText)
end

-- Hide the current notification
function VPNotiManager.Hide()
	if not isShowing then
		return
	end
	
	isShowing = false
	
	-- Cleanup
	if currentScope then
		currentScope:doCleanup()
		currentScope = nil
	end
	
	if currentUI then
		currentUI:Destroy()
		currentUI = nil
	end
end

-- Check if a notification is currently showing
function VPNotiManager.IsShowing()
	return isShowing
end

return VPNotiManager

