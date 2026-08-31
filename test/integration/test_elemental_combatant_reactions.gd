extends GutTest
## Integration tests for ElementalCombatant.handle_hit() — all ten A.2
## named reactions, plus ICD and Break-Free as they actually land on a
## real combatant.
##
## Scoped to each reaction's DIRECT, guaranteed effects (status, dot,
## slow, disable, armor, and same-tree AoE via get_nodes_in_group).
## Cinder Bloom / Ore Surge / Douse also spawn a Zone/SteamCloud via
## get_tree().current_scene, which a bare test scene leaves null — those
## calls no-op safely rather than crash, so this file doesn't assert on
## them; that footprint layer is better verified by playtest, per
## Section 8.1's own evaluation split.

const CombatantOwner := preload("res://test/helpers/combatant_owner.gd")

var target: ElementalCombatant
var attacker: Node2D

func before_each():
	target = ElementalCombatant.new()
	target.show_debug_readout = false
	add_child_autofree(target)
	attacker = Node2D.new()
	add_child_autofree(attacker)

func _hit(element: StringName, charge: int) -> HitData:
	var hit_data := HitData.new(0.0, Vector2.ZERO, attacker)
	hit_data.element = element
	hit_data.charge = charge
	return hit_data

# --- Sinh ---

func test_condensation_tier1_slows_and_leaves_generated_water():
	target.status.apply(Elements.THUY, 1)
	target.handle_hit(_hit(Elements.KIM, 1))
	assert_eq(target.status.element, Elements.THUY)
	assert_true(target.slow_effect.active)
	assert_almost_eq(target.slow_effect.speed_multiplier, 0.7, 0.01)

func test_condensation_tier2_slows_more_at_charge_2():
	target.status.apply(Elements.THUY, 2)
	target.handle_hit(_hit(Elements.KIM, 2))
	assert_almost_eq(target.slow_effect.speed_multiplier, 0.5, 0.01)

func test_overgrowth_roots_dots_and_tags_self():
	target.status.apply(Elements.MOC, 1)
	target.handle_hit(_hit(Elements.THUY, 1))
	assert_true(target.disable_effect.is_active(), "rooted")
	assert_true(target.dot_effect.active)
	assert_true(target.is_in_group(ElementalCombatant.OVERGROWTH_GROUP))

func test_overgrowth_spreads_to_a_nearby_combatant():
	var bystander_target := ElementalCombatant.new()
	bystander_target.show_debug_readout = false
	add_child_autofree(bystander_target)
	bystander_target.global_position = target.global_position + Vector2(50, 0)  # inside OVERGROWTH_RADIUS

	target.status.apply(Elements.MOC, 1)
	target.handle_hit(_hit(Elements.THUY, 1))

	assert_true(bystander_target.disable_effect.is_active())
	assert_true(bystander_target.is_in_group(ElementalCombatant.OVERGROWTH_GROUP))

func test_overgrowth_excludes_the_attacker_as_a_bystander():
	var attacker_owner := CombatantOwner.new()
	var attacker_elemental := ElementalCombatant.new()
	attacker_elemental.show_debug_readout = false
	add_child_autofree(attacker_owner)
	attacker_owner.add_child(attacker_elemental)
	attacker_owner.elemental = attacker_elemental
	attacker_owner.global_position = target.global_position

	target.status.apply(Elements.MOC, 1)
	var hit_data := HitData.new(0.0, Vector2.ZERO, attacker_owner)
	hit_data.element = Elements.THUY
	hit_data.charge = 1
	target.handle_hit(hit_data)

	assert_false(attacker_elemental.disable_effect.is_active(), "attacker's own combatant must be excluded")

func test_wildfire_chains_to_an_overgrowth_linked_combatant():
	var linked := ElementalCombatant.new()
	linked.show_debug_readout = false
	add_child_autofree(linked)
	linked.global_position = target.global_position + Vector2(80, 0)  # inside WILDFIRE_CHAIN_RADIUS
	linked.add_to_group(ElementalCombatant.OVERGROWTH_GROUP)
	linked.status.apply(Elements.MOC, 1)

	watch_signals(linked)
	target.status.apply(Elements.MOC, 1)
	target.handle_hit(_hit(Elements.HOA, 1))

	assert_eq(target.status.element, Elements.HOA, "direct target catches fire")
	assert_eq(linked.status.element, Elements.HOA, "chained target's Wood becomes Fire, not blank")
	assert_true(linked.dot_effect.active)
	assert_false(linked.is_in_group(ElementalCombatant.OVERGROWTH_GROUP), "consumed by the chain")
	assert_signal_emitted(linked, "bonus_damage_dealt")

