extends GutTest

const RuneRollerScript := preload("res://scripts/resources/runes/rune_roller.gd")
const RuneModifierDefScript := preload("res://scripts/resources/runes/rune_modifier_def.gd")

# Typed as RuneRoller so roller.roll() has a known return type (RuneData).
# Without this, GDScript cannot infer the type of local "rune" variables.
var roller: RuneRoller
var weapon_damage: RuneModifierDef
var weapon_reach: RuneModifierDef
var skill_cooldown: RuneModifierDef

func before_each():
	roller = RuneRollerScript.new()
	weapon_damage = _definition(&"damage", RuneModifierDef.AppliesTo.WEAPON, [])
	weapon_reach = _definition(&"reach", RuneModifierDef.AppliesTo.WEAPON, [Elements.HOA])
	skill_cooldown = _definition(&"cooldown", RuneModifierDef.AppliesTo.SKILL, [])
	var defs: Array[RuneModifierDef] = [weapon_damage, weapon_reach, skill_cooldown]
	roller.set_catalogue(defs)

func after_each():
	roller = null

func test_roll_filters_by_target_and_element():
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var rune: RuneData = roller.roll(Elements.HOA, RuneData.Target.WEAPON, rng)
	assert_true(rune.modifiers.size() >= 1)
	for modifier in rune.modifiers:
		assert_true(modifier.id == &"damage" or modifier.id == &"reach")

func test_roll_does_not_repeat_modifier_ids():
	var rng := RandomNumberGenerator.new()
	var rolled_two := false
	for seed_val in range(100):
		rng.seed = seed_val
		var rune: RuneData = roller.roll(Elements.HOA, RuneData.Target.WEAPON, rng)
		if rune.modifiers.size() == 2:
			assert_ne(rune.modifiers[0].id, rune.modifiers[1].id)
			rolled_two = true
			break
	assert_true(rolled_two, "Should have rolled a 2-modifier rune to verify non-repeating IDs")

func test_single_matching_definition_returns_one_modifier():
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var rune: RuneData = roller.roll(Elements.THO, RuneData.Target.SKILL, rng)
	assert_not_null(rune)
	assert_eq(rune.element, Elements.THO)
	assert_eq(rune.modifiers.size(), 1, "skill cooldown should be the only matching definition")
	assert_eq(rune.modifiers[0].id, &"cooldown")

func test_empty_pool_returns_rune_without_modifiers():
	roller.set_catalogue([])
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var rune: RuneData = roller.roll(Elements.THO, RuneData.Target.SKILL, rng)
	assert_not_null(rune)
	assert_eq(rune.element, Elements.THO)
	assert_eq(rune.modifiers.size(), 0, "empty pool should return rune with no modifiers")

func _definition(id: StringName, applies_to: RuneModifierDef.AppliesTo, elements: Array[StringName]) -> RuneModifierDef:
	var definition: RuneModifierDef = RuneModifierDefScript.new()
	definition.id = id
	definition.applies_to = applies_to
	definition.elements = elements
	definition.value_min = 1.0
	definition.value_max = 1.0
	return definition
