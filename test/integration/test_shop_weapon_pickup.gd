extends GutTest

const SAVE_TEST_ISOLATION := preload("res://test/helpers/save_test_isolation.gd")
const SHOP_WEAPON_PICKUP_SCRIPT := preload("res://scripts/items/shop_weapon_pickup.gd")
const PLAYER_SCENE_PATH := "res://scenes/player/player.tscn"
const MEDIUM_WEAPON_PATH := "res://scripts/resources/weapons/training_spear.tres"

var player: Player
var pickup: WeaponPickup
var _original_save_path: String


func before_all() -> void:
	_original_save_path = SaveManager._save_path


func after_all() -> void:
	SAVE_TEST_ISOLATION.restore(_original_save_path)


func before_each() -> void:
	SAVE_TEST_ISOLATION.isolate()
	UpgradeManager.reset()
	player = load(PLAYER_SCENE_PATH).instantiate()
	add_child_autofree(player)
	pickup = SHOP_WEAPON_PICKUP_SCRIPT.new() as WeaponPickup
	pickup.weapon = load(MEDIUM_WEAPON_PATH) as WeaponStats
	pickup.price = 45
	add_child_autofree(pickup)


func after_each() -> void:
	UpgradeManager.reset()


func test_insufficient_qi_does_not_equip_or_charge() -> void:
	var original_secondary := player.secondary_weapon
	UpgradeManager.award_qi(44.0)

	var purchased: bool = pickup._do_pickup(player, false)

	assert_false(purchased)
	assert_eq(player.secondary_weapon, original_secondary)
	assert_eq(UpgradeManager.qi, 44.0)
	assert_false(pickup._picked_up)


func test_purchase_equips_weapon_and_deducts_price() -> void:
	UpgradeManager.award_qi(45.0)

	var purchased: bool = pickup._do_pickup(player, false)

	assert_true(purchased)
	assert_eq(player.secondary_weapon, pickup.weapon)
	assert_eq(UpgradeManager.qi, 0.0)
	assert_true(pickup._picked_up)


func test_duplicate_weapon_is_blocked_without_spending_qi() -> void:
	player.secondary_weapon = pickup.weapon
	UpgradeManager.award_qi(45.0)
	var original_primary := player.weapon

	var purchased: bool = pickup._do_pickup(player, true)

	assert_false(purchased)
	assert_eq(player.weapon, original_primary)
	assert_eq(UpgradeManager.qi, 45.0)
	assert_false(pickup._picked_up)


func test_invalid_shop_weapon_does_not_spend_qi() -> void:
	pickup.weapon = null
	UpgradeManager.award_qi(45.0)

	var purchased: bool = pickup._do_pickup(player, false)

	assert_false(purchased)
	assert_eq(UpgradeManager.qi, 45.0)
	assert_false(pickup._picked_up)
