local Conditions = require(game.ReplicatedStorage.NpcHelper.Conditions)

return function(TREE)
	local FALLBACK = TREE.fallback
	local SEQUENCE = TREE.sequence
	local INVERT = TREE.invert

	-- was gettin a lil recessive having to spam function(actor, mainconfig) for each node nd shi so we just gon do it like this
	local function Condition(conditionName, ...)
		local extraArguments = ...
		return function(actor, mainConfig)
			return Conditions[conditionName](actor, mainConfig, extraArguments)
		end
	end

	local tree_composition = {
		brain_sequence = function(TREE)

			return FALLBACK {

				SEQUENCE {
					--Condition("debug_print", "continued sequence"),
					Condition('spawn_entity')
				},


				SEQUENCE {

					Condition('manage_humanoid_state'),

					FALLBACK {
						Condition('npc_healing'),
						Condition("always_true") 
					},


					FALLBACK { -- if tp back sequence returns false then itll keep going, which wont prevent the upper sequence from working (1/2)
						SEQUENCE{  -- if tp back (1/3)
							Condition('should_teleport_back'), 
							Condition('teleport_to_spawn'), -- then tp back (2/3)
						}, -- and if it tp backs (the always true) wont run (3/3)
						
						Condition("always_true") -- cuz of always true (2/2)
					},

					FALLBACK {
                        
                        -- enemy detection (only if not passive or has been attacked)
                        SEQUENCE {
                            FALLBACK {
                                INVERT{Condition('is_passive')}, -- not passive, can detect
                                Condition('has_been_attacked'), -- or has been attacked
                            },
                            Condition('detect_enemy'),
                        },
                        
                        -- if no enemy and far then it walks back
                        SEQUENCE{  
                            Condition('should_walk_back'), 
                            Condition('walk_to_spawn'), 
                        },
                        
                        -- else wander or idle at spawn
                        FALLBACK {
                            -- If passive, just idle at spawn
                            SEQUENCE {
                                Condition('is_passive'),
                                Condition('idle_at_spawn'),
                            },
                            
                            -- Otherwise wander normally
                            SEQUENCE {
                                Condition('should_wander'), -- first it checks if npc is elligble to wander
                                Condition('wander') -- walks to the point that has been generated	
                            }
                        }
                    },
				},

			}
		end,
	}	

	return SEQUENCE {
		
		tree_composition.brain_sequence(TREE),
		--tree_composition.target_sequence(TREE),
		--tree_composition.combat_sequence(TREE)

	}
end