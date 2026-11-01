extends GutTest

var player: Player

func before_each() -> void:
	UpgradeManager.reset()
	player = load("res://scenes/player/player.tscn").instantiate()
	add_child_autofree(player)
	RunManager._player = player
	var hud: Hud = get_node_or_null("/root/Hud")
	if hud == null:
		push_error("Hud autoload was not available for the room-clear upgrade test")
		return
	hud._player = player
	if hud.has_method("_close_upgrade_menu"):
		hud._close_upgrade_menu()
	PlaytestMode.close_panel()
	if hud.has_method("_set_debug_room_clear_state"):
		hud._set_debug_room_clear_state(true)

func after_each() -> void:
	UpgradeManager.reset()
	Input.action_release("pickup")
	var hud := get_node_or_null("/root/Hud")
	if hud != null and hud.has_method("_close_upgrade_menu"):
		hud._close_upgrade_menu()
	PlaytestMode.close_panel()
	RunManager._player = null
	if hud != null:
		hud._player = null
		hud._active_weapon_pickup = null
		hud._active_skill_pickup = null
		hud._active_rune_pickup = null
		hud._active_shop_station = null


func _open_upgrade_shop_for_test(hud: Hud) -> void:
	hud._open_shop_menu(ShopStation.Category.UPGRADE)


func _find_upgrade_option_index(hud: Hud, upgrade_type: String, pair: Array = []) -> int:
	for index in hud._all_upgrade_options.size():
		var option: Dictionary = hud._all_upgrade_options[index]
		if option.get("type") == upgrade_type and (pair.is_empty() or option.get("pair") == pair):
			return index
	return -1


func test_shop_station_opens_upgrade_menu_with_pickup_action() -> void:
	var hud := get_node_or_null("/root/Hud")
	assert_not_null(hud)
	assert_not_null(player)
	var station := ShopStation.new()
	hud._active_shop_station = station

	Input.action_press("pickup")
	hud._handle_room_clear_upgrade_input()

	assert_true(hud.is_upgrade_menu_active())
	station.free()


func test_swap_key_does_not_open_upgrade_shop_outside_a_station() -> void:
	var hud := get_node_or_null("/root/Hud")
	assert_not_null(hud)
	Input.action_press("swap")
	hud._handle_room_clear_upgrade_input()
	Input.action_release("swap")

	assert_false(hud.is_upgrade_menu_active())


func test_weapon_pickup_takes_priority_over_shop_station() -> void:
	var hud := get_node_or_null("/root/Hud")
	assert_not_null(hud)
	assert_not_null(player)
	var station := ShopStation.new()
	var pickup := WeaponPickup.new()
	hud._active_shop_station = station
	hud._active_weapon_pickup = pickup

	Input.action_press("pickup")
	hud._handle_room_clear_upgrade_input()

	assert_false(hud.is_upgrade_menu_active())
	pickup.free()
	station.free()


func test_room_clear_does_not_open_shop_or_close_playtest_panel() -> void:
	var hud := get_node_or_null("/root/Hud")
	assert_not_null(hud)
	assert_not_null(PlaytestMode._panel)
	PlaytestMode._panel.show()
	assert_true(PlaytestMode.is_panel_open())

	var room := RoomController.new()
	RunManager._on_room_cleared(room)
	room.free()

	assert_false(hud.is_upgrade_menu_active())
	assert_true(PlaytestMode.is_panel_open())


func test_upgrade_card_mouse_click_selects_before_confirming() -> void:
	var hud := get_node_or_null("/root/Hud")
	assert_not_null(hud)
	UpgradeManager.award_qi(30.0)
	player.current_health = player.max_health * 0.5
	_open_upgrade_shop_for_test(hud)
	assert_true(hud.is_upgrade_menu_active())

	var option_index := -1
	for index in range(1, Hud.UPGRADE_CARDS_VISIBLE):
		var option: Dictionary = hud._all_upgrade_options[index]
		if float(option.get("cost", 0.0)) <= UpgradeManager.qi:
			option_index = index
			break
	assert_gte(option_index, 0)
	var selected_option: Dictionary = hud._all_upgrade_options[option_index]
	var selected_cost := float(selected_option.get("cost", 0.0))
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	hud._on_upgrade_option_gui_input(click, option_index)
	assert_eq(hud._upgrade_menu_selected_index, option_index)
	assert_eq(UpgradeManager.qi, 30.0)

	hud._on_upgrade_option_gui_input(click, option_index)
	assert_eq(UpgradeManager.qi, 30.0 - selected_cost)
	assert_true(hud.is_upgrade_menu_active())


func test_upgrade_shop_purchases_weapon_might() -> void:
	var hud := get_node_or_null("/root/Hud")
	assert_not_null(hud)
	assert_not_null(RunManager._player)
	assert_true(hud.has_method("_can_open_upgrade_menu"))
	UpgradeManager.award_qi(75.0)
	_open_upgrade_shop_for_test(hud)
	assert_true(hud.is_upgrade_menu_active())
	assert_true(hud.has_method("_confirm_upgrade_selection"))
	var weapon_index := _find_upgrade_option_index(hud, "weapon")
	assert_true(weapon_index >= 0)
	hud._set_upgrade_selection(weapon_index)
	hud._confirm_upgrade_selection()
	assert_eq(UpgradeManager.weapon_might_multiplier(), 1.1)
	assert_true(hud.is_upgrade_menu_active())