func test_cinder_bloom_applies_earth_and_burns_nearby():
	var nearby := ElementalCombatant.new()
	nearby.show_debug_readout = false
	add_child_autofree(nearby)
	nearby.global_position = target.global_position + Vector2(60, 0)  # inside CINDER_BLOOM_BURN_RADIUS

	target.status.apply(Elements.THO, 1)
	target.handle_hit(_hit(Elements.HOA, 1))

	assert_eq(target.status.element, Elements.THO)
	assert_true(target.dot_effect.active)
	assert_true(nearby.dot_effect.active, "AoE burn should reach a nearby combatant too")

func test_ore_surge_applies_generated_metal_status():
	target.status.apply(Elements.KIM, 1)
	target.handle_hit(_hit(Elements.THO, 1))
	assert_eq(target.status.element, Elements.KIM)

# --- Khắc ---

func test_molten_full_clear_applies_base_dot():
	target.status.apply(Elements.KIM, 1)
	target.handle_hit(_hit(Elements.HOA, 1))
	assert_false(target.status.has_status())
	assert_almost_eq(target.dot_effect.damage_per_tick, 3.0, 0.01)

func test_molten_thua_applies_stronger_dot():
	target.status.apply(Elements.KIM, 1)
	target.handle_hit(_hit(Elements.HOA, 3))  # incoming 3 vs remaining 1 -> Thừa
	assert_almost_eq(target.dot_effect.damage_per_tick, 5.0, 0.01)

func test_silt_full_clear_applies_base_slow():
	target.status.apply(Elements.THUY, 1)
	target.handle_hit(_hit(Elements.THO, 1))
	assert_almost_eq(target.slow_effect.speed_multiplier, 0.6, 0.01)

func test_silt_thua_applies_stronger_slow():
	target.status.apply(Elements.THUY, 1)
	target.handle_hit(_hit(Elements.THO, 3))
	assert_almost_eq(target.slow_effect.speed_multiplier, 0.4, 0.01)

func test_root_break_full_clear_applies_base_stagger():
	target.status.apply(Elements.THO, 1)
	target.handle_hit(_hit(Elements.MOC, 1))
	assert_almost_eq(target.disable_effect.get_remaining_duration(), 0.6, 0.01)

func test_root_break_thua_applies_longer_stagger():
	target.status.apply(Elements.THO, 1)
	target.handle_hit(_hit(Elements.MOC, 3))
	assert_almost_eq(target.disable_effect.get_remaining_duration(), 1.1, 0.01)

func test_root_break_burst_staggers_a_nearby_combatant_too():
	var nearby := ElementalCombatant.new()
	nearby.show_debug_readout = false
	add_child_autofree(nearby)
	nearby.global_position = target.global_position + Vector2(60, 0)  # inside BURST_RADIUS

	target.status.apply(Elements.THO, 1)
	target.handle_hit(_hit(Elements.MOC, 1))

	assert_true(nearby.disable_effect.is_active(), "Burst should stagger nearby combatants too")

func test_sever_full_clear_shreds_base_armor():
	target.armor = 10.0
	target.status.apply(Elements.MOC, 1)
	target.handle_hit(_hit(Elements.KIM, 1))
	assert_almost_eq(target.armor, 7.0, 0.01)

func test_sever_thua_shreds_more_armor():
	target.armor = 10.0
	target.status.apply(Elements.MOC, 1)
	target.handle_hit(_hit(Elements.KIM, 3))
	assert_almost_eq(target.armor, 4.0, 0.01)

func test_sever_armor_never_goes_below_zero():
	target.armor = 2.0
	target.status.apply(Elements.MOC, 1)
	target.handle_hit(_hit(Elements.KIM, 3))  # would shred 6.0
	assert_eq(target.armor, 0.0)

