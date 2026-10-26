extends GutTest

const PLAYER_SCENE_PATH := "res://scenes/player/player.tscn"

var room_exit: RoomExit
var player: Player

func before_each() -> void:
	room_exit = RoomExit.new()
	var visual := Polygon2D.new()
	visual.name = "Visual"
	room_exit.add_child(visual)
	add_child_autofree(room_exit)
	player = load(PLAYER_SCENE_PATH).instantiate() as Player
	add_child_autofree(player)

func test_player_entering_unlocked_exit_shows_prompt_but_does_not_advance() -> void:
	room_exit.locked = false
	watch_signals(room_exit)
	room_exit._on_body_entered(player)
	assert_true(room_exit.is_prompt_visible())
	assert_signal_not_emitted(room_exit, "player_entered")

func test_request_enter_emits_only_for_unlocked_exit_with_player_in_range() -> void:
	watch_signals(room_exit)
	assert_false(room_exit.request_enter(), "locked exit must ignore activation")
	room_exit.locked = false
	assert_false(room_exit.request_enter(), "exit requires player proximity")
	room_exit._on_body_entered(player)
	assert_true(room_exit.request_enter())
	assert_signal_emitted(room_exit, "player_entered")

func test_locked_exit_hides_prompt_even_when_player_is_inside() -> void:
	room_exit._on_body_entered(player)
	assert_false(room_exit.is_prompt_visible())
	room_exit.locked = false
	assert_true(room_exit.is_prompt_visible())
	room_exit._on_body_exited(player)
	assert_false(room_exit.is_prompt_visible())
