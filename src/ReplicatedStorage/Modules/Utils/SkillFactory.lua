--[[
    Skill Factory
    
    Helper module to create weapon and alchemy skills with the WeaponSkillHold system.
    
    Usage:
        local SkillFactory = require(ReplicatedStorage.Modules.Utils.SkillFactory)
        
        -- Create weapon skill (can be held if no body movers)
        local StoneLance = SkillFactory.CreateWeaponSkill({
            name = "Stone Lance",
            animation = animations.StoneLance,
            hasBodyMovers = false,
            damage = 50,
            cooldown = 8,
            execute = function(self, player, character, holdDuration)
                -- Your skill logic here
                -- print(`Stone Lance held for {holdDuration}s`)
            end
        })
        
        -- Create alchemy skill (always executes immediately)
        local FlameBurst = SkillFactory.CreateAlchemySkill({
            name = "Flame Burst",
            animation = animations.FlameBurst,
            damage = 40,
            cooldown = 5,
            execute = function(self, player, character, holdDuration)
                -- Your alchemy logic here
                -- print("Flame Burst executed")
            end
        })
]]

local WeaponSkillHold = require(script.Parent.WeaponSkillHold)

local SkillFactory = {}

-- Create a weapon skill
function SkillFactory.CreateWeaponSkill(config)
	assert(config.name, "Weapon skill must have a name")
	assert(config.animation, "Weapon skill must have an animation")
	assert(config.execute, "Weapon skill must have an execute function")
	
	local skill = WeaponSkillHold.new({
		name = config.name,
		animation = config.animation,
		skillType = "weapon",
		hasBodyMovers = config.hasBodyMovers or false,
		damage = config.damage or 0,
		cooldown = config.cooldown or 0
	})
	
	-- Override Execute method with custom logic
	skill.Execute = config.execute
	
	return skill
end

-- Create an alchemy skill
function SkillFactory.CreateAlchemySkill(config)
	assert(config.name, "Alchemy skill must have a name")
	assert(config.animation, "Alchemy skill must have an animation")
	assert(config.execute, "Alchemy skill must have an execute function")
	
	local skill = WeaponSkillHold.new({
		name = config.name,
		animation = config.animation,
		skillType = "alchemy",
		hasBodyMovers = false, -- Doesn't matter for alchemy
		damage = config.damage or 0,
		cooldown = config.cooldown or 0
	})
	
	-- Override Execute method with custom logic
	skill.Execute = config.execute
	
	return skill
end

return SkillFactory

