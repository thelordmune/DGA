local Server = require(script.Parent);
local Replicated = game:GetService("ReplicatedStorage")
local start = require(Replicated.Modules.ECS.jecs_start)
local RefManager = require(Replicated.Modules.ECS.jecs_ref_manager)
local ref = RefManager.player -- Use player-specific ref system
-- local util = Replicated.Modules:WaitForChild("Utilities")



export type EntityObject = {
    Player	  : Player?;
    Character : Model;

    Weapon    : string?;
    
    Signals   : {};
    Snapshots : {};

    GetCFrame : () -> (CFrame);
}

local Appearance = require(script:WaitForChild("Appearance"))
local InventorySetup = require(Replicated.Modules.Utils.InventorySetup)

local EntityClass = {};
EntityClass.__index = EntityClass;

local systemsStarted = false

EntityClass.Get = function(Entity) : EntityObject
     -- print("Getting entity:", Entity.Name)
    if Server.Entities[Entity] then
         -- print("Entity found:", Entity.Name)
        return Server.Entities[Entity]
    end
     -- print("Entity not found:", Entity.Name)
end

EntityClass.Remove = function(Entity)
     -- print("Attempting to remove entity:", Entity.Name)
    if Server.Entities[Entity] then
        -- COMPREHENSIVE CLEANUP BEFORE REMOVAL
         -- print("=== CLEANING UP ENTITY ON DEATH ===")
         -- print("Entity:", Entity.Name)

        -- Clean up equip state before removing entity (prevents stuck states on respawn)
        if Server.Modules.Network and Server.Modules.Network.Equip then
            Server.Modules.Network.Equip.CleanupCharacterEquipState(Entity)
        end

        -- Clean up all character data (animations, cooldowns, etc.)
        if Server.Library and Server.Library.CleanupCharacter then
            Server.Library.CleanupCharacter(Entity)
             -- print("Cleaned up character data for:", Entity.Name)
        end

        -- Stop any playing animations
        if Entity:FindFirstChild("Humanoid") and Entity.Humanoid:FindFirstChild("Animator") then
            for _, track in pairs(Entity.Humanoid.Animator:GetPlayingAnimationTracks()) do
                track:Stop(0)
                track:Destroy()
            end
             -- print("Stopped all animations for:", Entity.Name)
        end

        setmetatable(Server.Entities[Entity], nil);
        Server.Entities[Entity] = nil;
        warn(("Removed: %s"):format(Entity.Name));

        local Player = Server.Service.Players:GetPlayerFromCharacter(Entity);
        if Player then
             -- print("Player found for respawn:", Player.Name)
            task.wait(Server.Service.Players.RespawnTime)
            if Player and Player:IsDescendantOf(Server.Service.Players) then
                 -- print("Respawning player:", Player.Name)
                Server.Service.RunService.Heartbeat:Wait();
                Player:LoadCharacter();
            end
        else
             -- print("No player found for entity:", Entity.Name)
        end
    else
         -- print("Entity not in Server.Entities:", Entity.Name)
    end
end

EntityClass.Init = function(Entity) : EntityObject
     -- print("Initializing entity:", Entity.Name)
    if Server.Entities[Entity] then 
         -- print("Entity already exists, returning existing:", Entity.Name)
        return Server.Entities[Entity] 
    end
    
    local self = setmetatable({}, EntityClass)
    self.Character = Entity;

    local Player = Server.Service.Players:GetPlayerFromCharacter(Entity);
    if Player then
		game.CollectionService:AddTag(self.Character, "Players")
         -- print("Player entity detected:", Player.Name, "Weapon:", Player:GetAttribute("Weapon"))
        self.Player = Player;
        self.Weapon = Player:GetAttribute("Weapon");
        self.Snapshots = {};
        -- Weapon skills will be given AFTER inventory is cleared (see below in LoadWeapon)
    else
         -- print("NPC entity detected:", Entity.Name, "Weapon:", Entity:GetAttribute("Weapon"))
        self.Weapon = Entity:GetAttribute("Weapon")
        -- Ensure NPC has the IsNPC attribute for damage system
        if not Entity:GetAttribute("IsNPC") then
            Entity:SetAttribute("IsNPC", true)
             -- print("Set IsNPC attribute for:", Entity.Name)
        end
    end;

    self:Initialize();

    warn(("Added: %s"):format(Entity.Name))

    -- Only start systems once
    if not systemsStarted then
         -- print("Starting ECS systems for the first time")
        start(game:GetService("ServerScriptService").Systems)
        systemsStarted = true
    else
         -- print("ECS systems already started")
    end

    Server.Entities[Entity] = self;
     -- print("Entity successfully added to Server.Entities:", Entity.Name)
    return self    
end

