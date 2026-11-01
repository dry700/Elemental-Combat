extends Node2D
## Subtle body-shaped ellipse shown while an ElementalCombatant shield is active.

const SEGMENTS := 48
const CENTER := Vector2(0.0, -5.0)
const RADIUS := Vector2(13.0, 19.0)

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
	var pulse := 0.5 + 0.5 * sin(_phase * 4.0)
	var points := PackedVector2Array()
	for index in range(SEGMENTS + 1):
		var angle := TAU * float(index) / float(SEGMENTS)
		points.append(CENTER + Vector2(cos(angle) * RADIUS.x, sin(angle) * RADIUS.y))
	draw_colored_polygon(points, Color(0.22, 0.72, 1.0, 0.035 + pulse * 0.025))
	draw_polyline(points, Color(0.28, 0.78, 1.0, 0.34 + pulse * 0.18), 1.2, true)
	var inner := PackedVector2Array()
	for point in points:
		inner.append(CENTER + (point - CENTER) * 0.88)
	draw_polyline(inner, Color(0.74, 0.94, 1.0, 0.12 + pulse * 0.08), 0.8, true)
