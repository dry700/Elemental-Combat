extends GutTest

func before_each() -> void:
	UpgradeManager.reset()
	var player: Player = load("res://scenes/player/player.tscn").instantiate()
	add_child_autofree(player)
	RunManager._player = player
	var hud: Hud = get_node_or_null("/root/Hud")
	if hud == null:
		push_error("Hud autoload was not available for the room-clear upgrade test")
	return
	if hud.has_method("_close_upgrade_menu"):
		hud._close_upgrade_menu()
	PlaytestMode.close_panel()
	if hud.has_method("_set_debug_room_clear_state"):
		hud._set_debug_room_clear_state(true)

func after_each() -> void:
	UpgradeManager.reset()
	var hud := get_node_or_null("/root/Hud")
	if hud != null and hud.has_method("_close_upgrade_menu"):
		hud._close_upgrade_menu()
	PlaytestMode.close_panel()
	RunManager._player = null


func test_room_clear_shop_closes_open_playtest_panel() -> void:
	var hud := get_node_or_null("/root/Hud")
	assert_not_null(hud)
	assert_not_null(PlaytestMode._panel)
	PlaytestMode._panel.show()
	assert_true(PlaytestMode.is_panel_open())

	RunManager._on_room_cleared(RoomController.new())

	assert_true(hud.is_upgrade_menu_active())
	assert_false(PlaytestMode.is_panel_open())


func test_upgrade_card_mouse_click_selects_before_confirming() -> void:
	var hud := get_node_or_null("/root/Hud")
	assert_not_null(hud)
	UpgradeManager.award_qi(30.0)
	RunManager._on_room_cleared(RoomController.new())
	assert_true(hud.is_upgrade_menu_active())

	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	hud._on_upgrade_option_gui_input(click, 1)
	assert_eq(hud._upgrade_menu_selected_index, 1)
	assert_eq(UpgradeManager.vitality_hp_bonus(), 0.0)
	assert_eq(UpgradeManager.qi, 30.0)

	hud._on_upgrade_option_gui_input(click, 1)
	assert_eq(UpgradeManager.vitality_hp_bonus(), 10.0)
	assert_eq(UpgradeManager.qi, 15.0)
	assert_true(hud.is_upgrade_menu_active())


func test_room_clear_upgrade_menu_opens_on_room_clear_and_purchases_weapon_might() -> void:
	var hud := get_node_or_null("/root/Hud")
	assert_not_null(hud)
	assert_not_null(RunManager._player)
	assert_true(hud.has_method("_can_open_upgrade_menu"))
	UpgradeManager.award_qi(75.0)
	var room := RoomController.new()
	RunManager._on_room_cleared(room)
	assert_true(hud.is_upgrade_menu_active())
	assert_true(hud.has_method("_confirm_upgrade_selection"))
	if hud.has_method("_set_upgrade_selection"):
		hud._set_upgrade_selection(0)
	hud._confirm_upgrade_selection()
	assert_eq(UpgradeManager.weapon_might_multiplier(), 1.1)
	assert_true(hud.is_upgrade_menu_active())


func test_room_clear_shop_allows_multiple_purchases_and_refresh() -> void:
	var hud := get_node_or_null("/root/Hud")
	assert_not_null(hud)
	UpgradeManager.award_qi(90.0)
	var room := RoomController.new()
	RunManager._on_room_cleared(room)
	assert_true(hud.is_upgrade_menu_active())
	assert_true(hud._all_upgrade_options.size() > 3)
	assert_eq(hud._all_upgrade_options.back().get("type"), "refresh")

	if hud.has_method("_set_upgrade_selection"):
		hud._set_upgrade_selection(0)
	hud._confirm_upgrade_selection()
	assert_true(hud.is_upgrade_menu_active())
	assert_eq(UpgradeManager.weapon_might_multiplier(), 1.1)

	if hud.has_method("_set_upgrade_selection"):
		hud._set_upgrade_selection(1)
	hud._confirm_upgrade_selection()
	assert_true(hud.is_upgrade_menu_active())
	assert_eq(UpgradeManager.vitality_hp_bonus(), 10.0)

	if hud.has_method("_set_upgrade_selection"):
		hud._set_upgrade_selection(hud._all_upgrade_options.size() - 1)
	hud._confirm_upgrade_selection()
	assert_true(hud.is_upgrade_menu_active())
	assert_eq(UpgradeManager.qi, 50.0)


func test_room_clear_ui_purchases_sinh_rank_one_and_favored_rank_two() -> void:
	var hud := get_node_or_null("/root/Hud")
	assert_not_null(hud)
	var pair: Array[StringName] = [Elements.KIM, Elements.THUY]
	UpgradeManager.award_qi(100.0)
	RunManager._on_room_cleared(RoomController.new())

	var rank_one_index := -1
	for index in hud._all_upgrade_options.size():
		var option: Dictionary = hud._all_upgrade_options[index]
		if option.get("type") == "sinh_rank1" and option.get("pair") == pair:
			rank_one_index = index
			break
	assert_true(rank_one_index >= 0)
	hud._set_upgrade_selection(rank_one_index)
	hud._confirm_upgrade_selection()
	assert_true(UpgradeManager.sinh_tier2_forced(pair))
	assert_eq(UpgradeManager.qi, 80.0)

	var generated_element := Elements.sinh_generated_element(pair)
	var rank_two_index := -1
	for index in hud._all_upgrade_options.size():
		var option: Dictionary = hud._all_upgrade_options[index]
		if option.get("type") == "sinh_rank2" and option.get("pair") == pair and option.get("favored") == generated_element:
			rank_two_index = index
			break
	assert_true(rank_two_index >= 0)
	hud._set_upgrade_selection(rank_two_index)
	hud._confirm_upgrade_selection()
	assert_eq(UpgradeManager.sinh_favored_element(pair), generated_element)
	assert_eq(UpgradeManager.qi, 35.0)


func test_room_clear_ui_purchases_khac_ranks_on_later_card_page() -> void:
	var hud := get_node_or_null("/root/Hud")
	assert_not_null(hud)
	var pair: Array[StringName] = [Elements.HOA, Elements.KIM]
	UpgradeManager.award_qi(65.0)
	RunManager._on_room_cleared(RoomController.new())

	var rank_one_index := -1
	for index in hud._all_upgrade_options.size():
		var option: Dictionary = hud._all_upgrade_options[index]
		if option.get("type") == "khac_rank1" and option.get("pair") == pair:
			rank_one_index = index
			break
	assert_true(rank_one_index >= 3)
	hud._set_upgrade_selection(rank_one_index - 1)
	hud._set_upgrade_selection(rank_one_index)
	var card_index: int = rank_one_index - hud._upgrade_page_offset
	assert_eq(card_index, 2)

	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	hud._on_upgrade_option_gui_input(click, card_index)
	assert_true(UpgradeManager.khac_graze_erased(pair))
	assert_eq(UpgradeManager.qi, 45.0)

	var rank_two_index := -1
	for index in hud._all_upgrade_options.size():
		var option: Dictionary = hud._all_upgrade_options[index]
		if option.get("type") == "khac_rank2" and option.get("pair") == pair:
			rank_two_index = index
			break
	assert_true(rank_two_index >= 0)
	hud._set_upgrade_selection(rank_two_index)
	hud._confirm_upgrade_selection()
	assert_true(UpgradeManager.khac_overwhelm_forced(pair))
	assert_eq(UpgradeManager.qi, 0.0)
