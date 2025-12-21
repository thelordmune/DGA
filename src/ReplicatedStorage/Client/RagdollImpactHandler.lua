--[[
	Ragdoll Impact Handler Module

	Client-side handler for ragdoll impact effects.
	Creates crater effects, debris, and plays impact sounds
	when characters hit the ground with force.
]]

local RagdollImpactHandler = {}
local CSystem = require(script.Parent)

local ReplicatedStorage = CSystem.Service.ReplicatedStorage
local Workspace = CSystem.Service.Workspace

local Bridges = require(ReplicatedStorage.Modules.Bridges)
local RockMod = require(ReplicatedStorage.Modules.Utils.RockMod)
local BaseEffects = require(ReplicatedStorage.Effects.Base)
local Library = require(ReplicatedStorage.Modules.Library)

-- Initialize
task.spawn(function()
	-- Listen for impact events from server
	Bridges.ECSClient:Connect(function(data)
		if not data or type(data) ~= "table" then
			warn("[RagdollImpactClient] Received non-table data:", data)
			return
		end

		if data.Module ~= "RagdollImpact" or data.Action ~= "CreateImpact" then
			return
		end

		local impactPosition = data.Position
		local impactVelocity = data.Velocity
		local characterName = data.CharacterName

		-- Find the character to apply downslam effect
		local character = Workspace.World.Live:FindFirstChild(characterName)
		if not character then
			warn(`[RagdollImpactClient] Character {characterName} not found in workspace`)
		end

		-- Calculate crater size based on impact velocity
		local velocityMagnitude = math.abs(impactVelocity.Y)
		local sizeMultiplier = math.clamp(velocityMagnitude / 100, 0.2, 0.5)
		local debrisCount = math.clamp(math.floor(velocityMagnitude / 10), 5, 15)

		-- Play downslam kick "Land" effect at GROUND impact position
		if character then
			-- Create the effect manually at the ground position
			local eff = ReplicatedStorage.Assets.VFX.Slam:Clone()
			eff.CFrame = CFrame.new(impactPosition)
			eff.Parent = Workspace.World.Visuals
			for _, v in eff:GetDescendants() do
				if v:IsA("ParticleEmitter") then
					v:Emit(v:GetAttribute("EmitCount"))
				end
			end
			task.delay(3, function()
				eff:Destroy()
			end)

			-- Play impact sound on the character
			local impactSound = ReplicatedStorage.Assets.SFX.Extra:FindFirstChild("Impact")
			if impactSound then
				Library.PlaySound(character, impactSound, true, 0.1)
			else
				warn("[RagdollImpactClient] Impact sound not found at ReplicatedStorage.Assets.SFX.Extra.Impact")
			end
		end

		-- Create crater effect on client at GROUND position
		-- Offset the crater slightly upward so rocks aren't buried underground
		local craterPosition = impactPosition + Vector3.new(0, 1, 0)
		local success, err = pcall(function()
			local craterCFrame = CFrame.new(craterPosition)

			local effect = RockMod.New("Crater", craterCFrame, {
				Distance = { 5.5, 15 },
				SizeMultiplier = sizeMultiplier,
				PartCount = 12,
				Layers = { 3, 3 },
				ExitIterationDelay = { 0.5, 1 },
				LifeCycle = {
					Entrance = {
						Type = "Elevate",
						Speed = 0.25,
						Division = 3,
						EasingStyle = Enum.EasingStyle.Quad,
						EasingDirection = Enum.EasingDirection.Out,
					},

					Exit = {
						Type = "SizeDown",
						Speed = 0.3,
						Division = 2,
						EasingStyle = Enum.EasingStyle.Sine,
						EasingDirection = Enum.EasingDirection.In,
					},
				},
			})

			if effect then
				effect:Debris("Normal", {
					Size = { 0.75, 2.5 },
					UpForce = { 0.55, 0.95 },
					RotationalForce = { 15, 35 },
					Spread = { 8, 8 },
					PartCount = debrisCount,
					Radius = 8,
					LifeTime = 5,
					LifeCycle = {
						Entrance = {
							Type = "SizeUp",
							Speed = 0.25,
							Division = 3,
							EasingStyle = Enum.EasingStyle.Quad,
							EasingDirection = Enum.EasingDirection.Out,
						},
						Exit = {
							Type = "SizeDown",
							Speed = 0.3,
							Division = 2,
							EasingStyle = Enum.EasingStyle.Sine,
							EasingDirection = Enum.EasingDirection.In,
						},
					},
				})
			else
				warn(`[RagdollImpactClient] RockMod.New returned nil - crater type may not exist`)
			end
		end)

		if not success then
			warn(`[RagdollImpactClient] Failed to create crater effect: {err}`)
		end
	end)
end)

return RagdollImpactHandler
