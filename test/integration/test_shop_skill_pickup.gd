extends GutTest

const SAVE_TEST_ISOLATION := preload("res://test/helpers/save_test_isolation.gd")
const SHOP_SKILL_PICKUP_SCRIPT := preload("res://scripts/items/shop_skill_pickup.gd")
const PLAYER_SCENE_PATH := "res://scenes/player/player.tscn"
const SKILL_PATH := "res://scripts/resources/skills/ember_burst.tres"

var player: Player
var pickup: SkillPickup
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
	pickup = SHOP_SKILL_PICKUP_SCRIPT.new() as SkillPickup
	pickup.skill = load(SKILL_PATH) as SkillData
	add_child_autofree(pickup)

func after_each() -> void:
	UpgradeManager.reset()

func test_shop_skill_requires_funds_and_spends_price_on_purchase() -> void:
	UpgradeManager.award_qi(60.0)
	assert_true(pickup._do_pickup(player, false))
	assert_eq(player.skill_2, pickup.skill)
	assert_eq(UpgradeManager.qi, 0.0)

func test_shop_skill_cannot_be_purchased_without_funds() -> void:
	UpgradeManager.award_qi(59.0)
	assert_false(pickup._do_pickup(player, false))
	assert_null(player.skill_2)
	assert_eq(UpgradeManager.qi, 59.0)

func test_duplicate_shop_skill_is_blocked_without_spending_qi() -> void:
	player.skill_1 = pickup.skill
	UpgradeManager.award_qi(60.0)
	assert_false(pickup._do_pickup(player, false))
	assert_null(player.skill_2)
	assert_eq(UpgradeManager.qi, 60.0)
