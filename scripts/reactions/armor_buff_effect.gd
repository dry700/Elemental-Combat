class_name ArmorBuffEffect
extends RefCounted
## Reusable armor-bonus component. Owner reads get_bonus_armor() when
## computing mitigated damage and applies it to whatever armor value it
## already uses. Refresh-only.

signal expired

var bonus_armor: float = 0.0
var active: bool = false

var _remaining_duration: float = 0.0


func apply(p_bonus_armor: float, p_duration: float) -> void:
	bonus_armor = p_bonus_armor
	_remaining_duration = p_duration
	active = true


func tick(delta: float) -> void:
	if not active:
		return
	_remaining_duration -= delta
	if _remaining_duration <= 0.0:
		clear()
		expired.emit()


func get_bonus_armor() -> float:
	return bonus_armor if active else 0.0


func get_remaining_duration() -> float:
	return _remaining_duration


func clear() -> void:
	active = false
	bonus_armor = 0.0