func test_sever_burst_shreds_a_nearby_combatant_too():
	var nearby := ElementalCombatant.new()
	nearby.show_debug_readout = false
	add_child_autofree(nearby)
	nearby.armor = 10.0
	nearby.global_position = target.global_position + Vector2(60, 0)  # inside BURST_RADIUS

	target.armor = 10.0
	target.status.apply(Elements.MOC, 1)
	target.handle_hit(_hit(Elements.KIM, 1))

	assert_almost_eq(nearby.armor, 7.0, 0.01, "Burst should shred armor on nearby combatants too")

func test_sever_burst_excludes_the_attacker_as_a_bystander():
	var attacker_owner := CombatantOwner.new()
	var attacker_elemental := ElementalCombatant.new()
	attacker_elemental.show_debug_readout = false
	add_child_autofree(attacker_owner)
	attacker_owner.add_child(attacker_elemental)
	attacker_owner.elemental = attacker_elemental
	attacker_owner.global_position = target.global_position
	attacker_elemental.armor = 10.0

	target.armor = 10.0
	target.status.apply(Elements.MOC, 1)
	var hit_data := HitData.new(0.0, Vector2.ZERO, attacker_owner)
	hit_data.element = Elements.KIM
	hit_data.charge = 1
	target.handle_hit(hit_data)

	assert_eq(attacker_elemental.armor, 10.0, "attacker's own combatant must be excluded from the Burst")

func test_douse_clears_the_burn_status():
	target.status.apply(Elements.HOA, 1)
	target.handle_hit(_hit(Elements.THUY, 1))
	assert_false(target.status.has_status())

func test_khac_partial_reduces_charge_and_grazes_without_clearing():
	# NOTE: under the current Charge grid, every PARTIAL cell (1v2, 2v3)
	# leaves charge - incoming = 1, never 0 — so handle_hit()'s defensive
	# "if status.charge <= 0: status.clear()" branch is currently
	# unreachable. Flagging this as a genuine QA observation, not a bug.
	target.status.apply(Elements.KIM, 2)
	target.handle_hit(_hit(Elements.HOA, 1))  # 1 vs 2 -> partial
	assert_eq(target.status.charge, 1, "charge reduced by the incoming amount, not cleared")
	assert_true(target.status.has_status())
	assert_true(target.disable_effect.is_active(), "universal graze")

func test_khac_vu_reverses_the_graze_onto_the_attacker():
	var attacker_owner := CombatantOwner.new()
	var attacker_elemental := ElementalCombatant.new()
	attacker_elemental.show_debug_readout = false
	add_child_autofree(attacker_owner)
	attacker_owner.add_child(attacker_elemental)
	attacker_owner.elemental = attacker_elemental

	target.status.apply(Elements.KIM, 3)  # remaining = 3
	var hit_data := HitData.new(0.0, Vector2.ZERO, attacker_owner)
	hit_data.element = Elements.HOA
	hit_data.charge = 1  # incoming = 1 -> Vũ
	target.handle_hit(hit_data)

	assert_eq(target.status.element, Elements.KIM, "target's status is untouched by Vũ")
	assert_eq(target.status.charge, 3)
	assert_true(attacker_elemental.disable_effect.is_active(), "attacker takes the graze instead")

# --- ICD / Break-Free ---

func test_icd_blocks_a_second_hit_of_the_same_element_within_the_window():
	target.status.apply(Elements.KIM, 1)
	target.handle_hit(_hit(Elements.HOA, 1))  # Molten fires, clears status
	target.status.apply(Elements.KIM, 1)      # re-apply directly, bypassing ICD, for the second check
	target.handle_hit(_hit(Elements.HOA, 1))  # should be BLOCKED — still on cooldown
	assert_true(target.status.has_status(), "second Molten should have been blocked by ICD")

func test_icd_does_not_block_a_different_element_from_the_same_attacker():
	target.status.apply(Elements.KIM, 1)
	target.handle_hit(_hit(Elements.HOA, 1))  # Molten fires; Hỏa now on cooldown for this attacker
	target.status.apply(Elements.MOC, 1)
	target.handle_hit(_hit(Elements.THO, 1))  # different element -> not gated
	assert_false(target.status.has_status(), "Root Break should still have fired despite Hỏa's ICD window")

func test_break_free_press_reduces_an_active_disable():
	target.disable_effect.apply(2.0, 0.5)
	target.break_free_press()
	assert_almost_eq(target.disable_effect.get_remaining_duration(), 1.6, 0.01)
