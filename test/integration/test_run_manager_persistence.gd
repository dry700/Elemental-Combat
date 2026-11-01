extends GutTest
## Integration tests for RunManager's SaveManager integration — autosave
## after a room transition, resuming from a save, and recording a
## win/loss into run history. Uses the real RunManager and SaveManager
## autoload singletons (same pattern as test_run_manager_sequence.gd),
## redirected to a throwaway save file for isolation.

const SaveTestIsolation := preload("res://test/helpers/save_test_isolation.gd")

var _original_save_path: String
var player: Player

func before_all():
	_original_save_path = SaveManager._save_path

func after_all():
	SaveTestIsolation.restore(_original_save_path)

func before_each():
	SaveTestIsolation.isolate()
	var player_scene: PackedScene = load("res://scenes/player/player.tscn")
	player = player_scene.instantiate()
	add_child_autofree(player)
	player.elemental.armor = 0.0
	# Reset RunManager's own state between tests — it's a persistent
	# autoload, not a fresh instance per test.
	RunManager._sequence = []
	RunManager._current_index = -1
	RunManager._current_room = null
	RunManager._player = player
	RunManager._elapsed_sec = 0.0
	RunManager._run_active = true
	RunManager.skip_scene_transitions = true
	if player.died.is_connected(RunManager._on_player_died):
		player.died.disconnect(RunManager._on_player_died)
	player.died.connect(RunManager._on_player_died)

func after_each():
	RunManager._run_active = false
	RunManager.skip_scene_transitions = false
	RunManager.set_process(false)
	RunManager._current_room = null
	RunManager._room_container = null
	RunManager._player = null

func test_finish_run_win_records_history_and_clears_save():
	RunManager._sequence = ["res://a.tscn", "res://b.tscn"]
	RunManager._elapsed_sec = 42.0
	SaveManager.save_in_progress_run(RunManager._sequence, 1, {}, 42.0)
	RunManager._finish_run("win", 2)
	var history := SaveManager.get_run_history()
	assert_eq(history[-1]["outcome"], "win")
	assert_eq(history[-1]["rooms_cleared"], 2)
	assert_false(SaveManager.has_in_progress_run())

func test_player_death_triggers_a_loss_record() -> void:
	RunManager._sequence = ["res://a.tscn", "res://b.tscn", "res://c.tscn"]
	RunManager._current_index = 1
	player._apply_damage(player.max_health)  # lethal
	await wait_for_signal(player.died, 1.0)
	var history := SaveManager.get_run_history()
	assert_eq(history[-1]["outcome"], "loss")
	assert_eq(history[-1]["rooms_cleared"], 1)

func test_player_death_in_shop_does_not_count_the_shop_as_cleared() -> void:
	RunManager._sequence = [
		"res://scenes/world/rooms/procedural_room.tscn",
		RunManager.SHOP_ROOM_SCENE_PATH,
		"res://scenes/world/rooms/procedural_room.tscn",
		RunManager.SHOP_ROOM_SCENE_PATH,
		RunManager.BOSS_ROOM_SCENE_PATH,
		RunManager.BOSS_SHOP_ROOM_SCENE_PATH,
	]
	RunManager._current_index = 3
	player._apply_damage(player.max_health)
	await wait_for_signal(player.died, 1.0)

	var history := SaveManager.get_run_history()
	assert_eq(history[-1]["outcome"], "loss")
	assert_eq(history[-1]["rooms_cleared"], 2, "the two preceding combat rooms count, but shops do not")

func test_boss_shop_stop_exit_finishes_with_combat_room_count() -> void:
	RunManager._sequence = [
		RunManager.ROOM_SCENE_PATHS[0],
		RunManager.SHOP_ROOM_SCENE_PATH,
		RunManager.ROOM_SCENE_PATHS[0],
		RunManager.SHOP_ROOM_SCENE_PATH,
		RunManager.ROOM_SCENE_PATHS[0],
		RunManager.SHOP_ROOM_SCENE_PATH,
		RunManager.BOSS_ROOM_SCENE_PATH,
		RunManager.BOSS_SHOP_ROOM_SCENE_PATH,
	]
	var stop_exit := RoomExit.new()
	stop_exit.exit_kind = RoomExit.ExitKind.STOP
	RunManager._on_room_exit_requested(stop_exit)
	stop_exit.free()

	var history := SaveManager.get_run_history()
	assert_eq(history[-1]["outcome"], "win")
	assert_eq(history[-1]["rooms_cleared"], 4, "three normal rooms and the boss count; four shops do not")

