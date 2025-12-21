--[[
	Modernized NPC System using jecs-utils ref

	This system now uses the new ref system to track NPCs.
	Observers handle spawn/despawn events automatically.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local InsertService = game:GetService("InsertService")

local comps = require(ReplicatedStorage.Modules.ECS.jecs_components)
local world = require(ReplicatedStorage.Modules.ECS.jecs_world)
local RefManager = require(ReplicatedStorage.Modules.ECS.jecs_ref_manager)
local OccupationData = require(ReplicatedStorage.Modules.OccupationData)
local CustomizationData = require(ReplicatedStorage.Modules.CustomizationData)
local RelationshipManager = require(ReplicatedStorage.Modules.Utils.RelationshipManager)
local Players = game:GetService("Players")

-- Hair asset IDs from GenerateHair.lua
local HAIR_DATA = {
	Male = {
		Regular = {
			13515609141, 13002675302, 15354053211, 12911961302, 12875433848, 13458529673, 7145036730, 13433250227,
			14594033045, 10472547652, 9678794874, 7436421066, 12283951209, 12281536963, 8082486982, 9930021350, 7222634196,
			7062107080, 6564177190, 13604405273, 13613963807, 18730352272, 16258214383, 16811634288,
			18614035623, 18654028028, 14761240955, 18644793758, 15431812636, 12007649057, 15228643039,
			4772335492, 18428787351, 17156849019, 17660929664, 14763696930, 14720386664, 16088468918, 12269536686,
			17828076063, 17343539011, 16752503082, 17325416471, 12454026428,
			17856933034, 17537788434, 18509795747, 17342752605, 17538185956, 17559553558, 13985919654, 17334331827, 16040030579,
			8213808170, 14258472141, 4878040985, 11461141476, 14705261988, 15670240923, 15837280405, 17166707678, 16848737789, 18716065433,
			17354005379, 12215653863, 295453051, 17535252603, 13336060119, 14896136763, 18964955410, 18199466043, 15366803289,
			15860553784, 14959928960, 16216120519, 17176221540, 17429768281, 9057322582, 15927551085, 17506035464, 17391547393,
			14917257190, 18558445206, 16732618611, 18539863421, 6216675304, 14892240503, 15505725140, 11377605079, 12512752850, 12523822861,
			4904074569, 185812332
		},
		Black = {
			16324156451, 16384059895, 16612265839, 16549916876, 17184574257, 18510413378,
			16384914512, 5534852325, 13004659172, 11925526319, 11244910596,
			13143910884, 13983155539, 12455993745, 16641413515, 12094575759, 17260820249, 18936679248,
			7390659411, 15449062633, 12579423689, 14511231632, 14666341458, 13628394874, 17341565507,
			15633204046, 18503024245, 18697914465, 17364092576, 17750337670, 5198069544, 6983893148, 15921775555, 6712905660, 4584980640,
			6995572325, 8696081004, 4584981984, 6905438759, 5153045569, 5164439083, 12105975615,
			12866747115, 7442838146, 17836503900, 11287051438, 16088398820, 18619205456, 12866753560, 15789786250,
			5100703261, 3993395372, 14125533276, 12179467440
		}
	},
	Female = {
		Regular = {
			18580292693, 16929998541,
			14248258727, 16653542035, 18570730523,
			16061696659, 17228828321, 17770226592,
			17470443420, 17464271716, 17388769202, 5029336839,
			17332166677, 18100482783, 17537709999, 14276180507, 12397744697, 8666972398, 13446595752, 12843385114,
			13232401920, 8154699751, 15696996201, 7602557150, 12865232071, 15085285216, 13337255262,
			17861245895, 11942405195, 13012552498, 11106121618, 16640134523, 18135792182,
			17165429539, 17563617890, 17654280271, 17231020955, 17211776772, 13472807890,
			9424759646, 10078496059, 13456038895, 11428234354, 12506032024, 12507759642, 11101076476, 7620726200, 6571562126,
			7960758771, 11387072569, 8031570897, 6441072389, 7439158772, 6210514083, 6754446477, 1708329071, 6475273980, 4997328475,
			4710923961, 4966169337, 5548484755
		},
		Black = {
			15069727041, 12616684153, 16379907094, 15893914533, 16379946117, 12542448389, 15184794900, 17632059178, 10424152958,
			17025026441, 15408979186, 15484158696, 12947220852, 14171199663, 14826853111, 13327495599, 13622008596, 16617499966,
			15029060883, 15176484789, 18536946933
		}
	}
}

-- Helper to position hair accessory on head
local function positionHairOnHead(accessory, head)
	local handle = accessory:FindFirstChild("Handle")
	local headAttachment = head:FindFirstChild("HairAttachment")
	local hairAttachment = handle and handle:FindFirstChild("HairAttachment")

	if handle and hairAttachment and headAttachment then
		handle.CFrame = headAttachment.WorldCFrame * hairAttachment.CFrame:Inverse()
	end
end

-- Preloaded clothing templates (loaded on server start like player system)
local preloadedShirts = {}
local preloadedPants = {}
local clothingPreloaded = false

local function preloadNPCClothing()
	if clothingPreloaded then return end
	clothingPreloaded = true

	for outfitId, outfit in pairs(CustomizationData.Clothes) do
		-- Preload shirt
		if outfit.shirt then
			pcall(function()
				local assetId = string.match(outfit.shirt, "%d+")
				if assetId then
					local model = InsertService:LoadAsset(tonumber(assetId))
					if model then
						local shirtItem = model:FindFirstChildWhichIsA("Shirt", true)
						if shirtItem then
							preloadedShirts[outfitId] = shirtItem.ShirtTemplate
						end
						model:Destroy()
					end
				end
			end)
			task.wait(0.05)
		end

		-- Preload pants
		if outfit.pants then
			pcall(function()
				local assetId = string.match(outfit.pants, "%d+")
				if assetId then
					local model = InsertService:LoadAsset(tonumber(assetId))
					if model then
						local pantsItem = model:FindFirstChildWhichIsA("Pants", true)
						if pantsItem then
							preloadedPants[outfitId] = pantsItem.PantsTemplate
						end
						model:Destroy()
					end
				end
			end)
			task.wait(0.05)
		end
	end
end

-- Start preloading in background
task.spawn(preloadNPCClothing)

-- Apply random clothing and appearance to wanderer NPCs
-- If savedAppearance is provided, use that instead of random
local function applyWandererAppearance(npcModel: Model, savedAppearance: {outfitId: number?, race: string?, gender: string?, hairId: number?, skinColor: string?}?)
	-- Defer to ensure model is fully loaded
	task.defer(function()
		if not npcModel or not npcModel.Parent then return end

		-- Use saved appearance if provided, otherwise generate random
		local outfitId, race, gender, hairId, skinColor

		if savedAppearance then
			-- Use saved appearance from befriended NPC
			outfitId = savedAppearance.outfitId
			race = savedAppearance.race
			gender = savedAppearance.gender
			hairId = savedAppearance.hairId
			skinColor = savedAppearance.skinColor
		else
			-- Pick random outfit from CustomizationData
			local outfitCount = 0
			for _ in pairs(CustomizationData.Clothes) do
				outfitCount = outfitCount + 1
			end
			outfitId = math.random(1, outfitCount)

			-- Pick random gender for hair
			gender = math.random() > 0.5 and "Male" or "Female"

			-- Pick random race for skin color
			local races = {"Amestrian", "Xing", "Ishvalan"}
			race = races[math.random(1, #races)]
			local raceData = CustomizationData.Races[race]
			local variants = {"variant1", "variant2", "variant3"}
			skinColor = raceData[variants[math.random(1, 3)]]

			-- Pick random hair
			local useBlackHair = race == "Xing" or (race == "Amestrian" and math.random() > 0.7)
			local hairPool = HAIR_DATA[gender][useBlackHair and "Black" or "Regular"]
			hairId = hairPool[math.random(1, #hairPool)]
		end

		local outfit = CustomizationData.Clothes[outfitId]
		if not outfit then return end

		-- Store appearance as attributes for client access (for relationship system)
		npcModel:SetAttribute("OutfitId", outfitId)
		npcModel:SetAttribute("Race", race)
		npcModel:SetAttribute("Gender", gender)
		npcModel:SetAttribute("HairId", hairId)
		npcModel:SetAttribute("SkinColor", skinColor)

		-- DELETE ALL existing Shirt and Pants instances (like player system)
		for _, child in npcModel:GetChildren() do
			if child:IsA("Shirt") or child:IsA("Pants") then
				child:Destroy()
			end
		end

		-- Wait a frame to ensure deletion completes (critical for clothing to apply)
		task.wait()

		-- Get templates (use preloaded if available, fallback to raw asset ID)
		local shirtTemplate = preloadedShirts[outfitId] or outfit.shirt
		local pantsTemplate = preloadedPants[outfitId] or outfit.pants

		-- Apply shirt
		local shirt = Instance.new("Shirt")
		shirt.Name = "Shirt"
		shirt.ShirtTemplate = shirtTemplate
		shirt.Parent = npcModel

		-- Apply pants
		local pants = Instance.new("Pants")
		pants.Name = "Pants"
		pants.PantsTemplate = pantsTemplate
		pants.Parent = npcModel

		-- Get race data for skin color
		local raceData = CustomizationData.Races[race]
		local skinBrickColor = BrickColor.new(skinColor)

		-- Apply skin color via BodyColors
		local bodyColors = npcModel:FindFirstChild("Body Colors")
		if bodyColors then
			bodyColors.HeadColor = skinBrickColor
			bodyColors.LeftArmColor = skinBrickColor
			bodyColors.RightArmColor = skinBrickColor
			bodyColors.LeftLegColor = skinBrickColor
			bodyColors.RightLegColor = skinBrickColor
			bodyColors.TorsoColor = skinBrickColor
		end

		-- Also apply skin color directly to body parts (for R15 or custom rigs)
		local bodyParts = {"Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg",
			"UpperTorso", "LowerTorso", "LeftUpperArm", "LeftLowerArm", "LeftHand",
			"RightUpperArm", "RightLowerArm", "RightHand", "LeftUpperLeg", "LeftLowerLeg",
			"LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot"}
		for _, partName in bodyParts do
			local part = npcModel:FindFirstChild(partName)
			if part and part:IsA("BasePart") then
				part.BrickColor = skinBrickColor
			end
		end

		-- Get hair color based on race
		local hairColorTable = CustomizationData.HairColor[race]
		local hairColor = hairColorTable and hairColorTable[1] or Color3.new(0, 0, 0)

		-- Apply hair (using pre-selected hairId from above)
		local head = npcModel:FindFirstChild("Head")
		local humanoid = npcModel:FindFirstChild("Humanoid")
		if head and humanoid and hairId then
			-- Load and apply hair accessory
			task.spawn(function()
				local success, accessoryModel = pcall(function()
					return InsertService:LoadAsset(hairId)
				end)

				if success and accessoryModel then
					local accessory = accessoryModel:FindFirstChildWhichIsA("Accessory")
					if accessory then
						-- Remove any existing hair accessories
						for _, child in npcModel:GetChildren() do
							if child:IsA("Accessory") and child:FindFirstChild("Handle") then
								local handle = child:FindFirstChild("Handle")
								if handle and handle:FindFirstChild("HairAttachment") then
									child:Destroy()
								end
							end
						end

						-- Add the new hair accessory
						humanoid:AddAccessory(accessory)
						positionHairOnHead(accessory, head)

						-- Apply hair color
						local handle = accessory:FindFirstChild("Handle")
						if handle then
							local mesh = handle:FindFirstChildOfClass("SpecialMesh")
							if mesh then
								mesh.TextureId = "rbxassetid://113724683736061" -- Black texture for coloring
								mesh.VertexColor = Vector3.new(hairColor.R, hairColor.G, hairColor.B)
							end
							handle.Material = Enum.Material.Asphalt
							handle.Color = hairColor
						end
					end
					accessoryModel:Destroy()
				end
			end)
		end

		-- Apply face if available
		if head then
			local faceData = CustomizationData.Face[gender] and CustomizationData.Face[gender][1]
			if faceData and faceData.assets then
				local faceAssets = faceData.assets:Clone()

				-- Create fakehead for face
				local existingFakehead = npcModel:FindFirstChild("fakehead")
				if not existingFakehead then
					local fakehead = head:Clone()
					fakehead.Name = "fakehead"
					fakehead.CanCollide = false
					fakehead.Transparency = 0
					fakehead.Color = skinBrickColor.Color
					local weld = Instance.new("Weld")
					weld.Part0 = head
					weld.Part1 = fakehead
					weld.Parent = fakehead
					fakehead.Parent = npcModel

					-- Apply face decals
					for _, v in faceAssets:GetChildren() do
						if v then
							v.Parent = fakehead
						end
					end
				end
			end
		end
	end)
end

-- Helper function to check if NPC is a wandering citizen (non-combat)
local function isWandererNPC(npcModel: Model): boolean
	local npcName = npcModel.Name:lower()
	return npcName:find("wanderer") ~= nil
end

-- Helper function to check if NPC is a combat NPC
local function isCombatNPC(npcModel: Model): boolean
	-- Wanderers are NEVER combat NPCs
	if isWandererNPC(npcModel) then
		return false
	end

	-- Check if NPC is in Dialogue folder (dialogue NPCs are never combat NPCs)
	local ancestor = npcModel
	while ancestor do
		if ancestor.Name == "Dialogue" and ancestor.Parent and ancestor.Parent.Name == "World" then
			---- print(`[Mobs] {npcModel.Name} is in World.Dialogue - DIALOGUE NPC`)
			return false -- Dialogue NPC
		end
		ancestor = ancestor.Parent
	end

	-- Check if NPC name contains "Dummy" or "Training" - these are NOT combat NPCs
	local npcName = npcModel.Name:lower()
	if npcName:find("dummy") or npcName:find("training") then
		---- print(`[Mobs] {npcModel.Name} is a training dummy - DIALOGUE NPC`)
		return false
	end

	-- OPTIMIZATION: Don't wait for Actor parent - just check immediately
	-- If Actor doesn't exist yet, the NPC will be reinitialized when it's fully loaded
	local actor = npcModel.Parent
	if not actor or not actor:IsA("Actor") then
		---- print(`[Mobs] {npcModel.Name} - No Actor parent found, assuming DIALOGUE NPC (safer default)`)
		return false -- Default to dialogue NPC if no Actor (safer for dummies/static NPCs)
	end

	local dataFolder = actor:FindFirstChild("Data")
	if not dataFolder then
		---- print(`[Mobs] {npcModel.Name} - No Data folder found, assuming DIALOGUE NPC (safer default)`)
		return false -- Default to dialogue NPC if no Data folder
	end

	-- Check Combat settings
	local combatFolder = dataFolder:FindFirstChild("Combat")
	if combatFolder then
		local lightValue = combatFolder:FindFirstChild("Light")
		if lightValue then
			---- print(`[Mobs] {npcModel.Name} - Combat.Light = {lightValue.Value}`)
			if lightValue.Value == true then
				return true
			end
		end
	end

	-- Check if has weapons enabled
	local weaponsFolder = dataFolder:FindFirstChild("Weapons")
	if weaponsFolder then
		local enabledValue = weaponsFolder:FindFirstChild("Enabled")
		if enabledValue then
			---- print(`[Mobs] {npcModel.Name} - Weapons.Enabled = {enabledValue.Value}`)
			if enabledValue.Value == true then
				return true
			end
		end
	end

	-- Check if has enemy detection
	local enemyDetectionFolder = dataFolder:FindFirstChild("EnemyDetection")
	if enemyDetectionFolder then
		local captureDistValue = enemyDetectionFolder:FindFirstChild("CaptureDistance")
		if captureDistValue then
			---- print(`[Mobs] {npcModel.Name} - EnemyDetection.CaptureDistance = {captureDistValue.Value}`)
			if captureDistValue.Value > 0 then
				return true
			end
		end
	end

	---- print(`[Mobs] {npcModel.Name} - No combat indicators found, defaulting to DIALOGUE NPC`)
	return false
end

-- Function to initialize NPC entity with all components
local function initializeNPCEntity(npcModel: Model): number
	-- Use new ref system with initializer function
	local entity = RefManager.entity(npcModel, function(e)
		-- Set all NPC components
		world:set(e, comps.Character, npcModel)
		world:set(e, comps.Mob, true)

		-- Determine if this is a combat NPC
		local isCombat = isCombatNPC(npcModel)
		if isCombat then
			world:set(e, comps.CombatNPC, true)
		end

		-- Check if this is a Wanderer (non-combat citizen)
		local isWanderer = isWandererNPC(npcModel)
		if isWanderer then
			-- Mark as wanderer, ensure NOT combat
			world:set(e, comps.WandererNPC, true)
			world:remove(e, comps.CombatNPC)

			-- Generate random identity (name, occupation, personality)
			local identity = OccupationData.generateRandomIdentity()
			world:set(e, comps.NPCIdentity, identity)

			-- Generate unique NPC ID for relationship tracking
			local npcId = RelationshipManager.generateNPCId(identity.name, identity.occupation)
			npcModel:SetAttribute("NPCId", npcId)

			-- Add proximity detection component
			world:set(e, comps.NPCProximity, {
				nearbyPlayer = nil,
				isWanderPaused = false,
				detectionRange = 8,
			})

			-- Add relationship tracking component
			world:set(e, comps.NPCRelationship, {
				relationships = {},
				hitCounts = {},
				dailyInteractions = {},
				lastDayReset = os.time(),
			})

			-- Add flee behavior component
			world:set(e, comps.NPCFlee, {
				isFleeing = false,
				fleeTarget = nil,
				fleeEndTime = 0,
			})

			-- Store identity as attributes for client access
			npcModel:SetAttribute("NPCName", identity.name)
			npcModel:SetAttribute("Occupation", identity.occupation)
			npcModel:SetAttribute("OccupationType", identity.occupationType)
			npcModel:SetAttribute("Personality", identity.personality)

			-- Apply random clothing and appearance
			applyWandererAppearance(npcModel)
		end

		-- Wanderers have lower max HP (50) and spawn at full health
		local initialHealth = isWanderer and 50 or 175
		local maxHealth = isWanderer and 50 or 175
		world:set(e, comps.Health, {current = initialHealth, max = maxHealth, tick = 0.5, tickspeed = 0.1})

		-- Sync Humanoid health with ECS Health component
		local humanoid = npcModel:FindFirstChild("Humanoid")
		if humanoid then
			humanoid.MaxHealth = maxHealth
			humanoid.Health = initialHealth
		end

		world:set(e, comps.Energy, {current = 100, tick = 0.5, tickspeed = 0.1})
		world:set(e, comps.InCombat, {value = false}) -- Required for health regen system
		world:set(e, comps.Combat, { weapon = "Fist", equipped = true, animation = "Fist" })
		world:set(e, comps.Attacking, {duration = 0, value = false})
		world:set(e, comps.Stun, {duration = 0, value = false})
		world:set(e, comps.NoRotate, {duration = 0, value = false})
		world:set(e, comps.Dashing, false)
		world:set(e, comps.Blocking, {duration = 0, value = false})
		world:set(e, comps.Carrying, {target = nil, value = false})
		world:set(e, comps.BeingGripped, false)
		world:set(e, comps.BeingCarried, false)
		world:set(e, comps.DeathLocation, CFrame.new(0,0,0))
		world:set(e, comps.Knocked, {duration = 0, value = false})
		world:set(e, comps.IFrame, {duration = 0, value = false})
		world:set(e, comps.Sprinting, false)
		world:set(e, comps.Ragdoll, {duration = 0, value = false})
		world:set(e, comps.CantMove, {duration = 0, value = false})
		world:set(e, comps.Dead, false)
		world:set(e, comps.Weapon, {name = "Fist", type = "Fist"})
		world:set(e, comps.Swing, 1)
		world:set(e, comps.WallRunning, false)
		world:set(e, comps.Sliding, false)
		world:set(e, comps.NoJump, {duration = 0, value = false})
		world:set(e, comps.ToSpeed, 0)
		world:set(e, comps.KeysLogged, 1)
		world:set(e, comps.Light, {duration = 0, value = false})
		world:set(e, comps.NoDash, {duration = 0, value = false})
		world:set(e, comps.LastHit, 0)
		world:set(e, comps.CritCD, {duration = 0, value = false})
		world:set(e, comps.Heavy, {duration = 0, value = false})
		world:set(e, comps.IgnoreParry, {duration = 0, value = false})
		world:set(e, comps.NoHurt, {duration = 0, value = false})
		world:set(e, comps.Damage, 0)
		world:set(e, comps.ParryTick, {duration = 0, value = false})
		world:set(e, comps.ParryStun, {duration = 0, value = false})
		world:set(e, comps.InAir, false)
		world:set(e, comps.Utility, {duration = 0, value = false})
		world:set(e, comps.Victim, nil)
		world:set(e, comps.Action, {duration = 0, value = false})
		world:set(e, comps.BlockBar, {Value = 0, MaxValue = 100})  -- Start at 0, increases to 100 when blocking hits
		world:set(e, comps.BBRegen, {duration = 0, value = false})
		world:set(e, comps.BlockBroken, false)
		world:set(e, comps.Armor, {duration = 0, armortype = "None", value = false})
		world:set(e, comps.QDC, {duration = 0, value = false})
		world:set(e, comps.NoRagdoll, false)
		world:set(e, comps.Locked, {duration = 0, value = false})

		-- ECS AI Components (only for combat NPCs)
		if isCombat then
			local hrp = npcModel:FindFirstChild("HumanoidRootPart")
			local spawnPos = hrp and hrp.Position or Vector3.new(0, 0, 0)
			local spawnCF = hrp and hrp.CFrame or CFrame.new(0, 0, 0)

			-- Transform component (required for AI)
			world:set(e, comps.Transform, {
				new = spawnCF,
				old = spawnCF
			})

			-- Locomotion component (movement intent)
			world:set(e, comps.Locomotion, {
				dir = Vector3.zero,
				speed = 0
			})

			-- AI State component
			local function randRange(min: number, max: number): number
				return min + (max - min) * math.random()
			end

			world:set(e, comps.AIState, {
				state = "wander",
				t = randRange(0, 2), -- Random starting time to desync NPCs
				dur = randRange(2, 5),
				circleSign = (math.random(0, 1) == 0) and -1 or 1,
			})

			-- Traits component (AI personality)
			local chaseWeight = randRange(0.3, 0.8)
			local fleeWeight = randRange(0.1, 0.4)
			local circleWeight = randRange(0.2, 0.5)
			local detectRange = randRange(25, 45)

			world:set(e, comps.Traits, {
				baseSpeedMul = randRange(0.8, 1.2),
				chaseWeight = chaseWeight,
				fleeWeight = fleeWeight,
				circleWeight = circleWeight,
				jumpWeight = randRange(0, 0.3),
				fleeDistance = randRange(8, 15),
				preferDistance = randRange(2, 5),
				detectRange = detectRange,
				loseSightRange = detectRange + randRange(10, 20),
			})

			-- Wander component
			world:set(e, comps.Wander, {
				center = spawnPos,
				radius = 30,
				nextMove = math.random() * 2, -- Random starting time to desync NPCs
			})

			-- Hitbox component (for debugging/attributes)
			if hrp then
				world:set(e, comps.Hitbox, hrp)
				hrp:SetAttribute("DetectRange", detectRange)
				hrp:SetAttribute("IsCombatNPC", true)

				-- Size component (for mob avoidance)
				-- Calculate size from HumanoidRootPart or use default
				local hitboxSize = hrp.Size
				world:set(e, comps.Size, hitboxSize.Magnitude)
			end

			-- NEW: NPC Combat AI Components
			-- Get config from Actor Data folder
			local actor = npcModel.Parent
			local captureDistance = 40
			local letGoDistance = 60
			local runAwayHP = 0.2
			local canStrafe = true
			local canWander = false -- Default to false - NPCs must explicitly opt-in to wandering
			local maxStrafeRadius = 12 -- REDUCED: Was 20, now 12 for tighter circle strafe
			local maxAlignmentDot = 0.5
			local walkSpeed = 16
			local runSpeed = 24
			local jumpPower = 50
			local smoothingAlpha = 0.3
			local maxWanderDistance = 30

			if actor and actor:IsA("Actor") then
				local dataFolder = actor:FindFirstChild("Data")
				if dataFolder then
					local enemyDetection = dataFolder:FindFirstChild("EnemyDetection")
					if enemyDetection then
						local captureDist = enemyDetection:FindFirstChild("CaptureDistance")
						if captureDist then captureDistance = captureDist.Value end
						local letGoDist = enemyDetection:FindFirstChild("LetGoDistance")
						if letGoDist then letGoDistance = letGoDist.Value end
					end

					local combatFolder = dataFolder:FindFirstChild("Combat")
					if combatFolder then
						local runAwayHPValue = combatFolder:FindFirstChild("RunAwayHP")
						if runAwayHPValue then runAwayHP = runAwayHPValue.Value end
					end

					local settingFolder = dataFolder:FindFirstChild("Setting")
					if settingFolder then
						local canStrafeValue = settingFolder:FindFirstChild("CanStrafe")
						if canStrafeValue then canStrafe = canStrafeValue.Value end
						local canWanderValue = settingFolder:FindFirstChild("CanWander")
						if canWanderValue then canWander = canWanderValue.Value end
					end

					local movementFolder = dataFolder:FindFirstChild("Movement")
					if movementFolder then
						local maxStrafeRadiusValue = movementFolder:FindFirstChild("MaxStrafeRadius")
						if maxStrafeRadiusValue then maxStrafeRadius = maxStrafeRadiusValue.Value end
						local maxAlignmentDotValue = movementFolder:FindFirstChild("MaxAlignmentDot")
						if maxAlignmentDotValue then maxAlignmentDot = maxAlignmentDotValue.Value end
						local smoothingAlphaValue = movementFolder:FindFirstChild("SmoothingAlpha")
						if smoothingAlphaValue then smoothingAlpha = smoothingAlphaValue.Value end
					end

					local humanoidDefaults = dataFolder:FindFirstChild("HumanoidDefaults")
					if humanoidDefaults then
						local walkSpeedValue = humanoidDefaults:FindFirstChild("WalkSpeed")
						if walkSpeedValue then walkSpeed = walkSpeedValue.Value end
						local runSpeedValue = humanoidDefaults:FindFirstChild("RunSpeed")
						if runSpeedValue then runSpeed = runSpeedValue.Value end
						local jumpPowerValue = humanoidDefaults:FindFirstChild("JumpPower")
						if jumpPowerValue then jumpPower = jumpPowerValue.Value end
					end

					local idleFolder = dataFolder:FindFirstChild("Idle")
					if idleFolder then
						local maxDistanceValue = idleFolder:FindFirstChild("MaxDistance")
						if maxDistanceValue then maxWanderDistance = maxDistanceValue.Value end
					end
				end
			end

			-- NPCCombatState (FIXED: Only start aggressive if they have capture range > 0)
			-- This prevents wandering NPCs from aggroing without being attacked
			local shouldStartAggressive = captureDistance > 0
			world:set(e, comps.NPCCombatState, {
				isPassive = not shouldStartAggressive, -- FIXED: Passive by default unless capture range set
				isAggressive = shouldStartAggressive,  -- FIXED: Only aggressive if they hunt players
				hasBeenAttacked = false,
				lastAttackTime = 0,
				lastDefenseTime = 0,
				lastActionTime = 0,
				justParried = false,
				parryTime = 0,
				lastM1Time = 0,
				lastSkillUsed = nil,
				hitsTaken = 0,
			})

			-- NPCSkillScoring
			world:set(e, comps.NPCSkillScoring, {
				bestSkill = nil,
				bestScore = 0,
				lastScoringTime = 0,
			})

			-- NPCGuardPattern (only for guards)
			local isGuard = string.find(npcModel.Name, "Guard") ~= nil
			world:set(e, comps.NPCGuardPattern, {
				enabled = isGuard,
				currentState = "Defensive",
				stateStartTime = os.clock(),
				comboCount = 0,
			})

			-- NPCPathfinding
			world:set(e, comps.NPCPathfinding, {
				isActive = false,
				pathState = "Direct",
				stateId = 0,
				waypoints = nil,
				currentWaypointIndex = 0,
				lastRecomputeTime = 0,
			})

			-- NPCMovementPattern
			world:set(e, comps.NPCMovementPattern, {
				current = "Direct",
				lastChanged = math.random() * 2, -- Random start to desync
				duration = math.random() * 1 + 2, -- 2-3 seconds
				strafeDirection = nil,
				sideDirection = nil,
				circleDirection = (math.random() > 0.5) and 1 or -1, -- Random circle direction
				zigzagDirection = (math.random() > 0.5) and 1 or -1, -- Random zigzag direction
				zigzagTimer = math.random(), -- Random zigzag phase
			})

			-- NPCWander (only add if NPC can wander)
			-- Guards should NOT wander, so they won't have this component
			if canWander then
				world:set(e, comps.NPCWander, {
					center = spawnPos, -- spawnPos is already the NPC's current position (from hrp.Position)
					radius = maxWanderDistance or 30,
					nextMove = math.random() * 3, -- Random starting time to desync
					swayX = 0,
					swayY = 0,
					noiseOffset = math.random() * 1000, -- Already randomized, good!
					currentDirection = Vector3.zero,
					isPaused = false, -- Initialize pause state
					pauseEndTime = 0,
					moveEndTime = 0,
				})
			end

			-- NPCConfig
			world:set(e, comps.NPCConfig, {
				captureDistance = captureDistance,
				letGoDistance = letGoDistance,
				runAwayHP = runAwayHP,
				safeRange = 15,
				canStrafe = canStrafe,
				canWander = canWander,
				maxStrafeRadius = maxStrafeRadius,
				maxAlignmentDot = maxAlignmentDot,
				walkSpeed = walkSpeed,
				runSpeed = runSpeed,
				jumpPower = jumpPower,
				smoothingAlpha = smoothingAlpha,
			})

			-- NPCSpawnData
			world:set(e, comps.NPCSpawnData, {
				spawnPosition = spawnPos,
				maxWanderDistance = maxWanderDistance,
			})

				-- Debug logging for initialization
			local combatState = world:get(e, comps.NPCCombatState)
			---- print("[Mobs] ⚔️ Initialized COMBAT NPC:", npcModel.Name, "Entity:", e, "with ECS AI")
			---- print(`[Mobs]    - isPassive: {combatState.isPassive}, canWander: {canWander}`)
			---- print(`[Mobs]    - Components: NPCCombatState, NPCMovementPattern, NPCConfig, Transform, Locomotion`)
			if canWander then
				---- print(`[Mobs]    - Added NPCWander (radius: {maxWanderDistance or 30})`)
			else
				---- print(`[Mobs]    - NPCWander NOT added (guard mode)`)
			end
		elseif isWanderer then
			-- Wanderer-specific AI components (simpler than combat NPCs)
			local hrp = npcModel:FindFirstChild("HumanoidRootPart")
			local spawnPos = hrp and hrp.Position or Vector3.new(0, 0, 0)
			local spawnCF = hrp and hrp.CFrame or CFrame.new(0, 0, 0)

			-- Transform component (required for movement)
			world:set(e, comps.Transform, {
				new = spawnCF,
				old = spawnCF
			})

			-- Locomotion component (movement intent)
			world:set(e, comps.Locomotion, {
				dir = Vector3.zero,
				speed = 0
			})

			-- NPCWander component for natural wandering behavior
			world:set(e, comps.NPCWander, {
				center = spawnPos,
				radius = 25, -- Wanderers stay closer to spawn
				nextMove = math.random() * 3,
				swayX = 0,
				swayY = 0,
				noiseOffset = math.random() * 1000,
				currentDirection = Vector3.zero,
				isPaused = false,
				pauseEndTime = 0,
				moveEndTime = 0,
			})

			-- NPCConfig for wanderer movement speeds
			world:set(e, comps.NPCConfig, {
				captureDistance = 0, -- No combat detection
				letGoDistance = 0,
				runAwayHP = 0,
				safeRange = 0,
				canStrafe = false,
				canWander = true,
				maxStrafeRadius = 0,
				maxAlignmentDot = 0,
				walkSpeed = 10, -- Slower, casual walk
				runSpeed = 18, -- For fleeing
				jumpPower = 0,
				smoothingAlpha = 0.3,
			})

			-- Mark as wanderer for HRP attributes
			if hrp then
				hrp:SetAttribute("IsWandererNPC", true)
				hrp:SetAttribute("IsCombatNPC", false)
			end

			---- print("[Mobs] 🚶 Initialized WANDERER NPC:", npcModel.Name, "Entity:", e, "with citizen AI")
		else
			---- print("[Mobs] 💬 Initialized DIALOGUE NPC:", npcModel.Name, "Entity:", e, "(no ECS AI)")
		end

		-- Mark components as ready for systems like health_regen
		world:set(e, comps.ComponentsReady, true)
	end)

	return entity
end

-- Track NPCs that have been initialized to avoid rescanning
local initializedNPCs = {}

-- OPTIMIZATION: Cache Live folder children instead of using GetDescendants
local liveFolder = workspace.World.Live
local cachedNPCs = {}

-- Helper to scan a folder for NPCs (non-recursive, more efficient)
local function scanFolderForNPCs(folder)
	for _, child in folder:GetChildren() do
		if child:IsA("Model") and not Players:GetPlayerFromCharacter(child) then
			if not initializedNPCs[child] and not cachedNPCs[child] then
				local existingEntity = RefManager.entity.find(child)
				if not existingEntity then
					-- FIXED: Initialize immediately instead of deferring to prevent NPCs from not loading
					initializeNPCEntity(child)
					initializedNPCs[child] = true
					cachedNPCs[child] = true
				else
					cachedNPCs[child] = true
				end
			end
		end
	end
end

-- Set up DescendantAdded listener for immediate NPC detection (more efficient than polling)
workspace.World.Live.DescendantAdded:Connect(function(descendant)
	if descendant:IsA("Model") and not Players:GetPlayerFromCharacter(descendant) then
		-- FIXED: Initialize immediately to ensure NPCs load properly
		-- Small delay to ensure model is fully loaded
		task.wait(0.1)
		if not initializedNPCs[descendant] then
			local existingEntity = RefManager.entity.find(descendant)
			if not existingEntity then
				initializeNPCEntity(descendant)
				initializedNPCs[descendant] = true
				cachedNPCs[descendant] = true
			end
		end
	end
end)

-- Clean up tracking when NPCs are removed
workspace.World.Live.DescendantRemoving:Connect(function(descendant)
	if initializedNPCs[descendant] then
		initializedNPCs[descendant] = nil
	end
	if cachedNPCs[descendant] then
		cachedNPCs[descendant] = nil
	end
end)

-- OPTIMIZATION: Do initial scan once on startup, then rely on DescendantAdded
local hasScannedOnce = false

return {
	run = function()
		-- Skip if more than 1 player (temporary restriction)
		if #Players:GetPlayers() > 1 then return end

		-- OPTIMIZATION: Only scan once on startup, then rely on DescendantAdded listener
		-- This eliminates the expensive GetDescendants() call every 2 seconds
		if not hasScannedOnce then
			hasScannedOnce = true
			-- Scan Live folder (non-recursive, much faster than GetDescendants)
			scanFolderForNPCs(liveFolder)
		end

		-- No periodic scanning needed - DescendantAdded handles everything
	end,

	settings = {
		phase = "Heartbeat",
		depends_on = {},
		server_only = true
	}
}