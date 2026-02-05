--|| KAZI
local players = game:GetService "Players"
local runService = game:GetService "RunService"

local Player: Player = players.LocalPlayer;

local Camera: Camera = workspace.CurrentCamera;

local Shakers = {}

export type Settings = {
	Magnitude: number?,
	Damp: number?,
	Frequency: number?,
	Falloff: number?,
	Influence: vector?,
	Location: vector?
}

local function Shake(Settings: Settings)
	if not Player or not Player.Character or not Player.Character.Parent then
		return
	end
	Settings = Settings or {}
	local Magnitude: number = Settings.Magnitude or 0.5 -- how much the cam shake moves from left to right
	local Damp: number = Settings.Damp or 0.007 -- how fast it slows down
	local Frequency: number = Settings.Frequency or 18 -- how fast the camshake moves left to right
	local Influence: number = Settings.Influence or vector.create(1, 1, 0)  -- which axis the camera shakes (e.g uc an set it to Vector3.new(0,1,0) so it only shakes up and down
	local Falloff: number = Settings.Falloff or 15  -- distance from the shake location when the shake starts to get weaker, (relative to camera)
	
	local Location: vector = Settings.Location;
	Location = if typeof(Location) ~= "Vector3" or type(Location) ~= "vector" then Location.Position else Location
	
	local Falloff: number = math.max(Falloff - vector.magnitude(Player.Character.PrimaryPart.Position - Location), 0) / Falloff

	-- Adjust the direction influence to be more subtle on the position
	local Direction: vector = vector.normalize(vector.create(math.random(-5, 5), math.random(-5, 5), math.random(-5, 5))) * Influence

	local Id: number = #Shakers + 1
	Shakers[Id] = vector.zero;
	local Now: number = 0;
	task.spawn(function()
		while Magnitude > 0.05 do
			local Delta: number = task.wait()
			Now += Delta
			-- Adjust the shaking intensity based on position
			Shakers[Id] = Falloff * Direction * Magnitude * math.sin(Now * Frequency)
			Magnitude *= Damp^Delta
		end

		Shakers[Id] = nil;
	end)
end

runService.RenderStepped:Connect(function()
	local Amount: number = vector.zero
	for _, Turn in next, Shakers do
		-- local DivideIndex: number = if Player:FindFirstChild"GameSettings" and Player["GameSettings"]:FindFirstChild"Less Screnshake"
		-- 	and Player["GameSettings"]["Less Screnshake"].Value == true then 5
		-- 	else 1
		local DivideIndex: number = 1
		Turn /= DivideIndex
		Amount += Turn;
	end

	-- Update the camera's CFrame by adding the shaker's influence to its position
	Camera.CFrame = Camera.CFrame + Amount;
end)

return Shake