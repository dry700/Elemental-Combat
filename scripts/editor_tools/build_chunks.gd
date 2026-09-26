extends SceneTree

const W_TILES = 26
const H_TILES = 20
const THICKNESS = 2
const H_DOOR_START = 10
const H_DOOR_END = 16
const V_DOOR_START = 13
const V_DOOR_END = 18

var chunk_script = preload("res://scripts/world/map_gen/chunk_base.gd")
var spawn_script = preload("res://scripts/world/enemy_spawn_point.gd")
var plat_scene = preload("res://scenes/world/one_way_platform.tscn")
var patrol_scene = preload("res://scenes/enemies/patrol_dummy.tscn")
var patrol_stats = preload("res://scripts/resources/enemies/neutral_brawler_stats.tres")
var kim_scene = preload("res://scenes/enemies/test_dummy.tscn")
var kim_stats = preload("res://scripts/resources/enemies/kim_spirit_stats.tres")
var tileset = preload("res://scenes/world/chunks/chunk_tileset.tres")

func _init():
    create_chunk("chunk_hallway", 10, Callable(self, "_build_hallway"))
    create_chunk("chunk_start", 2, Callable(self, "_build_start"))
    create_chunk("chunk_end", 8, Callable(self, "_build_end"))
    create_chunk("chunk_climb", 11, Callable(self, "_build_climb"))
    create_chunk("chunk_drop", 14, Callable(self, "_build_drop"))
    create_chunk("chunk_crossroads", 15, Callable(self, "_build_crossroads"))
    create_chunk("chunk_hallway_v2", 10, Callable(self, "_build_hallway_v2"))
    create_chunk("chunk_climb_v2", 11, Callable(self, "_build_climb_v2"))
    create_chunk("chunk_crossroads_v2", 15, Callable(self, "_build_crossroads_v2"))
    print("Chunks generated successfully!")
    quit()

func create_chunk(name: String, mask: int, builder: Callable):
    var root = Node2D.new()
    root.set_script(chunk_script)
    root.set("door_mask", mask)
    
    var tm = TileMapLayer.new()
    tm.tile_set = tileset
    tm.name = "TileMapLayer"
    root.add_child(tm)
    tm.owner = root
    
    for x in range(W_TILES):
        for y in range(H_TILES):
            var is_wall = false
            if y < THICKNESS:
                if (mask & 1) == 0 or (x < H_DOOR_START or x >= H_DOOR_END): is_wall = true
            elif y >= H_TILES - THICKNESS:
                if (mask & 4) == 0 or (x < H_DOOR_START or x >= H_DOOR_END): is_wall = true
            elif x < THICKNESS:
                if (mask & 8) == 0 or (y < V_DOOR_START or y >= V_DOOR_END): is_wall = true
            elif x >= W_TILES - THICKNESS:
                if (mask & 2) == 0 or (y < V_DOOR_START or y >= V_DOOR_END): is_wall = true
            
            if is_wall:
                tm.set_cell(Vector2i(x, y), 1, Vector2i(0, 0), 0)
    
    builder.call(tm, root)
    
    var packed = PackedScene.new()
    packed.pack(root)
    ResourceSaver.save(packed, "res://scenes/world/chunks/" + name + ".tscn")

func fill_rect(tm, x, y, w, h):
    for i in range(x, x+w):
        for j in range(y, y+h):
            tm.set_cell(Vector2i(i, j), 1, Vector2i(0, 0), 0)

func add_platform(root, x, y, w):
    var p = plat_scene.instantiate()
    p.set("width_tiles", w)
    p.position = Vector2(x * 16.0, y * 16.0)
    root.add_child(p)
    p.owner = root

func add_enemy(root, x, y, is_patrol=true):
    var sp = Node2D.new()
    sp.set_script(spawn_script)
    sp.name = "SpawnPoint_" + str(randi() % 1000)
    sp.position = Vector2(x * 16.0 + 8.0, y * 16.0)
    if is_patrol:
        sp.set("enemy_scene", patrol_scene)
        sp.set("enemy_stats", patrol_stats)
    else:
        sp.set("enemy_scene", kim_scene)
        sp.set("enemy_stats", kim_stats)
        sp.set("starting_element", "kim")
    root.add_child(sp)
    sp.owner = root

