class_name SlowEffect
extends RefCounted
## Reusable movement-speed-multiplier component. Owner reads
## get_speed_multiplier() when computing movement each frame and applies
## it to whatever speed value it already uses. Refresh-only.

signal expired

var speed_multiplier: float = 1.0
var active: bool = false

var _remaining_duration: float = 0.0


func apply(p_speed_multiplier: float, p_duration: float) -> void:
	speed_multiplier = p_speed_multiplier
	_remaining_duration = p_duration
	active = true


func tick(delta: float) -> void:
	if not active:
		return
	_remaining_duration -= delta
	if _remaining_duration <= 0.0:
		clear()
		expired.emit()


func get_speed_multiplier() -> float:
	return speed_multiplier if active else 1.0


func get_remaining_duration() -> float:
	return _remaining_duration


func clear() -> void:
	active = false
	speed_multiplier = 1.0
