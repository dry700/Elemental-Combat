class_name SweepHitboxVFX
extends Node2D
## Shows a solid Geo blade aura over Maid's Sweep's hitbox while attacking.

const AURA_COLOR := Color(1.0, 0.62, 0.08)
const BLADE_COLOR := Color(1.0, 0.72, 0.12)
const EDGE_COLOR := Color(1.0, 0.9, 0.44)
const CORE_COLOR := Color(1.0, 0.99, 0.78)

var player: Player
var collision_shape: CollisionShape2D
var _active: bool = false
var _phase: float = 0.0


func _ready() -> void:
	visible = false
	set_process(false)
	z_index = 2


func configure(p_player: Player, p_collision_shape: CollisionShape2D) -> void:
	player = p_player
	collision_shape = p_collision_shape
	queue_redraw()


func set_active(active: bool) -> void:
	_active = active
	set_process(active)
	_update_visibility()
	queue_redraw()


func _process(delta: float) -> void:
	_update_visibility()
	if visible:
		# The player can switch weapons during the buff, so read the live shape.
		_phase += delta
		queue_redraw()


func _update_visibility() -> void:
	visible = _active and is_instance_valid(player) and player.state == Player.State.ATTACK


func _draw() -> void:
	if not visible or not is_instance_valid(collision_shape):
		return
	var rectangle := collision_shape.shape as RectangleShape2D
	if rectangle == null:
		return
	var bounds := Rect2(collision_shape.position - rectangle.size * 0.5, rectangle.size)
	var pulse := 0.5 + 0.5 * sin(_phase * 4.2)
	# The opaque tapered silhouette reads as an oversized glowing sword; its
	# tip and heel stay inside the exact live collision rectangle.
	var glow_points := _blade_points(bounds.grow(3.0))
	draw_colored_polygon(glow_points, Color(AURA_COLOR.r, AURA_COLOR.g, AURA_COLOR.b, 0.20 + pulse * 0.12))
	var blade_points := _blade_points(bounds)
	draw_colored_polygon(blade_points, Color(BLADE_COLOR.r, BLADE_COLOR.g, BLADE_COLOR.b, 0.88))
	var closed_edge := blade_points.duplicate()
	closed_edge.append(blade_points[0])
	draw_polyline(closed_edge, Color(EDGE_COLOR.r, EDGE_COLOR.g, EDGE_COLOR.b, 0.9), 1.4, true)

	var center_y := bounds.get_center().y
	var core_start := bounds.position.x + bounds.size.x * 0.14
	var core_end := bounds.end.x - minf(bounds.size.y * 0.8, bounds.size.x * 0.18)
	var core_width := maxf(bounds.size.y * 0.12, 1.0)
	draw_line(Vector2(core_start, center_y), Vector2(core_end, center_y), Color(CORE_COLOR.r, CORE_COLOR.g, CORE_COLOR.b, 0.82), core_width, true)

	# A short bright sweep travels along the blade while the hitbox is active.
	var glint_x := lerpf(core_start, core_end, fposmod(_phase * 0.7, 1.0))
	draw_line(Vector2(glint_x, center_y - core_width * 1.4), Vector2(glint_x, center_y + core_width * 1.4), Color(CORE_COLOR.r, CORE_COLOR.g, CORE_COLOR.b, 0.95), 1.6, true)


func _blade_points(bounds: Rect2) -> PackedVector2Array:
	var center_y := bounds.get_center().y
	var half_height := bounds.size.y * 0.5
	var base_half_height := half_height * 0.36
	var shoulder_x := bounds.position.x + bounds.size.x * 0.13
	var tip_length := minf(half_height * 1.2, bounds.size.x * 0.18)
	return PackedVector2Array([
		Vector2(bounds.position.x, center_y - base_half_height),
		Vector2(shoulder_x, center_y - half_height * 0.72),
		Vector2(bounds.end.x - tip_length, center_y - half_height),
		Vector2(bounds.end.x, center_y),
		Vector2(bounds.end.x - tip_length, center_y + half_height),
		Vector2(shoulder_x, center_y + half_height * 0.72),
		Vector2(bounds.position.x, center_y + base_half_height),
	])
