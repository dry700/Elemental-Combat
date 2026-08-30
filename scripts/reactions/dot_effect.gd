class_name DotEffect
extends RefCounted
## Reusable damage-over-time component. Owner ticks it each physics frame
## and applies whatever damage tick() returns. Refresh-only — applying a
## new DoT while one is active replaces it, doesn't stack, consistent with
## how ElementalStatus and Charge already work elsewhere in this project.

signal expired

var damage_per_tick: float = 0.0
var tick_interval: float = 1.0
var active: bool = false

var _remaining_duration: float = 0.0
var _time_since_last_tick: float = 0.0


func apply(p_damage_per_tick: float, p_tick_interval: float, p_duration: float) -> void:
	damage_per_tick = p_damage_per_tick
	tick_interval = p_tick_interval
	_remaining_duration = p_duration
	_time_since_last_tick = 0.0
	active = true


## Returns the damage to apply this frame — 0.0 most frames, damage_per_tick
## on the frame a tick actually lands. Caller applies the returned value
## itself (to health, a damage counter, etc.) — this component only tracks
## timing, it doesn't know how "damage" is represented on its owner.
func tick(delta: float) -> float:
	if not active:
		return 0.0

	_remaining_duration -= delta
	_time_since_last_tick += delta

	var damage := 0.0
	if _time_since_last_tick >= tick_interval:
		damage = damage_per_tick
		_time_since_last_tick = 0.0

	if _remaining_duration <= 0.0:
		active = false
		expired.emit()

	return damage


func get_remaining_duration() -> float:
	return _remaining_duration


func clear() -> void:
	active = false
