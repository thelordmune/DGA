local TweenService = game:GetService("TweenService")

-- Random character pool for slot machine effect
local RANDOM_CHARS = {"@", "#", "$", "%", "&", "*", "!", "?", "+", "=", "~", "0", "1", "2", "3", "4", "5", "6", "7", "8", "9"}

-- Slot machine animation for a single TextLabel
local function slotMachineTextLabel(textLabel, finalText, options)
	options = options or {}
	local duration = options.duration or 0.8
	local charDelay = options.charDelay or 0.03
	local fadeInTime = options.fadeInTime or 0.3

	-- Start with random characters for entire text
	local currentText = ""
	for i = 1, #finalText do
		local char = finalText:sub(i, i)
		if char == " " or char == ":" then
			currentText = currentText .. char
		else
			currentText = currentText .. RANDOM_CHARS[math.random(1, #RANDOM_CHARS)]
		end
	end

	-- Set initial random text
	textLabel.Text = currentText
	textLabel.TextTransparency = 1

	-- Fade in
	local fadeTween = TweenService:Create(
		textLabel,
		TweenInfo.new(fadeInTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{TextTransparency = 0}
	)
	fadeTween:Play()
	fadeTween.Completed:Wait()

	task.wait(0.1)

	-- Animate each character in the entire text (except spaces and colons)
	for charIndex = 1, #finalText do
		local finalChar = finalText:sub(charIndex, charIndex)

		-- Skip spaces and colons
		if finalChar == " " or finalChar == ":" then
			continue
		end

		task.spawn(function()
			local delay = (charIndex - 1) * charDelay
			task.wait(delay)

			local elapsed = 0
			local randomizeInterval = 0.05
			local lastUpdate = 0

			-- Randomization phase
			while elapsed < duration do
				local dt = task.wait()
				elapsed = elapsed + dt
				lastUpdate = lastUpdate + dt

				if lastUpdate >= randomizeInterval then
					lastUpdate = 0
					-- Build text with current state
					local newText = ""
					for i = 1, #finalText do
						local char = finalText:sub(i, i)
						if char == " " or char == ":" then
							newText = newText .. char
						elseif i < charIndex then
							-- Already settled
							newText = newText .. finalText:sub(i, i)
						elseif i == charIndex then
							-- Currently randomizing
							newText = newText .. RANDOM_CHARS[math.random(1, #RANDOM_CHARS)]
						else
							-- Not started yet
							newText = newText .. RANDOM_CHARS[math.random(1, #RANDOM_CHARS)]
						end
					end
					textLabel.Text = newText
				end
			end

			-- Set final state for this character
			local finalTextBuild = ""
			for i = 1, #finalText do
				local char = finalText:sub(i, i)
				if char == " " or char == ":" then
					finalTextBuild = finalTextBuild .. char
				elseif i <= charIndex then
					finalTextBuild = finalTextBuild .. finalText:sub(i, i)
				else
					finalTextBuild = finalTextBuild .. RANDOM_CHARS[math.random(1, #RANDOM_CHARS)]
				end
			end
			textLabel.Text = finalTextBuild
		end)
	end

	-- Wait for all animations to complete (count non-space/colon chars)
	local animatedChars = 0
	for i = 1, #finalText do
		local char = finalText:sub(i, i)
		if char ~= " " and char ~= ":" then
			animatedChars = animatedChars + 1
		end
	end
	local totalTime = ((animatedChars - 1) * charDelay) + duration
	task.wait(totalTime)

	-- Ensure final text is set
	textLabel.Text = finalText
end

return slotMachineTextLabel