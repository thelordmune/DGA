local InputModule = {}
InputModule.__index = InputModule
local self = setmetatable({}, InputModule)
local Moves = require(game:GetService("ReplicatedStorage").Modules.Shared.Skills)

self.LastInput = 0
self.InputEndedManually = false

InputModule.InputBegan = function(_, Client)
local alchemy = Client.Alchemy
print(alchemy)
local Skill = Moves[alchemy][script.Name]
print(Skill)

	-- Get mouse position for aiming (for Rock Skewer)
	local mousePosition = Vector3.new(0, 0, 0)
	if Skill == "Rock Skewer" then
		local mouse = game.Players.LocalPlayer:GetMouse()
		local camera = workspace.CurrentCamera
		local unitRay = camera:ScreenPointToRay(mouse.X, mouse.Y)

		-- Raycast to find target position (limited distance)
		local raycastParams = RaycastParams.new()
		raycastParams.FilterDescendantsInstances = {Client.Character}
		raycastParams.FilterType = Enum.RaycastFilterType.Blacklist

		local maxDistance = 100  -- Maximum aiming distance
		local raycastResult = workspace:Raycast(unitRay.Origin, unitRay.Direction * maxDistance, raycastParams)

		if raycastResult then
			mousePosition = raycastResult.Position
		else
			-- If no hit, use max distance in that direction
			mousePosition = unitRay.Origin + (unitRay.Direction * maxDistance)
		end
	end

	Client.Packets[Skill].send({
		Air = Client.InAir,
		MousePosition = mousePosition,  -- Include mouse position for aiming
	})
end

InputModule.InputEnded = function(_, Client)
end

InputModule.InputChanged = function() end

return InputModule
