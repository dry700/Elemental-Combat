class_name DisableEffect
extends RefCounted
## Unifies Root/Stagger/Stun into one "target cannot act" component,
## matching A.3's framing of Break-Free as applying "universally to any
## stagger/stun/lock regardless of source" rather than needing a separate
## system per reaction.
##
## reduce_duration() is Break-Free's hook into this (see player.gd's
## _unhandled_input for the actual per-press wiring) — the floor rule
## from A.3 (a lock can be clawed back to baseline, never erased
## entirely) lives here, set once at apply() time per reaction.

signal expired

var active: bool = false

var _remaining_duration: float = 0.0
var _floor_duration: float = 0.0


func apply(p_duration: float, p_floor_duration: float = 0.0) -> void:
	_remaining_duration = p_duration
	_floor_duration = p_floor_duration
	active = true


func tick(delta: float) -> void:
	if not active:
		return
	_remaining_duration -= delta
	if _remaining_duration <= 0.0:
		active = false
		expired.emit()


## Break-Free's hook — reduces remaining duration but never below the
## floor set when this was applied (A.3's explicit floor rule).
##
## The floor only clamps while _remaining_duration is still ABOVE it. Once
## plain tick() decay (which isn't floor-clamped — see tick() above) has
## already carried it below the floor on its own, a press must keep
## counting down toward 0 like tick() would, not snap back UP to the
## floor. maxf(_remaining_duration - amount, _floor_duration) alone gets
## this backwards in exactly that case: e.g. remaining=0.3, floor=0.5,
## amount=0.4 gives maxf(-0.1, 0.5) = 0.5 — the press INCREASES the
## remaining time. Mash through that state and the lock never finishes,
## since every press re-snaps it back up to the floor it already passed.
func reduce_duration(amount: float) -> void:
	if not active:
		return
	if _remaining_duration > _floor_duration:
		_remaining_duration = maxf(_remaining_duration - amount, _floor_duration)
	else:
		_remaining_duration = maxf(_remaining_duration - amount, 0.0)
	if _remaining_duration <= 0.0:
		active = false
		expired.emit()


func is_active() -> bool:
	return active


func get_remaining_duration() -> float:
	return _remaining_duration


func clear() -> void:
	active = false
