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
	assert_true(hud._upgrade_options.size() >= 3)
	assert_true(hud._upgrade_options[2].text.contains("REFRESH SHOP"))

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
		hud._set_upgrade_selection(2)
	hud._confirm_upgrade_selection()
	assert_true(hud.is_upgrade_menu_active())
