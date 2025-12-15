--[[
    Example: Stone Lance with Hold System
    
    This shows how to integrate the WeaponSkillHold system with your existing Stone Lance skill.
    
    IMPORTANT: This is just an example. You'll need to adapt this to your actual input system.
]]

local ServerStorage = game:GetService("ServerStorage")
local Replicated = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

-- Import the hold system
local SkillFactory = require(Replicated.Modules.Utils.SkillFactory)

local Server = require(script.Parent.Parent)
local Utilities = require(Replicated.Modules.Utilities)
local Library = require(Replicated.Modules.Library)
local Packets = require(Replicated.Modules.Packets)
local Visuals = require(Replicated.Modules.Visuals)
local WeaponStats = require(ServerStorage.Stats._Weapons)
local MoveStats = require(ServerStorage.Stats._Moves)
local Ragdoll = require(Replicated.Modules.Utils.Ragdoll)

-- Create the Stone Lance skill with hold system
local StoneLance = SkillFactory.CreateWeaponSkill({
    name = "Stone Lance",
    animation = Replicated.Assets.Animations.Misc.Alchemy,
    hasBodyMovers = false, -- No body movers, can be held
    damage = 50,
    cooldown = 8,
    
    execute = function(self, player, character, holdDuration)
        ---- print(`[Stone Lance] Executed after {holdDuration}s hold`)
        
        -- Check if character is valid
        if not character or not character.Parent then
            return
        end
        
        -- Check states
        if Server.Library.StateCount(character.Actions) or Server.Library.StateCount(character.Stuns) then
            return
        end
        
        -- Stop all animations (already handled by hold system, but keep for safety)
        Server.Library.StopAllAnims(character)
        
        -- Set action state
        local animLength = self.animation.Length or 2.4
        Server.Library.TimedState(character.Actions, self.skillName, animLength)
        Server.Library.TimedState(character.Speeds, "AlcSpeed-0", animLength)
        
        -- Get move data
        local moveData = MoveStats[self.skillName]
        local hittimes = {}
        
        if moveData and moveData.DamageTable and moveData.DamageTable.Hittimes then
            for i, fraction in ipairs(moveData.DamageTable.Hittimes) do
                hittimes[i] = fraction * animLength
            end
        else
            hittimes = {(17/72) * animLength, (46/72) * animLength}
        end
        
        -- First hittime: Clap effect
        task.delay(hittimes[1], function()
            local s = Replicated.Assets.SFX.FMAB.Clap:Clone()
            s.Parent = character.HumanoidRootPart
            s:Play()
            Debris:AddItem(s, s.TimeLength)
            
            Server.Visuals.Ranged(character.HumanoidRootPart.Position, 300, {
                Module = "Base",
                Function = "Clap",
                Arguments = { character },
            })
        end)
        
        -- Second hittime: Stone Lance spawn
        task.delay(hittimes[2], function()
            local root = character.HumanoidRootPart
            if not root then return end
            
            local detectionRange = 30
            
            -- Optional: Increase range based on hold duration
            if holdDuration > 0.5 then
                detectionRange = detectionRange + (holdDuration * 5) -- +5 studs per second
                ---- print(`⚡ Charged range: {detectionRange} studs`)
            end
            
            local hasValidTarget = false
            local nearestTarget = nil
            local nearestDistance = math.huge
            
            -- Find nearest target
            for _, entity in pairs(workspace.World.Live:GetDescendants()) do
                if entity:IsA("Model") and entity ~= character and entity:FindFirstChild("Humanoid") and entity:FindFirstChild("HumanoidRootPart") then
                    local targetRoot = entity.HumanoidRootPart
                    local distance = (targetRoot.Position - root.Position).Magnitude
                    
                    if distance <= detectionRange and distance < nearestDistance then
                        hasValidTarget = true
                        nearestTarget = entity
                        nearestDistance = distance
                    end
                end
            end
            
            if not hasValidTarget or not nearestTarget then
                return
            end
            
            local targetRoot = nearestTarget.HumanoidRootPart
            local spawnPos = Vector3.new(targetRoot.Position.X, root.Position.Y, targetRoot.Position.Z)
            
            -- Transmutation circle
            Server.Visuals.Ranged(character.HumanoidRootPart.Position, 300, {
                Module = "Base",
                Function = "TransmutationCircle",
                Arguments = { character, CFrame.new(spawnPos) * CFrame.new(0, -2, 0) },
            })
            
            task.delay(0.3, function()
                local sl = Replicated.Assets.VFX.SL:Clone()
                
                -- Optional: Scale size based on hold duration
                local sizeMultiplier = 1
                if holdDuration > 0.5 then
                    sizeMultiplier = 1 + (holdDuration * 0.2) -- +20% per second
                    sl.Size = sl.Size * sizeMultiplier
                    ---- print(`⚡ Charged size: {sizeMultiplier}x`)
                end
                
                local wedgeHeight = sl.Size.Y
                local startPos = CFrame.new(spawnPos) * CFrame.new(0, -wedgeHeight - 2, 0)
                local endPos = CFrame.new(spawnPos) * CFrame.new(0, 4, 0)
                
                sl.CFrame = startPos
                sl.Anchored = true
                sl.CanCollide = false
                sl.Parent = workspace.World.Visuals
                
                -- Tween up
                local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Circular, Enum.EasingDirection.InOut)
                local tween = TweenService:Create(sl, tweenInfo, { CFrame = endPos })
                tween:Play()
                
                -- VFX
                task.delay(0.15, function()
                    local vfx = Replicated.Assets.VFX.WallVFX:Clone()
                    for _, v in vfx:GetChildren() do
                        if v:IsA("ParticleEmitter") then
                            v.Parent = sl
                        end
                    end
                    
                    task.delay(.15, function()
                        for _, v in sl:GetChildren() do
                            if v:IsA("ParticleEmitter") then
                                v:Emit(v:GetAttribute("EmitCount"))
                            end
                        end
                    end)
                end)
                
                -- Hitbox
                task.delay(0.25, function()
                    local Hitbox = Server.Modules.Hitbox
                    local hitboxSize = sl.Size
                    local hitboxCFrame = sl.CFrame * CFrame.new(0, wedgeHeight/2, 0)
                    
                    local HitTargets = Hitbox.SpatialQuery(character, hitboxSize, hitboxCFrame, false)
                    
                    for _, Target in pairs(HitTargets) do
                        if Target ~= character and Target:IsA("Model") and Target:FindFirstChild("Humanoid") then
                            ---- print("Stone Lance hit:", Target.Name)
                            
                            -- Apply damage (with hold bonus)
                            if moveData and moveData.DamageTable then
                                local damageTable = moveData.DamageTable
                                
                                -- Optional: Increase damage based on hold duration
                                if holdDuration > 0.5 then
                                    local damageMultiplier = 1 + (holdDuration * 0.2) -- +20% per second
                                    damageTable = table.clone(damageTable)
                                    damageTable.Damage = (damageTable.Damage or 50) * damageMultiplier
                                    ---- print(`⚡ Charged damage: {damageTable.Damage}`)
                                end
                                
                                Server.Modules.Damage.Tag(character, Target, damageTable)
                            end
                            
                            -- Launch target
                            local hitTargetRoot = Target:FindFirstChild("HumanoidRootPart")
                            if hitTargetRoot then
                                local direction = (hitTargetRoot.Position - root.Position).Unit
                                local horizontalPower = 10
                                local upwardPower = 30
                                
                                -- Optional: Increase launch power based on hold duration
                                if holdDuration > 0.5 then
                                    upwardPower = upwardPower + (holdDuration * 10)
                                    ---- print(`⚡ Charged launch: {upwardPower} upward power`)
                                end
                                
                                local velocity = Vector3.new(
                                    direction.X * horizontalPower,
                                    upwardPower,
                                    direction.Z * horizontalPower
                                )
                                
                                local targetHumanoid = Target:FindFirstChild("Humanoid")
                                if targetHumanoid then
                                    targetHumanoid.PlatformStand = true
                                end
                                
                                -- Apply velocity (player vs NPC)
                                local targetPlayer = game.Players:GetPlayerFromCharacter(Target)
                                
                                if targetPlayer then
                                    Packets.Bvel.sendTo({
                                        Character = Target,
                                        Name = "StoneLaunchVelocity",
                                        Targ = Target,
                                        Velocity = velocity
                                    }, targetPlayer)
                                else
                                    -- NPC velocity (server-side)
                                    local attachment = hitTargetRoot:FindFirstChild("StoneLanceAttachment")
                                    if not attachment then
                                        attachment = Instance.new("Attachment")
                                        attachment.Name = "StoneLanceAttachment"
                                        attachment.Parent = hitTargetRoot
                                    end
                                    
                                    local oldLV = hitTargetRoot:FindFirstChild("StoneLaunchVelocity")
                                    if oldLV then oldLV:Destroy() end
                                    
                                    local lv = Instance.new("LinearVelocity")
                                    lv.Name = "StoneLaunchVelocity"
                                    lv.MaxForce = math.huge
                                    lv.VectorVelocity = velocity
                                    lv.Attachment0 = attachment
                                    lv.RelativeTo = Enum.ActuatorRelativeTo.World
                                    lv.Parent = hitTargetRoot
                                    
                                    Packets.Bvel.sendToAll({
                                        Character = Target,
                                        Name = "StoneLaunchVelocity",
                                        Targ = Target,
                                        Velocity = velocity
                                    })
                                    
                                    task.delay(0.8, function()
                                        if lv and lv.Parent then lv:Destroy() end
                                    end)
                                end
                                
                                -- Ragdoll
                                Ragdoll.Ragdoll(Target, 2.5)
                                
                                task.delay(0.8, function()
                                    if targetHumanoid then
                                        targetHumanoid.PlatformStand = false
                                    end
                                end)
                            end
                        end
                    end
                end)
                
                -- Shatter effect after 2.5 seconds
                task.delay(2.5, function()
                    if sl and sl.Parent then
                        -- Your existing shatter code...
                        sl:Destroy()
                    end
                end)
            end)
        end)
    end
})

-- Export the skill
return StoneLance

--[[
    INTEGRATION NOTES:
    
    1. In your input handler (e.g., ZMove.lua), you would do:
    
        local StoneLance = require(path.to.StoneLance)
        
        InputModule.InputBegan = function(_, Client)
            StoneLance:OnInputBegan(Client.Player, Client.Character)
        end
        
        InputModule.InputEnded = function(_, Client)
            StoneLance:OnInputEnded(Client.Player)
        end
    
    2. The skill will:
        - Play 0.1s of animation and freeze when key is pressed
        - Show blue glow/particles while holding
        - Execute full skill when key is released
        - Apply bonuses based on hold duration:
            * Range: +5 studs per second
            * Size: +20% per second
            * Damage: +20% per second
            * Launch power: +10 upward per second
    
    3. For alchemy skills, just set skillType = "alchemy" and they'll execute immediately
]]

