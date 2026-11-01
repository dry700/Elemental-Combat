extends Node2D
## Warm, pulsing outline shown while bonus armor is active.

const SEGMENTS := 40
const CENTER := Vector2(0.0, -5.0)
const RADIUS := Vector2(13.0, 19.0)
const BUFF_COLOR := Color(1.0, 0.72, 0.22)

var _active: bool = false
var _phase: float = 0.0


func _ready() -> void:
	visible = false
	set_process(true)


func set_active(active: bool) -> void:
	_active = active
	visible = active
	queue_redraw()


func _process(delta: float) -> void:
	if not _active:
		return
	_phase += delta
	queue_redraw()


func _draw() -> void:
	if not _active:
		return
	var pulse := 0.5 + 0.5 * sin(_phase * 3.5)
	var points := PackedVector2Array()
	for index in range(SEGMENTS + 1):
		var angle := TAU * float(index) / float(SEGMENTS)
		points.append(CENTER + Vector2(cos(angle) * RADIUS.x, sin(angle) * RADIUS.y))
	draw_colored_polygon(points, Color(BUFF_COLOR.r, BUFF_COLOR.g, BUFF_COLOR.b, 0.025 + pulse * 0.025))
	draw_polyline(points, Color(BUFF_COLOR.r, BUFF_COLOR.g, BUFF_COLOR.b, 0.3 + pulse * 0.2), 1.25, true)
