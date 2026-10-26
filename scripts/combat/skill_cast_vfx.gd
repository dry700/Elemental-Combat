class_name SkillCastVFX
extends Node2D
## Brief elemental burst shown at the caster when an active skill is cast.

const LIFETIME: float = 0.38
const START_RADIUS: float = 8.0
const END_RADIUS: float = 38.0
const FRAGMENT_COUNT: int = 6

var element: StringName = Elements.NONE
var _elapsed: float = 0.0


func set_element(value: StringName) -> void:
	element = value
	queue_redraw()


func _ready() -> void:
	z_index = 2
	add_to_group("skill_cast_vfx")


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= LIFETIME:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var progress := clampf(_elapsed / LIFETIME, 0.0, 1.0)
	var color: Color = ElementIndicator.ELEMENT_COLOR.get(element, Color(0.85, 0.9, 1.0))
	color.a *= 1.0 - progress

	var radius := lerpf(START_RADIUS, END_RADIUS, progress)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, color, 2.0, true)

	var inner_progress := clampf(progress * 1.4 - 0.3, 0.0, 1.0)
	if inner_progress > 0.0:
		var inner_radius := lerpf(START_RADIUS, END_RADIUS * 0.72, inner_progress)
		draw_arc(Vector2.ZERO, inner_radius, 0.0, TAU, 32, color, 1.0, true)

	for index in range(FRAGMENT_COUNT):
		var angle := TAU * float(index) / FRAGMENT_COUNT + progress * 0.55
		var direction := Vector2.RIGHT.rotated(angle)
		var fragment_position := direction * radius
		var tip := fragment_position + direction * 5.0
		draw_line(fragment_position, tip, color, 2.0, true)
		draw_line(
			fragment_position + direction.rotated(PI * 0.5) * 2.0,
			fragment_position + direction.rotated(-PI * 0.5) * 2.0,
			color,
			1.5,
			true
		)
