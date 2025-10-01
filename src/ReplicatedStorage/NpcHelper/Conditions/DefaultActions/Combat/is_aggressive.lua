-- Function to check if NPC is in aggressive mode
return function(actor: Actor, mainConfig: table)
    local npc = actor:FindFirstChildOfClass("Model")
    if not npc then
        return false
    end

    -- Check if NPC is in aggressive mode
    if mainConfig.States and mainConfig.States.AggressiveMode then
        -- Optional: Add timeout for aggressive mode (e.g., 60 seconds)
        local aggressiveTimeout = 60  -- seconds
        local startTime = mainConfig.States.AggressiveModeStartTime or 0

        if os.clock() - startTime > aggressiveTimeout then
            -- Timeout reached, exit aggressive mode
            -- print("NPC", npc.Name, "aggressive mode timeout, returning to normal")
            mainConfig.States.AggressiveMode = false
            mainConfig.States.IsPassive = true  -- Return to passive if they were originally passive
            return false
        end

        -- print("is_aggressive check for", npc.Name, "- returning TRUE")
        return true
    end

    -- print("is_aggressive check for", npc.Name, "- returning FALSE (not in aggressive mode)")
    return false
end
