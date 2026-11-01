class_name SweepBuffEffect
extends RefCounted
## Refresh-only timed buff for Maid's Sweep (plan-shop-and-skills §7.2).
## While active, Player._configure_hitbox_for_current_swing() reads these
## multipliers and forces the swing element to Thổ — never touching raw
## reaction Charge. Mirrors ShieldEffect's apply/tick/clear/expired shape.

signal expired

var active: bool = false
var damage_mult: float = 1.0
var reach_mult: float = 1.0
var _remaining_duration: float = 0.0


## Refresh-only: re-casting resets the timer and the multipliers; the buff
## never stacks (same intent as ShieldEffect.apply).
func apply(duration: float, p_damage_mult: float = 1.0, p_reach_mult: float = 1.0) -> void:
	_remaining_duration = duration
	damage_mult = p_damage_mult
	reach_mult = p_reach_mult
	active = true


func tick(delta: float) -> void:
	if not active:
		return
	_remaining_duration -= delta
	if _remaining_duration <= 0.0:
		clear()
		expired.emit()


func get_remaining_duration() -> float:
	return _remaining_duration


func clear() -> void:
	active = false
	_remaining_duration = 0.0
