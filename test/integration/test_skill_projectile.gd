extends GutTest
## Integration tests for Ignite Dart's projectile conversion (A.5) —
## SkillProjectile's own single-target hit resolution, which routes
## through the full ElementalCombatant.handle_hit() pipeline and
## bypasses ICD exactly like cast_apply_enemy already did instantly,
## plus cast_apply_projectile()'s no-current_scene safety (mirrors
## test_overgrowth_snare_does_not_error_without_a_current_scene in
## test_elemental_combatant_skills.gd).

const CombatantOwner := preload("res://test/helpers/combatant_owner.gd")

var caster: ElementalCombatant


func before_each():
	caster = ElementalCombatant.new()
	caster.show_debug_readout = false
	add_child_autofree(caster)


## Builds an owner Node exposing `elemental` (duck-typed, same
## convention CombatantOwner already supports) with a real Hurtbox
## child — SkillProjectile collides with Hurtboxes on the OWNER, not
## with ElementalCombatant directly, unlike every other reaction test
## which calls handle_hit() on a bare ElementalCombatant.new().
func _make_target_owner() -> Dictionary:
	var owner_node := CombatantOwner.new()
	var target_elemental := ElementalCombatant.new()
	target_elemental.show_debug_readout = false
	add_child_autofree(owner_node)
	owner_node.add_child(target_elemental)
	owner_node.elemental = target_elemental
	var hurtbox := Hurtbox.new()
	owner_node.add_child(hurtbox)  ## Must precede setting .owner below — see EnemyCombatAI._ready()'s own comment on why.
	hurtbox.owner = owner_node
	return {"owner": owner_node, "elemental": target_elemental, "hurtbox": hurtbox}

func _make_dart(element: StringName, charge: int, attacker: Node) -> SkillProjectile:
	var dart := SkillProjectile.new()
	dart.element = element
	dart.charge = charge
	dart.attacker = attacker
	add_child_autofree(dart)
	return dart


func test_hit_resolves_through_the_full_reaction_pipeline():
	var t := _make_target_owner()
	t["elemental"].status.apply(Elements.KIM, 1)  # Hỏa khắc Kim -> Molten
	var dart := _make_dart(Elements.HOA, 1, null)

	dart._on_area_entered(t["hurtbox"])

	assert_false(t["elemental"].status.has_status(), "Molten should have cleared the Kim status")
	assert_true(t["elemental"].dot_effect.active, "Molten's DoT should have applied")

func test_hit_bypasses_icd():
	var t := _make_target_owner()
	t["elemental"].status.apply(Elements.KIM, 1)
	_make_dart(Elements.HOA, 1, null)._on_area_entered(t["hurtbox"])

	t["elemental"].status.apply(Elements.KIM, 1)
	_make_dart(Elements.HOA, 1, null)._on_area_entered(t["hurtbox"])  # would be ICD-blocked if this were a weapon hit

	assert_false(t["elemental"].status.has_status(), "second dart should still have resolved — skills bypass ICD")

func test_never_hits_its_own_wielder():
	var t := _make_target_owner()
	var original_element: StringName = t["elemental"].status.element
	var dart := _make_dart(Elements.HOA, 1, t["owner"])  # attacker == the target's own owner

	dart._on_area_entered(t["hurtbox"])

	assert_eq(t["elemental"].status.element, original_element, "a dart must never resolve against its own wielder")

func test_a_spent_dart_does_not_resolve_a_second_hit():
	var t := _make_target_owner()
	var dart := _make_dart(Elements.HOA, 1, null)
	dart._on_area_entered(t["hurtbox"])
	assert_eq(t["elemental"].status.element, Elements.HOA)

	t["elemental"].status.clear()
	dart._on_area_entered(t["hurtbox"])  # dart is already spent — must not resolve again
	assert_false(t["elemental"].status.has_status(), "a spent dart must not resolve a second time")

func test_cast_apply_projectile_does_not_error_without_a_current_scene():
	caster.cast_apply_projectile(Elements.HOA, 1, Vector2.RIGHT)
	assert_true(true, "cast_apply_projectile should not throw when current_scene is unset")
