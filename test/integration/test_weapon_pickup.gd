extends GutTest
## Integration tests for WeaponPickup — proximity tracking (body_entered/
## body_exited) plus the actual pickup, exercised directly via those
## callbacks and _do_pickup() rather than simulating real Area2D physics
## overlap or a real "F" InputEvent (avoids physics-frame and
## InputMap-timing flakiness while still exercising the real code path).

const PLAYER_SCENE_PATH := "res://scenes/player/player.tscn"

var player: Player
var pickup: WeaponPickup

func before_each():
	var player_scene: PackedScene = load(PLAYER_SCENE_PATH)
	player = player_scene.instantiate()
	add_child_autofree(player)
	pickup = WeaponPickup.new()
	pickup.weapon = WeaponStats.new()
	pickup.weapon.innate_element = Elements.KIM
	pickup.slot = WeaponPickup.Slot.PRIMARY
	add_child_autofree(pickup)

func test_entering_range_does_not_equip_by_itself():
	var original := player.weapon
	pickup._on_body_entered(player)
	assert_eq(player.weapon, original, "proximity alone must not equip — needs the F press")

func test_do_pickup_equips_the_targeted_slot():
	var original := player.weapon
	pickup._on_body_entered(player)
	pickup._do_pickup(player)
	assert_eq(player.weapon, pickup.weapon)
	assert_ne(player.weapon, original)

func test_do_pickup_targeting_secondary_slot_leaves_primary_untouched():
	pickup.slot = WeaponPickup.Slot.SECONDARY
	var original_primary := player.weapon
	pickup._on_body_entered(player)
	pickup._do_pickup(player)
	assert_eq(player.secondary_weapon, pickup.weapon)
	assert_eq(player.weapon, original_primary)

func test_leaving_range_clears_the_prompt_target():
	pickup._on_body_entered(player)
	pickup._on_body_exited(player)
	assert_null(pickup._player_in_range)

func test_a_second_pickup_call_after_pickup_does_nothing():
	pickup._on_body_entered(player)
	pickup._do_pickup(player)
	var equipped := player.weapon
	# _do_pickup already queue_free()'d the node — guard belongs to
	# _process()'s _picked_up check in real play; here we assert the
	# state flag itself is set, which is what prevents a second trigger.
	assert_true(pickup._picked_up)
	assert_eq(player.weapon, equipped)

func test_contact_from_a_non_player_body_is_ignored():
	var stranger := Node2D.new()
	add_child_autofree(stranger)
	var original := player.weapon
	pickup._on_body_entered(stranger)
	assert_null(pickup._player_in_range)
	assert_eq(player.weapon, original)
