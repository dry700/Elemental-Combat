extends GutTest

const SaveTestIsolation := preload("res://test/helpers/save_test_isolation.gd")

var _original_save_path: String
var player: Player

func before_all():
	_original_save_path = SaveManager._save_path

func after_all():
	SaveTestIsolation.restore(_original_save_path)

func before_each():
	SaveTestIsolation.isolate()
	UpgradeManager.reset()
	RunManager.loop = 1
	RunManager._continue_loop = false
	RunManager.skip_scene_transitions = true
	var player_scene: PackedScene = load("res://scenes/player/player.tscn")
	player = player_scene.instantiate()
	add_child_autofree(player)
	player.elemental.armor = 0.0
	RunManager._player = player

func after_each():
	RunManager.loop = 1
	RunManager._continue_loop = false
	RunManager.skip_scene_transitions = false
	RunManager._player = null
	UpgradeManager.reset()

func test_loop_1_enemy_stats_untouched():
	RunManager.loop = 1
	var spawn_point := EnemySpawnPoint.new()
	add_child_autofree(spawn_point)
	spawn_point.enemy_scene = load("res://scenes/enemies/test_dummy.tscn")
	var stats := EnemyStats.new()
	stats.max_health = 40.0
	stats.damage = 10.0
	spawn_point.enemy_stats = stats
	
	var enemy = spawn_point.spawn()
	assert_not_null(enemy)
	autofree(enemy)
	assert_eq(enemy.enemy_stats.max_health, 40.0)
	assert_eq(enemy.enemy_stats.damage, 10.0)
	assert_eq(stats.max_health, 40.0)
	assert_eq(stats.damage, 10.0)

func test_loop_3_enemy_stats_scaled_by_one_point_five_and_shared_resource_untouched():
	RunManager.loop = 3
	var spawn_point := EnemySpawnPoint.new()
	add_child_autofree(spawn_point)
	spawn_point.enemy_scene = load("res://scenes/enemies/test_dummy.tscn")
	var stats := EnemyStats.new()
	stats.max_health = 40.0
	stats.damage = 10.0
	spawn_point.enemy_stats = stats
	
	var enemy = spawn_point.spawn()
	assert_not_null(enemy)
	autofree(enemy)
	assert_eq(enemy.enemy_stats.max_health, 60.0)
	assert_eq(enemy.enemy_stats.damage, 15.0)
	# Verify the original resource was not mutated
	assert_eq(stats.max_health, 40.0)
	assert_eq(stats.damage, 10.0)
	assert_ne(enemy.enemy_stats, stats)

func test_loop_3_scales_node_exports_for_flying_enemy():
	RunManager.loop = 3
	var spawn_point := EnemySpawnPoint.new()
	add_child_autofree(spawn_point)
	spawn_point.enemy_scene = load("res://scenes/enemies/flying_enemy.tscn")
	
	var enemy = spawn_point.spawn()
	assert_not_null(enemy)
	autofree(enemy)
	# Default flying enemy: max_health = 10.0, damage = 10.0
	assert_almost_eq(enemy.max_health, 15.0, 0.01)
	assert_almost_eq(enemy.damage, 15.0, 0.01)

func test_start_next_loop_increments_loop_and_preserves_upgrades():
	RunManager.loop = 1
	UpgradeManager.award_qi(100.0)
	UpgradeManager.purchase_weapon_might()
	var qi_before: float = UpgradeManager.qi
	var might_before: float = UpgradeManager.weapon_might_multiplier()
	
	RunManager.start_next_loop()
	assert_eq(RunManager.loop, 2)
	assert_true(RunManager._continue_loop)
	assert_eq(UpgradeManager.qi, qi_before)
	assert_eq(UpgradeManager.weapon_might_multiplier(), might_before)

func test_finish_run_win_keeps_upgrades_and_carries_runes():
	UpgradeManager.award_qi(50.0)
	UpgradeManager.purchase_weapon_might()
	
	var rune := RuneData.new()
	rune.element = Elements.HOA
	player.weapon_rune = rune
	
	RunManager._finish_run("win", 3)
	assert_eq(UpgradeManager.weapon_might_multiplier(), 1.1)
	assert_false(RunManager.pending_weapon_rune.is_empty())
	assert_eq(RunManager.pending_weapon_rune.get("element"), Elements.HOA)
	
	# Simulating next loop start consuming pending loadout
	var new_player_scene: PackedScene = load("res://scenes/player/player.tscn")
	var new_player: Player = new_player_scene.instantiate()
	add_child_autofree(new_player)
	RunManager.consume_pending_loadout(new_player)
	assert_not_null(new_player.weapon_rune)
	assert_eq(new_player.weapon_rune.element, Elements.HOA)
	assert_true(RunManager.pending_weapon_rune.is_empty())

func test_loss_resets_loop_and_upgrades():
	RunManager.loop = 3
	RunManager._continue_loop = true
	UpgradeManager.award_qi(100.0)
	UpgradeManager.purchase_weapon_might()
	
	RunManager._finish_run("loss", 2)
	assert_eq(RunManager.loop, 1)
	assert_false(RunManager._continue_loop)
	assert_eq(UpgradeManager.weapon_might_multiplier(), 1.0)
	assert_eq(UpgradeManager.qi, 0.0)

func test_save_and_resume_round_trips_loop():
	RunManager.loop = 4
	RunManager._sequence = ["res://scenes/world/rooms/procedural_room.tscn"]
	RunManager._current_index = 0
	var dummy_room := Node2D.new()
	add_child_autofree(dummy_room)
	RunManager._current_room = dummy_room
	RunManager._autosave()
	
	var saved: Dictionary = SaveManager.load_in_progress_run()
	assert_eq(int(saved.get("loop", 1)), 4)
	
	# Resume test
	RunManager.loop = 1
	var room_container := Node2D.new()
	add_child_autofree(room_container)
	RunManager._room_container = room_container
	RunManager._resume_from_save(saved)
	assert_eq(RunManager.loop, 4)

func test_room_completion_runlog_output():
	RunManager.loop = 2
	RunManager._room_start_time = 10.0
	RunManager._elapsed_sec = 25.5
	RunManager._room_start_hp = 100.0
	player.current_health = 75.0
	UpgradeManager.qi_earned_total = 30.0
	RunManager._room_start_qi_earned = 10.0
	UpgradeManager.qi_spent_total = 20.0
	RunManager._room_start_qi_spent = 0.0
	
	RunManager._log_room_completed(1)
	pass_test("Runlog executed without error")

