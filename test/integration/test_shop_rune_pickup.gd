extends GutTest

const SHOP_RUNE_PICKUP_SCRIPT := preload("res://scripts/items/shop_rune_pickup.gd")

var player: Player
var pickup: Node


func before_each() -> void:
	UpgradeManager.reset()
	player = load("res://scenes/player/player.tscn").instantiate() as Player
	player.weapon = load("res://scripts/resources/weapons/training_dagger.tres")
	add_child_autofree(player)
	pickup = SHOP_RUNE_PICKUP_SCRIPT.new()
	pickup.set("rune", RuneData.new(Elements.KIM, RuneData.Target.WEAPON))
	add_child_autofree(pickup)


func after_each() -> void:
	UpgradeManager.reset()


func test_shop_rune_requires_funds_and_does_not_spend_when_unaffordable() -> void:
	UpgradeManager.award_qi(29)
	assert_false(bool(pickup.call("purchase", player, true)))
	assert_null(player.weapon_rune)
	assert_eq(UpgradeManager.qi, 29.0)


func test_shop_rune_purchase_equips_and_deducts_price() -> void:
	UpgradeManager.award_qi(30)
	assert_true(bool(pickup.call("purchase", player, true)))
	assert_eq(player.weapon_rune.element, Elements.KIM)
	assert_eq(UpgradeManager.qi, 0.0)
