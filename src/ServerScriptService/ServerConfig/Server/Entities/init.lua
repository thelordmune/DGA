local Server = require(script.Parent);
local Replicated = game:GetService("ReplicatedStorage")
local start = require(Replicated.Modules.ECS.jecs_start)
local ref = require(Replicated.Modules.ECS.jecs_ref)
-- local util = Replicated.Modules:WaitForChild("Utilities")

local DEBUG = false -- Toggle debugging

local function debugPrint(...)
    if DEBUG then
        print("[EntityClass]", ...)
    end
end

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
    debugPrint("Getting entity:", Entity.Name)
    if Server.Entities[Entity] then
        debugPrint("Entity found:", Entity.Name)
        return Server.Entities[Entity]
    end
    debugPrint("Entity not found:", Entity.Name)
end

EntityClass.Remove = function(Entity)
    debugPrint("Attempting to remove entity:", Entity.Name)
    if Server.Entities[Entity] then
        -- COMPREHENSIVE CLEANUP BEFORE REMOVAL
        debugPrint("=== CLEANING UP ENTITY ON DEATH ===")
        debugPrint("Entity:", Entity.Name)

        -- Clean up equip state before removing entity (prevents stuck states on respawn)
        if Server.Modules.Network and Server.Modules.Network.Equip then
            Server.Modules.Network.Equip.CleanupCharacterEquipState(Entity)
        end

        -- Clean up all character data (animations, cooldowns, etc.)
        if Server.Library and Server.Library.CleanupCharacter then
            Server.Library.CleanupCharacter(Entity)
            debugPrint("Cleaned up character data for:", Entity.Name)
        end

        -- Stop any playing animations
        if Entity:FindFirstChild("Humanoid") and Entity.Humanoid:FindFirstChild("Animator") then
            for _, track in pairs(Entity.Humanoid.Animator:GetPlayingAnimationTracks()) do
                track:Stop(0)
                track:Destroy()
            end
            debugPrint("Stopped all animations for:", Entity.Name)
        end

        setmetatable(Server.Entities[Entity], nil);
        Server.Entities[Entity] = nil;
        warn(("Removed: %s"):format(Entity.Name));

        local Player = Server.Service.Players:GetPlayerFromCharacter(Entity);
        if Player then
            debugPrint("Player found for respawn:", Player.Name)
            task.wait(Server.Service.Players.RespawnTime)
            if Player and Player:IsDescendantOf(Server.Service.Players) then
                debugPrint("Respawning player:", Player.Name)
                Server.Service.RunService.Heartbeat:Wait();
                Player:LoadCharacter();
            end
        else
            debugPrint("No player found for entity:", Entity.Name)
        end
    else
        debugPrint("Entity not in Server.Entities:", Entity.Name)
    end
end

EntityClass.Init = function(Entity) : EntityObject
    debugPrint("Initializing entity:", Entity.Name)
    if Server.Entities[Entity] then 
        debugPrint("Entity already exists, returning existing:", Entity.Name)
        return Server.Entities[Entity] 
    end
    
    local self = setmetatable({}, EntityClass)
    self.Character = Entity;

    local Player = Server.Service.Players:GetPlayerFromCharacter(Entity);
    if Player then 
		game.CollectionService:AddTag(self.Character, "Players")
        debugPrint("Player entity detected:", Player.Name, "Weapon:", Player:GetAttribute("Weapon"))
        self.Player = Player;
        self.Weapon = Player:GetAttribute("Weapon");
        self.Snapshots = {};
        local entity = ref.get("player", Player)  -- Fixed: Use "player" on server, not "local_player"
        task.delay(5, function()
            debugPrint("Giving weapon skills to player:", Player.Name, "Weapon:", self.Weapon)
            InventorySetup.GiveWeaponSkills(entity, self.Weapon, Player)
        end)
    else
        debugPrint("NPC entity detected:", Entity.Name, "Weapon:", Entity:GetAttribute("Weapon"))
        self.Weapon = Entity:GetAttribute("Weapon")
        -- Ensure NPC has the IsNPC attribute for damage system
        if not Entity:GetAttribute("IsNPC") then
            Entity:SetAttribute("IsNPC", true)
            debugPrint("Set IsNPC attribute for:", Entity.Name)
        end
    end;

    self:Initialize();

    warn(("Added: %s"):format(Entity.Name))

    -- Only start systems once
    if not systemsStarted then
        debugPrint("Starting ECS systems for the first time")
        start(game:GetService("ServerScriptService").Systems)
        systemsStarted = true
    else
        debugPrint("ECS systems already started")
    end

    Server.Entities[Entity] = self;
    debugPrint("Entity successfully added to Server.Entities:", Entity.Name)
    return self    
