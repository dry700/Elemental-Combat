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
	var player: Player = autofree(Player.new())
	player.weapon = dagger
	player._active_weapon = dagger
	for i in range(5):
		assert_false(player._advance_perfect_streak_and_check(), "first five hits are not yet a perfect streak")
	assert_true(player._advance_perfect_streak_and_check(), "the sixth hit qualifies as a perfect streak")
	var other_player: Player = autofree(Player.new())
	assert_false(other_player._advance_perfect_streak_and_check(), "streak state belongs to each wielder")
	player._perfect_streak_last_hit_time = Time.get_ticks_msec() / 1000.0 - 2.1
	assert_false(player._advance_perfect_streak_and_check(), "a 2s gap resets the streak")
	player.swap_weapon(true, WeaponStats.new())
	assert_false(player._advance_perfect_streak_and_check(), "weapon swap resets the streak")

func test_weapon_stats_condition_text():
	var w := WeaponStats.new()
	w.perfect_condition = WeaponStats.PerfectCondition.STREAK
	assert_eq(w.get_perfect_condition_text(), "6th landed hit in a streak")
	w.perfect_condition = WeaponStats.PerfectCondition.TARGET_SLOWED
	assert_eq(w.get_perfect_condition_text(), "Target is slowed")
	w.perfect_condition = WeaponStats.PerfectCondition.TARGET_DISABLED
	assert_eq(w.get_perfect_condition_text(), "Target is disabled")
	w.perfect_condition = WeaponStats.PerfectCondition.FINISHER
	assert_eq(w.get_perfect_condition_text(), "Combo finisher")
	w.perfect_condition = WeaponStats.PerfectCondition.PLUNGE
	assert_eq(w.get_perfect_condition_text(), "Plunge impact from a high apex")
	w.perfect_condition = WeaponStats.PerfectCondition.LONG_RANGE
	assert_eq(w.get_perfect_condition_text(), "Long distance hit")
	w.perfect_condition = WeaponStats.PerfectCondition.DODGE
	assert_eq(w.get_perfect_condition_text(), "Shortly after dodge")
	w.perfect_condition = WeaponStats.PerfectCondition.AIRBORNE
	assert_eq(w.get_perfect_condition_text(), "Attacking while airborne")
	w.perfect_condition = WeaponStats.PerfectCondition.CLOSE_RANGE
	assert_eq(w.get_perfect_condition_text(), "Point-blank range")
	w.perfect_condition = WeaponStats.PerfectCondition.TIP
	assert_eq(w.get_perfect_condition_text(), "Target near the tip of reach")
	w.perfect_condition = WeaponStats.PerfectCondition.LOW_HEALTH
	assert_eq(w.get_perfect_condition_text(), "Target below 30% health")
	w.perfect_condition = WeaponStats.PerfectCondition.NONE
	assert_eq(w.get_perfect_condition_text(), "")

func test_new_weapon_resources_load_with_valid_perfect_values_and_combo_steps():
	var paths: Array[String] = [
		"res://scripts/resources/weapons/dao.tres",
		"res://scripts/resources/weapons/song_kiem.tres",
		"res://scripts/resources/weapons/mau.tres",
		"res://scripts/resources/weapons/quan_dao.tres",
		"res://scripts/resources/weapons/lien_chau_no.tres",
		"res://scripts/resources/weapons/dinh_nam_dao.tres",
	]
	for path in paths:
		var weapon := load(path) as WeaponStats
		assert_not_null(weapon, "Weapon resource should load: %s" % path)
		if weapon == null:
			continue
		assert_gt(weapon.combo_steps.size(), 0, "Weapon must define at least one combo step: %s" % path)
		assert_true(weapon.perfect_multiplier >= 1.5)
		assert_true(weapon.perfect_multiplier <= 2.0)

func test_existing_weapon_resources_define_their_perfect_windows():
	var expected: Dictionary = {
		"training_dagger.tres": [WeaponStats.PerfectCondition.STREAK, 1.5],
		"training_spear.tres": [WeaponStats.PerfectCondition.TARGET_SLOWED, 1.75],
		"training_staff.tres": [WeaponStats.PerfectCondition.TARGET_DISABLED, 2.0],
		"training_greatsword.tres": [WeaponStats.PerfectCondition.FINISHER, 1.75],
		"training_hammer.tres": [WeaponStats.PerfectCondition.PLUNGE, 2.0],
		"training_bow.tres": [WeaponStats.PerfectCondition.LONG_RANGE, 1.5],
	}
	for filename in expected:
		var weapon := load("res://scripts/resources/weapons/" + filename) as WeaponStats
		assert_not_null(weapon)
		if weapon == null:
			continue
		assert_eq(weapon.perfect_condition, expected[filename][0], filename)
		assert_almost_eq(weapon.perfect_multiplier, expected[filename][1], 0.01, filename)

func test_scattershot_resource_has_five_projectiles_across_thirty_degree_cone():
	var weapon := load("res://scripts/resources/weapons/lien_chau_no.tres") as WeaponStats
	assert_not_null(weapon)
	assert_eq(weapon.projectile_count, 5)
	var angles := weapon.get_projectile_angles()
	assert_eq(angles.size(), 5)
	assert_almost_eq(angles[0], -15.0, 0.01)
	assert_almost_eq(angles[2], 0.0, 0.01)
	assert_almost_eq(angles[4], 15.0, 0.01)