func test_room_clear_shop_allows_multiple_purchases_without_refresh() -> void:
	var hud := get_node_or_null("/root/Hud")
	assert_not_null(hud)
	UpgradeManager.award_qi(90.0)
	_open_upgrade_shop_for_test(hud)
	assert_true(hud.is_upgrade_menu_active())
	assert_true(hud._all_upgrade_options.size() > 3)
	assert_false(hud._all_upgrade_options.any(func(option): return option.get("type") == "refresh"))

	var visible_reaction := false
	for index in Hud.UPGRADE_CARDS_VISIBLE:
		if hud._is_reaction_upgrade(hud._all_upgrade_options[index]):
			visible_reaction = true
	assert_true(visible_reaction, "a reaction upgrade should appear on the first card page")

	var weapon_index := _find_upgrade_option_index(hud, "weapon")
	assert_true(weapon_index >= 0)
	hud._set_upgrade_selection(weapon_index)
	hud._confirm_upgrade_selection()
	assert_true(hud.is_upgrade_menu_active())
	assert_eq(UpgradeManager.weapon_might_multiplier(), 1.1)

	var vitality_index := _find_upgrade_option_index(hud, "vitality")
	assert_true(vitality_index >= 0)
	hud._set_upgrade_selection(vitality_index)
	hud._confirm_upgrade_selection()
	assert_true(hud.is_upgrade_menu_active())
	assert_eq(UpgradeManager.vitality_hp_bonus(), 10.0)

	assert_eq(UpgradeManager.qi, 50.0)


func test_restore_card_heals_thirty_percent_and_charges_escalating_cost() -> void:
	var hud := get_node_or_null("/root/Hud")
	assert_not_null(hud)
	player.current_health = 50.0
	UpgradeManager.award_qi(30.0)
	_open_upgrade_shop_for_test(hud)

	var restore_index := _find_upgrade_option_index(hud, "restore")
	assert_true(restore_index >= 0)
	hud._set_upgrade_selection(restore_index)
	hud._confirm_upgrade_selection()

	assert_almost_eq(player.current_health, 80.0, 0.01)
	assert_eq(UpgradeManager.restore_uses(), 1)
	assert_eq(UpgradeManager.qi, 10.0)
	var next_restore_index := _find_upgrade_option_index(hud, "restore")
	assert_true(next_restore_index >= 0)
	var next_restore: Dictionary = hud._all_upgrade_options[next_restore_index]
	assert_eq(next_restore.get("cost"), 30.0)
	assert_true(str(next_restore.get("desc")).contains("Used 1 times"))


func test_restore_at_full_health_does_not_charge() -> void:
	var hud := get_node_or_null("/root/Hud")
	assert_not_null(hud)
	UpgradeManager.award_qi(30.0)
	_open_upgrade_shop_for_test(hud)
	var restore_index := _find_upgrade_option_index(hud, "restore")
	assert_true(restore_index >= 0)
	hud._set_upgrade_selection(restore_index)

	assert_true(str(hud._all_upgrade_options[restore_index].get("desc")).contains("[Full HP]"))
	hud._confirm_upgrade_selection()

	assert_eq(player.current_health, player.max_health)
	assert_eq(UpgradeManager.qi, 30.0)
	assert_eq(UpgradeManager.restore_uses(), 0)


func test_room_clear_ui_purchases_sinh_rank_one_and_favored_rank_two() -> void:
	var hud := get_node_or_null("/root/Hud")
	assert_not_null(hud)
	var pair: Array[StringName] = [Elements.KIM, Elements.THUY]
	UpgradeManager.award_qi(100.0)
	_open_upgrade_shop_for_test(hud)

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
	assert_eq(UpgradeManager.qi, 75.0)

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
	assert_eq(UpgradeManager.qi, 20.0)


func test_room_clear_ui_can_purchase_the_other_sinh_favor_choice() -> void:
	var hud := get_node_or_null("/root/Hud")
	assert_not_null(hud)
	var pair: Array[StringName] = [Elements.KIM, Elements.THUY]
	UpgradeManager.award_qi(80.0)
	_open_upgrade_shop_for_test(hud)

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

	var generated := Elements.sinh_generated_element(pair)
	var other: StringName = pair[0] if pair[1] == generated else pair[1]
	var other_choice_index := -1
	for index in hud._all_upgrade_options.size():
		var option: Dictionary = hud._all_upgrade_options[index]
		if option.get("type") == "sinh_rank2" and option.get("pair") == pair \
				and option.get("favored") == other:
			other_choice_index = index
			break
	assert_true(other_choice_index >= 0)
	hud._set_upgrade_selection(other_choice_index)
	hud._confirm_upgrade_selection()
	assert_eq(UpgradeManager.sinh_favored_element(pair), other)
	assert_eq(UpgradeManager.qi, 0.0)


