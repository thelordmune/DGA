--[[
	VFX Cleanup System
	
	Tracks and cleans up all active VFX (particle emitters, connections, effects)
	when a character dies or when moves are cancelled.
	
	Usage:
		VFXCleanup.RegisterVFX(character, vfxInstance, connection, cleanupCallback)
		VFXCleanup.CleanupCharacter(character) -- Called on death or move cancel
]]

local VFXCleanup = {}

-- Track all active VFX per character
local activeVFX = {} -- [Character] = { {instance, connection, callback}, ... }

--[[
	Register a VFX effect for a character
	@param character Model - The character that owns this VFX
	@param vfxInstance Instance? - The VFX instance to destroy (optional)
	@param connection RBXScriptConnection? - Connection to disconnect (optional)
	@param cleanupCallback function? - Custom cleanup function (optional)
]]
function VFXCleanup.RegisterVFX(character: Model, vfxInstance: Instance?, connection: RBXScriptConnection?, cleanupCallback: (() -> ())?)
	if not character then return end
	
	-- Initialize character's VFX table if it doesn't exist
	if not activeVFX[character] then
		activeVFX[character] = {}
	end
	
	-- Store the VFX data
	table.insert(activeVFX[character], {
		instance = vfxInstance,
		connection = connection,
		callback = cleanupCallback,
	})
end

--[[
	Clean up all VFX for a character
	@param character Model - The character to clean up
]]
function VFXCleanup.CleanupCharacter(character: Model)
	if not character then return end
	
	local vfxList = activeVFX[character]
	if not vfxList then return end
	
	---- print(`[VFXCleanup] Cleaning up {#vfxList} VFX entries for {character.Name}`)
	
	-- Clean up each VFX entry
	for _, vfxData in ipairs(vfxList) do
		-- Disconnect connection
		if vfxData.connection then
			pcall(function()
				vfxData.connection:Disconnect()
			end)
		end
		
		-- Destroy instance
		if vfxData.instance and vfxData.instance.Parent then
			pcall(function()
				-- Disable all particle emitters first
				for _, descendant in vfxData.instance:GetDescendants() do
					if descendant:IsA("ParticleEmitter") then
						descendant.Enabled = false
					end
				end
				vfxData.instance:Destroy()
			end)
		end
		
		-- Call custom cleanup callback
		if vfxData.callback then
			pcall(vfxData.callback)
		end
	end
	
	-- Clear the character's VFX table
	activeVFX[character] = nil
end

--[[
	Clean up all particle emitters on a character (for move cancellation)
	@param character Model - The character to clean up
]]
function VFXCleanup.DisableCharacterParticles(character: Model)
	if not character then return end

	-- Disable all particle emitters on the character
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("ParticleEmitter") then
			descendant.Enabled = false
		end
	end

	-- Also disable particle emitters on weapons
	local leftWeapon = character:FindFirstChild("LeftWeapon") or character:FindFirstChild("LeftGun")
	local rightWeapon = character:FindFirstChild("RightWeapon") or character:FindFirstChild("RightGun")

	if leftWeapon then
		for _, descendant in leftWeapon:GetDescendants() do
			if descendant:IsA("ParticleEmitter") then
				descendant.Enabled = false
			end
		end
	end

	if rightWeapon then
		for _, descendant in rightWeapon:GetDescendants() do
			if descendant:IsA("ParticleEmitter") then
				descendant.Enabled = false
			end
		end
	end
end

--[[
	Clean up all VFX in workspace.World.Visuals that are associated with a character
	@param character Model - The character to clean up
]]
function VFXCleanup.CleanupVisualsFolder(character: Model)
	if not character then return end
	
	local visualsFolder = workspace:FindFirstChild("World")
	if visualsFolder then
		visualsFolder = visualsFolder:FindFirstChild("Visuals")
	end
	
	if not visualsFolder then return end
	
	-- Find and destroy VFX that might be associated with this character
	-- This is a safety net for VFX that weren't properly registered
	for _, vfx in visualsFolder:GetChildren() do
		-- Check if VFX has a reference to the character or is following the character
		if vfx:IsA("Model") or vfx:IsA("Part") then
			-- Disable all particle emitters
			for _, descendant in vfx:GetDescendants() do
				if descendant:IsA("ParticleEmitter") then
					descendant.Enabled = false
				end
			end
		end
	end
end

--[[
	Get the number of active VFX for a character (for debugging)
	@param character Model - The character to check
	@return number - Number of active VFX entries
]]
function VFXCleanup.GetActiveVFXCount(character: Model): number
	if not character or not activeVFX[character] then
		return 0
	end
	return #activeVFX[character]
end

return VFXCleanup

