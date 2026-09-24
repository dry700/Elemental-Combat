class_name RuneData
extends RefCounted

## Rolled rune state stored on a Player equipment slot.

enum Target { WEAPON, SKILL }

var element: StringName = Elements.NONE
var target: Target = Target.WEAPON
var modifiers: Array[Dictionary] = []

func _init(p_element: StringName = Elements.NONE, p_target: Target = Target.WEAPON) -> void:
	element = p_element
	target = p_target

func to_dict() -> Dictionary:
	var serialized: Array[Dictionary] = []
	for modifier in modifiers:
		serialized.append({
			"id": String(modifier.get("id", &"")),
			"value": float(modifier.get("value", 0.0)),
		})
	return {
		"element": String(element),
		"target": int(target),
		"modifiers": serialized,
	}

static func from_dict(data: Dictionary) -> RuneData:
	if not data.has("element") or not data.has("target") or not data.has("modifiers"):
		return null
	if not (data.element is String or data.element is StringName):
		return null
	if not (data.target is int) or int(data.target) < Target.WEAPON or int(data.target) > Target.SKILL:
		return null
	if not data.modifiers is Array:
		return null

	var rune := RuneData.new(StringName(data.element), data.target as Target)
	for raw_modifier in data.modifiers:
		if not raw_modifier is Dictionary:
			return null
		if not raw_modifier.has("id") or not raw_modifier.has("value"):
			return null
		if not (raw_modifier.id is String or raw_modifier.id is StringName):
			return null
		if not (raw_modifier.value is int or raw_modifier.value is float):
			return null
		rune.modifiers.append({
			"id": StringName(raw_modifier.id),
			"value": float(raw_modifier.value),
		})
	return rune

func describe_lines() -> Array[String]:
	var lines: Array[String] = []
	for modifier in modifiers:
		lines.append("%s: %s" % [String(modifier.get("id", &"unknown")), str(modifier.get("value", 0.0))])
	if lines.is_empty():
		lines.append("No modifiers")
	return lines