end

function EntityClass:Initialize()
    debugPrint("Initializing character:", self.Character.Name)
    
    self.Character.PrimaryPart = self.Character:WaitForChild("HumanoidRootPart");
    self.Character.PrimaryPart:AddTag("Roots");
    debugPrint("Set PrimaryPart and added Roots tag for:", self.Character.Name)
    
    for _, v in next, self.Character:GetChildren() do
        if v and (v:IsA("BasePart") or v:IsA("MeshPart")) then
            v.CollisionGroup = "Players";
        end
    end
    debugPrint("Set collision groups for:", self.Character.Name)
    
    for _, Frame in next, Server.Service.ServerStorage.Frames:GetChildren() do
        local Inst = Frame:Clone();
        if Frame:IsA("StringValue") then Inst.Value = "[]" end
        Inst.Parent = self.Character;
        
        if Frame.Name == "Posture" then
            Frame:AddTag("PostureInstances");
        end
    end
    debugPrint("Cloned frames for:", self.Character.Name)
    
    -- Only set parent if not already in workspace.World.Live
    if not self.Character:IsDescendantOf(workspace.World.Live) then
        debugPrint("Moving character to workspace.World.Live:", self.Character.Name)
        self.Character.Parent = workspace.World.Live
    else
        debugPrint("Character already in workspace.World.Live:", self.Character.Name)
    end
    
    if self.Player then
        debugPrint("Loading appearance for player:", self.Player.Name)
        task.spawn(Appearance.Load, self.Player)

        -- Initialize dodge charges for players
        self.Character:SetAttribute("DodgeCharges", 2)
        debugPrint("Initialized dodge charges for:", self.Player.Name)

        -- Initialize equipped state for players
        self.Character:SetAttribute("Equipped", false)
        debugPrint("Initialized equipped state for:", self.Player.Name)

        -- COMPREHENSIVE SERVER-SIDE CLEANUP AND REINITIALIZATION
        debugPrint("=== SERVER-SIDE CHARACTER REINITIALIZATION ===")
        debugPrint("Player:", self.Player.Name)

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
                debugPrint("Reset all cooldowns for:", self.Player.Name)
            end
        end

        -- Ensure all character frames are properly initialized
        task.wait(0.1) -- Wait for frames to be cloned
        if self.Character:FindFirstChild("Actions") then
            self.Character.Actions.Value = "[]"
            debugPrint("Initialized Actions frame")
        end
        if self.Character:FindFirstChild("Stuns") then
            self.Character.Stuns.Value = "[]"
            debugPrint("Initialized Stuns frame")
        end
        if self.Character:FindFirstChild("Speeds") then
            self.Character.Speeds.Value = "[]"
            debugPrint("Initialized Speeds frame")
        end
        if self.Character:FindFirstChild("Status") then
            self.Character.Status.Value = "[]"
            debugPrint("Initialized Status frame")
        end

        -- CLEAR HOTBAR AND INVENTORY (Fix item mismatch on respawn)
        if self.Player then
            local ref = require(Server.Service.ReplicatedStorage.Modules.ECS.jecs_ref)
            local InventoryManager = require(Server.Service.ReplicatedStorage.Modules.Utils.InventoryManager)

            local pent = ref.get("player", self.Player)
            if pent then
                InventoryManager.resetPlayerInventory(pent)
                debugPrint("Cleared hotbar and inventory for:", self.Player.Name)
            end
        end
    end

    self:LoadWeapon(self.Character)
    
    local function Remove() 
        debugPrint("Remove function called for:", self.Character.Name)
        self.Remove(self.Character) 
    end
    self.Character:GetPropertyChangedSignal("PrimaryPart"):Once(Remove)
    self.Character:WaitForChild("Humanoid").Died:Once(Remove)
    
    debugPrint("Character initialization complete:", self.Character.Name)
