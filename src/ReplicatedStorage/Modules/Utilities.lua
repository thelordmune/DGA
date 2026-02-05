local module = {}
module.__index = module
local self = setmetatable({}, module)

module.Debris = {};

--// Server Utilities \\--

local Players = game:GetService("Players")
local Replicated = game:GetService("ReplicatedStorage")
local Storage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local CoreGameCallbacks = {}
local TempCallbacks = {}

local RNG = Random.new(1337)

local Items = {}
local Types = {
	["Instance"] = "Destroy",
	["Table"] = "Remove",
	["RBXScriptConnection"] = "Disconnect",
}

function LinearInterpolate(a, b, t)
	return a + (b - a) * t
end

local function deepCopy(t)
	local copy = {}
	for i, v in t do
		if type(v) == "table" then
			copy[i] = deepCopy(v)
			setmetatable(copy[i], getmetatable(v))
		else
			copy[i] = v
		end
	end
	return copy
end

local function MoreAccurateWait(Value)
	Value = Value or 1/60
	local Start = os.clock()
	while os.clock() - Start < Value do
		RunService.Stepped:Wait()
	end
end

local function RemoveItem(Part)
	local Info = Items[Part]

	if Info[4] == "Instance" then		
		if Info[5] then
			local Tween = TweenService:Create(Part, Info[5].Tweeninfo, Info[5].Goals)
			Tween:Play()
			coroutine.resume(coroutine.create(function()
				MoreAccurateWait(Info[5].Duration)
				Part:Destroy()
			end))
		else
			Part:Destroy()
		end
	elseif Info[4] == "RBXScriptConnection" then
		Info[1]:Disconnect()
	else
		table.clear(Part[1])
	end

	Items[Part] = nil
end

