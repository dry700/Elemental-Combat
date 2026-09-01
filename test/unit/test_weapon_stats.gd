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
	assert_eq(w.lunge_speed, 150.0)
	assert_eq(w.reach, 14.0)
	assert_eq(w.hitbox_radius, 10.0)
	assert_eq(w.combo_length, 1)
	assert_almost_eq(w.combo_damage_step_multiplier, 1.0, 0.01)
