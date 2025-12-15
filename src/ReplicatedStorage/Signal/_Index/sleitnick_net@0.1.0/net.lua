local RunService = game:GetService("RunService")

--[=[
	@class Net
	Basic networking module for creating and handling static
	RemoteEvents and RemoteFunctions.
	
	12/15/2023 - Added support for UnreliableRemoteEvent
]=]
local Net = {}

--[=[
	Gets an UnreliableRemoteEvent with the given name.
	
	```lua
	local unreliableRemoteEvent = Net:UnreliableRemoteEvent("MousePositionChanged")
	```
]=]
function Net:UnreliableRemoteEvent(name: string): UnreliableRemoteEvent
	name = "URE/" .. name
	if RunService:IsServer() then
		local u = script:FindFirstChild(name)
		if not u then
			u = Instance.new("UnreliableRemoteEvent")
			u.Name = name
			u.Parent = script
		end
		return u
	else
		local u = script:WaitForChild(name, 10)
		if not u then
			error("Failed to find UnreliableRemoteEvent: " .. name, 2)
		end
		return u
	end
end


--[=[
	Gets a RemoteEvent with the given name.

	On the server, if the RemoteEvent does not exist, then
	it will be created with the given name.

	On the client, if the RemoteEvent does not exist, then
	it will wait until it exists for at least 10 seconds.
	If the RemoteEvent does not exist after 10 seconds, an
	error will be thrown.

	```lua
	local remoteEvent = Net:RemoteEvent("PointsChanged")
	```
]=]
function Net:RemoteEvent(name: string): RemoteEvent
	name = "RE/" .. name
	if RunService:IsServer() then
		local r = script:FindFirstChild(name)
		if not r then
			r = Instance.new("RemoteEvent")
			r.Name = name
			r.Parent = script
		end
		return r
	else
		local r = script:WaitForChild(name, 10)
		if not r then
			error("Failed to find RemoteEvent: " .. name, 2)
		end
		return r
	end
end

--[=[
	Connects a handler function to the given UnreliableRemoteEvent.
	
	-- Server
	Net:ConnectUnreliable("MousePositionChanged", function(player, ...) end)
	```
]=]
function Net:ConnectUnreliable(name: string, handler: (...any) -> ()): RBXScriptConnection
	if RunService:IsServer() then
		return self:UnreliableRemoteEvent(name).OnServerEvent:Connect(handler)
	else
		return self:UnreliableRemoteEvent(name).OnClientEvent:Connect(handler)
	end
end

--[=[
	Connects a handler function to the given RemoteEvent.

	```lua
	-- Client
	Net:Connect("PointsChanged", function(points)
		---- print("Points", points)
	end)

	-- Server
	Net:Connect("SomeEvent", function(player, ...) end)
	```
]=]
function Net:Connect(name: string, handler: (...any) -> ()): RBXScriptConnection
	if RunService:IsServer() then
		return self:RemoteEvent(name).OnServerEvent:Connect(handler)
	else
		return self:RemoteEvent(name).OnClientEvent:Connect(handler)
	end
end

--[=[
	Gets a RemoteFunction with the given name.

	On the server, if the RemoteFunction does not exist, then
	it will be created with the given name.

	On the client, if the RemoteFunction does not exist, then
	it will wait until it exists for at least 10 seconds.
	If the RemoteFunction does not exist after 10 seconds, an
	error will be thrown.

	```lua
	local remoteFunction = Net:RemoteFunction("GetPoints")
	```
]=]
function Net:RemoteFunction(name: string): RemoteFunction
	name = "RF/" .. name
	if RunService:IsServer() then
		local r = script:FindFirstChild(name)
		if not r then
			r = Instance.new("RemoteFunction")
			r.Name = name
			r.Parent = script
		end
		return r
	else
		local r = script:WaitForChild(name, 10)
		if not r then
			error("Failed to find RemoteFunction: " .. name, 2)
		end
		return r
	end
end

--[=[
	@server
	Sets the invocation function for the given RemoteFunction.

	```lua
	Net:Handle("GetPoints", function(player)
		return 10
	end)
	```
]=]
function Net:Handle(name: string, handler: (player: Player, ...any) -> ...any)
	self:RemoteFunction(name).OnServerInvoke = handler
end

--[=[
	@client
	Invokes the RemoteFunction with the given arguments.

	```lua
	local points = Net:Invoke("GetPoints")
	```
]=]
function Net:Invoke(name: string, ...: any): ...any
	return self:RemoteFunction(name):InvokeServer(...)
end

--[=[
	@server
	Destroys all RemoteEvents and RemoteFunctions. This
	should really only be used in testing environments
	and not during runtime.
]=]
function Net:Clean()
	script:ClearAllChildren()
end

return Net