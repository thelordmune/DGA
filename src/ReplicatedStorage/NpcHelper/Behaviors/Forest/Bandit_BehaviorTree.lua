local Conditions = require(game.ReplicatedStorage.NpcHelper.Conditions)
local Trees = require(game.ReplicatedStorage.NpcHelper.Trees)

return function(TREE)
	local FALLBACK = TREE.fallback
	local SEQUENCE = TREE.sequence
	local INVERT = TREE.invert
	-- was gettin a lil recessive having to spam function(actor, mainconfig) for each node nd shi so we just gon do it like this
	local function Condition(conditionName, ...)
		local extraArguments = { ... }
		return function(actor, mainConfig)
			local result = Conditions[conditionName](actor, mainConfig, table.unpack(extraArguments))

			--print("Condition:", conditionName, "Result:", result)

			return result
		end
	end

	local tree_composition
	tree_composition = {
		idle_sequence = function(TREE)
			return SEQUENCE({
				Condition("is_passive"),
				INVERT({Condition("is_aggressive")}), -- Don't idle if aggressive
				Condition("idle_at_spawn"),
			})
		end,

		aggressive_sequence = function(TREE)
			return SEQUENCE({
				Condition("enter_aggressive_mode"), -- Check if should enter aggressive mode
				Condition("is_aggressive"), -- Confirm we're in aggressive mode
				FALLBACK({
					-- If we have a target from being attacked, pursue them
					SEQUENCE({
						Condition("detect_enemy"),
						Condition("follow_enemy"),
					}),
					-- Otherwise search for enemies more aggressively
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

				-- Priority 3: Original targeting logic for normal behavior
				SEQUENCE({
					FALLBACK({
						SEQUENCE({
							FALLBACK({ -- CONDITIONS TO SPRINT
								Condition("is_low_health"),
								Condition("should_sprint_on_follow"),
							}),
							Condition("sprint"),
						}),
						Condition("stop_sprint"),
					}),
					Condition("always_false"),
				}),

				SEQUENCE({
					Condition("is_low_health"),
					Condition("run_away"),
				}),

				Condition("follow_enemy"),
			})
		end,

		attack_sequence = function(tree)
			local function aggressive_attack_loop(TREE)
				return SEQUENCE({
					Condition("is_aggressive"),
					Condition("enemy_within_range", 25),
					FALLBACK({
						-- Use intelligent attack system when aggressive
						SEQUENCE({
							Condition("enemy_within_range", 15),
							FALLBACK({
								Condition("intelligent_attack"), -- Try intelligent attack first
								Condition("npc_continuous_attack"),  -- Fallback to continuous attack
							}),
						}),
						-- Move closer if too far
						SEQUENCE({
							INVERT({Condition("enemy_within_range", 15)}),
							Condition("follow_enemy"),
						}),
					})
				})
			end

			local function long_distance_attack(TREE)
				return SEQUENCE({
					Condition("enemy_within_range", 25),
					INVERT({Condition("enemy_within_range", 15)}),
					FALLBACK({
						Condition("intelligent_attack"), -- Use intelligent attack
						Condition("npc_attack"), -- Fallback to basic attack
					}),
				})
			end
			local function medium_distance_attack(TREE)
				return SEQUENCE({
					Condition("enemy_within_range", 15),
					INVERT({Condition("enemy_within_range", 8)}),
					FALLBACK({
						Condition("intelligent_attack"), -- Use intelligent attack
						Condition("npc_attack"), -- Fallback to basic attack
					}),
				})
			end
			local function close_distance_attack(TREE)
				return FALLBACK({
					SEQUENCE({
						Condition("enemy_has_state", "Attacking", "M1"),
						Condition("block"), -- Block if enemy is attacking
					}),
					SEQUENCE({
						Condition("enemy_within_range", 15),
						FALLBACK({
							Condition("intelligent_attack"), -- Use intelligent attack
							Condition("npc_attack"), -- Fallback to basic attack
						}),
					}),
				})
			end
			return FALLBACK({
				-- Priority 1: Aggressive attack loop when in aggressive mode
				aggressive_attack_loop(TREE),
				-- Priority 2: Normal attack patterns
				long_distance_attack(TREE),
				medium_distance_attack(TREE),
				close_distance_attack(TREE),
			})
		end,
		defense_sequence = function(tree)
			local function long_distance_attack(TREE)
				return Condition("always_false")
			end
			local function medium_distance_attack(TREE)
				return Condition("always_false")
			end
			local function close_distance_attack(TREE)
				return FALLBACK({
					--SEQUENCE {
					--	Condition('enemy_has_state', "Attacking", "M1"),
					--	Condition('block'),
					--},

					SEQUENCE({
						Condition("enemy_attacking_with", "Guardbreak"),
						Condition("dash", "Back"),
					}),

					FALLBACK({

						SEQUENCE({
							FALLBACK({ -- CONDITIONS TO BLOCK
								Condition("enemy_has_state", "Attacking", "M1"),
							}),
							Condition("block"),
						}),
						Condition("stop_block"),
					}),
				})
			end
			return FALLBACK({
				long_distance_attack(TREE),
				medium_distance_attack(TREE),
				SEQUENCE({
					Condition("enemy_within_range", 14),
					close_distance_attack(TREE),
				}),
			})
		end,
		combat_sequence = function(tree)
			return FALLBACK({
				-- Priority 1: If aggressive, always engage in combat
				SEQUENCE({
					Condition("is_aggressive"),
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
