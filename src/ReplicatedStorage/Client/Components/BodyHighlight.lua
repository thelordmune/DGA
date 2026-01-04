-- BodyHighlight Component
-- Displays a body silhouette with highlighted limbs based on Junction targeting

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage.Modules.Fusion)

local Children, scoped, peek, Computed, Spring, Value, Tween =
    Fusion.Children, Fusion.scoped, Fusion.peek, Fusion.Computed, Fusion.Spring, Fusion.Value, Fusion.Tween

-- Body part positions relative to silhouette (normalized 0-1)
local BodyPartPositions = {
    LeftArm = UDim2.fromScale(0.12, 0.42),
    RightArm = UDim2.fromScale(0.88, 0.42),
    LeftLeg = UDim2.fromScale(0.35, 0.78),
    RightLeg = UDim2.fromScale(0.65, 0.78),
}

local BodyPartSizes = {
    LeftArm = UDim2.fromScale(0.18, 0.32),
    RightArm = UDim2.fromScale(0.18, 0.32),
    LeftLeg = UDim2.fromScale(0.16, 0.32),
    RightLeg = UDim2.fromScale(0.16, 0.32),
}

local TInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

return function(scope, props: {
    Parent: Instance?,
    Junction: string?, -- "LeftArm", "RightArm", "LeftLeg", "RightLeg", "RandomArm", "RandomLeg", "Random"
    JunctionChance: number?,
    Visible: any, -- Fusion Value for visibility
})
    local junction = props.Junction
    local junctionChance = props.JunctionChance or 0
    local visible = props.Visible

    -- Helper to check if a body part should be highlighted
    local function isPartHighlighted(partName: string): boolean
        if not junction then return false end

        if junction == "RandomArm" then
            return partName == "LeftArm" or partName == "RightArm"
        elseif junction == "RandomLeg" then
            return partName == "LeftLeg" or partName == "RightLeg"
        elseif junction == "Random" then
            return true -- All limbs
        else
            return junction == partName
        end
    end

    -- Create body part highlight frame
    local function createBodyPart(partName: string)
        local highlighted = isPartHighlighted(partName)

        return scope:New "Frame" {
            Name = partName,
            Position = BodyPartPositions[partName],
            Size = BodyPartSizes[partName],
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundColor3 = highlighted and Color3.fromRGB(200, 50, 50) or Color3.fromRGB(80, 80, 80),
            BackgroundTransparency = scope:Tween(
                scope:Computed(function(use)
                    if not use(visible) then return 1 end
                    return highlighted and 0.3 or 0.7
                end),
                TInfo
            ),
            BorderSizePixel = 0,
            ZIndex = 10000002,

            [Children] = {
                scope:New "UICorner" {
                    CornerRadius = UDim.new(0.2, 0),
                },
                -- Glow effect when highlighted
                scope:New "UIStroke" {
                    Color = Color3.fromRGB(255, 100, 100),
                    Thickness = highlighted and 1 or 0,
                    Transparency = scope:Tween(
                        scope:Computed(function(use)
                            if not use(visible) then return 1 end
                            return highlighted and 0.3 or 1
                        end),
                        TInfo
                    ),
                },
            }
        }
    end

    return scope:New "Frame" {
        Name = "BodyHighlight",
        Parent = props.Parent,
        Size = UDim2.fromOffset(40, 60),
        Position = UDim2.fromScale(0.75, 0.45),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        ZIndex = 10000002,

        [Children] = {
            -- Torso (non-highlightable, just for visual)
            scope:New "Frame" {
                Name = "Torso",
                Position = UDim2.fromScale(0.5, 0.45),
                Size = UDim2.fromScale(0.35, 0.35),
                AnchorPoint = Vector2.new(0.5, 0.5),
                BackgroundColor3 = Color3.fromRGB(60, 60, 60),
                BackgroundTransparency = scope:Tween(
                    scope:Computed(function(use)
                        return if use(visible) then 0.5 else 1
                    end),
                    TInfo
                ),
                BorderSizePixel = 0,
                ZIndex = 10000002,
                [Children] = {
                    scope:New "UICorner" { CornerRadius = UDim.new(0.1, 0) },
                },
            },
            -- Head (non-highlightable)
            scope:New "Frame" {
                Name = "Head",
                Position = UDim2.fromScale(0.5, 0.15),
                Size = UDim2.fromScale(0.22, 0.18),
                AnchorPoint = Vector2.new(0.5, 0.5),
                BackgroundColor3 = Color3.fromRGB(60, 60, 60),
                BackgroundTransparency = scope:Tween(
                    scope:Computed(function(use)
                        return if use(visible) then 0.5 else 1
                    end),
                    TInfo
                ),
                BorderSizePixel = 0,
                ZIndex = 10000002,
                [Children] = {
                    scope:New "UICorner" { CornerRadius = UDim.new(0.5, 0) },
                },
            },
            -- Body parts (highlightable)
            createBodyPart("LeftArm"),
            createBodyPart("RightArm"),
            createBodyPart("LeftLeg"),
            createBodyPart("RightLeg"),

            -- Junction chance text
            scope:New "TextLabel" {
                Name = "ChanceLabel",
                Position = UDim2.fromScale(0.5, 1.05),
                Size = UDim2.fromOffset(50, 12),
                AnchorPoint = Vector2.new(0.5, 0),
                BackgroundTransparency = 1,
                Text = junctionChance > 0 and string.format("%d%%", math.floor(junctionChance * 100)) or "",
                Font = Enum.Font.Sarpanch,
                TextSize = 9,
                TextColor3 = Color3.fromRGB(255, 100, 100),
                TextTransparency = scope:Tween(
                    scope:Computed(function(use)
                        return if use(visible) then 0 else 1
                    end),
                    TInfo
                ),
                ZIndex = 10000003,
            },
        }
    }
end
