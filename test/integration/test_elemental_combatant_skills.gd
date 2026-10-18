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

func test_area_burst_hits_only_nearby_targets_and_excludes_caster():
	var nearby := ElementalCombatant.new()
	nearby.show_debug_readout = false
	add_child_autofree(nearby)
	var distant := ElementalCombatant.new()
	distant.show_debug_readout = false
	distant.position = Vector2(200, 0)
	add_child_autofree(distant)
	var caster_damage := [0]
	var nearby_damage := [0]
	var distant_damage := [0]
	caster.bonus_damage_dealt.connect(func(_amount): caster_damage[0] += 1)
	nearby.bonus_damage_dealt.connect(func(_amount): nearby_damage[0] += 1)
	distant.bonus_damage_dealt.connect(func(_amount): distant_damage[0] += 1)
	caster.cast_area_burst(Elements.NONE, 50.0, 10.0)
	assert_eq(caster_damage[0], 0)
	assert_eq(nearby_damage[0], 1)
	assert_eq(distant_damage[0], 0)

func test_area_burst_control_uses_cc_resistance():
	target.cc_resistance.configure(0, 8.0)
	caster.cast_area_burst(Elements.NONE, 50.0, 0.0, 1.0)
	assert_true(target.disable_effect.active)
	assert_almost_eq(target.disable_effect.get_remaining_duration(), 0.5, 0.1)

func test_fan_cast_is_safe_without_current_scene():
	caster.cast_projectile_fan(Elements.MOC, 2, Vector2.RIGHT, 5, 40.0, 5.0, 220.0, 0.5, false, 0.0)
	assert_true(true)

func test_fan_spawns_count_with_even_spread_angles_when_scene_exists():
	var scene_root := Node2D.new()
	get_tree().root.add_child(scene_root)
	var previous_scene: Node = get_tree().current_scene
	get_tree().current_scene = scene_root
	caster.cast_projectile_fan(Elements.MOC, 2, Vector2.RIGHT, 3, 30.0, 5.0, 220.0, 0.5, false, 0.0)
	var shots: Array[Node] = scene_root.get_children()
	assert_eq(shots.size(), 3)
	assert_almost_eq(rad_to_deg(shots[0].direction.angle()), -15.0, 0.01)
	assert_almost_eq(rad_to_deg(shots[1].direction.angle()), 0.0, 0.01)
	assert_almost_eq(rad_to_deg(shots[2].direction.angle()), 15.0, 0.01)
	get_tree().current_scene = previous_scene
	get_tree().root.remove_child(scene_root)
	scene_root.free()

func test_armor_buff_refreshes_without_stacking():
	caster.cast_buff_armor(15.0, 6.0)
	caster.cast_buff_armor(25.0, 4.0)
	assert_eq(caster.armor_buff.bonus_armor, 25.0)
	assert_almost_eq(caster.armor_buff.get_remaining_duration(), 4.0, 0.01)
