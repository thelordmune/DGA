local NetworkModule = {}
local Server = require(script.Parent.Parent)
local Replicated = game:GetService("ReplicatedStorage")
local Library = require(Replicated.Modules.Library)
local Debris = game:GetService("Debris")

-- Active connections for cleanup
local activeConnections = {}

local function cleanUp()
	for _, connection in activeConnections do
		if connection and connection.Connected then
			connection:Disconnect()
		end
	end
	activeConnections = {}
end

NetworkModule.EndPoint = function(Player, Data)
	local Character = Player.Character

	if not Character then
		return
	end

	-- Check if this is an NPC (no Player instance) or a real player
	local isNPC = typeof(Player) ~= "Instance" or not Player:IsA("Player")

	-- For players, check equipped status
	if not isNPC and not Character:GetAttribute("Equipped") then
		return
	end

	local PlayerObject = Server.Modules["Players"].Get(Player)
	local Animation = Replicated.Assets.Animations.Misc.Alchemy

	if Server.Library.StateCount(Character.Actions) or Server.Library.StateCount(Character.Stuns) then
		return
	end

	-- For NPCs, skip the PlayerObject.Keys check
	local canUseSkill = isNPC or (PlayerObject and PlayerObject.Keys)

	if canUseSkill and not Server.Library.CheckCooldown(Character, script.Name) then
		cleanUp()
		Server.Library.SetCooldown(Character, script.Name, 10) -- 10 second cooldown
		Server.Library.StopAllAnims(Character)

		local Alchemy = Library.PlayAnimation(Character, Animation)
		if not Alchemy then
			return
		end

		Alchemy.Looped = false

		Server.Library.TimedState(Character.Actions, script.Name, Alchemy.Length)
		Server.Library.TimedState(Character.Speeds, "AlcSpeed-0", Alchemy.Length)
		Server.Library.TimedState(Character.Speeds, "Jump-50", Alchemy.Length) -- Prevent jumping during move
		Server.Library.TimedState(Character.Stuns, "NoRotate", Alchemy.Length)

		local root = Character:FindFirstChild("HumanoidRootPart")
		if not root then
			return
		end

		-- Clean up when animation ends
		Alchemy.Ended:Once(function()
			cleanUp()
		end)

		-- Wait for animation keyframe
		local kfConn
		kfConn = Alchemy.KeyframeReached:Connect(function(key)
			if key == "Clap" then
				-- Play clap sound
				local s = Replicated.Assets.SFX.FMAB.Clap:Clone()
				s.Parent = root
				s:Play()
				Debris:AddItem(s, s.TimeLength)

				-- Visual effects
				Server.Visuals.Ranged(root.Position, 300, {
					Module = "Base",
					Function = "Clap",
					Arguments = { Character },
				})
			end

			if key == "Touch" then
				-- Play transmutation sound
				local s = Replicated.Assets.SFX.FMAB.Transmute:Clone()
				s.Volume = 2
				s.Parent = root
				s:Play()
				Debris:AddItem(s, s.TimeLength)

				Server.Visuals.Ranged(root.Position, 300, {
					Module = "Base",
					Function = "Transmute",
					Arguments = { Character },
				})

				-- Send visual packet to all clients for Ground Decay effect
				Server.Visuals.Ranged(root.Position, 300, {
					Module = "Base",
					Function = "GroundDecay",
					Arguments = { Character },
				})

				-- Damage detection for all 3 craters
				-- First crater (small radius, big damage)
				task.delay(0.2, function()
					local Hitbox = Server.Modules.Hitbox
					local hitTargets = Hitbox.SpatialQuery(Character, Vector3.new(8, 6, 8), root.CFrame)

					for _, hitTarget in hitTargets do
						if hitTarget ~= Character then
							Server.Modules.Damage.Tag(Character, hitTarget, {
								Damage = 12,
								PostureDamage = 15,
								Stun = 0.6,
								BlockBreak = true, -- FIXED: Ground Decay should guard break
								M1 = false,
								M2 = false,
								FX = Replicated.Assets.VFX.Blood.Attachment,
							})
						end
					end
				end)

				-- Second crater (medium radius, medium damage)
				task.delay(0.6, function()
					local Hitbox = Server.Modules.Hitbox
					local hitTargets = Hitbox.SpatialQuery(Character, Vector3.new(14, 6, 14), root.CFrame)

					for _, hitTarget in hitTargets do
						if hitTarget ~= Character then
							Server.Modules.Damage.Tag(Character, hitTarget, {
								Damage = 10,
								PostureDamage = 12,
								Stun = 0.5,
								BlockBreak = true, -- FIXED: Ground Decay should guard break
								M1 = false,
								M2 = false,
								FX = Replicated.Assets.VFX.Blood.Attachment,
							})
						end
					end
				end)

				-- Third crater (large radius, small damage)
				task.delay(1.0, function()
					local Hitbox = Server.Modules.Hitbox
					local hitTargets = Hitbox.SpatialQuery(Character, Vector3.new(22, 6, 22), root.CFrame)

					for _, hitTarget in hitTargets do
						if hitTarget ~= Character then
							Server.Modules.Damage.Tag(Character, hitTarget, {
								Damage = 8,
								PostureDamage = 10,
								Stun = 0.4,
								BlockBreak = true, -- FIXED: Ground Decay should guard break
								M1 = false,
								M2 = false,
								FX = Replicated.Assets.VFX.Blood.Attachment,
							})
						end
					end
				end)
			end
		end)
		table.insert(activeConnections, kfConn)
	end
end

return NetworkModule

