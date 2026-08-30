extends Node
## Global "hit-stop" (hit-freeze) manager — briefly slows the whole game on
## impact to sell weight and make hits readable. This is a core "juice"
## technique per Swink (2009), cited in the proposal's lit review
## (Section 4.1) as the theoretical basis for tuning combat feel in Sprint 1.
##
## Usage: HitStop.freeze(0.05) from anywhere, e.g. when a Hitbox connects.
## Overlapping calls extend the freeze rather than fighting each other.

var _active_until_msec: int = 0
var _is_frozen: bool = false


func freeze(duration_sec: float, time_scale: float = 0.05) -> void:
	var now := Time.get_ticks_msec()
	var requested_until := now + int(duration_sec * 1000.0)
	_active_until_msec = max(_active_until_msec, requested_until)

	if _is_frozen:
		return  # Already counting down; it will pick up the extended time above.

	_is_frozen = true
	Engine.time_scale = time_scale
	_wait_and_restore()


func _wait_and_restore() -> void:
	while Time.get_ticks_msec() < _active_until_msec:
		# ignore_time_scale = true (4th arg) so this timer isn't itself
		# slowed down by the freeze it's supposed to be counting through.
		await get_tree().create_timer(0.01, true, false, true).timeout

	Engine.time_scale = 1.0
	_is_frozen = false
