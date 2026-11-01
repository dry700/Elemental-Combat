extends Node2D
## Brief, faint lightning link shown when a shielder grants an ally a shield.

const LIFETIME := 0.28
const SEGMENTS := 9

var source: Node2D
var target: Node2D
var _age: float = 0.0


func configure(from_node: Node2D, to_node: Node2D) -> void:
	source = from_node
	target = to_node


func _ready() -> void:
	z_index = 10
	add_to_group("shield_link_vfx")
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	if not is_instance_valid(source) or not is_instance_valid(target):
		queue_free()
		return
	_age += delta
	if _age >= LIFETIME:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	if not is_instance_valid(source) or not is_instance_valid(target):
		return
	var start := to_local(source.global_position + Vector2(0.0, -5.0))
	var finish := to_local(target.global_position + Vector2(0.0, -5.0))
	var span := finish - start
	if span.length_squared() < 1.0:
		return
	var normal := Vector2(-span.y, span.x).normalized()
	var fade := 1.0 - clampf(_age / LIFETIME, 0.0, 1.0)
	var points := PackedVector2Array([start])
	for index in range(1, SEGMENTS):
		var t := float(index) / float(SEGMENTS)
		var jitter := sin(float(index) * 9.7 + _age * 31.0) * 3.0 * fade
		points.append(start.lerp(finish, t) + normal * jitter)
	points.append(finish)
	draw_polyline(points, Color(0.28, 0.78, 1.0, 0.14 * fade), 4.0, true)
	draw_polyline(points, Color(0.34, 0.84, 1.0, 0.48 * fade), 1.5, true)
	draw_polyline(points, Color(0.82, 0.96, 1.0, 0.32 * fade), 0.65, true)