function EntityClass:Initialize()
     -- print("Initializing character:", self.Character.Name)
    
    self.Character.PrimaryPart = self.Character:WaitForChild("HumanoidRootPart");
    self.Character.PrimaryPart:AddTag("Roots");
     -- print("Set PrimaryPart and added Roots tag for:", self.Character.Name)
    
    for _, v in next, self.Character:GetChildren() do
        if v and (v:IsA("BasePart") or v:IsA("MeshPart")) then
            v.CollisionGroup = "Players";
        end
    end
     -- print("Set collision groups for:", self.Character.Name)
    
    for _, Frame in next, Server.Service.ServerStorage.Frames:GetChildren() do
        local Inst = Frame:Clone();
        if Frame:IsA("StringValue") then Inst.Value = "[]" end
        Inst.Parent = self.Character;
        
        if Frame.Name == "Posture" then
            Frame:AddTag("PostureInstances");
        end
    end
     -- print("Cloned frames for:", self.Character.Name)
    
    -- Only set parent if not already in workspace.World.Live
    if not self.Character:IsDescendantOf(workspace.World.Live) then
         -- print("Moving character to workspace.World.Live:", self.Character.Name)
        self.Character.Parent = workspace.World.Live
    else
         -- print("Character already in workspace.World.Live:", self.Character.Name)
    end
    
    if self.Player then
         -- print("Loading appearance for player:", self.Player.Name)
        task.spawn(Appearance.Load, self.Player)

        -- Initialize dodge charges for players
        self.Character:SetAttribute("DodgeCharges", 2)
         -- print("Initialized dodge charges for:", self.Player.Name)

        -- Initialize equipped state for players
        self.Character:SetAttribute("Equipped", false)
         -- print("Initialized equipped state for:", self.Player.Name)

        -- COMPREHENSIVE SERVER-SIDE CLEANUP AND REINITIALIZATION
         -- print("=== SERVER-SIDE CHARACTER REINITIALIZATION ===")
         -- print("Player:", self.Player.Name)

        -- Clear any stuck cooldowns and states from previous character
        if Server.Library then
            if Server.Library.CleanupCharacter then
                Server.Library.CleanupCharacter(self.Character)
            end
            if Server.Library.ResetCooldown then
                Server.Library.ResetCooldown(self.Character, "Dodge")
                Server.Library.ResetCooldown(self.Character, "DodgeCancel")
                Server.Library.ResetCooldown(self.Character, "Feint")
                Server.Library.ResetCooldown(self.Character, "Equip")
                 -- print("Reset all cooldowns for:", self.Player.Name)
            end
        end

        -- Ensure all character frames are properly initialized
        task.wait(0.1) -- Wait for frames to be cloned
        if self.Character:FindFirstChild("Actions") then
            self.Character.Actions.Value = "[]"
             -- print("Initialized Actions frame")
        end
        if self.Character:FindFirstChild("Stuns") then
            self.Character.Stuns.Value = "[]"
             -- print("Initialized Stuns frame")
        end
        if self.Character:FindFirstChild("Speeds") then
            self.Character.Speeds.Value = "[]"
             -- print("Initialized Speeds frame")
        end
        if self.Character:FindFirstChild("Status") then
            self.Character.Status.Value = "[]"
             -- print("Initialized Status frame")
        end

        -- Inventory and weapon skills are now handled in playerloader.luau
        -- This ensures components are initialized before skills are added
    else
        -- NPC initialization
         -- print("Initializing NPC frames for:", self.Character.Name)

        -- Ensure all character frames are properly initialized for NPCs
        task.wait(0.1) -- Wait for frames to be cloned
        if self.Character:FindFirstChild("Actions") then
            self.Character.Actions.Value = "[]"
             -- print("Initialized Actions frame for NPC")
        end
        if self.Character:FindFirstChild("Stuns") then
            self.Character.Stuns.Value = "[]"
             -- print("Initialized Stuns frame for NPC")
        end
        if self.Character:FindFirstChild("Speeds") then
            self.Character.Speeds.Value = "[]"
             -- print("Initialized Speeds frame for NPC")
        end
        if self.Character:FindFirstChild("Status") then
            self.Character.Status.Value = "[]"
             -- print("Initialized Status frame for NPC")
        end
        if self.Character:FindFirstChild("IFrames") then
            self.Character.IFrames.Value = "[]"
             -- print("Initialized IFrames frame for NPC")
        end
        if self.Character:FindFirstChild("Frames") then
            self.Character.Frames.Value = "[]"
             -- print("Initialized Frames frame for NPC")
        end

         -- print("Finished initializing NPC frames for:", self.Character.Name)
    end

    self:LoadWeapon(self.Character)

    local function RemoveOnDeath()
        warn(`[ENTITY REMOVAL] Humanoid died for {self.Character.Name}! Removing entity...`)
        self.Remove(self.Character)
    end

    -- Only remove entity when PrimaryPart becomes nil (character being destroyed)
    -- Don't remove on any PrimaryPart change (which can happen during ragdoll)
    local primaryPartConnection
    primaryPartConnection = self.Character:GetPropertyChangedSignal("PrimaryPart"):Connect(function()
        if not self.Character.PrimaryPart then
            warn(`[ENTITY REMOVAL] PrimaryPart is nil for {self.Character.Name}! Character being destroyed, removing entity...`)
            if primaryPartConnection then
                primaryPartConnection:Disconnect()
            end
            self.Remove(self.Character)
        else
             -- print(`[ENTITY] PrimaryPart changed for {self.Character.Name} but still exists, not removing`)
        end
    end)

    self.Character:WaitForChild("Humanoid").Died:Once(RemoveOnDeath)
    
     -- print("Character initialization complete:", self.Character.Name)
