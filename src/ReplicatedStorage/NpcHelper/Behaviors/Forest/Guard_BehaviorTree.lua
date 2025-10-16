--[[
    Guard Behavior Tree
    
    Guards have specific behavior:
    - Passive until attacked
    - Use structured attack patterns when aggro'd
    - Defensive stance with counter-attacks
    - Return to patrol after combat
]]

local Conditions = require(game.ReplicatedStorage.NpcHelper.Conditions)
local Trees = require(game.ReplicatedStorage.NpcHelper.Trees)

return function(TREE)
    local FALLBACK = TREE.fallback
    local SEQUENCE = TREE.sequence
    local INVERT = TREE.invert
    
    local function Condition(conditionName, ...)
        local extraArguments = { ... }
        return function(actor, mainConfig)
            local result = Conditions[conditionName](actor, mainConfig, table.unpack(extraArguments))
            return result
        end
    end
    
    local tree_composition
    tree_composition = {
        idle_sequence = function(TREE)
            return SEQUENCE({
                Condition("is_passive"),
                INVERT({Condition("is_aggressive")}),
                Condition("idle_at_spawn"),
            })
        end,
        
        aggressive_sequence = function(TREE)
            return SEQUENCE({
                Condition("enter_aggressive_mode"),
                Condition("is_aggressive"),
                FALLBACK({
                    SEQUENCE({
                        Condition("detect_enemy"),
                        Condition("follow_enemy"),
                    }),
                    Condition("detect_enemy"),
                })
            })
        end,
        
        target_sequence = function(TREE)
            return FALLBACK({
                -- Priority 1: Handle aggressive mode (when attacked)
                tree_composition.aggressive_sequence(TREE),

                -- Priority 2: If passive and not attacked, just idle
                tree_composition.idle_sequence(TREE),

                -- Priority 3: Follow if enemy detected
                Condition("follow_enemy"),
            })
        end,
        
        -- Guard-specific attack sequence using pattern system
        attack_sequence = function(tree)
            return FALLBACK({
                -- Priority 1: Use guard attack pattern when aggressive
                SEQUENCE({
                    Condition("can_act"), -- Check if NPC can act (not stunned)
                    Condition("is_aggressive"),
                    Condition("enemy_within_range", 25),
                    FALLBACK({
                        -- Use guard-specific attack pattern
                        Condition("guard_attack_pattern"),
                        -- Fallback to intelligent attack if pattern fails
                        Condition("intelligent_attack"),
                        -- Last resort: basic attack
                        Condition("npc_attack"),
                    }),
                }),

                -- Priority 2: Normal attack when in range but not aggressive
                SEQUENCE({
                    Condition("can_act"), -- Check if NPC can act (not stunned)
                    Condition("enemy_within_range", 15),
                    FALLBACK({
                        Condition("intelligent_attack"),
                        Condition("npc_attack"),
                    }),
                }),
            })
        end,
        
        defense_sequence = function(tree)
            return FALLBACK({
                -- Priority 1: Smart defense - react intelligently to player actions
                Condition("smart_defense"),

                -- Priority 2: Dodge guardbreak attacks
                SEQUENCE({
                    Condition("enemy_attacking_with", "Guardbreak"),
                    Condition("dash", "Back"),
                }),

                -- Removed automatic blocking - smart_defense handles this with randomness now
                -- Priority 3: Block if enemy is attacking
                -- SEQUENCE({
                --     Condition("enemy_has_state", "Attacking"),
                --     Condition("block"),
                -- }),

                -- Priority 3: Stop blocking if not needed
                Condition("stop_block"),
            })
        end,
        
        combat_sequence = function(tree)
            return FALLBACK({
                -- Priority 1: If aggressive, engage in combat with pattern
                SEQUENCE({
                    Condition("is_aggressive"),
                    FALLBACK({
                        -- Priority 1: Dash to reposition (moved up - dash more often!)
                        SEQUENCE({
                            Condition("should_dash"),
                            FALLBACK({
                                Condition("dash", "Left"),
                                Condition("dash", "Right"),
                                Condition("dash", "Back"),
                                Condition("dash", "Forward"),
                            }),
                        }),

                        -- Priority 2: Smart defense - always check for player actions
                        tree_composition.defense_sequence(TREE),

                        -- Priority 3: Attack with guard pattern
                        tree_composition.attack_sequence(TREE),
                    }),
                }),

                -- Priority 2: Normal combat if not passive
                SEQUENCE({
                    INVERT({ Condition("is_passive") }),
                    FALLBACK({
                        SEQUENCE({
                            Condition("enemy_has_state", "Attacking"),
                            tree_composition.defense_sequence(TREE),
                        }),
                        FALLBACK({
                            Condition("stop_block"),
                            Condition("always_true"),
                        }),
                        tree_composition.attack_sequence(TREE),
                    }),
                }),

                -- Priority 3: If passive and not aggressive, just idle
                SEQUENCE({
                    Condition("is_passive"),
                    INVERT({Condition("is_aggressive")}),
                    tree_composition.idle_sequence(TREE),
                }),
            })
        end,
    }
    
    return SEQUENCE({
        Trees.default_brain_sequence(TREE),
        tree_composition.target_sequence(TREE),
        tree_composition.combat_sequence(TREE),
    })
end

