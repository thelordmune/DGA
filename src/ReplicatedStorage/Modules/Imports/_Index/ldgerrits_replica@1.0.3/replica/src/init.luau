local RunService = game:GetService("RunService")

if RunService:IsServer() then
	return require(script.ReplicaServer)
else
	local server = script:FindFirstChild("ReplicaServer")
	if server then
		server:Destroy()
	end

	return require(script.ReplicaClient)
end
