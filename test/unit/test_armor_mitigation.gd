extends GutTest
## Unit tests for ElementalCombatant armor mitigation.

var combatant: ElementalCombatant

func before_each():
	combatant = ElementalCombatant.new()
	combatant.show_debug_readout = false
	add_child_autofree(combatant)

func test_zero_armor_is_identity():
	combatant.armor = 0.0
	assert_almost_eq(combatant.mitigate_damage(25.0), 25.0, 0.001)

func test_ten_armor_reduces_damage_by_expected_ratio():
	combatant.armor = 10.0
	assert_almost_eq(combatant.mitigate_damage(100.0), 100.0 * 100.0 / 110.0, 0.001)

func test_one_hundred_armor_halves_damage():
	combatant.armor = 100.0
	assert_almost_eq(combatant.mitigate_damage(100.0), 50.0, 0.001)

func test_active_armor_buff_adds_to_base_armor():
	combatant.armor = 10.0
	combatant.armor_buff.apply(10.0, 2.0)
	assert_almost_eq(combatant.mitigate_damage(100.0), 100.0 * 100.0 / 120.0, 0.001)

func test_expired_armor_buff_no_longer_mitigates_damage():
	combatant.armor = 10.0
	combatant.armor_buff.apply(10.0, 1.0)
	combatant.tick(1.0)
	assert_almost_eq(combatant.mitigate_damage(100.0), 100.0 * 100.0 / 110.0, 0.001)

func test_sever_shreds_base_armor_but_preserves_active_buff():
	combatant.armor = 10.0
	combatant.armor_buff.apply(10.0, 2.0)
	var attacker := Node2D.new()
	add_child_autofree(attacker)
	combatant._apply_sever_burst(3.0, attacker)
	assert_almost_eq(combatant.mitigate_damage(100.0), 100.0 * 100.0 / 117.0, 0.001)