end

function EntityClass:LoadWeapon(Character: Model)
    local WeaponName = self.Weapon
    debugPrint("Loading weapon for:", Character.Name, "Weapon:", WeaponName)
    
local WeaponName = self.Weapon
    if WeaponName == "Fist" then 
        print("weapon is fist")
        local WeaponFolder: Folder? = Server.Service.ServerStorage.Assets.Models.Weapons[WeaponName]
        if WeaponFolder then
            print("Found Fist weapon folder")
            for _, v in WeaponFolder:GetChildren() do
                print("Processing weapon part:", v.Name)
                if v:GetAttribute("Arm") then
                    print("Found Arms attribute on:", v.Name)
                    local rightPart = v:Clone()
                    local leftPart = v:Clone()
                    rightPart.Parent = Character["Right Arm"]
                    leftPart.Parent = Character["Left Arm"]
                    print("Cloned", v.Name, "to both arms")
                elseif v:GetAttribute("RightLeg") then
                    print("Found RightLeg attribute on:", v.Name)
                    local part = v:Clone()
                    part.Parent = Character["Right Leg"]
                    print("Cloned", v.Name, "to right leg")
                else
                    print("No special attributes found on:", v.Name)
                end
            end
        else
            print("Fist weapon folder not found")
        end
        return 
    end
    
    local WeaponFolder: Folder? = Server.Service.ServerStorage.Assets.Models.Weapons[WeaponName]

    if WeaponFolder then
        debugPrint("Found weapon folder for:", WeaponName, "Character:", Character.Name)
        for _, WepPart in pairs(Server.Service.ServerStorage.Assets.Models.Weapons[WeaponName]:GetChildren()) do
            local PotentialPart = WepPart:Clone()
            debugPrint("Cloning weapon part:", WepPart.Name, "for:", Character.Name)

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
        debugPrint("Weapon loading complete for:", Character.Name, "Weapon:", WeaponName)
    else
        debugPrint("Weapon folder not found for:", WeaponName, "Character:", Character.Name)
    end
end

function EntityClass:GetCFrame(TimeStamp: number) : CFrame
    TimeStamp = TimeStamp and TimeStamp or workspace:GetServerTimeNow()

    if self and self.Snapshots and self.Character then
        local CurrentCF = self.Character.PrimaryPart.CFrame;
        local LatestSnapshot;
        local PreviousSnapshot;

        for i = #self.Snapshots - 1, 1, -1 do
            if self.Snapshots[i].Time < TimeStamp then
                PreviousSnapshot = self.Snapshots[i]
                LatestSnapshot = self.Snapshots[i + 1]
            end
        end

        if not PreviousSnapshot then
            return CurrentCF;	
        end

        local Percentage = (TimeStamp - PreviousSnapshot.Time) / (LatestSnapshot.Time - PreviousSnapshot.Time)
        local Prediction = PreviousSnapshot.CFrame:Lerp(LatestSnapshot.CFrame, Percentage);

        if (CurrentCF.Position - Prediction.Position).Magnitude <= 12 then --> 12 is the sanity distance check
            CurrentCF = Prediction
        end

        return CurrentCF;
    else
        return self.Character.HumanoidRootPart.CFrame
    end
end

Server.Utilities:AddToCoreLoop(function(DeltaTime)
    for _, Instance in Server.Service.CollectionService:GetTagged("PostureInstances") do
        --> Some arbitrary check to see if in combat, recently taken damage what ever blah blah
        Instance.Value -= .1  -- Reduced posture regeneration from .25 to .1
    end
end)

return EntityClass