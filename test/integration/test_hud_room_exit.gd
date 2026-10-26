extends GutTest

var player: Player
var room_exit: RoomExit

func before_each() -> void:
	player = load("res://scenes/player/player.tscn").instantiate() as Player
	add_child_autofree(player)
	room_exit = RoomExit.new()
	room_exit.locked = false
	add_child_autofree(room_exit)
	Hud._player = player
	Hud._active_weapon_pickup = null
	Hud._active_skill_pickup = null
	Hud._active_rune_pickup = null
	Hud._active_shop_station = null
	Hud._active_room_exit = null

func after_each() -> void:
	Input.action_release("pickup")
	Hud._close_overlay()
	Hud._active_weapon_pickup = null
	Hud._active_skill_pickup = null
	Hud._active_rune_pickup = null
	Hud._active_shop_station = null
	Hud._active_room_exit = null
	Hud._player = null

func test_f_press_at_unlocked_exit_emits_room_advance_signal() -> void:
	room_exit._on_body_entered(player)
	Hud._refresh_active_pickups()
	watch_signals(room_exit)
	Input.action_press("pickup")
	Hud._handle_pickup_overlay_input()
	assert_signal_emitted(room_exit, "player_entered")

func test_pickup_wins_when_pickup_and_exit_overlap() -> void:
	var pickup := WeaponPickup.new()
	pickup.weapon = WeaponStats.new()
	add_child_autofree(pickup)
	pickup._on_body_entered(player)
	room_exit._on_body_entered(player)
	Hud._refresh_active_pickups()
	watch_signals(room_exit)
	Input.action_press("pickup")
	Hud._handle_pickup_overlay_input()
	assert_true(pickup._picked_up, "F should equip the available pickup")
	assert_signal_not_emitted(room_exit, "player_entered", "the same F press must not also advance the room")