end

function EntityClass:LoadWeapon(Character: Model)
    local WeaponName = self.Weapon
     -- print("Loading weapon for:", Character.Name, "Weapon:", WeaponName)
    
local WeaponName = self.Weapon
    if WeaponName == "Fist" then 
        -- -- print("weapon is fist")
        local WeaponFolder: Folder? = Server.Service.ServerStorage.Assets.Models.Weapons[WeaponName]
        if WeaponFolder then
            -- -- print("Found Fist weapon folder")
            for _, v in WeaponFolder:GetChildren() do
                -- -- print("Processing weapon part:", v.Name)
                if v:GetAttribute("Arm") then
                    -- -- print("Found Arms attribute on:", v.Name)
                    local rightPart = v:Clone()
                    local leftPart = v:Clone()
                    rightPart.Parent = Character["Right Arm"]
                    leftPart.Parent = Character["Left Arm"]
                    -- -- print("Cloned", v.Name, "to both arms")
                elseif v:GetAttribute("RightLeg") then
                    -- -- print("Found RightLeg attribute on:", v.Name)
                    local part = v:Clone()
                    part.Parent = Character["Right Leg"]
                    -- -- print("Cloned", v.Name, "to right leg")
                else
                    -- -- print("No special attributes found on:", v.Name)
                end
            end
        else
            -- print("Fist weapon folder not found")
        end
        return 
    end
    
    local WeaponFolder: Folder? = Server.Service.ServerStorage.Assets.Models.Weapons[WeaponName]

    if WeaponFolder then
         -- print("Found weapon folder for:", WeaponName, "Character:", Character.Name)
        for _, WepPart in pairs(Server.Service.ServerStorage.Assets.Models.Weapons[WeaponName]:GetChildren()) do
            local PotentialPart = WepPart:Clone()
             -- print("Cloning weapon part:", WepPart.Name, "for:", Character.Name)

            if PotentialPart:FindFirstChild("Unequip") then
                if PotentialPart.Unequip:GetAttribute("Part0") then
                    if not PotentialPart.Unequip.Part0 then
                        PotentialPart.Unequip.Part0 = Character[PotentialPart.Unequip:GetAttribute("Part0")]
                    end
                else
                    if not PotentialPart.Unequip.Part1 then
                        PotentialPart.Unequip.Part1 = Character[PotentialPart.Unequip:GetAttribute("Part1")]
                    end
                end
            elseif PotentialPart:FindFirstChild("TorsoWeld") then
                if PotentialPart.TorsoWeld:GetAttribute("Part0") then
                    PotentialPart.TorsoWeld.Part0 = Character[PotentialPart.TorsoWeld:GetAttribute("Part0")]
                else
                    PotentialPart.TorsoWeld.Part1 = Character[PotentialPart.TorsoWeld:GetAttribute("Part1")]
                end
            end

            PotentialPart.Parent = Character 
        end
         -- print("Weapon loading complete for:", Character.Name, "Weapon:", WeaponName)
    else
         -- print("Weapon folder not found for:", WeaponName, "Character:", Character.Name)
    end
end

function EntityClass:GetCFrame(TimeStamp: number) : CFrame
    -- DISABLED: Snapshot reconciliation system completely disabled to prevent rubberbanding
    -- The anti-exploit system was causing players to rubberband when hit with knockback/velocity
    -- Just return current position for all characters
    if self and self.Character and self.Character.PrimaryPart then
        return self.Character.PrimaryPart.CFrame
    elseif self and self.Character and self.Character.HumanoidRootPart then
        return self.Character.HumanoidRootPart.CFrame
    end

    return CFrame.new()
end

Server.Utilities:AddToCoreLoop(function(DeltaTime)
    for _, Instance in Server.Service.CollectionService:GetTagged("PostureInstances") do
        --> Some arbitrary check to see if in combat, recently taken damage what ever blah blah
        Instance.Value -= .1  -- Reduced posture regeneration from .25 to .1
    end
end)

return EntityClass