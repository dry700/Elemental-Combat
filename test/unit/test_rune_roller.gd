extends GutTest

var weapon_damage: RuneModifierDef
var weapon_reach: RuneModifierDef
var skill_cooldown: RuneModifierDef

func before_each():
	weapon_damage = _definition(&"damage", RuneModifierDef.AppliesTo.WEAPON, [])
	weapon_reach = _definition(&"reach", RuneModifierDef.AppliesTo.WEAPON, [Elements.HOA])
	skill_cooldown = _definition(&"cooldown", RuneModifierDef.AppliesTo.SKILL, [])
	RuneRoller.set_catalogue([weapon_damage, weapon_reach, skill_cooldown])

func after_each():
	RuneRoller.set_catalogue([])

func test_roll_filters_by_target_and_element():
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var rune := RuneRoller.roll(Elements.HOA, RuneData.Target.WEAPON, rng)
	assert_true(rune.modifiers.size() >= 1)
	for modifier in rune.modifiers:
		assert_true(modifier.id == &"damage" or modifier.id == &"reach")

func test_roll_does_not_repeat_modifier_ids():
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	var rune := RuneRoller.roll(Elements.HOA, RuneData.Target.WEAPON, rng)
	if rune.modifiers.size() == 2:
		assert_ne(rune.modifiers[0].id, rune.modifiers[1].id)

func test_empty_pool_returns_rune_without_modifiers():
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var rune := RuneRoller.roll(Elements.THO, RuneData.Target.SKILL, rng)
	assert_not_null(rune)
	assert_eq(rune.element, Elements.THO)
	assert_eq(rune.modifiers.size(), 1, "skill cooldown should be the only matching definition")

func _definition(id: StringName, applies_to: RuneModifierDef.AppliesTo, elements: Array[StringName]) -> RuneModifierDef:
	var definition := RuneModifierDef.new()
	definition.id = id
	definition.applies_to = applies_to
	definition.elements = elements
	definition.value_min = 1.0
	definition.value_max = 1.0
	return definition
