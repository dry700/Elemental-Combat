class_name ShopStation
extends Area2D

const HALF_SIZE: float = 12.0
const PROMPT_COLOR := Color(1.0, 1.0, 1.0, 0.9)

var _player_in_range: Player = null

func _ready() -> void:
	add_to_group("shop_stations")
	monitoring = true
	collision_layer = 0
	collision_mask = 1
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(HALF_SIZE, HALF_SIZE) * 2.0
	shape.shape = rect
	add_child(shape)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	queue_redraw()

func _on_body_entered(body: Node2D) -> void:
	var player := body as Player
	if player == null:
		return
	_player_in_range = player
	queue_redraw()

func _on_body_exited(body: Node2D) -> void:
	if body == _player_in_range:
		_player_in_range = null
		queue_redraw()

func _draw() -> void:
	var s := HALF_SIZE
	draw_rect(Rect2(Vector2(-s, -s), Vector2(s * 2.0, s * 2.0)), Color(0.3, 0.8, 1.0, 0.85), true)
	draw_rect(Rect2(Vector2(-s, -s), Vector2(s * 2.0, s * 2.0)), Color.BLACK, false, 1.5)
	if _player_in_range != null:
		draw_string(ThemeDB.fallback_font, Vector2(-26, -s - 12), "F Shop", HORIZONTAL_ALIGNMENT_CENTER, 60, 12, PROMPT_COLOR)
