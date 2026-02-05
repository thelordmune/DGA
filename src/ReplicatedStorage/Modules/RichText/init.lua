local swagtext = {}

local TS = game:GetService("TweenService")

local function CheckForListLayout(target, verbose)
	for _, d in pairs(target:GetChildren()) do
		if d:IsA("UIListLayout") then
			return true
		elseif d:IsA("UIGridLayout") then
			if verbose then warn("SWAGTEXT >> ", target, "contains UIGridLayout. This may cause issues with word formatting.") end
			return true
		end
	end
	if verbose then warn("SWAGTEXT >> ", target, "does not contain UIListLayout or UIGridLayout. One will be created.") end
	return false
end

local function ShakeText(target)
	while target.Parent do
		local x, y, r = math.random(0, 0), math.random(-2, 2), math.random(-10, 10)
		target.Position = UDim2.new(0, x, 0, y)
		target.Rotation = r

		task.wait(0.05)
	end
end

local function Wave(target, i)
	if i then task.wait(i) end
	while target.Parent do
		TS:Create(target, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {Position = UDim2.fromOffset(0, 2)}):Play()
		wait(0.5)
		TS:Create(target, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {Position = UDim2.fromOffset(0, -2)}):Play()
		wait(0.5)
	end
end

local function TextAppear(target, mode)	
	if mode then
		if string.match(mode, "fade") then
			target.TextTransparency = 1
			TS:Create(target, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextTransparency = 0}):Play()
		end

		if string.match(mode, "up") then
			target.Position = UDim2.fromOffset(0, 5)
			TS:Create(target, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = UDim2.fromOffset(0, 0)}):Play()
		elseif string.match(mode, "down") then
			target.Position = UDim2.fromOffset(0, -5)
			TS:Create(target, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = UDim2.fromOffset(0, 0)}):Play()
		elseif string.match(mode, "diverge") then
			target.Position = UDim2.fromOffset(0, math.random(-5, 5))
			TS:Create(target, TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Position = UDim2.fromOffset(0, 0)}):Play()
		elseif string.match(mode, "sizeright") then
			target.Size = UDim2.new(4, 0, 1, 0)
			target.TextXAlignment = Enum.TextXAlignment.Right
			TS:Create(target, TweenInfo.new(0.8, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UDim2.new(0, 1, 1, 1)}):Play()
		end

		if string.match(mode, "rotate") then
			target.Rotation = 30
			TS:Create(target, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Rotation = 0}):Play()
		elseif string.match(mode, "rotright") then
			target.Rotation = -30
			TS:Create(target, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Rotation = 0}):Play()
		elseif string.match(mode, "shake") then
			local rand = math.random(-30, 30)
			target.Rotation = rand
			TS:Create(target, TweenInfo.new(0.5, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out), {Rotation = 0}):Play()
		elseif string.match(mode, "rotultra") then
			target.Rotation = 360
			TS:Create(target, TweenInfo.new(0.7, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Rotation = 0}):Play()
		end
	end
end

local function RainbowText(target, offset, i)
	local start = os.clock() + i

	while target.Parent do
		local hue = (os.clock() - start + offset / 255) % 1
		target.TextColor3 = Color3.fromHSV(hue, 1, 1)

		task.wait(0.05)
	end
end

str = ""

