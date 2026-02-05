--!strict
--[[
	ActionCancellation - Centralized Cleanup System

	Handles all cleanup when states are cancelled:
	- Stop animations (with configurable fade)
	- Destroy velocities/body movers
	- Cleanup VFX (only VFX tagged to the cancelled action)
	- Clear state from ECS and StateManager

	VFX and Velocity Tracking:
	When creating VFX or velocities during an action, register them with this module.
	When the action is cancelled, only the registered VFX/velocities will be cleaned up.

	Usage:
		local ActionCancellation = require(path.to.ActionCancellation)

		-- When creating VFX during an action:
		local vfx = Instance.new("ParticleEmitter")
		ActionCancellation.RegisterVFX(character, vfx, "M1Attack")

		-- When creating velocity during an action:
		local velocity = Instance.new("LinearVelocity")
		ActionCancellation.RegisterVelocity(character, velocity, "Dashing")

		-- When cancelling an action:
		ActionCancellation.Cancel(character, { actionName = "M1Attack" })
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ActionCancellation = {}

-- Type definitions
export type CancellationOptions = {
	stopAnimations: boolean?,
	animationFadeTime: number?,
	destroyVelocities: boolean?,
	cleanupVFX: boolean?,
	actionName: string?,       -- If set, only cleanup tagged to this action
	preserveIFrames: boolean?,
	customCallback: (() -> ())?,
}

-- VFX tracking per character per action
-- character -> { vfx -> actionName }
local VFXTracking: { [Model]: { [Instance]: string } } = {}

-- Velocity tracking per character per action
-- character -> { velocity -> actionName }
local VelocityTracking: { [Model]: { [Instance]: string } } = {}

-- Cleanup connections for destroyed characters
local CleanupConnections: { [Model]: RBXScriptConnection } = {}

-- ============================================
-- REGISTRATION FUNCTIONS
-- ============================================

--[[
	Register a VFX instance with action tagging for targeted cleanup
	@param character Model - The character the VFX belongs to
	@param vfx Instance - The VFX instance (ParticleEmitter, Beam, etc.)
	@param actionName string - The action this VFX belongs to
]]
function ActionCancellation.RegisterVFX(character: Model, vfx: Instance, actionName: string)
	if not VFXTracking[character] then
		VFXTracking[character] = {}
		ActionCancellation.SetupCharacterCleanup(character)
	end

	VFXTracking[character][vfx] = actionName

	-- Auto-remove when VFX is destroyed
	vfx.Destroying:Once(function()
		if VFXTracking[character] then
			VFXTracking[character][vfx] = nil
		end
	end)
end

--[[
	Register a velocity/body mover with action tagging
	@param character Model - The character the velocity belongs to
	@param velocity Instance - The body mover (LinearVelocity, BodyVelocity, etc.)
	@param actionName string - The action this velocity belongs to
]]
function ActionCancellation.RegisterVelocity(character: Model, velocity: Instance, actionName: string)
	if not VelocityTracking[character] then
		VelocityTracking[character] = {}
		ActionCancellation.SetupCharacterCleanup(character)
	end

	VelocityTracking[character][velocity] = actionName

	-- Auto-remove when velocity is destroyed
	velocity.Destroying:Once(function()
		if VelocityTracking[character] then
			VelocityTracking[character][velocity] = nil
		end
	end)
end

--[[
	Setup cleanup for a character (ensures tracking tables are cleaned on death)
	@param character Model - The character to track
]]
function ActionCancellation.SetupCharacterCleanup(character: Model)
	if CleanupConnections[character] then
		return -- Already setup
	end

	CleanupConnections[character] = character.Destroying:Connect(function()
		VFXTracking[character] = nil
		VelocityTracking[character] = nil
		CleanupConnections[character] = nil
	end)
end

-- ============================================
-- CLEANUP FUNCTIONS
-- ============================================

--[[
	Stop all playing animations on a character
	@param character Model - The character
	@param fadeTime number? - Fade out time (default 0.1)
]]
function ActionCancellation.StopAllAnimations(character: Model, fadeTime: number?)
	fadeTime = fadeTime or 0.1

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then return end

	for _, track in animator:GetPlayingAnimationTracks() do
		-- Skip core animations (idle, walk, run)
		local priority = track.Priority
		if priority == Enum.AnimationPriority.Core or priority == Enum.AnimationPriority.Idle then
			continue
		end

		track:Stop(fadeTime)
	end
end

--[[
	Destroy all body movers on a character
	@param character Model - The character
	@param actionName string? - If set, only destroy movers tagged with this action
]]
function ActionCancellation.DestroyVelocities(character: Model, actionName: string?)
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	local trackedVelocities = VelocityTracking[character]

	for _, child in rootPart:GetChildren() do
		if child:IsA("LinearVelocity") or child:IsA("BodyVelocity") or
			child:IsA("BodyPosition") or child:IsA("BodyGyro") or
			child:IsA("AlignPosition") or child:IsA("AlignOrientation") or
			child:IsA("VectorForce") or child:IsA("BodyForce") then

			if actionName then
				-- Only destroy if tagged with this action
				if trackedVelocities and trackedVelocities[child] == actionName then
					child:Destroy()
				end
			else
				-- Destroy all (force cleanup)
				child:Destroy()
			end
		end
	end

	-- Also check torso and other parts for body movers
	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") then
			for _, child in part:GetChildren() do
				if child:IsA("BodyPosition") or child:IsA("BodyGyro") or
					child:IsA("AlignPosition") or child:IsA("AlignOrientation") then

					if actionName then
						if trackedVelocities and trackedVelocities[child] == actionName then
							child:Destroy()
						end
					else
						child:Destroy()
					end
				end
			end
		end
	end

	-- Clear residual velocity (only if destroying all)
	if not actionName and rootPart then
		rootPart.AssemblyLinearVelocity = Vector3.zero
		rootPart.AssemblyAngularVelocity = Vector3.zero
	end
end

--[[
	Cleanup VFX for a character
	@param character Model - The character
	@param actionName string? - If set, only cleanup VFX tagged with this action
]]
function ActionCancellation.CleanupVFX(character: Model, actionName: string?)
	local trackedVFX = VFXTracking[character]
	if not trackedVFX then return end

	local toCleanup = {}

	for vfx, taggedAction in pairs(trackedVFX) do
		if actionName then
			if taggedAction == actionName then
				table.insert(toCleanup, vfx)
			end
		else
			table.insert(toCleanup, vfx)
		end
	end

	for _, vfx in toCleanup do
		if vfx and vfx.Parent then
			-- For particle emitters, stop emission first for cleaner cleanup
			if vfx:IsA("ParticleEmitter") then
				vfx.Enabled = false
				-- Delay destruction to let existing particles fade
				task.delay(vfx.Lifetime.Max, function()
					if vfx and vfx.Parent then
						vfx:Destroy()
					end
				end)
			elseif vfx:IsA("Beam") then
				vfx.Enabled = false
				task.delay(0.2, function()
					if vfx and vfx.Parent then
						vfx:Destroy()
					end
				end)
			else
				vfx:Destroy()
			end
		end

		trackedVFX[vfx] = nil
	end
end

--[[
	Cleanup only VFX for a specific action (convenience wrapper)
	@param character Model - The character
	@param actionName string - The action to cleanup VFX for
]]
function ActionCancellation.CleanupActionVFX(character: Model, actionName: string)
	ActionCancellation.CleanupVFX(character, actionName)
end

--[[
	Cleanup only velocities for a specific action (convenience wrapper)
	@param character Model - The character
	@param actionName string - The action to cleanup velocities for
]]
function ActionCancellation.CleanupActionVelocities(character: Model, actionName: string)
	ActionCancellation.DestroyVelocities(character, actionName)
end

-- ============================================
-- MAIN CANCELLATION FUNCTION
-- ============================================

--[[
	Cancel and cleanup for a character
	@param character Model - The character
	@param options CancellationOptions? - Cleanup options
]]
function ActionCancellation.Cancel(character: Model, options: CancellationOptions?)
	options = options or {}

	-- Default options
	local stopAnimations = options.stopAnimations ~= false -- default true
	local animationFadeTime = options.animationFadeTime or 0.1
	local destroyVelocities = options.destroyVelocities ~= false -- default true
	local cleanupVFX = options.cleanupVFX ~= false -- default true
	local actionName = options.actionName

	-- Stop animations
	if stopAnimations then
		ActionCancellation.StopAllAnimations(character, animationFadeTime)
	end

	-- Destroy velocities
	if destroyVelocities then
		ActionCancellation.DestroyVelocities(character, actionName)
	end

	-- Cleanup VFX
	if cleanupVFX then
		ActionCancellation.CleanupVFX(character, actionName)
	end

	-- Call custom callback
	if options.customCallback then
		options.customCallback()
	end
end

-- ============================================
-- ECS ENTITY VERSIONS
-- ============================================

-- ECS imports (lazy loaded to avoid circular dependency)
local world = nil
local comps = nil
local RefManager = nil

local function ensureECS()
	if not world then
		world = require(ReplicatedStorage.Modules.ECS.jecs_world)
		comps = require(ReplicatedStorage.Modules.ECS.jecs_components)
		RefManager = require(ReplicatedStorage.Modules.ECS.jecs_ref_manager)
	end
end

--[[
	Get character model from ECS entity
	@param entity number - The ECS entity
	@return Model? - The character model or nil
]]
local function getCharacterFromEntity(entity: number): Model?
	ensureECS()

	local character = world:get(entity, comps.Character)
	return character
end

--[[
	Cancel and cleanup for an ECS entity
	@param entity number - The ECS entity
	@param options CancellationOptions? - Cleanup options
]]
function ActionCancellation.CancelECS(entity: number, options: CancellationOptions?)
	local character = getCharacterFromEntity(entity)
	if character then
		ActionCancellation.Cancel(character, options)
	end
end

--[[
	Register VFX for an ECS entity
	@param entity number - The ECS entity
	@param vfx Instance - The VFX instance
	@param actionName string - The action this VFX belongs to
]]
function ActionCancellation.RegisterVFXECS(entity: number, vfx: Instance, actionName: string)
	local character = getCharacterFromEntity(entity)
	if character then
		ActionCancellation.RegisterVFX(character, vfx, actionName)
	end
end

--[[
	Register velocity for an ECS entity
	@param entity number - The ECS entity
	@param velocity Instance - The body mover
	@param actionName string - The action this velocity belongs to
]]
function ActionCancellation.RegisterVelocityECS(entity: number, velocity: Instance, actionName: string)
	local character = getCharacterFromEntity(entity)
	if character then
		ActionCancellation.RegisterVelocity(character, velocity, actionName)
	end
end

-- ============================================
-- INITIALIZATION
-- ============================================

-- Register with UnifiedStateController
task.defer(function()
	local success, UnifiedStateController = pcall(function()
		return require(script.Parent.UnifiedStateController)
	end)

	if success and UnifiedStateController then
		UnifiedStateController.SetActionCancellation(ActionCancellation)
	end
end)

return ActionCancellation
