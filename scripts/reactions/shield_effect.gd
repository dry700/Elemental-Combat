class_name ShieldEffect
extends RefCounted
## Refresh-only shield that absorbs a single hit.

signal broken(attacker: Node)
signal expired
signal changed(active: bool)

var active: bool = false
var _remaining_duration: float = 0.0


func apply(duration: float) -> void:
	_remaining_duration = duration
	active = true
	changed.emit(true)


func tick(delta: float) -> void:
	if not active:
		return
	_remaining_duration -= delta
	if _remaining_duration <= 0.0:
		clear()
		expired.emit()


func absorb_hit(attacker: Node = null) -> bool:
	if not active:
		return false
	clear()
	broken.emit(attacker)
	return true


func get_remaining_duration() -> float:
	return _remaining_duration


func clear() -> void:
	var was_active := active
	active = false
	_remaining_duration = 0.0
	if was_active:
		changed.emit(false)
