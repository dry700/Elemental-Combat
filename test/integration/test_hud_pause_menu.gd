extends GutTest

const SaveTestIsolation := preload("res://test/helpers/save_test_isolation.gd")

var _original_save_path: String
var player: Player
var room: Node2D


func before_all() -> void:
	_original_save_path = SaveManager._save_path


func after_all() -> void:
	SaveTestIsolation.restore(_original_save_path)


func before_each() -> void:
	SaveTestIsolation.isolate()
	get_tree().paused = false
	var player_scene := load("res://scenes/player/player.tscn") as PackedScene
	player = player_scene.instantiate() as Player
	add_child_autofree(player)
	player.weapon = load("res://scripts/resources/weapons/training_dagger.tres") as WeaponStats
	player.skill_1 = load("res://scripts/resources/skills/stoneguard.tres") as SkillData

	room = Node2D.new()
	add_child_autofree(room)
	RunManager._player = player
	RunManager._current_room = room
	RunManager._sequence = ["res://scenes/world/rooms/procedural_room.tscn"]
	RunManager._current_index = 0
	RunManager._elapsed_sec = 12.0
	RunManager._run_active = true
	Hud._player = player
	Hud._close_pause_menu()


func after_each() -> void:
	Input.action_release("menu_cancel")
	get_tree().paused = false
	Hud._pause_menu_active = false
	Hud._pause_overlay.visible = false
	Hud._player = null
	RunManager._run_active = false
	RunManager.set_process(false)
	RunManager._player = null
	RunManager._current_room = null
	RunManager._sequence = []
	RunManager._current_index = -1


func test_escape_opens_pause_menu_with_equipped_weapons_and_skills() -> void:
	Input.action_press("menu_cancel")
	Hud._handle_pause_input()

	assert_true(Hud._pause_menu_active)
	assert_true(Hud._pause_overlay.visible)
	assert_true(get_tree().paused)
	assert_eq(Hud._pause_weapon_cards.size(), 2)
	assert_eq(Hud._pause_skill_cards.size(), 2)
	assert_eq(
			Hud._pause_weapon_cards[0].get_node("MarginContainer/HBox/VBox/Title").text,
			player.weapon.weapon_name + " (EQUIPPED)")
	assert_eq(
			Hud._pause_weapon_cards[1].get_node("MarginContainer/HBox/VBox/Title").text,
			"Empty Weapon")
	assert_eq(
			Hud._pause_skill_cards[0].get_node("MarginContainer/HBox/VBox/Title").text,
			player.skill_1.skill_name)
	assert_eq(
			Hud._pause_skill_cards[1].get_node("MarginContainer/HBox/VBox/Title").text,
			"Empty Skill")


func test_continue_closes_pause_menu_and_resumes_game() -> void:
	Hud._open_pause_menu()
	Hud._close_pause_menu()

	assert_false(Hud._pause_menu_active)
	assert_false(Hud._pause_overlay.visible)
	assert_false(get_tree().paused)


func test_escape_does_not_override_an_active_equipment_overlay() -> void:
	Hud._overlay_active = true
	Input.action_press("menu_cancel")
	Hud._handle_pause_input()

	assert_false(Hud._pause_menu_active)
	assert_false(get_tree().paused)
	Hud._overlay_active = false


func test_save_mid_run_persists_equipment_and_current_room() -> void:
	assert_true(RunManager.save_mid_run())

	var saved: Dictionary = SaveManager.load_in_progress_run()
	assert_eq(saved.get("sequence"), RunManager._sequence)
	assert_eq(saved.get("current_index"), 0)
	assert_eq(saved.get("player", {}).get("weapon_path"), player.weapon.resource_path)
	assert_eq(saved.get("player", {}).get("skill_1_path"), player.skill_1.resource_path)
	assert_true(SaveManager.has_in_progress_run())
