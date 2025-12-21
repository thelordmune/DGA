--[[
	Chat Command System

	Handles slash commands from TextChatService.
	Currently supports:
	- /set time <time> - Set time of day (admin only)
	- /set weapon <weapon> - Set player weapon
	- /set alchemy <alchemy> - Set player alchemy
]]

local TextChatService = game:GetService("TextChatService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Admin user IDs
local ADMIN_IDS = {
	1166419362, -- Owner
}

-- Time presets
local TIME_PRESETS = {
	["dawn"] = "05:30:00",
	["morning"] = "08:00:00",
	["noon"] = "12:00:00",
	["afternoon"] = "14:00:00",
	["evening"] = "17:30:00",
	["dusk"] = "19:00:00",
	["night"] = "21:00:00",
	["midnight"] = "00:00:00",
	["sunrise"] = "06:00:00",
	["sunset"] = "18:30:00",
}

-- Check if player is admin
local function isAdmin(player: Player): boolean
	return table.find(ADMIN_IDS, player.UserId) ~= nil
end

-- Parse time string to Lighting.TimeOfDay format
local function parseTime(timeArg: string): string?
	-- Check presets first
	local preset = TIME_PRESETS[string.lower(timeArg)]
	if preset then
		return preset
	end

	-- Try to parse as number (hour)
	local hour = tonumber(timeArg)
	if hour and hour >= 0 and hour <= 24 then
		return string.format("%02d:00:00", math.floor(hour) % 24)
	end

	-- Try to parse as HH:MM format
	local h, m = timeArg:match("^(%d+):(%d+)$")
	if h and m then
		local hNum, mNum = tonumber(h), tonumber(m)
		if hNum and mNum and hNum >= 0 and hNum <= 23 and mNum >= 0 and mNum <= 59 then
			return string.format("%02d:%02d:00", hNum, mNum)
		end
	end

	return nil
end

-- Handle /set time command
local function handleSetTime(player: Player, timeArg: string): (boolean, string)
	if not isAdmin(player) then
		return false, "You don't have permission to use this command."
	end

	local parsedTime = parseTime(timeArg)
	if not parsedTime then
		local presetList = {}
		for name in pairs(TIME_PRESETS) do
			table.insert(presetList, name)
		end
		table.sort(presetList)
		return false, "Invalid time. Use a preset (" .. table.concat(presetList, ", ") .. ") or HH:MM format."
	end

	Lighting.TimeOfDay = parsedTime
	return true, "Time set to " .. parsedTime
end

-- Load Commands module for weapon/alchemy
local Commands
task.spawn(function()
	local Server = require(game.ServerScriptService.ServerConfig.Server)
	Commands = require(Server.Network.Commands)
end)

-- Process chat commands
local function processCommand(player: Player, message: string): (boolean, string?)
	-- Must start with /
	if not message:sub(1, 1) == "/" then
		return false, nil
	end

	local command = message:sub(2) -- Remove leading /
	local parts = {}
	for part in command:gmatch("%S+") do
		table.insert(parts, part)
	end

	if #parts == 0 then
		return false, nil
	end

	local cmd = string.lower(parts[1])

	-- /set command
	if cmd == "set" and #parts >= 3 then
		local setType = string.lower(parts[2])
		local setValue = parts[3]

		if setType == "time" then
			return handleSetTime(player, setValue)
		elseif setType == "weapon" and Commands then
			return Commands.SetWeapon(player, setValue)
		elseif setType == "alchemy" and Commands then
			return Commands.SetAlchemy(player, setValue)
		else
			return false, "Invalid set type. Use 'time', 'weapon', or 'alchemy'."
		end
	end

	return false, nil
end

-- Set up TextChatService command handling
local function setupChatCommands()
	-- Wait for TextChatService to be ready
	local textChannels = TextChatService:WaitForChild("TextChannels", 10)
	if not textChannels then
		warn("[ChatCommands] TextChannels not found, using legacy chat")
		return
	end

	-- Create a TextChatCommand for /set
	local setCommand = Instance.new("TextChatCommand")
	setCommand.Name = "SetCommand"
	setCommand.PrimaryAlias = "/set"
	setCommand.SecondaryAlias = "/s"
	setCommand.Parent = TextChatService

	setCommand.Triggered:Connect(function(textSource, unfilteredText)
		local player = Players:GetPlayerByUserId(textSource.UserId)
		if not player then return end

		-- Remove the command prefix and process
		local message = unfilteredText:gsub("^/set%s*", ""):gsub("^/s%s*", "")
		local parts = {}
		for part in message:gmatch("%S+") do
			table.insert(parts, part)
		end

		if #parts >= 2 then
			local setType = string.lower(parts[1])
			local setValue = parts[2]

			local success, result
			if setType == "time" then
				success, result = handleSetTime(player, setValue)
			elseif setType == "weapon" and Commands then
				success, result = Commands.SetWeapon(player, setValue)
			elseif setType == "alchemy" and Commands then
				success, result = Commands.SetAlchemy(player, setValue)
			else
				result = "Invalid set type. Use 'time', 'weapon', or 'alchemy'."
			end

			-- Send feedback to player via system message
			if result then
				local channel = textChannels:FindFirstChild("RBXGeneral")
				if channel then
					channel:DisplaySystemMessage("[System] " .. result)
				end
			end
		end
	end)
end

-- Initialize
task.spawn(setupChatCommands)

-- Also handle legacy chat for backwards compatibility
Players.PlayerAdded:Connect(function(player)
	player.Chatted:Connect(function(message)
		if message:sub(1, 1) == "/" then
			local success, result = processCommand(player, message)
			if result then
				-- Could send a notification to player here
				print(string.format("[ChatCommands] %s: %s", player.Name, result))
			end
		end
	end)
end)

-- Handle existing players
for _, player in Players:GetPlayers() do
	player.Chatted:Connect(function(message)
		if message:sub(1, 1) == "/" then
			local success, result = processCommand(player, message)
			if result then
				print(string.format("[ChatCommands] %s: %s", player.Name, result))
			end
		end
	end)
end

print("[ChatCommands] Chat command system initialized")
