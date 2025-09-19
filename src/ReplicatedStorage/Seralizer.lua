--!strict
export type DataTable = {[string]: any}

type ValueBase<t> = {
	Value: t,
	Name: string,
	Parent: Instance?
}

local module = {}

local valueTypeMapping = {
	["string"] = "StringValue",
	["number"] = function(value: number)
		return math.floor(value) == value and "IntValue" or "NumberValue"
	end,
	["boolean"] = "BoolValue",
	["Vector3"] = "Vector3Value",
	["CFrame"] = "CFrameValue",
	["Instance"] = "ObjectValue"
}

function module.ToTable(mainFolder: Instance, addInTable: DataTable)
	for _, instance : any in mainFolder:GetChildren() do
		if instance:IsA("Folder") or instance:IsA("Configuration") then
			addInTable[instance.Name] = {}
			module.ToTable(instance, addInTable[instance.Name])
		else
			addInTable[instance.Name] = instance.Value
		end
	end
end

function module.LoadTableThroughInstance(mainFolder: Instance, dataTable: DataTable)
	if mainFolder and dataTable then
		for index, value in dataTable do

			if typeof(value) == "table" then
				local newFolder = Instance.new("Folder")
				newFolder.Name = `{tostring(index)}`
				newFolder.Parent = mainFolder
				module.LoadTableThroughInstance(newFolder, value)
			else
				local valueType = typeof(value)
				local instanceType = valueTypeMapping[valueType]

				if typeof(instanceType) == "function" then
					instanceType = instanceType(value)
				end

				if instanceType then
					local newValue = (Instance.new(instanceType) :: any) :: ValueBase<typeof(value)>
					newValue.Value = value
					newValue.Name = `{tostring(index)}`
					newValue.Parent = mainFolder
				end
			end
		end
	end
end

return module