func _build_hallway(tm, root):
    add_platform(root, 5, 16.5, 4)
    add_platform(root, 17, 15.0, 4)
    fill_rect(tm, 8, 2, 2, 4)
    fill_rect(tm, 13, 2, 2, 6)
    fill_rect(tm, 20, 2, 2, 3)
    add_enemy(root, 6, 14.5)
    add_enemy(root, 18, 13.0, false)

func _build_start(tm, root):
    add_platform(root, 3, 15.0, 5)
    add_platform(root, 8, 11.5, 4)
    fill_rect(tm, 2, 2, 2, 16)

func _build_end(tm, root):
    add_platform(root, 18, 12.0, 5)
    add_platform(root, 13, 15.0, 5)
    add_enemy(root, 15, 13.0)
    add_enemy(root, 20, 10.0, false)
    add_enemy(root, 8, 16.0)

func _build_climb(tm, root):
    add_platform(root, 10, 16.5, 6)
    add_platform(root, 4, 15.0, 6)
    add_platform(root, 16, 13.5, 6)
    add_platform(root, 10, 12.0, 6)
    add_platform(root, 4, 10.5, 6)
    add_platform(root, 16, 9.0, 6)
    add_platform(root, 10, 7.5, 6)
    add_platform(root, 4, 6.0, 6)
    add_platform(root, 16, 4.5, 6)
    add_platform(root, 10, 3.0, 6)
    add_enemy(root, 12, 14.5)
    add_enemy(root, 18, 7.0, false)

func _build_drop(tm, root):
    add_platform(root, 4, 5.0, 4)
    add_platform(root, 18, 9.5, 4)
    add_platform(root, 8, 14.0, 4)
    add_enemy(root, 5, 3.0, false)
    add_enemy(root, 19, 7.5, false)

func _build_crossroads(tm, root):
    add_platform(root, 10, 10.5, 6)
    add_platform(root, 4, 6.0, 4)
    add_platform(root, 18, 6.0, 4)
    add_platform(root, 4, 15.0, 4)
    add_platform(root, 18, 15.0, 4)
    add_enemy(root, 13, 8.5)
    add_enemy(root, 5, 13.0, false)

func _build_hallway_v2(tm, root):
    add_platform(root, 2, 14.0, 6)
    add_platform(root, 18, 14.0, 6)
    add_platform(root, 11, 16.5, 4)
    fill_rect(tm, 12, 2, 2, 8)
    add_enemy(root, 4, 12.0, false)
    add_enemy(root, 20, 12.0)

func _build_climb_v2(tm, root):
    add_platform(root, 6, 16.5, 3)
    add_platform(root, 17, 16.5, 3)
    add_platform(root, 11, 15.0, 4)
    add_platform(root, 6, 13.5, 3)
    add_platform(root, 17, 13.5, 3)
    add_platform(root, 11, 12.0, 4)
    add_platform(root, 6, 10.5, 3)
    add_platform(root, 17, 10.5, 3)
    add_platform(root, 11, 9.0, 4)
    add_platform(root, 6, 7.5, 3)
    add_platform(root, 17, 7.5, 3)
    add_platform(root, 11, 6.0, 4)
    add_platform(root, 6, 4.5, 3)
    add_platform(root, 17, 4.5, 3)
    add_platform(root, 11, 3.0, 4)
    add_enemy(root, 13, 13.0, false)
    add_enemy(root, 13, 7.0, false)

func _build_crossroads_v2(tm, root):
    fill_rect(tm, 10, 8, 6, 4)
    add_platform(root, 3, 15.0, 4)
    add_platform(root, 19, 15.0, 4)
    add_platform(root, 11, 6.5, 4)
    add_platform(root, 3, 6.5, 3)
    add_platform(root, 20, 6.5, 3)
    add_enemy(root, 13, 4.5)
    add_enemy(root, 5, 13.0)
    add_enemy(root, 21, 13.0)