func test_death_after_run_already_finished_does_not_double_record() -> void:
	RunManager._sequence = ["res://a.tscn"]
	RunManager._finish_run("win", 1)  # _run_active is now false
	var count_before := SaveManager.get_run_history().size()
	player._apply_damage(player.max_health)
	await wait_for_signal(player.died, 1.0)
	assert_eq(SaveManager.get_run_history().size(), count_before, "a death after the run already ended must not add a second entry")

func test_resume_from_save_restores_sequence_and_player_state():
	var saved_sequence: Array[String] = ["res://a.tscn", "res://b.tscn", "res://c.tscn"]
	var player_state := {"current_health": 17.0, "weapon_path": "", "secondary_weapon_path": "", "skill_1_path": "", "skill_2_path": ""}
	# Point current_index PAST the sequence so _resume_from_save()'s own
	# call to _advance() hits the "run complete" branch instead of
	# trying to instantiate a real (possibly non-existent) room scene —
	# keeps this test focused on state restoration, not room loading.
	var saved := {
		"sequence": saved_sequence,
		"current_index": saved_sequence.size(),
		"elapsed_sec": 88.0,
		"player": player_state,
	}
	RunManager._resume_from_save(saved)
	assert_eq(RunManager._sequence, saved_sequence)
	assert_almost_eq(RunManager._elapsed_sec, 88.0, 0.01)
	assert_eq(player.current_health, 17.0)

func test_save_snapshot_round_trips_map_structure():
	var map_structure := {
		"grid_w": 4,
		"grid_h": 3,
		"start_cell": [0, 1],
		"finish_cell": [3, 1],
		"cells": [{"x": 0, "y": 1, "mask": 2, "chunk_path": "res://scenes/world/chunks/chunk_start.tscn"}],
	}
	SaveManager.save_in_progress_run(["res://scenes/world/rooms/procedural_room.tscn"], 0, {}, 12.0, map_structure)
	var saved: Dictionary = SaveManager.load_in_progress_run()
	assert_eq(saved["map_structure"], map_structure)

func test_resume_rebuilds_the_saved_procedural_map_structure():
	var source_generator := MapGenerator.new(4, 3)
	source_generator.load_pool_from_dir("res://scenes/world/chunks")
	source_generator.generate()
	var source_root := Node2D.new()
	source_generator.build_map(source_root)
	add_child_autofree(source_root)
	var map_structure := source_generator.to_dict()
	var room_container := Node2D.new()
	add_child_autofree(room_container)
	RunManager._room_container = room_container
	var saved := {
		"sequence": ["res://scenes/world/rooms/procedural_room.tscn"],
		"current_index": 0,
		"elapsed_sec": 23.0,
		"player": {"current_health": 25.0},
		"map_structure": map_structure,
	}
	RunManager._resume_from_save(saved)
	var resumed_room := RunManager._current_room as ProceduralRoomController
	assert_not_null(resumed_room)
	assert_eq(resumed_room.map_gen.to_dict(), map_structure)

func test_playtest_teleports_to_start_finish_and_any_chunk():
	var room := load("res://scenes/world/rooms/procedural_room.tscn").instantiate() as ProceduralRoomController
	add_child_autofree(room)
	RunManager._current_room = room
	var start_position := room.get_player_spawn_position()
	assert_true(RunManager.teleport_player_to_playtest_target("start"))
	assert_eq(player.global_position, start_position)
	assert_true(RunManager.teleport_player_to_playtest_target("finish"))
	var cell: Vector2i = room.get_playtest_cells()[0]
	var chunk_position: Vector2 = room.get_playtest_teleport_position(cell)
	assert_true(RunManager.teleport_player_to_playtest_target(cell))
	assert_eq(player.global_position, chunk_position)

