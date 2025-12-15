local players = game:GetService("Players")
local Replicated = game:GetService("ReplicatedStorage")
local runService = game:GetService("RunService")

local ClientReplion = nil
local Replion = require(Replicated.Modules.Shared.Replion)

local Global = {}; Global.__index = Global;
local self = setmetatable({}, Global)

function Global.GetData(player: Player, path: string | {string}?, yield: number?)
	local PlayerReplion = if runService:IsServer() then 
		Replion.Server:WaitReplionFor(player, "Data", yield) 
		else 
		ClientReplion or Replion.Client:WaitReplion("Data", yield)

	if runService:IsClient() then
		ClientReplion = PlayerReplion
	end

	if PlayerReplion then
		local truePath

		if type(path) == "string" then
			-- Handle dot notation
			truePath = {}
			for segment in path:gmatch("[^%.]+") do
				table.insert(truePath, segment)
			end
		elseif type(path) == "table" then
			truePath = path
		else
			truePath = {}  -- Empty path to get the entire data
		end

		return PlayerReplion:Get(truePath)
	end

	return nil
end

function Global.SetData(player: Player, modifier: ({[string]: any})->({[string]: any})?, yield: number?)
	if not runService:IsServer() then
		return -- This is server only but I'm putting it next to get data
	end
	local PlayerReplion = Replion.Server:WaitReplionFor(player, "Data", yield)
	if PlayerReplion then
		--local path = "Slot_"..PlayerReplion:Get("Current_Slot")
		------ print(PlayerReplion,PlayerReplion.Data)
		local newData = Global.GetDeepCopy(PlayerReplion.Data)
		newData = modifier(newData) or newData

		PlayerReplion:Update(newData) -- Iirc replion auto optimizes this and automatically filters out the changes

	end

end

function Global.ListenToDataChange(player: Player, path: (string | {string})?)
	local callback = nil
	local connection = nil

	local function OnReplion(PlayerReplion: Replion.ClientReplion | Replion.ServerReplion)
		local function onChange(new, old)
			if callback then callback(new, old) end
		end

		local truePath = {}
		if not path then
			truePath = {"Data"}
		elseif type(path) == "string" then
			for segment in path:gmatch("[^%.]+") do
				table.insert(truePath, segment)
			end
		elseif type(path) == "table" then
			truePath = path
		end

		local function getValueAtPath()
			return Global.getNestedValue(PlayerReplion.Data, truePath)
		end

		local originalValue = getValueAtPath()

		connection = PlayerReplion:OnDataChange(function()
			local newValue = getValueAtPath()
			if newValue ~= originalValue then
				onChange(newValue, originalValue)
				originalValue = newValue
			end
		end)
	end

	if runService:IsServer() then
		Replion.Server:AwaitReplionFor(player, "Data", OnReplion)
	else
		Replion.Client:AwaitReplion("Data", OnReplion)
	end

	return function(newCallback: (data: any)->())
		callback = newCallback
		return connection
	end
end

function Global.GetDeepCopy(Table)
	local Copy = {}

	for Index, Value in pairs(Table) do
		local IndexType, ValueType = type(Index), type(Value)

		if IndexType == "table" and ValueType == "table" then
			Index, Value = Global.GetDeepCopy(Index), Global.GetDeepCopy(Value)
		elseif ValueType == "table" then
			Value = Global.GetDeepCopy(Value)
		elseif IndexType == "table" then
			Index = Global.GetDeepCopy(Index)
		end

		Copy[Index] = Value
	end

	return Copy
end 

return Global