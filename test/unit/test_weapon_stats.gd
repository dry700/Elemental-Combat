extends GutTest
## Unit tests for WeaponStats.resolve_swing() — A.4's rune fork and the
## Base/+Rune Charge table.

func test_light_weapon_no_rune_base_charge_is_1():
	var w := WeaponStats.new()
	w.weight = WeaponStats.Weight.LIGHT
	w.innate_element = Elements.HOA
	assert_eq(w.resolve_swing().charge, 1)

func test_heavy_weapon_no_rune_base_charge_is_2():
	var w := WeaponStats.new()
	w.weight = WeaponStats.Weight.HEAVY
	w.innate_element = Elements.KIM
	assert_eq(w.resolve_swing().charge, 2)

func test_same_element_rune_adds_plus_one_to_light_weapon():
	var w := WeaponStats.new()
	w.weight = WeaponStats.Weight.LIGHT
	w.innate_element = Elements.HOA
	w.rune_element = Elements.HOA
	assert_eq(w.resolve_swing().charge, 2)

func test_same_element_rune_on_heavy_weapon_reaches_charge_ceiling_of_3():
	var w := WeaponStats.new()
	w.weight = WeaponStats.Weight.HEAVY
	w.innate_element = Elements.KIM
	w.rune_element = Elements.KIM
	assert_eq(w.resolve_swing().charge, 3)

func test_different_element_rune_grants_no_charge_bonus():
	var w := WeaponStats.new()
	w.weight = WeaponStats.Weight.HEAVY
	w.innate_element = Elements.HOA
	w.rune_element = Elements.THO
	assert_eq(w.resolve_swing().charge, 2, "different-element rune trades +1 for alternation")

func test_different_element_rune_alternates_starting_with_innate():
	var w := WeaponStats.new()
	w.weight = WeaponStats.Weight.LIGHT
	w.innate_element = Elements.HOA
	w.rune_element = Elements.THO
	assert_eq(w.resolve_swing().element, Elements.HOA, "first swing uses innate")
	assert_eq(w.resolve_swing().element, Elements.THO, "second swing alternates")
	assert_eq(w.resolve_swing().element, Elements.HOA, "third swing alternates back")

func test_new_weapon_stats_have_sane_lunge_range_and_combo_defaults():
	var w := WeaponStats.new()
	assert_eq(w.lunge_speed, 75.0)
	assert_eq(w.reach, 7.0)
	assert_eq(w.hitbox_radius, 5.0)
	assert_eq(w.combo_steps.size(), 1)
	assert_almost_eq(w.combo_damage_step_multiplier, 1.0, 0.01)

func test_new_weapon_stats_have_default_perfect_hit_values():
	var w := WeaponStats.new()
	assert_eq(w.perfect_condition, WeaponStats.PerfectCondition.NONE)
	assert_almost_eq(w.perfect_multiplier, 1.5, 0.01)

func test_dagger_streak_requires_six_hits_and_resets_on_gap_or_swap():
	var dagger := WeaponStats.new()
	dagger.perfect_condition = WeaponStats.PerfectCondition.STREAK
	dagger.perfect_multiplier = 1.5
	var player := Player.new()
	player.weapon = dagger
	player._active_weapon = dagger
	for i in range(5):
		assert_false(player._advance_perfect_streak_and_check(), "first five hits are not yet a perfect streak")
	assert_true(player._advance_perfect_streak_and_check(), "the sixth hit qualifies as a perfect streak")
	player._perfect_streak_last_hit_time = Time.get_ticks_msec() / 1000.0 - 2.1
	assert_false(player._advance_perfect_streak_and_check(), "a 2s gap resets the streak")
	player.swap_weapon(true, WeaponStats.new())
	assert_false(player._advance_perfect_streak_and_check(), "weapon swap resets the streak")
