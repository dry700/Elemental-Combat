extends GutTest
## Integration tests for WeaponPickup — proximity tracking (body_entered/
## body_exited), the F quick-pickup default-slot logic, and the explicit
## 1/2 slot choice (A.4, "full swap"). Exercised directly via those
## callbacks/_do_pickup()/_default_target_is_primary() rather than
## simulating real Area2D physics overlap or real F/1/2 InputEvents
## (avoids physics-frame and InputMap-timing flakiness while still
## exercising the real code path).

const PLAYER_SCENE_PATH := "res://scenes/player/player.tscn"

var player: Player
var pickup: WeaponPickup

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
	pickup = WeaponPickup.new()
	pickup.weapon = WeaponStats.new()
	pickup.weapon.innate_element = Elements.KIM
	pickup.slot = WeaponPickup.Slot.PRIMARY
	add_child_autofree(pickup)

func test_entering_range_does_not_equip_by_itself():
	var original := player.weapon
	pickup._on_body_entered(player)
	assert_eq(player.weapon, original, "proximity alone must not equip — needs a key press")

func test_explicit_choice_of_slot_1_equips_primary_regardless_of_pickups_default():
	pickup.slot = WeaponPickup.Slot.SECONDARY  # default would target secondary
	pickup._on_body_entered(player)
	pickup._do_pickup(player, true)  # player explicitly chose "1"
	assert_eq(player.weapon, pickup.weapon, "explicit slot 1 must win over the pickup's own default")

func test_explicit_choice_of_slot_2_equips_secondary_regardless_of_pickups_default():
	pickup.slot = WeaponPickup.Slot.PRIMARY  # default would target primary
	var original_primary := player.weapon
	pickup._on_body_entered(player)
	pickup._do_pickup(player, false)  # player explicitly chose "2"
	assert_eq(player.secondary_weapon, pickup.weapon)
	assert_eq(player.weapon, original_primary, "primary must be untouched by an explicit slot-2 choice")

func test_quick_pickup_defaults_to_an_empty_slot_over_the_pickups_own_default():
	pickup.slot = WeaponPickup.Slot.PRIMARY  # would normally target primary
	# Fresh Player scene fills `weapon` via its own _ready() fallback but
	# leaves secondary_weapon empty — the actually-empty slot should win.
	assert_null(player.secondary_weapon)
	pickup._on_body_entered(player)
	assert_false(pickup._default_target_is_primary(player), "quick pickup should prefer the empty secondary slot")

func test_quick_pickup_falls_back_to_the_pickups_own_slot_when_both_full():
	pickup.slot = WeaponPickup.Slot.SECONDARY
	player.secondary_weapon = WeaponStats.new()  # fill the previously-empty slot too
	pickup._on_body_entered(player)
	assert_false(pickup._default_target_is_primary(player), "with both slots full, falls back to the pickup's own preferred slot (secondary)")

func test_leaving_range_clears_the_prompt_target():
	pickup._on_body_entered(player)
	pickup._on_body_exited(player)
	assert_null(pickup._player_in_range)

func test_a_second_pickup_call_after_pickup_does_nothing():
	pickup._on_body_entered(player)
	pickup._do_pickup(player, true)
	var equipped := player.weapon
	assert_true(pickup._picked_up)
	assert_eq(player.weapon, equipped)

func test_contact_from_a_non_player_body_is_ignored():
	var stranger := Node2D.new()
	add_child_autofree(stranger)
	var original := player.weapon
	pickup._on_body_entered(stranger)
	assert_null(pickup._player_in_range)
	assert_eq(player.weapon, original)
