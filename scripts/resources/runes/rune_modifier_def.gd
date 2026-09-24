class_name RuneModifierDef
extends Resource

## Authored definition for one rolled rune modifier.

enum AppliesTo { WEAPON, SKILL, BOTH }

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var value_min: float = 0.0
@export var value_max: float = 0.0
@export var value_step: float = 0.0
@export var applies_to: AppliesTo = AppliesTo.BOTH
@export var elements: Array[StringName] = []

func applies_to_rune(target: RuneData.Target, element: StringName) -> bool:
	var target_matches := applies_to == AppliesTo.BOTH
	if target == RuneData.Target.WEAPON:
		target_matches = target_matches or applies_to == AppliesTo.WEAPON
	else:
		target_matches = target_matches or applies_to == AppliesTo.SKILL
	return target_matches and (elements.is_empty() or elements.has(element))
