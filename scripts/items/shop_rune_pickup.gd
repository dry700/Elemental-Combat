class_name ShopRunePickup
extends RunePickup

@export var price: int = 30


func purchase(player: Player, is_primary: bool) -> bool:
	if rune == null or player == null or not player.can_apply_rune(rune, is_primary):
		return false
	if not UpgradeManager.spend_qi(price):
		return false
	_do_pickup(player, is_primary)
	return true
