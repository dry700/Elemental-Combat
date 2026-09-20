class_name CCResistance
extends RefCounted
## Shared diminishing-returns tracker for control effects.
## A Disable and a Slow both consume the same counter, so repeated
## control applications are capped as a single "control uptime" budget.

var free_hits: int = 999
var window_seconds: float = 8.0

var _recent_count: int = 0
var _window_timer: float = 0.0


func configure(p_free_hits: int, p_window_seconds: float) -> void:
	free_hits = p_free_hits
	window_seconds = p_window_seconds


func tick(delta: float) -> void:
	if _recent_count <= 0:
		return
	_window_timer -= delta
	if _window_timer <= 0.0:
		_recent_count = 0
		_window_timer = 0.0


## Called once per control application attempt, before the underlying
## effect is applied. A multiplier of 1.0 keeps full effect, 0.5 halves it,
## and 0.0 fully blocks the control effect for this hit.
func consume_and_get_multiplier() -> float:
	var multiplier: float = 1.0
	if _recent_count < free_hits:
		multiplier = 1.0
	elif _recent_count == free_hits:
		multiplier = 0.5
	else:
		multiplier = 0.0

	_recent_count += 1
	_window_timer = window_seconds
	return multiplier
