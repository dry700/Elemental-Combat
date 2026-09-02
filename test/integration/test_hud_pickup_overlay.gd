extends GutTest
## Integration tests for Hud's weapon/skill pickup selection overlay —
## opening on "pickup" (F), navigating, confirming via F/1/2/click, and
## closing without equipping. Uses the real Hud singleton (same
## reasoning as test_hud_pickup_prompts.gd) and forces Hud._player
## directly rather than waiting a frame for _refresh_player_ref().

var player: Player
var pickup: WeaponPickup

func before_each():
	var player_scene: PackedScene = load("res://scenes/player/player.tscn")
	player = player_scene.instantiate()
	add_child_autofree(player)
	pickup = WeaponPickup.new()
	pickup.weapon = WeaponStats.new()
	pickup.weapon.weapon_name = "Test Blade"
	add_child_autofree(pickup)
	Hud._player = player

func after_each():
	Hud._close_overlay()
	Hud._active_weapon_pickup = null
	Hud._player = null

func test_opening_overlay_sets_active_and_targets_the_pickup():
	pickup._on_body_entered(player)
	Hud._open_overlay(pickup, true)
	assert_true(Hud.is_overlay_active())
	assert_eq(Hud._overlay_pickup, pickup)

func test_confirm_equips_the_selected_slot_and_closes_overlay():
	var original := player.weapon
	Hud._open_overlay(pickup, true)
	Hud._overlay_selected_primary = true
	Hud._confirm_overlay_selection()
	assert_eq(player.weapon, pickup.weapon)
	assert_ne(player.weapon, original)
	assert_false(Hud.is_overlay_active())

func test_confirm_targeting_secondary_leaves_primary_untouched():
	var original_primary := player.weapon
	Hud._open_overlay(pickup, true)
	Hud._overlay_selected_primary = false
	Hud._confirm_overlay_selection()
	assert_eq(player.secondary_weapon, pickup.weapon)
	assert_eq(player.weapon, original_primary)

func test_mouse_click_on_an_option_selects_and_confirms_immediately():
	Hud._open_overlay(pickup, true)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	Hud._on_overlay_option_gui_input(event, false)
	assert_eq(player.secondary_weapon, pickup.weapon)
	assert_false(Hud.is_overlay_active())

func test_close_overlay_does_not_equip_anything():
	var original := player.weapon
	Hud._open_overlay(pickup, true)
	Hud._close_overlay()
	assert_eq(player.weapon, original)
	assert_false(Hud.is_overlay_active())

func test_cannot_open_overlay_while_player_is_attacking():
	player.state = Player.State.ATTACK
	assert_false(Hud._can_open_overlay())
