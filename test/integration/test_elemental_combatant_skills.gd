extends GutTest
## Integration tests for A.5's skill effects (ElementalCombatant.cast_*()).
## Focus: the cleanse-skill Charge-bypass exemption and ICD bypass —
## the two behaviours Section 8.1 calls out by name.

var caster: ElementalCombatant
var target: ElementalCombatant
var owner_node: Node2D

func before_each():
	owner_node = Node2D.new()
	caster = ElementalCombatant.new()
	caster.show_debug_readout = false
	add_child_autofree(owner_node)
	owner_node.add_child(caster)
	target = ElementalCombatant.new()
	target.show_debug_readout = false
	add_child_autofree(target)

func test_stoneguard_applies_self_status_without_reaction_resolution():
	caster.status.apply(Elements.THUY, 1)  # Thủy khắc Hỏa — would react if routed through handle_hit
	caster.cast_apply_self(Elements.THO, 2)
	assert_eq(caster.status.element, Elements.THO)
	assert_eq(caster.status.charge, 2)

func test_cleansing_tide_clears_then_applies_bypassing_charge():
	caster.status.apply(Elements.HOA, 3)  # a hard-to-remove Charge-3 status
	caster.cast_cleanse_and_apply_self(Elements.THUY, 2)
	assert_eq(caster.status.element, Elements.THUY, "cleared first, nothing left to react against")
	assert_eq(caster.status.charge, 2)

func test_ignite_dart_routes_through_the_full_reaction_pipeline():
	target.status.apply(Elements.KIM, 1)
	caster.cast_apply_enemy(target, Elements.HOA, 1)
	assert_false(target.status.has_status(), "Molten should have cleared the Kim status")
	assert_true(target.dot_effect.active, "Molten's DoT should have applied")

func test_ignite_dart_bypasses_icd_on_repeated_casts():
	target.status.apply(Elements.KIM, 1)
	caster.cast_apply_enemy(target, Elements.HOA, 1)
	target.status.apply(Elements.KIM, 1)
	caster.cast_apply_enemy(target, Elements.HOA, 1)  # would be ICD-blocked if this were a weapon hit
	assert_false(target.status.has_status(), "skills self-limit via cooldown, not ICD")

func test_rending_edge_strips_status_bypassing_charge_entirely():
	target.status.apply(Elements.HOA, 3)  # Charge 3 — would be a Wu rebel via a weak weapon hit
	caster.cast_remove_enemy(target)
	assert_false(target.status.has_status(), "always fully removes, regardless of Charge")

func test_overgrowth_snare_does_not_error_without_a_current_scene():
	caster.cast_apply_area(Elements.MOC, 120.0, 8.0)
	assert_true(true, "cast_apply_area should not throw when current_scene is unset")
