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
				Condition("idle_at_spawn"),
			})
		end,

		target_sequence = function(TREE)
			return FALLBACK({
				-- If passive and not attacked, skip targeting
				tree_composition.idle_sequence(TREE),

				-- Original targeting logic
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
			local function long_distance_attack(TREE)
				return Condition("always_false")
			end
			local function medium_distance_attack(TREE)
				return Condition("always_false")
			end
			local function close_distance_attack(TREE)
				return FALLBACK({
					SEQUENCE({
						Condition("enemy_has_state", "Attacking", "M1"),
						--FALLBACK {
						--	Condition('use_guard_break'), --guqardbreak skils or m2
						--	SEQUENCE {
						--		Condition('wait_for_hit', 0.5), -- waits for the npc to land a hit for half a second
						--		Condition('repeat_action', "M1", 4), -- repeats the m1 action 4 times
						--		Condition('use_finisher'), -- skills that knockback

						--	},
						--},
					}),
					--SEQUENCE {
					--	INVERT{Condition('enemy_has_state', "Blocking")},
					--	FALLBACK {
					--		Condition('use_m1s_or_combo_starters'),
					--		SEQUENCE {
					--			Condition('wait_for_hit', 1), -- waits for the npc to land a hit for 1s
					--			Condition('repeat_action', "M1", 4), -- repeats the m1 action 4 times
					--			Condition('use_finisher'), -- skills that knockback
					--		},
					--		Condition('curve_dash_behind_player'),
					--	},
					--},
					--SEQUENCE {
					--	Condition('enemy_has_state', "Blocking"),
					--	FALLBACK {
					--		Condition('use_guard_break'), --guqardbreak skils or m2
					--		SEQUENCE {
					--			Condition('wait_for_hit', 0.5), -- waits for the npc to land a hit for half a second
					--			Condition('repeat_action', "M1", 4), -- repeats the m1 action 4 times
					--			Condition('use_finisher'), -- skills that knockback

					--		},
					--	},
					--},
				})
			end
			return FALLBACK({
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
				-- Only engage in combat if not passive or has been attacked
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

				-- If passive, just idle
				tree_composition.idle_sequence(TREE),
			})
		end,
	}

	return SEQUENCE({

		Trees.default_brain_sequence(TREE),
		tree_composition.target_sequence(TREE),
		tree_composition.combat_sequence(TREE),
	})
end
