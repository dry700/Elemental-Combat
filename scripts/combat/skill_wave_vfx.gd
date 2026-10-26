class_name SkillWaveVFX
extends Node2D
## A directional water crest with rippling foam trails for wave-style skills.

const LIFETIME: float = 0.52
const WAVE_HEIGHT: float = 22.0
const CREST_COUNT: int = 3
const CREST_SPACING: float = 0.22
const FOAM_LINES: int = 3

var element: StringName = Elements.THUY
var wave_direction: int = 1
var wave_distance: float = 90.0
var _elapsed: float = 0.0


func set_element(value: StringName) -> void:
	element = value
	queue_redraw()


func set_wave_direction(value: int) -> void:
	wave_direction = -1 if value < 0 else 1


func set_wave_distance(value: float) -> void:
	wave_distance = maxf(value, 1.0)


func _ready() -> void:
	z_index = 2
	add_to_group("skill_wave_vfx")


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= LIFETIME:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var progress := clampf(_elapsed / LIFETIME, 0.0, 1.0)
	var color: Color = ElementIndicator.ELEMENT_COLOR.get(element, Color(0.3, 0.55, 0.95))
	color.a *= 1.0 - progress
	var front := wave_distance * ease(progress, 0.7)

	for crest_index in range(CREST_COUNT):
		var crest_progress := progress - float(crest_index) * CREST_SPACING
		if crest_progress <= 0.0:
			continue
		var crest_x := wave_distance * ease(crest_progress, 0.7)
		var crest_alpha := 1.0 - float(crest_index) * 0.18
		var crest_color := color
		crest_color.a *= crest_alpha
		var points := PackedVector2Array()
		for point_index in range(13):
			var t := float(point_index) / 12.0
			var y := lerpf(-WAVE_HEIGHT, WAVE_HEIGHT, t)
			var bow := sin(t * PI) * 7.0
			points.append(Vector2(wave_direction * (crest_x + bow), y))
		draw_polyline(points, crest_color, 3.0 if crest_index == 0 else 1.5, true)

	for line_index in range(FOAM_LINES):
		var y_offset := (float(line_index) - 1.0) * 13.0
		var trail := PackedVector2Array()
		for point_index in range(17):
			var t := float(point_index) / 16.0
			var x := front * t
			var ripple := sin(t * TAU * 2.0 + progress * 7.0 + float(line_index)) * 2.0
			trail.append(Vector2(wave_direction * x, y_offset + ripple))
		draw_polyline(trail, color, 1.5, true)
