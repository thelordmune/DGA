local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage.Modules.Fusion)

local Children, scoped, OnEvent, Spring, Computed =
	Fusion.Children, Fusion.scoped, Fusion.OnEvent, Fusion.Spring, Fusion.Computed

return function(scope, props: {})
	local scope = scoped(Fusion, {})

	-- Get props
	local isOpen = props.isOpen
	local currentView = props.currentView
	local activeQuestData = props.activeQuestData
	local questsList = props.questsList
	local parent = props.Parent

	-- Spring for smooth open/close animation
	local positionSpring = scope:Spring(
		scope:Computed(function(use)
			return if use(isOpen) then UDim2.fromScale(0.0423, 0.186) else UDim2.fromScale(-0.3, 0.186)
		end),
		25, -- speed
		1 -- damping
	)

scope:New "Frame" {
  Parent = parent,
  Name = "Holder",
  BackgroundColor3 = Color3.fromRGB(255, 255, 255),
  BackgroundTransparency = 1,
  BorderColor3 = Color3.fromRGB(0, 0, 0),
  BorderSizePixel = 0,
  ClipsDescendants = true,
  Position = positionSpring,
  Size = UDim2.fromOffset(275, 400),

  [Children] = {
        scope:New "TextButton" {
          Name = "AQButton",
          BackgroundColor3 = Color3.fromRGB(255, 255, 255),
          BackgroundTransparency = 1,
          BorderColor3 = Color3.fromRGB(0, 0, 0),
          BorderSizePixel = 0,
          FontFace = Font.new(
            "rbxasset://fonts/families/Sarpanch.json",
            Enum.FontWeight.Bold,
            Enum.FontStyle.Normal
          ),
          Position = UDim2.fromScale(0.0873, 0.0275),
          Size = UDim2.fromOffset(112, 50),
          Text = "Active Quest",
          TextColor3 = Color3.fromRGB(255, 255, 255),
          TextSize = 20,
          TextWrapped = true,
          ZIndex = 2,

          [OnEvent "Activated"] = function()
            currentView:set("ActiveQuest")
          end,

          [Children] = {
            scope:New "ImageLabel" {
              Name = "ImageLabel",
              BackgroundColor3 = Color3.fromRGB(255, 255, 255),
              BackgroundTransparency = 1,
              BorderColor3 = Color3.fromRGB(0, 0, 0),
              BorderSizePixel = 0,
              Image = "rbxassetid://85631517185548",

              ScaleType = Enum.ScaleType.Slice,
              Size = UDim2.fromScale(1, 1),
              SliceCenter = Rect.new(9, 9, 21, 21),
            },

            scope:New "UICorner" {
              Name = "UICorner",
              CornerRadius = UDim.new(0, 10),
            },
          }
        },

        scope:New "TextButton" {
          Name = "QIButton",
          BackgroundColor3 = Color3.fromRGB(255, 255, 255),
          BackgroundTransparency = 1,
          BorderColor3 = Color3.fromRGB(0, 0, 0),
          BorderSizePixel = 0,
          FontFace = Font.new(
            "rbxasset://fonts/families/Sarpanch.json",
            Enum.FontWeight.Bold,
            Enum.FontStyle.Normal
          ),
          Position = UDim2.fromScale(0.52, 0.0275),
          Size = UDim2.fromOffset(112, 50),
          Text = "Quest Index",
          TextColor3 = Color3.fromRGB(255, 255, 255),
          TextSize = 20,
          TextWrapped = true,
          ZIndex = 2,

          [OnEvent "Activated"] = function()
            currentView:set("QuestIndex")
          end,

          [Children] = {
            scope:New "ImageLabel" {
              Name = "ImageLabel",
              BackgroundColor3 = Color3.fromRGB(255, 255, 255),
              BackgroundTransparency = 1,
              BorderColor3 = Color3.fromRGB(0, 0, 0),
              BorderSizePixel = 0,
              Image = "rbxassetid://85631517185548",

              ScaleType = Enum.ScaleType.Slice,
              Size = UDim2.fromScale(1, 1),
              SliceCenter = Rect.new(9, 9, 21, 21),
            },

            scope:New "UICorner" {
              Name = "UICorner",
              CornerRadius = UDim.new(0, 10),
            },
          }
        },

        scope:New "ImageLabel" {
          Name = "Background",
          BackgroundColor3 = Color3.fromRGB(255, 255, 255),
          BackgroundTransparency = 1,
          BorderColor3 = Color3.fromRGB(0, 0, 0),
          BorderSizePixel = 0,
          Image = "rbxassetid://85774200010476",
          
          ImageTransparency = 0.1,
          Size = UDim2.fromScale(1, 1),

          [Children] = {
            scope:New "UICorner" {
              Name = "UICorner",
              CornerRadius = UDim.new(0, 10),
            },
          }
        },

        scope:New "ImageLabel" {
          Name = "Border",
          BackgroundColor3 = Color3.fromRGB(255, 255, 255),
          BackgroundTransparency = 1,
          BorderColor3 = Color3.fromRGB(0, 0, 0),
          BorderSizePixel = 0,
          Image = "rbxassetid://80989206568872",
          
          ScaleType = Enum.ScaleType.Slice,
          Size = UDim2.fromScale(1, 1),
          SliceCenter = Rect.new(10, 7, 20, 20),
        },

        scope:New "ScrollingFrame" {
          Name = "QuestIndex",
          BackgroundColor3 = Color3.fromRGB(255, 255, 255),
          BackgroundTransparency = 1,
          BorderColor3 = Color3.fromRGB(0, 0, 0),
          BorderSizePixel = 0,
          Position = UDim2.fromScale(0.0873, 0.203),
          ScrollBarImageTransparency = 1,
          Selectable = false,
          Size = UDim2.fromOffset(231, 276),
          Visible = scope:Computed(function(use)
            return use(currentView) == "QuestIndex"
          end),

          [Children] = {
            scope:New "UIListLayout" {
              Name = "UIListLayout",
              HorizontalAlignment = Enum.HorizontalAlignment.Center,
              Padding = UDim.new(0, 5),
              SortOrder = Enum.SortOrder.LayoutOrder,
            },

            -- Dynamically create quest buttons
            scope:Computed(function(use)
              local quests = use(questsList)
              local buttons = {}

              for i, quest in ipairs(quests) do
                table.insert(buttons, scope:New "TextButton" {
                  Name = "Quest_" .. i,
                  Active = false,
                  BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                  BackgroundTransparency = 1,
                  BorderColor3 = Color3.fromRGB(0, 0, 0),
                  BorderSizePixel = 0,
                  FontFace = Font.new(
                    "rbxasset://fonts/families/Sarpanch.json",
                    Enum.FontWeight.Bold,
                    Enum.FontStyle.Normal
                  ),
                  Selectable = false,
                  Size = UDim2.fromOffset(200, 50),
                  Text = quest.questName,
                  TextColor3 = Color3.fromRGB(255, 255, 255),
                  TextSize = 18,
                  TextWrapped = true,
                  LayoutOrder = i,

                  [OnEvent "Activated"] = function()
                    -- Switch to Active Quest view when clicked
                    currentView:set("ActiveQuest")
                  end,

                  [Children] = {
                    scope:New "ImageLabel" {
                      Name = "Background",
                      BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                      BackgroundTransparency = 1,
                      BorderColor3 = Color3.fromRGB(0, 0, 0),
                      BorderSizePixel = 0,
                      Image = "rbxassetid://85631517185548",
                      ScaleType = Enum.ScaleType.Slice,
                      Size = UDim2.fromScale(1, 1),
                      SliceCenter = Rect.new(9, 9, 21, 21),
                      ZIndex = 0,
                    },

                    scope:New "UICorner" {
                      Name = "UICorner",
                      CornerRadius = UDim.new(0, 8),
                    },
                  }
                })
              end

              return buttons
            end),
          }
        },

        scope:New "Frame" {
          Name = "ActiveQuest",
          BackgroundColor3 = Color3.fromRGB(255, 255, 255),
          BackgroundTransparency = 1,
          BorderColor3 = Color3.fromRGB(0, 0, 0),
          BorderSizePixel = 0,
          Position = UDim2.fromScale(0.0873, 0.215),
          Size = UDim2.fromOffset(231, 272),
          Visible = scope:Computed(function(use)
            return use(currentView) == "ActiveQuest"
          end),

          [Children] = {
            scope:New "TextLabel" {
              Name = "QuestName",
              BackgroundColor3 = Color3.fromRGB(255, 255, 255),
              BackgroundTransparency = 1,
              BorderColor3 = Color3.fromRGB(0, 0, 0),
              BorderSizePixel = 0,
              FontFace = Font.new(
                "rbxasset://fonts/families/Sarpanch.json",
                Enum.FontWeight.Bold,
                Enum.FontStyle.Normal
              ),
              Position = UDim2.fromScale(0.0649, 0.0735),
              Size = UDim2.fromOffset(200, 50),
              Text = scope:Computed(function(use)
                local quest = use(activeQuestData)
                if quest then
                  return quest.questName
                else
                  return "No Active Quest"
                end
              end),
              TextColor3 = Color3.fromRGB(255, 255, 255),
              TextScaled = true,
              TextSize = 14,
              TextWrapped = true,
              TextXAlignment = Enum.TextXAlignment.Left,
              TextYAlignment = Enum.TextYAlignment.Top,
            },

            scope:New "TextLabel" {
              Name = "Description",
              BackgroundColor3 = Color3.fromRGB(255, 255, 255),
              BackgroundTransparency = 1,
              BorderColor3 = Color3.fromRGB(0, 0, 0),
              BorderSizePixel = 0,
              FontFace = Font.new(
                "rbxasset://fonts/families/Sarpanch.json",
                Enum.FontWeight.Regular,
                Enum.FontStyle.Normal
              ),
              Position = UDim2.fromScale(0.0649, 0.327),
              Size = UDim2.fromOffset(200, 161),
              Text = scope:Computed(function(use)
                local quest = use(activeQuestData)
                if quest then
                  return quest.description
                else
                  return "Accept a quest from an NPC to begin your adventure!"
                end
              end),
              TextColor3 = Color3.fromRGB(220, 220, 220),
              TextSize = 16,
              TextWrapped = true,
              TextXAlignment = Enum.TextXAlignment.Left,
              TextYAlignment = Enum.TextYAlignment.Top,
            },
          }
        },
      }
    }
end