local function AddItem(Part, Lifetime,Info) --  Info is like this {Duration = 1, Tweeninfo = TweenInfo.new(Duration,EasingStyle, EasingDirecton), Goals = {CFrame = CFrame.new(0,-5,0)}
	local Type = typeof(Part) --                                                 Case sensitive

	assert(Types[Type])
	assert(typeof(Lifetime) == "number")
	Info = Info or false
	Items[Part] = {Part, Lifetime, os.clock(), Type, Info}
end

(if RunService:IsServer() then RunService.Heartbeat else RunService.RenderStepped):Connect(function(Delta)
	for _, Callback in pairs(CoreGameCallbacks) do
		Callback(Delta)
	end

	local CallbackValue
	for _, CallbackData in pairs(TempCallbacks) do
		CallbackValue = CallbackData.Callback(Delta)

		if CallbackData.Warning ~= nil then
			if not CallbackData.Warning and os.clock() - CallbackData.Init > 60 then
				CallbackData.Warning = true
				warn("Temp Callback Not Disconnected", CallbackData.Trace)
			end
		end

		if CallbackValue then
			table.remove(TempCallbacks, table.find(TempCallbacks, CallbackData))
		end
	end
	
	for Inst, Info in Items do
		if os.clock() - (Info[3] + Info[2]) > 0 then RemoveItem(Inst) end;
	end
end)

function module:AddToCoreLoop(Callback)
	table.insert(CoreGameCallbacks, Callback)
end

function module:AddToTempLoop(callback , Warn: boolean)
	local DoWarn = false
	if Warn then DoWarn = true end;
	local Info

	if DoWarn then
		Info = {
			Callback = callback;
			Init = os.clock();
			Warning = false;
			Trace = debug.traceback()
		}
	else
		Info = {Callback = callback}
	end
	table.insert(TempCallbacks, Info)
end

function module:UnixConnection(Duration, MainCallback: (Alpha: number, Delta: number, InverseAlpha: number, CurrentDuration: number) -> (), Conditional, EndingCallback : (Alpha: number, Delta: number, InverseAlpha: number) -> ())
	local Disconnect = false
	local TimeOut = false
	local Start = os.clock()

	module:AddToTempLoop(function(Delta)
		TimeOut = not (Start + Duration > os.clock())

		if MainCallback and (Conditional and Conditional() or Conditional == nil) and not TimeOut then
			local Alpha = (os.clock() - Start) / Duration
			local InverseAlpha = LinearInterpolate(1, 0, Alpha)
			MainCallback(Alpha, Delta, InverseAlpha, (os.clock() - Start))
		elseif not Disconnect then
			Disconnect = true
			if MainCallback and TimeOut then
				MainCallback(1, Delta, 0, Duration)
			end

			if EndingCallback then
				EndingCallback(1, Delta, 0)
			end
			return true
		end

	end)
end

function module:UnixWithFrequency(Duration, Frequency, StartCallback, FinishedCallback)
	local StartOS = os.clock()
	local Event = if RunService:IsServer() then RunService.Heartbeat else RunService.RenderStepped
	local LastCallback = StartOS

	local Connection 
	Connection = Event:Connect(function(Delta)
		local Delta = os.clock() - LastCallback
		if Delta > Frequency then
			LastCallback = os.clock()
			StartCallback((os.clock() - StartOS) / Duration, Delta)
		end

		if Connection and os.clock() - StartOS > Duration then
			Connection:Disconnect()
			Connection = nil

			if FinishedCallback then
				FinishedCallback(1, Delta)
			end
		end
	end)

end

function module:BindWithSpacing(CallBack, Frequency, Duration, FinishedCallBack)
	local StartOS = os.clock()
	local LastCallback = StartOS
	local NeedsToDisconnect = false

	local Connection
	module:AddToTempLoop(function()
		local Delta = os.clock() - LastCallback
		if Delta > Frequency then
			LastCallback = os.clock() + Frequency
			local Alpha = (os.clock() - StartOS) / Duration
			local InverseAlpha = LinearInterpolate(1, 0, Alpha)

			CallBack((os.clock() - StartOS)/Duration, Delta, InverseAlpha, (os.clock() - StartOS))
		end


		if not NeedsToDisconnect and os.clock() - StartOS > Duration then
			NeedsToDisconnect = true
			if FinishedCallBack then
				FinishedCallBack(
					(os.clock() - StartOS)/Duration,
					Delta
				)
			end

			return true
		end
	end)
end



function module:ConvertNormalPosToCF(Normal, Pos) 
	local RightVector = (CFrame.lookAt(Pos, Pos + Normal)).UpVector
	local LookVector = RightVector:Cross(Normal)
	return CFrame.fromMatrix(
		Pos,
		-LookVector,
		Normal,
		RightVector
	)
end

function module:DisableAllVisuals(Container : Instance)
	for _, Desc : Instance in ipairs(Container:GetDescendants()) do
		if Desc:IsA("ParticleEmitter") or Desc:IsA("Beam") or Desc:IsA("Trail") or Desc:IsA("PointLight") then
			Desc.Enabled = false
		end
	end
end

function module:EnabledAllVisuals(Container : Instance)
	for _, Desc : Instance in pairs(Container:GetDescendants()) do
		if Desc:IsA("ParticleEmitter") or Desc:IsA("Beam") or Desc:IsA("Trail") or Desc:IsA("PointLight") then
			Desc.Enabled = true
		end
	end
end

function module:EmitAllParticles(Container : BasePart) 
	for _, Desc in ipairs(Container:GetDescendants()) do
		if Desc:IsA("ParticleEmitter") then
			Desc:Emit(Desc.Rate)
		end
	end
end

function module:EmitParticlesAlt(Container : BasePart?)
	for _, Particle : ParticleEmitter in pairs(Container:GetDescendants()) do
		if Particle:IsA("ParticleEmitter") then
			Particle:Emit(Particle:GetAttribute("EmitCount"), Particle:GetAttribute("EmitDelay"))
		end
	end
end

function module:ScaleParticles(ParticlesContainer, Scale) 
	for _, Desc in pairs(ParticlesContainer:GetDescendants()) do 
		if Desc:IsA("ParticleEmitter") then 
			local ScaledSize = {}

			for KeypointNumber = 1, #Desc.Size.Keypoints do 
				table.insert(ScaledSize, NumberSequenceKeypoint.new(Desc.Size.Keypoints[KeypointNumber].Time, Desc.Size.Keypoints[KeypointNumber].Value*Scale, Desc.Size.Keypoints[KeypointNumber].Envelope))
			end

			Desc.Speed = NumberRange.new(Desc.Speed.Min*Scale, Desc.Speed.Max*Scale)
			Desc.Acceleration *= Scale
			Desc.Size = NumberSequence.new(ScaledSize)

			table.clear(ScaledSize)
		end
	end
end

function module:ReturnRandomAngle()
	return CFrame.Angles(RNG:NextNumber(-360, 360), RNG:NextNumber(-360, 360), RNG:NextNumber(-360, 360))
end

function module:DeepCopy(t)
	return deepCopy(t)
end


function module.Debris:AddItem(Part, Lifetime, Info)
	AddItem(Part, Lifetime, Info)
end

function module.Debris:AddItems(Parts, Lifetimes, Info)

	for i, Item in ipairs(Parts) do
		AddItem(Item, Lifetimes[i], Info)
	end

end

function module.Debris:CancelItem(Item)
	if Items[Item] then
		Items[Item] = nil
	end
end

function module.Debris:GetAllDebris()
	return Items
end

function module.Debris:GetDebris(Item)
	return Items[Item]
end

return module
