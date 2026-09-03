extends GutTest
## Unit tests for Player's death handling (Player._apply_damage/_die) —
## added specifically so RunManager has a real "loss" condition to
## record in the run history (see save_manager.gd/run_manager.gd).

const PLAYER_SCENE_PATH := "res://scenes/player/player.tscn"

var player: Player

func before_each():
	var player_scene: PackedScene = load(PLAYER_SCENE_PATH)
	player = player_scene.instantiate()
	add_child_autofree(player)

func test_damage_below_max_health_does_not_die():
	player._apply_damage(player.max_health * 0.5)
	assert_false(player._is_dead)

func test_lethal_damage_triggers_death():
	watch_signals(player)
	player._apply_damage(player.max_health)
	assert_true(player._is_dead)
	assert_signal_emitted(player, "died")

func test_died_signal_fires_only_once():
	watch_signals(player)
	player._apply_damage(player.max_health)
	player._apply_damage(10.0)
	assert_signal_emit_count(player, "died", 1)

func test_further_damage_after_death_does_not_reduce_health_further():
	player._apply_damage(player.max_health)
	var health_at_death := player.current_health
	player._apply_damage(50.0)
	assert_eq(player.current_health, health_at_death)

func test_current_health_never_goes_negative():
	player._apply_damage(player.max_health * 5.0)
	assert_eq(player.current_health, 0.0)
