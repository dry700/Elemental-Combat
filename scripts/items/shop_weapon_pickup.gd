class_name ShopWeaponPickup
extends WeaponPickup
## A priced weapon stall in a procedural shop.

@export var price: int = 35


func _do_pickup(player: Player, is_primary: bool) -> bool:
	if _picked_up or player == null or weapon == null or player.would_duplicate_weapon(is_primary, weapon):
		return false
	if not UpgradeManager.spend_qi(price):
		return false
	return super._do_pickup(player, is_primary)


func _prompt_text() -> String:
	return "F Buy %d Qi" % price


func _prompt_color() -> Color:
	return PROMPT_COLOR if UpgradeManager.qi >= price else Color(0.65, 0.65, 0.65, 0.9)


func _prompt_width() -> float:
	return 100.0
