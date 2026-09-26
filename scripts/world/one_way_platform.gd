class_name OneWayPlatform
extends StaticBody2D

@export var width_tiles: int = 3:
	set(value):
		width_tiles = value
		_update_shape()

func _ready() -> void:
	_update_shape()

func _update_shape() -> void:
	var col = get_node_or_null("CollisionShape2D")
	var vis = get_node_or_null("Visual")
	if col == null or vis == null:
		return
	var w = width_tiles * 16.0
	var rect = col.shape as RectangleShape2D
	if rect != null:
		rect.size = Vector2(w, 8.0)
	col.position = Vector2(w / 2.0, 4.0)
	vis.polygon = PackedVector2Array([Vector2(0,0), Vector2(w,0), Vector2(w,8), Vector2(0,8)])
