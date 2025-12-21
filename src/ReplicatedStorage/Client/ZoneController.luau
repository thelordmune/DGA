local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage.Modules.Fusion)
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer
local plrGui = player:WaitForChild("PlayerGui")

local Children, scoped, peek, out = Fusion.Children, Fusion.scoped, Fusion.peek, Fusion.Out
local TInfo = TweenInfo.new(1.5, Enum.EasingStyle.Circular, Enum.EasingDirection.InOut, 0)

-- Zone sound effect
local zoneSound = ReplicatedStorage.Assets.SFX.MISC.Zone:Clone()
zoneSound.Parent = SoundService
zoneSound.Volume = 0 -- Start at 0 for fade in

-- Store UI references globally to manage cleanup
local currentUI
local currentZoneConnection
local characterDiedConnection
local respawnZoneCheckConnection

local function CleanupUI()
    if currentUI then
        currentUI:Destroy()
        currentUI = nil
    end
    if currentZoneConnection then
        currentZoneConnection:Disconnect()
        currentZoneConnection = nil
    end
    if characterDiedConnection then
        characterDiedConnection:Disconnect()
        characterDiedConnection = nil
    end
    if respawnZoneCheckConnection then
        respawnZoneCheckConnection:Disconnect()
        respawnZoneCheckConnection = nil
    end
end

local function ZoneDisplay()
    -- Clean up any existing UI first
    CleanupUI()

    local scope = scoped(Fusion, {})
    local currentZone : string? = scope:Value("Unknown")
    local started : boolean = scope:Value(false)
    
    -- Handle zone changes
    local function onZoneChanged()
        local newZone = workspace:GetAttribute("CurrentZone") or "Unknown" :: string
        currentZone:set(newZone)
        started:set(true)

        -- Play zone sound effect with fade in/out
        if zoneSound then
            zoneSound.Volume = 0
            zoneSound:Play()

            -- Fade in
            local fadeInTween = TweenService:Create(
                zoneSound,
                TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
                { Volume = 0.5 }
            )
            fadeInTween:Play()

            -- Fade out after 1 second
            task.delay(1, function()
                local fadeOutTween = TweenService:Create(
                    zoneSound,
                    TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                    { Volume = 0 }
                )
                fadeOutTween:Play()
            end)
        end

        task.wait(1.5)
        started:set(false)
    end
    
    -- Set up zone change connection
    currentZoneConnection = workspace:GetAttributeChangedSignal("CurrentZone"):Connect(onZoneChanged)
    
    -- Check if there's already a zone when the UI loads
    if workspace:GetAttribute("CurrentZone") then
        onZoneChanged()
    end

    -- Create the UI and store reference
    currentUI = scope:New "ScreenGui" {
        Parent = plrGui,
        Name = "ZoneDisplayGui",
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        ResetOnSpawn = false,

        [Children] = {
            scope:New "Frame" {
                Name = "MainFrame",
                BackgroundTransparency = 1,
                Position = scope:Tween(
                    scope:Computed(function(use)
                        return if use(started) then UDim2.fromScale(0.253, 0) else UDim2.fromScale(0.253, -0.1)
                    end),
                    TInfo
                ),
                Size = UDim2.fromScale(0.518, 0.268),

                [Children] = {
                    scope:New "TextLabel" {
                        Name = "ZoneText",
                        BackgroundTransparency = 1,
                        FontFace = Font.new("rbxassetid://16658237174", Enum.FontWeight.Bold, Enum.FontStyle.Italic),
                        Position = UDim2.fromScale(0.188, 0.167),
                        Size = UDim2.fromScale(0.618, 0.334),
                        Text = scope:Computed(function(use)
                            return use(currentZone)
                        end),
                        TextColor3 = Color3.fromRGB(207, 207, 207),
                        TextTransparency = scope:Tween(
                            scope:Computed(function(use)
                                return if use(started) then 0 else 1
                            end),
                            TInfo
                        ),
                        TextScaled = true,
                        ZIndex = 2,

                        [Children] = {
                            scope:New "UIStroke" {
                                Name = "TextStroke",
                                Color = Color3.fromRGB(255, 255, 255),
                                Transparency = scope:Tween(
                                    scope:Computed(function(use)
                                        return if use(started) then 0 else 1
                                    end),
                                    TInfo
                                ),
                                [Children] = {
                                    scope:New("UIGradient")({
                                        Color = ColorSequence.new({
                                            ColorSequenceKeypoint.new(0, Color3.fromRGB(112, 112, 112)),
                                            ColorSequenceKeypoint.new(0.335, Color3.fromRGB(112, 112, 112)),
                                            ColorSequenceKeypoint.new(0.496, Color3.fromRGB(76, 76, 76)),
                                            ColorSequenceKeypoint.new(0.634, Color3.fromRGB(112, 112, 112)),
                                            ColorSequenceKeypoint.new(1, Color3.fromRGB(112, 112, 112)),
                                        }),
                                        Rotation = 90,
                                    }),
                                },
                            },
                        },
                    },
                },
            }
        }
    }

    return currentUI
end

local function SetupCharacterEvents(character)
    local humanoid = character:WaitForChild("Humanoid")
    
    -- Disconnect previous death connection if it exists
    if characterDiedConnection then
        characterDiedConnection:Disconnect()
    end
    
    characterDiedConnection = humanoid.Died:Connect(function()
        CleanupUI()
        
        -- Reinitialize when character respawns
        player.CharacterAdded:Once(function(newCharacter)
            task.wait(1) -- Wait for character to fully load
            
            -- Create new UI
            ZoneDisplay()
            
            -- Force a zone check after respawn
            respawnZoneCheckConnection = newCharacter:WaitForChild("HumanoidRootPart").Changed:Connect(function()
                if workspace:GetAttribute("CurrentZone") then
                    -- Trigger zone display
                    local current = workspace:GetAttribute("CurrentZone")
                    workspace:SetAttribute("CurrentZone", nil) -- Reset
                    workspace:SetAttribute("CurrentZone", current) -- Set again to trigger display
                    
                    -- Disconnect after first successful check
                    if respawnZoneCheckConnection then
                        respawnZoneCheckConnection:Disconnect()
                        respawnZoneCheckConnection = nil
                    end
                end
            end)
            
            SetupCharacterEvents(newCharacter)
        end)
    end)
end

-- Initial setup
ZoneDisplay()

if player.Character then
    SetupCharacterEvents(player.Character)
end

-- Handle future characters
player.CharacterAdded:Connect(SetupCharacterEvents)

return function()
    -- Cleanup when the module is destroyed
    return CleanupUI
end