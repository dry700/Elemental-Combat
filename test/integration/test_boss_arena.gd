extends GutTest

const BOSS_ROOM_PATH := "res://scenes/world/rooms/room_boss.tscn"
const THO_NGUU_STATS_PATH := "res://scripts/resources/enemies/tho_nguu_boss_stats.tres"

func test_boss_room_dimensions_and_camera_limits() -> void:
	var room := load(BOSS_ROOM_PATH).instantiate() as RoomController
	add_child_autofree(room)

	assert_not_null(room)
	assert_eq(room.camera_horizontal_limits, Vector2(-330, 330))

	var boundary_left := room.get_node_or_null("BoundaryLeft") as StaticBody2D
	var boundary_right := room.get_node_or_null("BoundaryRight") as StaticBody2D
	assert_not_null(boundary_left)
	assert_not_null(boundary_right)
	assert_almost_eq(boundary_left.position.x, -320.0, 0.01)
	assert_almost_eq(boundary_right.position.x, 320.0, 0.01)

	var ground := room.get_node_or_null("Ground") as StaticBody2D
	assert_not_null(ground)
	var collision := ground.get_node("CollisionShape2D") as CollisionShape2D
	var ground_shape := collision.shape as RectangleShape2D
	assert_almost_eq(ground_shape.size.x, 640.0, 0.01)


func test_boss_room_contains_one_way_platforms() -> void:
	var room := load(BOSS_ROOM_PATH).instantiate() as RoomController
	add_child_autofree(room)

	var platforms: Array[Node] = room.find_children("*", "OneWayPlatform", true, false)
	assert_gte(platforms.size(), 3, "boss room should contain several one-way platforms at different heights")
	for p in platforms:
		var platform := p as OneWayPlatform
		assert_not_null(platform)
		assert_gt(platform.width_tiles, 0)


func test_boss_room_wave_marker_groups_segregated_from_initial_spawn() -> void:
	var room := load(BOSS_ROOM_PATH).instantiate() as RoomController
	add_child_autofree(room)

	# Only the boss itself should be a direct EnemySpawnPoint child of RoomBoss
	var direct_spawn_points: int = 0
	for child in room.get_children():
		if child is EnemySpawnPoint:
			direct_spawn_points += 1
	assert_eq(direct_spawn_points, 1, "only the boss should be a direct spawn point child")

	var wave_1 := room.get_node_or_null("Wave1Spawns") as Node2D
	var wave_2 := room.get_node_or_null("Wave2Spawns") as Node2D
	var wave_3 := room.get_node_or_null("Wave3Spawns") as Node2D
	assert_not_null(wave_1)
	assert_not_null(wave_2)
	assert_not_null(wave_3)

	for wave in [wave_1, wave_2, wave_3]:
		var spawns: Array[Node] = wave.find_children("*", "EnemySpawnPoint", false, false)
		assert_gte(spawns.size(), 4, "each wave must have at least brawler, flyer, shooter, support")

		var has_brawler := false
		var has_flyer := false
		var has_shooter := false
		var has_support := false

		for node in spawns:
			var sp := node as EnemySpawnPoint
			var scene_path: String = sp.enemy_scene.resource_path if sp.enemy_scene != null else ""
			if scene_path.ends_with("patrol_dummy.tscn"):
				has_brawler = true
			elif scene_path.ends_with("flying_enemy.tscn"):
				has_flyer = true
			elif scene_path.ends_with("shooter_enemy.tscn"):
				has_shooter = true
			elif scene_path.ends_with("shielder_enemy.tscn") or scene_path.ends_with("armor_buffer_enemy.tscn"):
				has_support = true

		assert_true(has_brawler, "%s has brawler" % wave.name)
		assert_true(has_flyer, "%s has flyer" % wave.name)
		assert_true(has_shooter, "%s has shooter" % wave.name)
		assert_true(has_support, "%s has support" % wave.name)


func test_boss_spawn_point_uses_tho_nguu_stats() -> void:
	var room_scene: PackedScene = load(BOSS_ROOM_PATH)
	var room := room_scene.instantiate()
	# Don't add to tree so EnemySpawnPoint doesn't resolve and free itself yet
	var sp := room.get_node_or_null("EnemySpawnPoint") as EnemySpawnPoint
	assert_not_null(sp)
	assert_not_null(sp.boss_stats)
	assert_eq(sp.boss_stats.boss_name, "Thổ Ngưu")
	assert_eq(sp.boss_stats.element, Elements.THO)
	room.free()
