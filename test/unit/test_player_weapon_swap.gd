extends GutTest
## Unit tests for Player.swap_weapon() — the data-side of the weapon
## pickup system (see WeaponPickup, which calls this on player contact).

const PLAYER_SCENE_PATH := "res://scenes/player/player.tscn"

var player: Player

const SaveTestIsolation := preload("res://test/helpers/save_test_isolation.gd")

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

func test_swap_primary_replaces_weapon_and_returns_the_old_one():
	var original := player.weapon
	var new_weapon := WeaponStats.new()
	new_weapon.innate_element = Elements.THUY
	var returned := player.swap_weapon(true, new_weapon)
	assert_eq(player.weapon, new_weapon)
	assert_eq(returned, original)

func test_swap_secondary_replaces_secondary_only():
	var original_primary := player.weapon
	var new_weapon := WeaponStats.new()
	var returned := player.swap_weapon(false, new_weapon)
	assert_eq(player.secondary_weapon, new_weapon)
	assert_eq(player.weapon, original_primary, "primary slot must be untouched")
	assert_eq(returned, null, "secondary_weapon starts unset in the base scene")

func test_swap_emits_weapon_changed_signal():
	watch_signals(player)
	var new_weapon := WeaponStats.new()
	player.swap_weapon(true, new_weapon)
	assert_signal_emitted_with_parameters(player, "weapon_changed", [true, new_weapon])
