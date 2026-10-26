class_name TrailVFX
extends Line2D
## Tapering swing trail: wide at the weapon tip, narrowing to nothing at
## the tail. Prototype replacement for SlashVFX on arc (SWING) weapons —
## opt in per weapon via WeaponStats.use_trail_vfx.
##
## Samples the tip's WORLD position, so it lives in global space
## (top_level = true) instead of rotating/mirroring with the Hitbox like
## SlashVFX does. Points are aged by REAL time (Time.get_ticks_msec), so
## HitStop's time_scale drop doesn't stretch or bunch the trail.
##
## Usage: create with .new(), set tip_source/tip_offset/element/
## sample_duration BEFORE add_child(). It samples for sample_duration,
## then fades out its remaining points and frees itself.

const MAX_AGE_MSEC: int = 120  ## How long a point lives — controls trail length.
const MAX_POINTS: int = 10     ## Few points keeps a crisp crescent, not a wobbly ribbon.

## The node whose transform carries the tip (the player's Hitbox).
var tip_source: Node2D
## Local offset from tip_source to the tip (reach along +x).
var tip_offset: Vector2 = Vector2.ZERO
var element: StringName = Elements.NONE
var sample_duration: float = 0.2
var max_width: float = 6.0

var _samples: Array[Dictionary] = []  ## [{pos: Vector2, t: int}], oldest first.
var _start_msec: int = 0


func _ready() -> void:
	top_level = true
	position = Vector2.ZERO  ## top_level: position is now global, so points are global coords.
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	width = max_width
	default_color = Color.WHITE
	joint_mode = Line2D.LINE_JOINT_ROUND

	# Oldest point is index 0 (offset 0), newest is the tip (offset 1):
	# width and alpha both grow from 0 at the tail to full at the tip.
	var taper := Curve.new()
	taper.add_point(Vector2(0.0, 0.0))
	taper.add_point(Vector2(1.0, 1.0))
	width_curve = taper

	# Constant interpolation = hard colour bands, which suits the 16x16
	# pixel-art look better than a smooth fade.
	var base: Color = ElementIndicator.ELEMENT_COLOR.get(element, Color(0.95, 0.95, 0.95))
	var bands := Gradient.new()
	bands.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	bands.offsets = PackedFloat32Array([0.0, 0.25, 0.5, 0.75])
	bands.colors = PackedColorArray([
		Color(base, 0.20), Color(base, 0.45), Color(base, 0.70), Color(base, 0.95),
	])
	gradient = bands

	_start_msec = Time.get_ticks_msec()
	_sample()


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	var sampling := now - _start_msec < int(sample_duration * 1000.0)
	if sampling:
		_sample()

	while not _samples.is_empty() and now - int(_samples[0]["t"]) > MAX_AGE_MSEC:
		_samples.pop_front()

	if not sampling and _samples.is_empty():
		queue_free()
		return
	_rebuild()


func _sample() -> void:
	if tip_source == null or not is_instance_valid(tip_source):
		return
	_samples.append({
		"pos": tip_source.to_global(tip_offset),
		"t": Time.get_ticks_msec(),
	})
	while _samples.size() > MAX_POINTS:
		_samples.pop_front()


func _rebuild() -> void:
	clear_points()
	for sample in _samples:
		add_point(sample["pos"])
