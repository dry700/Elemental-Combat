class_name ProceduralRoomController
extends RoomController

var map_gen: MapGenerator
var start_chunk: Node2D
var finish_chunk: Node2D

func _init() -> void:
	pass

func _enter_tree() -> void:
	map_gen = MapGenerator.new(4, 3)
	map_gen.load_pool_from_dir("res://scenes/world/chunks")
	map_gen.generate()
	map_gen.build_map(self)
	
	# Find start and finish chunks among immediate children
	for child in get_children():
		if child.is_in_group("start_chunk"):
			start_chunk = child as Node2D
		if child.is_in_group("finish_chunk"):
			finish_chunk = child as Node2D
			
	var floor_y = MapGenerator.CHUNK_H - (2 * 16) - 15
	
	# Create PlayerSpawn
	if start_chunk != null:
		var ps = Node2D.new()
		ps.add_to_group("player_spawn")
		ps.position = Vector2(MapGenerator.CHUNK_W / 2, floor_y)
		start_chunk.add_child(ps)
		
	# Create Exit
	if finish_chunk != null:
		# Need to use the RoomExit script
		var exit_script = preload("res://scripts/world/room_exit.gd")
		var exit_node = Area2D.new()
		exit_node.set_script(exit_script)
		exit_node.name = "Exit"
		exit_node.collision_layer = 0
		exit_node.collision_mask = 1
		
		var shape = CollisionShape2D.new()
		var rect = RectangleShape2D.new()
		rect.size = Vector2(10, 30)
		shape.shape = rect
		exit_node.add_child(shape)
		
		var visual = Polygon2D.new()
		visual.name = "Visual"
		visual.polygon = PackedVector2Array([
			Vector2(-5, -15), Vector2(5, -15), Vector2(5, 15), Vector2(-5, 15)
		])
		exit_node.add_child(visual)
		
		exit_node.position = Vector2(MapGenerator.CHUNK_W / 2, floor_y - 15)
		finish_chunk.add_child(exit_node)
		
		# Assign to parent's exit property
		exit = exit_node

func _ready() -> void:
	# RoomController._ready has already run and looked for immediate children.
	# But our chunks hold the EnemySpawnPoints as grandchildren!
	_spawn_points.clear()
	_find_spawn_points(self)
	
	if exit != null:
		exit.locked = not _spawn_points.is_empty()
		
	for spawn_point in _spawn_points:
		spawn_point.spawn()
		
	_check_cleared()

func _find_spawn_points(node: Node) -> void:
	for child in node.get_children():
		if child is EnemySpawnPoint:
			_spawn_points.append(child)
		_find_spawn_points(child)

func get_player_spawn_position() -> Vector2:
	if start_chunk != null:
		for child in start_chunk.get_children():
			if child.is_in_group("player_spawn"):
				return child.global_position
	return Vector2.ZERO