func test_playtest_regenerates_current_procedural_room():
	var room_container := Node2D.new()
	add_child_autofree(room_container)
	var room := load("res://scenes/world/rooms/procedural_room.tscn").instantiate() as ProceduralRoomController
	room_container.add_child(room)
	RunManager._room_container = room_container
	RunManager._current_room = room
	RunManager._sequence = ["res://scenes/world/rooms/procedural_room.tscn"]
	RunManager._current_index = 0
	assert_true(RunManager.regenerate_current_room())
	await get_tree().process_frame
	assert_not_null(RunManager._current_room)
	assert_ne(RunManager._current_room, room)
	assert_true(RunManager._current_room is ProceduralRoomController)

func test_save_snapshot_round_trips_shop_state():
	var shop_state := {
		"stock": {
			"weapon": [
				{"type": "shop_weapon", "weapon_path": "res://scripts/resources/weapons/training_dagger.tres", "cost": 35, "purchased": true},
				{"type": "shop_weapon", "weapon_path": "res://scripts/resources/weapons/training_spear.tres", "cost": 45, "purchased": false},
			],
			"skill": [
				{"type": "shop_skill", "skill_path": "res://scripts/resources/skills/ember_burst.tres", "cost": 60, "purchased": false},
			],
			"rune": [
				{"type": "shop_rune", "rune": {"element": "hoa", "target": 0, "modifiers": [{"id": "damage_pct", "value": 15.0}]}, "cost": 30, "purchased": false},
			]
		},
		"refresh_counts": {}
	}
	SaveManager.save_in_progress_run(
		[RunManager.SHOP_ROOM_SCENE_PATH], 0, {}, 10.0, {}, {}, 1, shop_state
	)
	var saved: Dictionary = SaveManager.load_in_progress_run()
	assert_not_null(saved)
	assert_eq(saved["shop_state"]["stock"]["weapon"].size(), 2)
	assert_true(saved["shop_state"]["stock"]["weapon"][0]["purchased"])
	assert_eq(saved["shop_state"]["stock"]["skill"][0]["skill_path"], "res://scripts/resources/skills/ember_burst.tres")
	assert_eq(saved["shop_state"]["stock"]["rune"][0]["rune"]["element"], "hoa")

func test_legacy_snapshot_without_shop_state_still_loads_cleanly():
	var room_container := Node2D.new()
	add_child_autofree(room_container)
	RunManager._room_container = room_container
	var saved := {
		"sequence": [RunManager.SHOP_ROOM_SCENE_PATH],
		"current_index": 0,
		"elapsed_sec": 15.0,
		"player": {"current_health": 40.0},
		"upgrade_state": {},
		"loop": 1,
	}
	# Has no "shop_state" key — legacy format.
	RunManager._resume_from_save(saved)
	assert_not_null(RunManager._current_room)
	assert_true(RunManager._current_room is ShopRoom)
	assert_eq(player.current_health, 40.0)

	# When opening a shop station, missing stock rolls fresh without error
	Hud._player = player
	Hud._open_shop_menu(ShopStation.Category.WEAPON)
	assert_eq(Hud._all_upgrade_options.size(), 3)
	Hud._close_upgrade_menu()
	Hud.clear_shop_stock()
	Hud._player = null