func test_room_clear_ui_purchases_khac_ranks_on_later_card_page() -> void:
	var hud := get_node_or_null("/root/Hud")
	assert_not_null(hud)
	var pair: Array[StringName] = [Elements.HOA, Elements.KIM]
	UpgradeManager.award_qi(80.0)
	_open_upgrade_shop_for_test(hud)

	var rank_one_index := -1
	for index in hud._all_upgrade_options.size():
		var option: Dictionary = hud._all_upgrade_options[index]
		if option.get("type") == "khac_rank1" and option.get("pair") == pair:
			rank_one_index = index
			break
	hud._set_upgrade_selection(rank_one_index)
	var card_index: int = rank_one_index - hud._upgrade_page_offset
	assert_gte(card_index, 0)
	assert_lt(card_index, Hud.UPGRADE_CARDS_VISIBLE)

	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	hud._on_upgrade_option_gui_input(click, card_index)
	assert_true(UpgradeManager.khac_graze_erased(pair))
	assert_eq(UpgradeManager.qi, 55.0)

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


func _visible_reaction_indicators(hud: Hud) -> Array:
	var indicators: Array = []
	for indicator in hud._reaction_strip.get_children():
		if indicator.visible:
			indicators.append(indicator)
	return indicators


func test_reaction_cards_and_hud_strip_show_owned_ranked_pairs() -> void:
	var hud := get_node_or_null("/root/Hud")
	assert_not_null(hud)
	var sinh_pair: Array[StringName] = [Elements.KIM, Elements.THUY]
	var khac_pair: Array[StringName] = [Elements.HOA, Elements.KIM]
	UpgradeManager.award_qi(200.0)
	_open_upgrade_shop_for_test(hud)

	var sinh_rank_one_index := -1
	for index in hud._all_upgrade_options.size():
		var option: Dictionary = hud._all_upgrade_options[index]
		if option.get("type") == "sinh_rank1" and option.get("pair") == sinh_pair:
			sinh_rank_one_index = index
			break
	assert_true(sinh_rank_one_index >= 0)
	hud._set_upgrade_selection(sinh_rank_one_index)
	var card_index: int = sinh_rank_one_index - hud._upgrade_page_offset
	var rank_one_card: UpgradeCard = hud._upgrade_cards[card_index]
	assert_eq(rank_one_card._reaction_visual.reaction_pair, sinh_pair)
	assert_eq(rank_one_card._reaction_visual.reaction_rank, 1)
	hud._confirm_upgrade_selection()

	var generated_element := Elements.sinh_generated_element(sinh_pair)
	var sinh_rank_two_index := -1
	for index in hud._all_upgrade_options.size():
		var option: Dictionary = hud._all_upgrade_options[index]
		if option.get("type") == "sinh_rank2" and option.get("pair") == sinh_pair \
				and option.get("favored") == generated_element:
			sinh_rank_two_index = index
			break
	assert_true(sinh_rank_two_index >= 0)
	hud._set_upgrade_selection(sinh_rank_two_index)
	card_index = sinh_rank_two_index - hud._upgrade_page_offset
	var rank_two_card: UpgradeCard = hud._upgrade_cards[card_index]
	assert_eq(rank_two_card._reaction_visual.reaction_rank, 2)
	assert_eq(rank_two_card._reaction_visual.favored_element, generated_element)
	hud._confirm_upgrade_selection()

	assert_true(UpgradeManager.purchase_khac_rank1(khac_pair))
	var visible_indicators := _visible_reaction_indicators(hud)
	assert_eq(visible_indicators.size(), 2)
	var first_indicator: Control = visible_indicators[0]
	var second_indicator: Control = visible_indicators[1]
	assert_true(first_indicator.visible)
	assert_true(second_indicator.visible)
	assert_eq(first_indicator.get("reaction_pair"), sinh_pair)
	assert_eq(first_indicator.get("reaction_rank"), 2)
	assert_eq(second_indicator.get("reaction_pair"), khac_pair)
	assert_eq(second_indicator.get("reaction_rank"), 1)
	await get_tree().process_frame
	var strip_rect: Rect2 = hud._reaction_strip.get_global_rect()
	assert_gt(
			strip_rect.position.y,
			hud.get_viewport().get_visible_rect().size.y * 0.65,
			"reaction indicators should stay near the bottom of the HUD")
	assert_false(
			strip_rect.intersects(hud._qi_label.get_global_rect()),
			"reaction indicators should not overlap the Qi label")
	assert_false(
			strip_rect.intersects(hud._player_hp_fill.get_global_rect()),
			"reaction indicators should not overlap the player HP bar")

	var saved_state: Dictionary = UpgradeManager.to_save_state()
	UpgradeManager.reset()
	assert_false(hud._reaction_strip.visible)
	assert_eq(_visible_reaction_indicators(hud).size(), 0)
	UpgradeManager.apply_save_state(saved_state)
	visible_indicators = _visible_reaction_indicators(hud)
	assert_eq(visible_indicators.size(), 2)
	assert_eq(visible_indicators[0].get("reaction_rank"), 2)
	assert_true(visible_indicators[0].visible)
