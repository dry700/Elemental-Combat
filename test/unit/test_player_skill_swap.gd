extends GutTest
## Unit tests for Player.swap_skill() — the data-side of skill pickups
## (see SkillPickup, which calls this on an F press). Mirrors
## test_player_weapon_swap.gd's structure for swap_weapon().

const PLAYER_SCENE_PATH := "res://scenes/player/player.tscn"

var player: Player

func before_each():
	var player_scene: PackedScene = load(PLAYER_SCENE_PATH)
	player = player_scene.instantiate()
	add_child_autofree(player)

func test_swap_primary_replaces_skill_1_and_returns_the_old_one():
	var original := player.skill_1
	var new_skill := SkillData.new()
	new_skill.element = Elements.THUY
	var returned := player.swap_skill(true, new_skill)
	assert_eq(player.skill_1, new_skill)
	assert_eq(returned, original)

func test_swap_secondary_replaces_skill_2_only():
	var original_skill_1 := player.skill_1
	var new_skill := SkillData.new()
	var returned := player.swap_skill(false, new_skill)
	assert_eq(player.skill_2, new_skill)
	assert_eq(player.skill_1, original_skill_1, "skill_1 must be untouched")
	assert_eq(returned, null, "skill_2 starts unset in the base scene")

func test_swap_emits_skill_changed_signal():
	watch_signals(player)
	var new_skill := SkillData.new()
	player.swap_skill(true, new_skill)
	assert_signal_emitted_with_parameters(player, "skill_changed", [true, new_skill])
