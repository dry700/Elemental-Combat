extends GutTest

const SHOP_ROOM_PATH := "res://scenes/world/rooms/shop_room.tscn"
const BOSS_SHOP_ROOM_PATH := "res://scenes/world/rooms/boss_shop_room.tscn"


func test_shop_room_starts_cleared_without_baseline_rune() -> void:
	var room := load(SHOP_ROOM_PATH).instantiate() as RoomController
	add_child_autofree(room)

	assert_true(room._is_cleared)
	assert_false(room.exit.locked)
	assert_true(room.get_tree().get_nodes_in_group("rune_pickups").is_empty())


func test_shop_room_has_one_station_for_each_category() -> void:
	var room := load(SHOP_ROOM_PATH).instantiate() as RoomController
	add_child_autofree(room)
	var categories: Array[int] = []
	for node in room.get_children():
		if node is ShopStation:
			categories.append(int(node.category))

	assert_eq(categories.size(), 4)
	assert_true(categories.has(ShopStation.Category.UPGRADE))
	assert_true(categories.has(ShopStation.Category.WEAPON))
	assert_true(categories.has(ShopStation.Category.SKILL))
	assert_true(categories.has(ShopStation.Category.RUNE))


func test_boss_shop_exposes_stop_and_deeper_exits() -> void:
	var room := load(BOSS_SHOP_ROOM_PATH).instantiate() as RoomController
	add_child_autofree(room)

	var stop_exit := room.get_node("Exit") as RoomExit
	var deeper_exit := room.get_node("DeeperExit") as RoomExit
	assert_false(stop_exit.locked)
	assert_false(deeper_exit.locked)
	assert_eq(stop_exit.label, "Stop")
	assert_eq(stop_exit.exit_kind, RoomExit.ExitKind.STOP)
	assert_eq(deeper_exit.label, "Go deeper")
	assert_eq(deeper_exit.exit_kind, RoomExit.ExitKind.DEEPER)


func test_weapon_skill_and_rune_stations_roll_three_offers() -> void:
	for category in [ShopStation.Category.WEAPON, ShopStation.Category.SKILL, ShopStation.Category.RUNE]:
		var offers: Array[Dictionary] = Hud._roll_shop_offers(category)
		assert_eq(offers.size(), 3)
		for offer in offers:
			assert_true(str(offer.get("type", "")).begins_with("shop_"))
			assert_gt(int(offer.get("cost", 0)), 0)


func test_weapon_offer_uses_slot_chooser_and_charges_only_on_confirm() -> void:
	var room := load(SHOP_ROOM_PATH).instantiate() as RoomController
	add_child_autofree(room)
	var player := load("res://scenes/player/player.tscn").instantiate() as Player
	room.add_child(player)
	player.weapon = load("res://scripts/resources/weapons/training_dagger.tres")
	RunManager._current_room = room
	Hud._player = player
	UpgradeManager.reset()
	UpgradeManager.award_qi(45)
	var offer := {
		"type": "shop_weapon",
		"cost": 45,
		"weapon": load("res://scripts/resources/weapons/training_spear.tres"),
		"purchased": false,
	}

	Hud._open_shop_offer(offer)
	assert_true(Hud._overlay_active)
	assert_eq(UpgradeManager.qi, 45.0)
	Hud._confirm_overlay_selection()

	assert_eq(player.secondary_weapon.weapon_name, "Training Spear")
	assert_eq(UpgradeManager.qi, 0.0)
	assert_true(offer["purchased"])
	Hud._close_overlay()
	Hud._shop_offer_opened_overlay = false
	Hud._player = null
	RunManager._current_room = null
	UpgradeManager.reset()


func test_category_station_opens_its_three_offer_menu() -> void:
	var room := load(SHOP_ROOM_PATH).instantiate() as RoomController
	add_child_autofree(room)
	RunManager._current_room = room
	Hud._player = load("res://scenes/player/player.tscn").instantiate() as Player
	add_child_autofree(Hud._player)
	Hud._open_shop_menu(ShopStation.Category.SKILL)

	assert_true(Hud.is_upgrade_menu_active())
	assert_eq(Hud._upgrade_menu_category, ShopStation.Category.SKILL)
	assert_eq(Hud._all_upgrade_options.size(), 3)
	assert_true(str(Hud._all_upgrade_options[0].get("type", "")).begins_with("shop_skill"))

	Hud._close_upgrade_menu()
	Hud._shop_offer_stock.clear()
	Hud._shop_stock_room_id = 0
	Hud._player = null
	RunManager._current_room = null


func test_skill_offer_uses_slot_chooser_and_charges_only_on_confirm() -> void:
	var room := load(SHOP_ROOM_PATH).instantiate() as RoomController
	add_child_autofree(room)
	var player := load("res://scenes/player/player.tscn").instantiate() as Player
	room.add_child(player)
	RunManager._current_room = room
	Hud._player = player
	UpgradeManager.reset()
	UpgradeManager.award_qi(60)
	var offer := {
		"type": "shop_skill",
		"cost": 60,
		"skill": load("res://scripts/resources/skills/ember_burst.tres"),
		"purchased": false,
	}

	Hud._open_shop_offer(offer)
	assert_true(Hud._overlay_active)
	assert_eq(UpgradeManager.qi, 60.0)
	Hud._confirm_overlay_selection()

	assert_eq(player.skill_1.skill_name, "Ember Burst")
	assert_eq(UpgradeManager.qi, 0.0)
	assert_true(offer["purchased"])
	Hud._close_overlay()
	Hud._shop_offer_opened_overlay = false
	Hud._player = null
	RunManager._current_room = null
	UpgradeManager.reset()
