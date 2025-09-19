local DataHandler = {}; local Server = require(script.Parent)
DataHandler.__index = DataHandler;
local self = setmetatable({}, DataHandler)

local ProfileService, Template = require(script.ProfileService), require(script.Template);
local replion = require(game.ReplicatedStorage.Modules.Shared.Replion)
local ProfileStore = ProfileService.GetProfileStore("IronVeilTestStorev001", Template)

local Disabled = true

if Disabled == true then
    ProfileStore = ProfileStore.Mock
end

local Profiles = {};
local PlayerReplions = {};

function DataHandler:GetProfile(Player: Player)
    if Profiles[Player] then return Profiles[Player] end;
end

function DataHandler:GetData(Player: Player)
    if Profiles[Player] then return Profiles[Player].Data end;
end

function DataHandler:GetReplion(Player: Player)
    return PlayerReplions[Player]
end

function DataHandler:LoadData(Player: Player)
    local Profile = ProfileStore:LoadProfileAsync("Player_"..Player.UserId, function() return "ForceLoad" end)
    if Profile ~= nil then
        Profile:AddUserId(Player.UserId);
        Profile:Reconcile();
        Profile:ListenToRelease(function()
            Profile[Player] = nil;
            Profile = nil;
            Player:Kick("Data Loaded On Another Server | Please Rejoin")
        end)

        if Player:IsDescendantOf(Server.Service.Players) then
            Profiles[Player] = Profile;

            local playerReplion = replion.Server.new({
                Channel = "Data",
                ReplicateTo = Player,
                Data = Profile.Data
            })

            playerReplion:OnDataChange(function(newData)
                Profile.Data = newData
            end)

            playerReplion:BeforeDestroy(function()
                Profile.Data = playerReplion.Data
                Profile:Release()
            end)

            PlayerReplions[Player] = playerReplion;

            local GlobalUpdates = Profile.GlobalUpdates;
            for _, v in next, GlobalUpdates:GetActiveUpdates() do
                GlobalUpdates:LockActiveUpdate(v[1])
            end

            for _, Update in next, GlobalUpdates:GetLockedUpdates() do
                local ID = Update[1]
                local Data = Update[2]
                Profile.GlobalUpdates:ClearLockedUpdate(ID)
            end

            GlobalUpdates:ListenToNewActiveUpdate(function(ID, Data)
                GlobalUpdates:LockActiveUpdate(ID)
            end)

            GlobalUpdates:ListenToNewLockedUpdate(function(ID, Data)
                Profile.GlobalUpdates:ClearLockedUpdate(ID)
            end)

            Player:SetAttribute("DataLoaded", true);
            if Server.Service.RunService:IsStudio() then
                print(Profile);
            end

            return Profile;
        else
            Profile:Release()
            if Profiles[Player] then Profiles[Player] = nil end;
        end

    else
        Player:Kick("Data Issue, Please Rejoin");
    end

end

function DataHandler:RemoveData(Player: Player)
    if PlayerReplions[Player] then
        PlayerReplions[Player]:Destroy()
        PlayerReplions[Player] = nil;
    end
    
    if Profiles[Player] then
        Profiles[Player]:Release()
        Profiles[Player] = nil;
    end
end

return DataHandler