func test_resume_in_shop_room_restores_exact_station_offers_and_purchased_flags():
	var room_container := Node2D.new()
	add_child_autofree(room_container)
	RunManager._room_container = room_container
	var shop_state := {
		"stock": {
			"weapon": [
				{"type": "shop_weapon", "weapon_path": "res://scripts/resources/weapons/training_dagger.tres", "cost": 35, "purchased": true},
				{"type": "shop_weapon", "weapon_path": "res://scripts/resources/weapons/training_spear.tres", "cost": 45, "purchased": false},
			],
			"skill": [
				{"type": "shop_skill", "skill_path": "res://scripts/resources/skills/ember_burst.tres", "cost": 60, "purchased": false},
			],
			"rune": [
				{"type": "shop_rune", "rune": {"element": "hoa", "target": 0, "modifiers": [{"id": "damage_pct", "value": 20.0}]}, "cost": 30, "purchased": true},
			]
		}
	}
	var saved := {
		"sequence": [RunManager.SHOP_ROOM_SCENE_PATH],
		"current_index": 0,
		"elapsed_sec": 20.0,
		"player": {"current_health": 50.0},
		"upgrade_state": {},
		"loop": 1,
		"shop_state": shop_state,
	}
	RunManager._resume_from_save(saved)
	assert_not_null(RunManager._current_room)
	assert_true(RunManager._current_room is ShopRoom)

	Hud._player = player

	# Check weapon stock
	Hud._open_shop_menu(ShopStation.Category.WEAPON)
	assert_eq(Hud._all_upgrade_options.size(), 2)
	assert_eq(Hud._all_upgrade_options[0]["weapon"].resource_path, "res://scripts/resources/weapons/training_dagger.tres")
	assert_true(Hud._all_upgrade_options[0]["purchased"])
	assert_eq(Hud._all_upgrade_options[1]["weapon"].resource_path, "res://scripts/resources/weapons/training_spear.tres")
	assert_false(Hud._all_upgrade_options[1]["purchased"])
	Hud._close_upgrade_menu()

	# Check skill stock
	Hud._open_shop_menu(ShopStation.Category.SKILL)
	assert_eq(Hud._all_upgrade_options.size(), 1)
	assert_eq(Hud._all_upgrade_options[0]["skill"].resource_path, "res://scripts/resources/skills/ember_burst.tres")
	assert_false(Hud._all_upgrade_options[0]["purchased"])
	Hud._close_upgrade_menu()

	# Check rune stock
	Hud._open_shop_menu(ShopStation.Category.RUNE)
	assert_eq(Hud._all_upgrade_options.size(), 1)
	assert_eq(Hud._all_upgrade_options[0]["rune"].element, "hoa")
	assert_true(Hud._all_upgrade_options[0]["purchased"])
	Hud._close_upgrade_menu()

	Hud.clear_shop_stock()
	Hud._player = null

func test_shop_purchase_triggers_autosave_so_resume_preserves_purchase():
	var room_container := Node2D.new()
	add_child_autofree(room_container)
	RunManager._room_container = room_container
	RunManager._sequence = [RunManager.SHOP_ROOM_SCENE_PATH]
	RunManager._current_index = -1
	RunManager._advance()

	Hud._player = player
	UpgradeManager.reset()
	UpgradeManager.award_qi(100)

	# Open weapon shop and roll offers
	Hud._open_shop_menu(ShopStation.Category.WEAPON)
	assert_eq(Hud._all_upgrade_options.size(), 3)
	var target_offer: Dictionary = Hud._all_upgrade_options[0]
	assert_false(target_offer["purchased"])

	# Purchase the first offer
	Hud._open_shop_offer(target_offer)
	assert_true(Hud._overlay_active)
	Hud._confirm_overlay_selection()

	# Verify it marked purchased in memory
	assert_true(target_offer["purchased"])

	# Verify autosave was triggered and written to SaveManager
	var saved: Dictionary = SaveManager.load_in_progress_run()
	assert_not_null(saved, "mid-run save should exist immediately after purchase")
	var saved_shop_state: Dictionary = saved.get("shop_state", {})
	assert_false(saved_shop_state.is_empty(), "saved shop state should not be empty")
	var saved_weapons: Array = saved_shop_state.get("stock", {}).get("weapon", [])
	assert_gte(saved_weapons.size(), 1)
	assert_true(saved_weapons[0]["purchased"], "saved offer should be marked purchased to prevent exploit")

	Hud._close_upgrade_menu()
	Hud.clear_shop_stock()
	Hud._player = null
	UpgradeManager.reset()
