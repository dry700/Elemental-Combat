class_name ShopSkillPickup
extends SkillPickup
## A priced skill stall in a procedural shop.

@export var price: int = 60

func _do_pickup(player: Player, is_primary: bool) -> bool:
	if _picked_up or player == null or skill == null or player.would_duplicate_skill(is_primary, skill):
		return false
	if not UpgradeManager.spend_qi(price):
		return false
	return super._do_pickup(player, is_primary)

func _prompt_text() -> String:
	return "F %d Qi" % price
