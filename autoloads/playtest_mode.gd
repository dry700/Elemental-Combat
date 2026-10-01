extends CanvasLayer
## Debug-build-only tools for playtesting procedural runs.

const GRANT_QI_AMOUNT: float = 1000.0
const REACTIONS: Array[Dictionary] = [
	{"name": "Condensation", "pair": [&"kim", &"thuy"], "sinh": true},
	{"name": "Overgrowth", "pair": [&"thuy", &"moc"], "sinh": true},
	{"name": "Wildfire", "pair": [&"moc", &"hoa"], "sinh": true},
	{"name": "Cinder Bloom", "pair": [&"hoa", &"tho"], "sinh": true},
	{"name": "Ore Surge", "pair": [&"tho", &"kim"], "sinh": true},
	{"name": "Molten", "pair": [&"hoa", &"kim"], "sinh": false},
	{"name": "Silt", "pair": [&"tho", &"thuy"], "sinh": false},
	{"name": "Root Break", "pair": [&"moc", &"tho"], "sinh": false},
	{"name": "Sever", "pair": [&"kim", &"moc"], "sinh": false},
	{"name": "Douse", "pair": [&"thuy", &"hoa"], "sinh": false},
]

var _panel: PanelContainer
var _invincibility_button: Button
var _teleport_target: OptionButton
var _reaction_target: OptionButton
var _status: Label
var _invincibility_enabled: bool = false


func _ready() -> void:
	layer = 120
	if not OS.is_debug_build():
		return
	_build_panel()


func is_panel_open() -> bool:
	return _panel != null and _panel.visible


func _unhandled_key_input(event: InputEvent) -> void:
	if not OS.is_debug_build() or not event.is_action_pressed("playtest_toggle", false):
		return
	_panel.visible = not _panel.visible
	if _panel.visible:
		_refresh_teleport_targets()
	get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if not OS.is_debug_build():
		return
	var player := RunManager._player as Player
	if player != null and player.playtest_invincible != _invincibility_enabled:
		player.playtest_invincible = _invincibility_enabled


func _build_panel() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_panel = PanelContainer.new()
	_panel.anchor_left = 1.0
	_panel.anchor_right = 1.0
	_panel.offset_left = -258.0
	_panel.offset_right = -8.0
	_panel.offset_top = 8.0
	_panel.offset_bottom = 316.0
	_panel.visible = false
	root.add_child(_panel)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(scroll)
	var content := VBoxContainer.new()
	content.custom_minimum_size.x = 224.0
	content.add_theme_constant_override("separation", 4)
	scroll.add_child(content)

	var title := Label.new()
	title.text = "PLAYTEST TOOLS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)
	content.add_child(HSeparator.new())

	_invincibility_button = Button.new()
	_invincibility_button.toggle_mode = true
	_invincibility_button.text = "Invincibility: OFF"
	_invincibility_button.toggled.connect(_on_invincibility_toggled)
	content.add_child(_invincibility_button)
	_add_button(content, "Regenerate Current Map", _on_regenerate_pressed)

	_teleport_target = OptionButton.new()
	content.add_child(_teleport_target)
	_add_button(content, "Teleport", _on_teleport_pressed)
	_add_button(content, "+1000 Qi", _on_grant_qi_pressed)

	var stat_row := HBoxContainer.new()
	content.add_child(stat_row)
	_add_button(stat_row, "Buy HP", _on_buy_vitality_pressed)
	_add_button(stat_row, "Buy Damage", _on_buy_damage_pressed)

	_reaction_target = OptionButton.new()
	for reaction in REACTIONS:
		_reaction_target.add_item(reaction["name"])
	content.add_child(_reaction_target)
	var rank_row := HBoxContainer.new()
	content.add_child(rank_row)
	_add_button(rank_row, "Buy Rank 1", _on_buy_rank1_pressed)
	_add_button(rank_row, "Buy Rank 2", _on_buy_rank2_pressed)

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.text = "F12 closes this panel."
	content.add_child(_status)


func _add_button(parent: Control, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _refresh_teleport_targets() -> void:
	_teleport_target.clear()
	_teleport_target.add_item("Start")
	_teleport_target.set_item_metadata(0, "start")
	_teleport_target.add_item("Finish")
	_teleport_target.set_item_metadata(1, "finish")
	var room := RunManager._current_room as ProceduralRoomController
	if room == null:
		_teleport_target.disabled = true
		return
	_teleport_target.disabled = false
	for cell in room.get_playtest_cells():
		_teleport_target.add_item("Chunk (%d, %d)" % [cell.x, cell.y])
		_teleport_target.set_item_metadata(_teleport_target.item_count - 1, cell)


func _on_invincibility_toggled(enabled: bool) -> void:
	_invincibility_enabled = enabled
	_invincibility_button.text = "Invincibility: ON" if enabled else "Invincibility: OFF"
	var player := RunManager._player as Player
	if player != null:
		player.playtest_invincible = enabled


func _on_regenerate_pressed() -> void:
	if RunManager.regenerate_current_room():
		_set_status("Regenerating this procedural room.")
	else:
		_set_status("Regeneration is available in procedural rooms.")


func _on_teleport_pressed() -> void:
	var target: Variant = _teleport_target.get_item_metadata(_teleport_target.selected)
	_set_status("Teleported." if RunManager.teleport_player_to_playtest_target(target) else "No procedural teleport target is available.")


func _on_grant_qi_pressed() -> void:
	UpgradeManager.award_qi(GRANT_QI_AMOUNT)
	_set_status("Granted %d Qi." % int(GRANT_QI_AMOUNT))


func _on_buy_vitality_pressed() -> void:
	var player := RunManager._player as Player
	if not UpgradeManager.purchase_vitality():
		_set_status("Not enough Qi for Vitality.")
		return
	if player != null:
		player.max_health += 10.0
		player.current_health = minf(player.current_health + 10.0, player.max_health)
	_set_status("Vitality increased by 10 HP.")


func _on_buy_damage_pressed() -> void:
	_set_status("Damage increased." if UpgradeManager.purchase_weapon_might() else "Not enough Qi for Weapon Might.")


func _on_buy_rank1_pressed() -> void:
	var reaction: Dictionary = REACTIONS[_reaction_target.selected]
	var pair := _selected_reaction_pair(reaction)
	var success: bool
	if reaction["sinh"]:
		success = UpgradeManager.purchase_sinh_rank1(pair)
	else:
		success = UpgradeManager.purchase_khac_rank1(pair)
	_set_status("Rank 1 purchased." if success else "Rank 1 unavailable or not enough Qi.")


func _on_buy_rank2_pressed() -> void:
	var reaction: Dictionary = REACTIONS[_reaction_target.selected]
	var pair := _selected_reaction_pair(reaction)
	var success: bool
	if reaction["sinh"]:
		success = UpgradeManager.purchase_sinh_rank2(pair, Elements.sinh_generated_element(pair))
	else:
		success = UpgradeManager.purchase_khac_rank2(pair)
	_set_status("Rank 2 purchased." if success else "Buy Rank 1 first and check your Qi.")


func _selected_reaction_pair(reaction: Dictionary) -> Array[StringName]:
	var pair: Array[StringName] = []
	for element in reaction["pair"]:
		pair.append(StringName(element))
	return pair


func _set_status(message: String) -> void:
	_status.text = message