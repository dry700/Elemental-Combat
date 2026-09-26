class_name MapGenerator
extends RefCounted

const CHUNK_W := 416.0
const CHUNK_H := 320.0

const DIR_UP := 1
const DIR_RIGHT := 2
const DIR_DOWN := 4
const DIR_LEFT := 8

var grid_w: int
var grid_h: int
var grid: Dictionary # Vector2i -> int (mask)

var start_cell: Vector2i
var finish_cell: Vector2i

# A dictionary mapping mask (int) -> Array[PackedScene]
var chunk_pool: Dictionary = {}

func _init(w: int, h: int) -> void:
	grid_w = w
	grid_h = h
	grid = {}

func load_pool_from_dir(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tscn"):
			var scene: PackedScene = load(path + "/" + file_name)
			var state := scene.get_state()
			var mask := -1
			for i in range(state.get_node_property_count(0)):
				if state.get_node_property_name(0, i) == "door_mask":
					mask = state.get_node_property_value(0, i)
					break
			if mask != -1:
				if not chunk_pool.has(mask):
					chunk_pool[mask] = []
				chunk_pool[mask].append(scene)
		file_name = dir.get_next()

func generate() -> void:
	grid.clear()
	var current := Vector2i(0, randi() % grid_h)
	start_cell = current
	grid[current] = 0
	
	var path := [current]
	while current.x < grid_w - 1:
		var next_steps: Array[Vector2i] = []
		for i in range(3):
			next_steps.append(Vector2i(1, 0))
			
		if current.y > 0 and not grid.has(current + Vector2i(0, -1)):
			next_steps.append(Vector2i(0, -1))
		if current.y < grid_h - 1 and not grid.has(current + Vector2i(0, 1)):
			next_steps.append(Vector2i(0, 1))
			
		var step: Vector2i = next_steps[randi() % next_steps.size()]
		var next_cell := current + step
		
		var dir_to_next := 0
		var dir_from_next := 0
		if step == Vector2i(1, 0):
			dir_to_next = DIR_RIGHT
			dir_from_next = DIR_LEFT
		elif step == Vector2i(0, -1):
			dir_to_next = DIR_UP
			dir_from_next = DIR_DOWN
		elif step == Vector2i(0, 1):
			dir_to_next = DIR_DOWN
			dir_from_next = DIR_UP
			
		grid[current] |= dir_to_next
		grid[next_cell] = dir_from_next
		
		current = next_cell
		path.append(current)
		
	finish_cell = current
	
	var num_branches = randi_range(0, 1)
	for i in range(num_branches):
		var branch_start: Vector2i = path[randi() % path.size()]
		_carve_branch(branch_start, 1)

func _carve_branch(start: Vector2i, length: int) -> void:
	var current := start
	for i in range(length):
		var next_steps: Array[Vector2i] = []
		for step in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
			var n = current + step
			if n.x >= 0 and n.x < grid_w and n.y >= 0 and n.y < grid_h and not grid.has(n):
				next_steps.append(step)
		if next_steps.is_empty():
			break
		var step: Vector2i = next_steps[randi() % next_steps.size()]
		var next_cell := current + step
		
		var dir_to_next := 0
		var dir_from_next := 0
		if step == Vector2i(1, 0):
			dir_to_next = DIR_RIGHT
			dir_from_next = DIR_LEFT
		elif step == Vector2i(-1, 0):
			dir_to_next = DIR_LEFT
			dir_from_next = DIR_RIGHT
		elif step == Vector2i(0, -1):
			dir_to_next = DIR_UP
			dir_from_next = DIR_DOWN
		elif step == Vector2i(0, 1):
			dir_to_next = DIR_DOWN
			dir_from_next = DIR_UP
			
		grid[current] |= dir_to_next
		grid[next_cell] = dir_from_next
		current = next_cell

func build_map(parent: Node2D) -> void:
	for cell in grid:
		var mask: int = grid[cell]
		var chunk_node: Node2D = null
		
		if chunk_pool.has(mask) and chunk_pool[mask].size() > 0:
			var scene: PackedScene = chunk_pool[mask][randi() % chunk_pool[mask].size()]
			chunk_node = scene.instantiate() as Node2D
		else:
			chunk_node = _build_fallback_chunk(mask)
			
		chunk_node.position = Vector2(cell.x * CHUNK_W, cell.y * CHUNK_H)
		parent.add_child(chunk_node)
		
		if cell == start_cell:
			chunk_node.add_to_group("start_chunk")
		if cell == finish_cell:
			chunk_node.add_to_group("finish_chunk")

func _build_fallback_chunk(mask: int) -> Node2D:
	var root := Node2D.new()
	var tm := TileMapLayer.new()
	var ts := load("res://scenes/world/chunks/chunk_tileset.tres") as TileSet
	tm.tile_set = ts
	root.add_child(tm)
	
	var w_tiles = 26
	var h_tiles = 20
	var thickness = 2
	
	# Horizontal doors (top/bottom) centered
	var h_door_start = (w_tiles - 6) / 2
	var h_door_end = h_door_start + 6
	
	# Vertical doors (left/right) placed at floor level
	var v_door_end = h_tiles - thickness
	var v_door_start = v_door_end - 5
	
	for x in range(w_tiles):
		for y in range(h_tiles):
			var is_wall = false
			if y < thickness:
				if (mask & DIR_UP) == 0 or (x < h_door_start or x >= h_door_end):
					is_wall = true
			elif y >= h_tiles - thickness:
				if (mask & DIR_DOWN) == 0 or (x < h_door_start or x >= h_door_end):
					is_wall = true
			elif x < thickness:
				if (mask & DIR_LEFT) == 0 or (y < v_door_start or y >= v_door_end):
					is_wall = true
			elif x >= w_tiles - thickness:
				if (mask & DIR_RIGHT) == 0 or (y < v_door_start or y >= v_door_end):
					is_wall = true
			
			if is_wall:
				tm.set_cell(Vector2i(x, y), 1, Vector2i(0, 0), 0)
				
	# Create a zigzag staircase if the player needs to climb UP
	if mask & DIR_UP:
		var plat_scene := load("res://scenes/world/one_way_platform.tscn") as PackedScene
		var add_plat = func(px: float, py: float, pw: int):
			var p = plat_scene.instantiate()
			p.set("width_tiles", pw)
			p.position = Vector2(px * 16.0, py * 16.0)
			root.add_child(p)
			
		add_plat.call(4, 16.5, 7)
		add_plat.call(15, 15.0, 7)
		add_plat.call(4, 13.5, 7)
		add_plat.call(15, 12.0, 7)
		add_plat.call(4, 10.5, 7)
		add_plat.call(15, 9.0, 7)
		add_plat.call(4, 7.5, 7)
		add_plat.call(15, 6.0, 7)
		add_plat.call(4, 4.5, 7)
		add_plat.call(h_door_start - 1, 3.0, h_door_end - h_door_start + 3)

	return root
