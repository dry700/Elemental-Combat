extends GutTest
## Unit tests for Player.to_save_state()/apply_save_state() — the
## serialize/restore round trip RunManager's autosave and resume rely
## on. Uses real weapon/skill .tres assets so resource_path is genuinely
## populated (a runtime WeaponStats.new() has an empty resource_path and
## is correctly skipped — see the "" guards in both methods). Adjust the
## two paths below if your resources/ folder layout differs.

const PLAYER_SCENE_PATH := "res://scenes/player/player.tscn"
const WEAPON_PATH := "res://scripts/resources/weapons/training_dagger.tres"
const SKILL_PATH := "res://scripts/resources/skills/ignite_dart.tres"

var player: Player

func before_each():
	var player_scene: PackedScene = load(PLAYER_SCENE_PATH)
	player = player_scene.instantiate()
	add_child_autofree(player)

func test_to_save_state_captures_health_armor_and_equipped_paths():
	player.weapon = load(WEAPON_PATH)
	player.skill_1 = load(SKILL_PATH)
	player.current_health = 55.0
	player.elemental.armor = 7.0
	var state := player.to_save_state()
	assert_eq(state["current_health"], 55.0)
	assert_eq(state["armor"], 7.0)
	assert_eq(state["weapon_path"], WEAPON_PATH)
	assert_eq(state["skill_1_path"], SKILL_PATH)

func test_to_save_state_uses_empty_string_for_an_unset_slot():
	var state := player.to_save_state()
	assert_eq(state["secondary_weapon_path"], "")
	assert_eq(state["skill_2_path"], "")

func test_apply_save_state_restores_health_armor_and_weapon():
	var state := {
		"current_health": 33.0,
		"max_health": 100.0,
		"armor": 4.0,
		"weapon_path": WEAPON_PATH,
		"secondary_weapon_path": "",
		"skill_1_path": "",
		"skill_2_path": "",
	}
	player.apply_save_state(state)
	assert_eq(player.current_health, 33.0)
	assert_eq(player.elemental.armor, 4.0)
	assert_eq(player.weapon.resource_path, WEAPON_PATH)

func test_apply_save_state_leaves_a_slot_untouched_when_path_is_empty():
	var original_weapon := player.weapon
	var state := {"weapon_path": "", "secondary_weapon_path": "", "skill_1_path": "", "skill_2_path": ""}
	player.apply_save_state(state)
	assert_eq(player.weapon, original_weapon)

func test_save_then_apply_round_trips_correctly():
	player.weapon = load(WEAPON_PATH)
	player.skill_2 = load(SKILL_PATH)
	player.current_health = 21.0
	var state := player.to_save_state()

	var fresh_scene: PackedScene = load(PLAYER_SCENE_PATH)
	var fresh_player: Player = fresh_scene.instantiate()
	add_child_autofree(fresh_player)
	fresh_player.apply_save_state(state)

	assert_eq(fresh_player.current_health, 21.0)
	assert_eq(fresh_player.weapon.resource_path, WEAPON_PATH)
	assert_eq(fresh_player.skill_2.resource_path, SKILL_PATH)
