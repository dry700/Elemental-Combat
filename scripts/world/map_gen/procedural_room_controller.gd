class_name ProceduralRoomController
extends RoomController

const LoadoutSelectScript := preload("res://scripts/ui/loadout_select.gd")
const ShopWeaponPickupScript := preload("res://scripts/items/shop_weapon_pickup.gd")

var map_gen: MapGenerator
var start_chunk: Node2D
var finish_chunk: Node2D
var saved_map_structure: Dictionary = {}

func _init() -> void:
	pass

func _enter_tree() -> void:
	map_gen = MapGenerator.new(4, 3)
	map_gen.load_pool_from_dir("res://scenes/world/chunks")
	if saved_map_structure.is_empty() or not map_gen.load_layout(saved_map_structure):
		if not saved_map_structure.is_empty():
			push_warning("ProceduralRoomController: saved map structure is invalid; generating a new layout")
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
	_baseline_rune_spawned = true
	
	if exit != null:
		exit.locked = false
		
	for spawn_point in _spawn_points:
		spawn_point.spawn()
		
	_populate_shop()
	_check_cleared()

func _populate_shop() -> void:
	var shop_chunk: Node2D = null
	for child in get_children():
		if child.is_in_group("shop_chunk"):
			shop_chunk = child as Node2D
			break
	if shop_chunk == null:
		return
	var floor_y := MapGenerator.CHUNK_H - 32.0 - 15.0
	var station_script := preload("res://scripts/items/shop_station.gd")
	var station = station_script.new()
	station.position = Vector2(MapGenerator.CHUNK_W / 2.0, floor_y + 9.0)
	shop_chunk.add_child(station)

	var free_rune := RunePickup.new()
	free_rune.set_rune(RuneRoller.default().roll(Elements.ALL[randi() % Elements.ALL.size()], RuneData.Target.WEAPON))
	free_rune.position = Vector2(160.0, floor_y + 9.0)
	shop_chunk.add_child(free_rune)

	var stock := _get_shop_weapon_stock()
	var stall_positions := [100.0, 316.0]
	for index in mini(stock.size(), stall_positions.size()):
		var weapon: WeaponStats = stock[index]
		var pickup: WeaponPickup = ShopWeaponPickupScript.new()
		pickup.weapon = weapon
		pickup.slot = WeaponPickup.Slot.PRIMARY if index == 0 else WeaponPickup.Slot.SECONDARY
		pickup.set("price", _shop_weapon_price(weapon))
		pickup.position = Vector2(stall_positions[index], floor_y + 9.0)
		shop_chunk.add_child(pickup)


func _get_shop_weapon_stock() -> Array[WeaponStats]:
	var paths: Array[String] = []
	for path in LoadoutSelectScript.STARTING_WEAPON_PATHS:
		paths.append(path)
	for unlocked_path in SaveManager.get_unlocked_weapon_paths():
		var path := str(unlocked_path)
		if not paths.has(path):
			paths.append(path)

	var player: Player = RunManager._player if RunManager != null else null
	var held_paths: Array[String] = []
	if player != null:
		if player.weapon != null and player.weapon.resource_path != "":
			held_paths.append(player.weapon.resource_path)
		if player.secondary_weapon != null and player.secondary_weapon.resource_path != "":
			held_paths.append(player.secondary_weapon.resource_path)

	var candidates: Array[WeaponStats] = []
	for path in paths:
		if path.get_file().begins_with("runed_") or held_paths.has(path):
			continue
		var weapon := load(path) as WeaponStats
		if weapon == null:
			push_warning("ProceduralRoomController: skipping invalid shop weapon resource %s" % path)
			continue
		candidates.append(weapon)
	candidates.shuffle()
	return candidates


func _shop_weapon_price(weapon: WeaponStats) -> int:
	match weapon.weight:
		WeaponStats.Weight.LIGHT:
			return 35
		WeaponStats.Weight.MEDIUM:
			return 45
		WeaponStats.Weight.HEAVY:
			return 55
	return 45

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


func get_playtest_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if map_gen == null:
		return cells
	for cell in map_gen.grid:
		cells.append(cell)
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y or (a.y == b.y and a.x < b.x)
	)
	return cells


func get_playtest_teleport_position(target: Variant) -> Variant:
	if target is String and target == "start":
		return get_player_spawn_position()
	var floor_y := MapGenerator.CHUNK_H - (2 * 16) - 15
	if target is String and target == "finish" and finish_chunk != null:
		return finish_chunk.to_global(Vector2(MapGenerator.CHUNK_W / 2.0 - 35.0, floor_y))
	if target is Vector2i and map_gen != null and map_gen.grid.has(target):
		var local_position := Vector2(target.x * MapGenerator.CHUNK_W + MapGenerator.CHUNK_W / 2.0, target.y * MapGenerator.CHUNK_H + floor_y)
		return to_global(local_position)
	return null
