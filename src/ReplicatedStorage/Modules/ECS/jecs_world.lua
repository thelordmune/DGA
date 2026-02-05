local jecs = require(game:GetService("ReplicatedStorage").Modules.Imports.jecs)

-- IMPORTANT: Tags must be required BEFORE creating the world
-- jecs.tag() pre-registers tag entities that get allocated when the world is created
-- This ensures stable entity IDs and proper tag behavior (zero storage)
local _tags = require(script.Parent.jecs_tags)

return jecs.World.new() :: jecs.World