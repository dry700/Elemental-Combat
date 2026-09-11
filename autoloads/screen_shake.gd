extends Node
## Global camera-shake manager. Call ScreenShake.shake(intensity, duration)
## from anywhere, no reference-passing needed — mirrors HitStop.freeze()'s
## external shape exactly: a single call, an overlapping call extends
## rather than fights the current one, fully self-resetting once done.
##
## Internally this uses _process() rather than HitStop's async wait-loop,
## because shake needs a freshly randomized camera offset every rendered
## frame — HitStop only ever needs to KNOW a duration has elapsed, never
## to do per-frame work during the wait, so its timer-poll approach
## doesn't fit here.
##
## Finds the active Camera2D via the "player" group rather than holding
## a direct reference, so it keeps working across room transitions that
## free and recreate the Player node (see RunManager) without needing
## anyone to re-register it.

const WEIGHT_SHAKE: Dictionary = {
	&"light": {"intensity": 1.5, "duration": 0.08},
	&"medium": {"intensity": 2.5, "duration": 0.12},
	&"heavy": {"intensity": 4.5, "duration": 0.18},
	&"none": {"intensity": 2.0, "duration": 0.1},
}

var _peak_trauma: float = 0.0
var _shake_started_msec: int = 0
var _active_until_msec: int = 0
var _camera: Camera2D = null
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	set_process(false)  ## Only costs a frame callback while something is actually shaking.


func shake(intensity: float, duration: float) -> void:
	var now := Time.get_ticks_msec()
	var requested_until := now + int(duration * 1000.0)
	if requested_until >= _active_until_msec:
		# Same "extend, don't fight" rule as HitStop.freeze() — a bigger
		# or longer shake overrides an in-progress smaller one instead
		# of the two competing frame to frame.
		_peak_trauma = intensity
		_shake_started_msec = now
		_active_until_msec = requested_until
	set_process(true)


func shake_for_weight(weapon_weight: StringName) -> void:
	var preset: Dictionary = WEIGHT_SHAKE.get(weapon_weight, WEIGHT_SHAKE[&"none"])
	shake(preset["intensity"], preset["duration"])


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	if now >= _active_until_msec:
		_reset_camera_offset()
		set_process(false)
		return

	_find_camera()
	if _camera == null:
		return

	var total_duration := float(_active_until_msec - _shake_started_msec)
	var remaining := float(_active_until_msec - now)
	var t := remaining / total_duration if total_duration > 0.0 else 0.0
	var magnitude := _peak_trauma * t  ## Linear decay to 0 — an abrupt cutoff reads as a glitch, not an impact settling.

	_camera.offset = Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)) * magnitude


func _find_camera() -> void:
	if _camera != null and is_instance_valid(_camera):
		return
	var player := get_tree().get_first_node_in_group("player")
	if player != null:
		_camera = player.get_node_or_null("Camera2D") as Camera2D


func _reset_camera_offset() -> void:
	if _camera != null and is_instance_valid(_camera):
		_camera.offset = Vector2.ZERO