function swagtext.AnimateText(str, location, delayTime, font, mode, wordMode, textSize, ahori, avert, extra, verbose)

	local state = {}
	local default = {
		color = Color3.fromRGB(255, 255, 255),
		strokeSize = 2,
		bold = false,
		italic = false,
		rainbow = false,
		shake = false,
		wave = false,
		noanim = false,
		waitTime = -1,
	}
	table.insert(state, default)

	--BEWARE, TABLE.CLONE DOES NOT DEEP COPY
	local commands = {
		["<red>"] = function()
			local newState = table.clone(state[#state])
			newState.color = Color3.fromRGB(255, 0, 0)
			return newState
		end,
		["<blue>"] = function()
			local newState = table.clone(state[#state])
			newState.color = Color3.fromRGB(0, 0, 255)
			return newState
		end,
		["<bold>"] = function()
			local newState = table.clone(state[#state])
			newState.bold = true
			return newState
		end,
		["<italic>"] = function()
			local newState = table.clone(state[#state])
			newState.italic = true
			return newState
		end,
		["<rainbow>"] = function()
			local newState = table.clone(state[#state])
			newState.rainbow = true
			return newState
		end,
		["<shake>"] = function()
			local newState = table.clone(state[#state])
			newState.shake = true
			return newState
		end,
		["<wave>"] = function()
			local newState = table.clone(state[#state])
			newState.wave = true
			return newState
		end,
		["<noanim>"] = function()
			local newState = table.clone(state[#state])
			newState.noanim = true
			return newState
		end,
		["<n>"] = "newline", -- Special marker for new line
		["<color=#"] = true,
		--	["<strokeSize="] = true,
		["<pause="] = true,
		["</"] = function()
			table.remove(state)
		end,
	}

	local word = {}
	local wordLocation = nil
	local currentLineFrame = nil

	print("location -- ", location:GetFullName())

	-- Create main container with vertical layout for lines
	local mainLayout = location:FindFirstChild("UIListLayout")
	if not mainLayout then
		mainLayout = Instance.new("UIListLayout")
		mainLayout.Parent = location
		mainLayout.FillDirection = Enum.FillDirection.Vertical
		mainLayout.SortOrder = Enum.SortOrder.LayoutOrder
		if avert then mainLayout.VerticalAlignment = avert end
	end

	-- Create first line frame
	local function createNewLine()
		local lineFrame = Instance.new("Frame")
		lineFrame.Name = "SWAGTEXT_LINEFRAME"
		lineFrame.AutomaticSize = Enum.AutomaticSize.XY
		lineFrame.Size = UDim2.new(1, 0, 0, 0)
		lineFrame.BackgroundTransparency = 1
		lineFrame.Parent = location
		lineFrame.LayoutOrder = #location:GetChildren()

		local lineLayout = Instance.new("UIListLayout")
		lineLayout.Parent = lineFrame
		lineLayout.FillDirection = Enum.FillDirection.Horizontal
		lineLayout.SortOrder = Enum.SortOrder.LayoutOrder
		if ahori then lineLayout.HorizontalAlignment = ahori end

		return lineFrame
	end

	currentLineFrame = createNewLine()

	local i = 1
	while i <= string.len(str) do
		local letter = string.sub(str, i, i)

		if tonumber(wordMode) == 1 or wordMode == nil then
			if #word == 0 then
				local wordframe = Instance.new("Frame")
				wordframe.AutomaticSize = Enum.AutomaticSize.XY
				wordframe.Size = UDim2.new(0, 0, 0, 1)
				wordframe.Parent = currentLineFrame
				wordframe.LayoutOrder = #currentLineFrame:GetChildren()
				wordLocation = wordframe
				wordframe.BackgroundTransparency = 1
				wordframe.Name = "SWAGTEXT_WORDFRAME"
				local listlayout = Instance.new("UIListLayout")
				listlayout.Parent = wordframe
				listlayout.FillDirection = Enum.FillDirection.Horizontal
			end

			if letter == " " then
				table.clear(word)
			else
				table.insert(word, letter)
			end
		end

		if letter == "<" then
			for command, action in pairs(commands) do
				if string.sub(str, i, i + #command - 1) == command then
					if command == "<n>" then
						-- Create new line
						table.clear(word) -- Clear current word
						currentLineFrame = createNewLine()
						i = i + 3 -- Skip past "<n>"
					elseif command == "</" then
						action()
						i = i + (string.find(str, ">", i) or 0) - i + 1 
					elseif command == "<color=#" then -- custom way of handling the color command because it requires an input
						local hex = string.sub(str, i+8, i+13)
						local new = {color = Color3.fromHex(hex), bold = state[#state].bold, rainbow = state[#state].rainbow, shake = state[#state].shake, wave = state[#state].wave, waitTime = state[#state].waitTime, noanim = state[#state].noanim}
						table.insert(state, new)
						i = i + (string.find(str, ">", i) or 0) - i + 1
					elseif command == "<pause=" then
						local length = string.find(str, ">", i)
						local input = tonumber(string.sub(str, i + 7, length - 1))
						if input then
							print(input)
							-- Create a new state with the updated waitTime
							local new = {color = state[#state].color, bold = state[#state].bold, rainbow = state[#state].rainbow, shake = state[#state].shake, wave = state[#state].wave, waitTime = input, noanim = state[#state].noanim}
							-- Insert the new state at the beginning (overrides current waitTime)
							table.insert(state, new)
							print(new.waitTime)
						else
							warn("SWAGTEXT >> Invalid pause time provided in <pause= command.")
						end
						i = i + (string.find(str, ">", i) or 0) - i + 1
					else
						local new = action()
						table.insert(state, new)
						i = i + #command -- skip past the tag
					end
					break
				end
			end
		else

			local char = script.Assets.LetterFrame:Clone()

			if wordMode == 1 or wordMode == nil then
				char.Parent = wordLocation
				char.LayoutOrder = #wordLocation:GetChildren()
			else
				char.Parent = currentLineFrame
				char.LayoutOrder = #currentLineFrame:GetChildren()
			end

			char.TextLabel.Text = letter
			local current = state[#state] or default

			if font then
				char.TextLabel.Font = font
			else
				char.TextLabel.Font = Enum.Font.Arial
			end

			-- >> switched coroutine.wrap() to task.spawn(), a tad bit slower but a generally more stable method (courtesy of Indominiso)
			if current.shake then
				task.spawn(ShakeText, char.TextLabel)
			elseif current.wave then
				if delayTime == 0 then
					task.spawn(Wave, char.TextLabel, i/10)
				else
					task.spawn(Wave, char.TextLabel)
				end
			end

			if current.rainbow then
				task.spawn(RainbowText, char.TextLabel, (i * 5), i)
			else
				char.TextLabel.TextColor3 = current.color or default.color
			end

			if current.bold then
				char.TextLabel.RichText = true
				char.TextLabel.Text = "<b>"..letter.."</b>"
			end

			if current.italic then
				char.TextLabel.RichText = true
				char.TextLabel.Text = "<i>"..letter.."</i>"
			end

			if textSize then
				char.TextLabel.TextScaled = false
				char.TextLabel.TextSize = textSize
				char.AutomaticSize = Enum.AutomaticSize.XY
			end

			if typeof(extra) == "table" then
				for i, v in extra do
					v:Clone().Parent = char.TextLabel
				end
			elseif extra then
				extra:Clone().Parent = char.TextLabel
			end

			if current.noanim == false then
				TextAppear(char.TextLabel, mode)
			else
				print("awesome")
			end
			char.Name = "SWAGTEXT_LETTERFRAME"
			char.Visible = true
			i = i + 1

		end

		--print(letter, delayTime, s.waitTime)
		if state[#state].waitTime > 0 then
			print(state[#state].waitTime, delayTime)
			wait(state[#state].waitTime)
		elseif state[#state].waitTime == 0 then

		elseif delayTime ~= 0 then
			wait(delayTime)
		elseif delayTime == 0 then
			print("zero time!!")
		else
			wait(0.05)
		end
	end
end

function swagtext.ClearText(location)
	if location then
		for _, l in location:GetChildren() do
			if l.Name == "SWAGTEXT_WORDFRAME" or l.Name == "SWAGTEXT_LETTERFRAME" or l.Name == "SWAGTEXT_LINEFRAME" then
				l:Destroy()
			end
		end
	else
		warn("SWAGTEXT >> Cannot clear text because the location was invalid")	
	end
end

return swagtext
