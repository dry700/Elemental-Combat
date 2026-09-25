extends GutTest
## Unit tests for Player rune slot management (P5b)

const PLAYER_SCENE_PATH := "res://scenes/player/player.tscn"
const SaveTestIsolation := preload("res://test/helpers/save_test_isolation.gd")

var player: Player
var _original_save_path: String

func before_all():
	_original_save_path = SaveManager._save_path

func after_all():
	SaveTestIsolation.restore(_original_save_path)

func before_each():
	SaveTestIsolation.isolate()
	var player_scene: PackedScene = load(PLAYER_SCENE_PATH)
	player = player_scene.instantiate()
	add_child_autofree(player)

func test_apply_rune_sets_weapon_rune_and_returns_old():
	var old_rune := RuneData.new(Elements.HOA, RuneData.Target.WEAPON)
	player.weapon_rune = old_rune
	
	var new_rune := RuneData.new(Elements.THUY, RuneData.Target.WEAPON)
	var returned_old := player.apply_rune(new_rune, true)
	
	assert_eq(player.get_weapon_rune(true), new_rune)
	assert_eq(returned_old, old_rune)

func test_can_apply_rune_checks_for_weapon_presence():
	var rune := RuneData.new(Elements.THUY, RuneData.Target.WEAPON)
	
	player.weapon = null
	assert_false(player.can_apply_rune(rune, true))
	
	player.weapon = WeaponStats.new()
	assert_true(player.can_apply_rune(rune, true))
	
	player.secondary_weapon = null
	assert_false(player.can_apply_rune(rune, false))

func test_swap_weapon_updates_rune():
	var new_weapon := WeaponStats.new()
	var new_rune := RuneData.new(Elements.THO, RuneData.Target.WEAPON)
	
	player.swap_weapon(true, new_weapon, new_rune)
	
	assert_eq(player.weapon, new_weapon)
	assert_eq(player.get_weapon_rune(true), new_rune)
