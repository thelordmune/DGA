local Replicated = game:GetService("ReplicatedStorage")
local Utilities = require(Replicated.Modules.Utilities)
local Debris = Utilities.Debris
local Actors = require(Replicated.Modules.Actor.Actors)
local Visuals = require(Replicated.Visuals)
local module = {}

module.Information = {}

module.BufferFunction = function(FuncName: string,...)
	local Args = {...}
	if module[FuncName] then
		module[FuncName](table.unpack(Args))
	end
end


module.M1Check = function(MetaTable,Action,Anim,Sound,Start,AttackDelay)
	Actors.AddToTempLoop(function()
		if MetaTable and MetaTable["StunCheck"] and MetaTable:StunCheck() then
			MetaTable.Cancels["M1"] = true
			task.synchronize()
			if Action then Action:Destroy() end
			if Anim then Anim:Stop() end
			if Sound then Sound:Destroy() end

			task.desynchronize()
			
			return true
		end
		print("M1")
		if tick() - Start > (AttackDelay - .055) then
			return true
		end 
	end)
end

module.M2Check = function(MetaTable,Action,Anim,Sound,Start,AttackDelay,Sound2)
	Actors.AddToTempLoop(function()
		if MetaTable and MetaTable["StunCheck"] and MetaTable:StunCheck() then
			MetaTable.Cancels["M2"] = true
			task.synchronize()
			if Action then Action:Destroy() end
			if Anim then Anim:Stop() end
			if Sound then Sound:Destroy() end
			if Sound2 then Sound2:Destroy() end

			task.desynchronize()

			return true
		end
		print("M2")
		if tick() - Start > (AttackDelay - .055) then
			return true
		end 
	end)
end

module.Thrust = function(MetaTable,Action,Anim,Sound,Start,AttackDelay)
	Actors.AddToTempLoop(function()
		if MetaTable and MetaTable["StunCheck"] and MetaTable:StunCheck() then
			MetaTable.Cancels["Thrust"] = true
			task.synchronize()
			if Action then Action:Destroy() end
			if Anim then Anim:Stop() end
			if Sound then Sound:Destroy() end

			task.desynchronize()

			return true
		end
		print("Thrust")
		if tick() - Start > (AttackDelay) then
			return true
		end 
	end)
end

module.StunCheck = function(Type,MetaTable,Action,Anim,Sound)
	Actors.AddToTempLoop(function()
		if MetaTable and MetaTable["StunCheck"] and MetaTable:StunCheck() then
			MetaTable.Cancels[Type] = true
			task.synchronize()
			if Action then Action:Destroy() end
			if Anim then Anim:Stop() end
			if Sound then Sound:Destroy() end
			
			task.desynchronize()
		end
		
		print(MetaTable.Cancels[Type])
		
		return MetaTable.Cancels[Type]
	end)
end

module.ForwardVelocity = function(Character,Velocity, Speed)
	Actors.AddToTempLoop(function()
		if not Velocity or not Character or not Character:FindFirstChild("HumanoidRootPart") then return true end
		
		task.synchronize()
		
		Velocity.Velocity = Character.HumanoidRootPart.CFrame.LookVector *  Speed
		
		task.desynchronize()
	end)
end

module.SmoothVelocity = function(Character, Velocity, Speed,LengthOfVelocity)
	local function sine(x)
		return math.cos((x * math.pi) / 2)
	end
	local waited = 0
	
	local speedBack
	Actors.AddToTempLoop(function()
		if not Velocity or not Character then return true end

		task.synchronize()
		
		waited += task.wait()
		speedBack = math.max(sine(waited / LengthOfVelocity), 0.09) * -Speed
		Velocity.Velocity = Character.HumanoidRootPart.CFrame.LookVector * speedBack

		task.desynchronize()
	end)
end

module.Knockback = function(Character, Velocity, LOV, MS, SB, OG)
	local function sine(x)
		return math.cos((x * math.pi) / 2)
	end
	
	local waited = 0

	Actors.AddToTempLoop(function()
		if not Velocity then
			task.synchronize()
			
			Visuals.Ranged(Character.HumanoidRootPart.Position,300,{Module = "Misc",Function = "HyperArmor",Arguments = {Character,.35}})

			local HyperArmor = Instance.new("BinaryStringValue")
			HyperArmor.Name = "HyperArmor"
			HyperArmor.Parent = Character.States.Status
			Debris:AddItem(HyperArmor,0.5)

			local Knockback = Instance.new("BinaryStringValue")
			Knockback.Name = "Knockback"
			Knockback.Parent = Character.States.Status
			Debris:AddItem(Knockback,0.5)
			
			task.desynchronize()
			return true 
		end
		
		if not Character then return true end
		
		
		waited += task.wait()
		SB = math.max(sine(waited / LOV), 0.09) * -MS
		
		task.synchronize()
		Velocity.Velocity = OG * SB
		
		task.desynchronize()

		
	end)
end

module.Projectile = function(Character: Model,Part ,Speed)
	Actors.AddToTempLoop(function(Delta)
		
		if not Part or not Character or Speed < 0 then return true end
		
		Speed -= Delta
		
		local Increment = Speed * (Delta * 60)
		
		task.synchronize()
		
		Part.CFrame = Part.CFrame * CFrame.new(0,0,-Increment)
		
		task.desynchronize()
	end)
end

return module
