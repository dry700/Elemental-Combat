extends CanvasLayer
## Minimal always-on combat HUD, built entirely in code (same approach
## VisionBlocker already uses for its own overlay) rather than as a
## hand-authored .tscn — avoids yet another editor-resave/NodePath class
## of bug this project has already hit more than once with room .tscn
## files. Registered as an autoload (project.godot) so it's present in
## every scene automatically — test_arena, procedural runs, and
## hand-placed rooms alike — with nothing to wire up per-scene.
##
## Shows, bottom-left to bottom-right: player HP, then the four A.4/A.5
## equip slots (weapon 1, weapon 2, skill 1, skill 2). A boss name +
## health bar appears top-centre only while a Boss is present in the
## scene, with a white tick mark on the bar at the boss's own
## phase_transition_health_ratio.
##
## Pickup selection overlay: pressing "pickup" (F) near a WeaponPickup or
## SkillPickup opens a small menu instead of instantly equipping —
## WeaponPickup/SkillPickup themselves no longer read any input at all
## (see their own headers); this autoload owns the whole interaction.
## Navigate with menu_up/menu_down (W/S or Up/Down), confirm the
## highlighted slot with "pickup" (F) again or the explicit
## equip_slot_1/equip_slot_2 (1/2) shortcuts, or click a slot directly
## with the mouse to select-and-confirm it in one step. Escape
## (menu_cancel) backs out without equipping anything. Player.gd freezes
## voluntary action input for the duration via Hud.is_overlay_active().
##
## Polls each frame rather than being fully signal-driven: health drains
## via DoT ticks, not just discrete hits, so a light _process poll is
## simpler here than wiring a listener for every source of change —
## consistent with ElementalCombatant's own debug readout doing the same.
## Native canvas render size is half the window's actual pixel size now
## (project.godot's display/window/stretch settings) — the engine stretches
## the whole low-res frame up rather than this file pre-scaling anything
## itself. Every absolute number below was tuned against the old
## unstretched assumption; multiplying by this factor keeps them correctly
## proportioned. Retune this one constant if the stretch ratio (window
## override size ÷ viewport size in project.godot) ever changes.
const UI_SCALE: float = 0.5
const SHOP_WEAPON_PICKUP_SCRIPT := preload("res://scripts/items/shop_weapon_pickup.gd")
const SHOP_SKILL_PICKUP_SCRIPT := preload("res://scripts/items/shop_skill_pickup.gd")
const SHOP_RUNE_PICKUP_SCRIPT := preload("res://scripts/items/shop_rune_pickup.gd")
const LOADOUT_SELECT_SCRIPT := preload("res://scripts/ui/loadout_select.gd")
const REACTION_PAIR_INDICATOR_SCRIPT := preload("res://scripts/ui/reaction_pair_indicator.gd")
const SKILL_ENERGY_RING_SCRIPT := preload("res://scripts/ui/skill_energy_ring.gd")

const SLOT_SIZE: float = 40.0 * UI_SCALE
const SLOT_SEPARATION: float = 8.0 * UI_SCALE
const SLOT_EMPTY_COLOR := Color(0.2, 0.2, 0.24, 0.9)
const BAR_BG_COLOR := Color(0.15, 0.15, 0.18, 0.9)
const PLAYER_HP_COLOR := Color(0.35, 0.85, 0.4)
const BOSS_HP_COLOR := Color(0.85, 0.3, 0.3)
const PHASE_TICK_COLOR := Color(1.0, 1.0, 1.0, 0.85)
const PROMPT_TEXT_COLOR := Color(1.0, 0.9, 0.3, 1.0)  ## Matches WeaponPickup/SkillPickup's own prompt colour family.
const OVERLAY_BG_COLOR := Color(0.08, 0.08, 0.1, 0.92)
const OVERLAY_SELECTED_COLOR := Color(0.35, 0.55, 0.85, 0.9)


var _player_hp_bg: Control
var _player_hp_fill: Control
var _player_hp_label: Label
var _qi_label: Label
var _reaction_strip: HBoxContainer

var _boss_panel: Control
var _boss_name_label: Label
var _boss_hp_bg: Control
var _boss_hp_fill: Control
var _boss_phase_tick: Control

var _weapon_1_box: Control
var _weapon_1_label: Label
var _weapon_1_prompt: Label
var _weapon_2_box: Control
var _weapon_2_label: Label
var _weapon_2_prompt: Label
var _skill_1_box: Control
var _skill_1_label: Label
var _skill_1_prompt: Label
var _skill_2_box: Control
var _skill_2_label: Label
var _skill_2_prompt: Label

var _player: Player
var _boss: Boss

## Whichever WeaponPickup/SkillPickup/ShopStation the player is currently standing
## near, if any — see _refresh_active_pickups().
var _active_weapon_pickup: WeaponPickup = null
var _active_skill_pickup: SkillPickup = null
var _active_rune_pickup: Node = null
var _active_shop_station = null
var _active_room_exit: RoomExit = null

## --- Pickup selection overlay state ---
var _overlay_panel: Control
var _overlay_title: Label
var _overlay_card_1: PickupCard
var _overlay_card_2: PickupCard
var _ground_item_card: PickupCard
var _ground_container_1: CenterContainer
var _ground_container_2: CenterContainer

enum OverlayKind { WEAPON, SKILL, RUNE }

var _overlay_active: bool = false
var _overlay_pickup: Node = null  ## A WeaponPickup, SkillPickup, or RunePickup
var _overlay_kind: OverlayKind = OverlayKind.WEAPON
var _overlay_selected_primary: bool = true

var _inspect_pane: PickupCard
var _inspect_active: bool = false

var _upgrade_panel: CenterContainer
var _upgrade_title: Label
var _upgrade_options: Array = []
var _upgrade_cards: Array[PanelContainer] = []
var _upgrade_card_style: StyleBoxFlat
var _upgrade_card_selected_style: StyleBoxFlat
var _upgrade_menu_active: bool = false
var _upgrade_menu_selected_index: int = 0
var _upgrade_menu_category: int = ShopStation.Category.UPGRADE
var _shop_stock_room_id: int = 0
var _shop_offer_stock: Dictionary = {}
var _pending_shop_offer: Dictionary = {}
var _shop_offer_opened_overlay: bool = false
var _debug_room_clear_state: bool = false
## Reaction upgrade menu state — paged list of all available options.
## Each entry is a Dictionary: {type, label, desc, cost, pair, favored}
var _all_upgrade_options: Array[Dictionary] = []
var _upgrade_page_offset: int = 0  ## First visible option index.
const UPGRADE_CARDS_VISIBLE: int = 3  ## Physical card count — unchanged.
var _pause_menu_active: bool = false
var _pause_overlay: Control
var _pause_weapon_cards: Array[PickupCard] = []
var _pause_skill_cards: Array[PickupCard] = []
var _pause_status_label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 110  # Above VisionBlocker's own darkness overlay (layer 100) — HUD chrome stays visible even inside a steam cloud's blackout.

	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Never eats a click by default — attack is bound to mouse buttons (input_setup.gd). Only the overlay's own slot options (below) opt back into receiving clicks.
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	_build_player_hp_bar(root)
	_build_qi_label(root)
	_build_reaction_strip(root)
	_build_slots(root)
	_build_boss_panel(root)
	_build_overlay(root)
	_build_upgrade_menu(root)
	_build_pause_menu(root)

	var um := get_node_or_null("/root/UpgradeManager")
	if um != null:
		um.qi_changed.connect(_on_qi_changed)
		um.reaction_ranks_changed.connect(_refresh_reaction_strip)
		_on_qi_changed(um.qi)
		_refresh_reaction_strip()


func _build_player_hp_bar(root: Control) -> void:
	var custom_bar = get_node_or_null("MarginContainer/PlayerStats/HealthBar")
	if custom_bar != null:
		_player_hp_fill = custom_bar
		_player_hp_label = custom_bar.get_node_or_null("HealthLabel")
		return
	var container := Control.new()
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	container.position = Vector2(20, -40) * UI_SCALE
	container.size = Vector2(180, 20) * UI_SCALE
	root.add_child(container)
	_player_hp_bg = _make_rect(container, BAR_BG_COLOR, Vector2.ZERO, container.size)
	_player_hp_fill = _make_rect(container, PLAYER_HP_COLOR, Vector2.ZERO, container.size)


func _build_qi_label(root: Control) -> void:
	var custom_qi = get_node_or_null("MarginContainer/PlayerStats/QiLabel")
	if custom_qi != null:
		_qi_label = custom_qi
		return
	_qi_label = Label.new()
	_qi_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_qi_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_qi_label.position = Vector2(-150, 20) * UI_SCALE
	_qi_label.size = Vector2(130, 30) * UI_SCALE
	_qi_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_qi_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_qi_label.add_theme_font_size_override("font_size", int(18 * UI_SCALE))
	_qi_label.add_theme_color_override("font_color", Color(0.6, 0.9, 1.0))
	_qi_label.text = "Qi: 0"
	root.add_child(_qi_label)


func _on_qi_changed(new_total: float) -> void:
	if _qi_label != null:
		_qi_label.text = "Qi: %d" % int(new_total)


func _build_reaction_strip(root: Control) -> void:
	_reaction_strip = HBoxContainer.new()
	_reaction_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reaction_strip.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_reaction_strip.position = Vector2(12.0, -180.0) * UI_SCALE
	_reaction_strip.add_theme_constant_override("separation", 1)
	root.add_child(_reaction_strip)
	for _index in 10:
		var indicator: Control = REACTION_PAIR_INDICATOR_SCRIPT.new()
		_reaction_strip.add_child(indicator)
		indicator.call("set_reaction", [], 0)


func _refresh_reaction_strip() -> void:
	if _reaction_strip == null:
		return
	var visible_index := 0
	for definition in _reaction_upgrade_definitions():
		var pair: Array = definition["pair"]
		var rank := UpgradeManager.reaction_rank(pair)
		if rank <= 0:
			continue
		var favored: StringName = UpgradeManager.sinh_favored_element(pair) \
				if definition["branch"] == "sinh" else &""
		var indicator: Control = _reaction_strip.get_child(visible_index)
		indicator.call("set_reaction", pair, rank, favored)
		indicator.tooltip_text = "%s - Rank %d" % [definition["name"], rank]
		visible_index += 1

	for index in range(visible_index, _reaction_strip.get_child_count()):
		_reaction_strip.get_child(index).call("set_reaction", [], 0)

	_reaction_strip.visible = visible_index > 0


func _build_slots(root: Control) -> void:
	var c_w1 = get_node_or_null("MarginContainer/EquipSlots/Weapon1")
	if c_w1 != null:
		_weapon_1_box = c_w1; _weapon_1_label = Label.new(); _weapon_1_prompt = Label.new()
		_weapon_2_box = get_node("MarginContainer/EquipSlots/Weapon2"); _weapon_2_label = Label.new(); _weapon_2_prompt = Label.new()
		_skill_1_box = get_node("MarginContainer/EquipSlots/Skill1"); _skill_1_label = Label.new(); _skill_1_prompt = Label.new()
		_skill_2_box = get_node("MarginContainer/EquipSlots/Skill2"); _skill_2_label = Label.new(); _skill_2_prompt = Label.new()
		return
	var total_width := SLOT_SIZE * 4 + SLOT_SEPARATION * 3
	var container := HBoxContainer.new()
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	container.position = Vector2(-total_width - 20 * UI_SCALE, -SLOT_SIZE - 20 * UI_SCALE)
	container.size = Vector2(total_width, SLOT_SIZE)
	container.add_theme_constant_override("separation", int(SLOT_SEPARATION))
	root.add_child(container)

	var w1 := _make_slot(container, "1")
	_weapon_1_box = w1[0]; _weapon_1_label = w1[1]; _weapon_1_prompt = w1[2]
	var w2 := _make_slot(container, "2")
	_weapon_2_box = w2[0]; _weapon_2_label = w2[1]; _weapon_2_prompt = w2[2]
	var s1 := _make_slot(container, "Q")
	_skill_1_box = s1[0]; _skill_1_label = s1[1]; _skill_1_prompt = s1[2]
	var s2 := _make_slot(container, "E")
	_skill_2_box = s2[0]; _skill_2_label = s2[1]; _skill_2_prompt = s2[2]


func _make_slot(parent: Control, prompt_text: String) -> Array:
	var slot := Control.new()
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	parent.add_child(slot)

	var box := _make_rect(slot, SLOT_EMPTY_COLOR, Vector2.ZERO, Vector2(SLOT_SIZE, SLOT_SIZE))

	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", int(18 * UI_SCALE))
	slot.add_child(label)

	var prompt := Label.new()
	prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt.text = prompt_text
	prompt.position = Vector2(0, -18 * UI_SCALE)
	prompt.size = Vector2(SLOT_SIZE, 16 * UI_SCALE)
	prompt.add_theme_font_size_override("font_size", int(13 * UI_SCALE))
	prompt.add_theme_constant_override("outline_size", maxi(1, int(3 * UI_SCALE)))
	prompt.add_theme_color_override("font_color", PROMPT_TEXT_COLOR)
	prompt.add_theme_color_override("font_outline_color", Color.BLACK)
	prompt.add_theme_constant_override("outline_size", 3)
	prompt.visible = false
	slot.add_child(prompt)

	return [box, label, prompt]


func _build_boss_panel(root: Control) -> void:
	var custom_boss = get_node_or_null("MarginContainer/BossUI")
	if custom_boss != null:
		_boss_panel = custom_boss
		_boss_name_label = custom_boss.get_node("BossName")
		_boss_hp_fill = custom_boss.get_node("BossHealthBar")
		return
	var panel_width := 440.0 * UI_SCALE
	_boss_panel = Control.new()
	_boss_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_boss_panel.position = Vector2(-panel_width / 2.0, 16 * UI_SCALE)
	_boss_panel.size = Vector2(panel_width, 44 * UI_SCALE)
	_boss_panel.visible = false
	root.add_child(_boss_panel)

	_boss_name_label = Label.new()
	_boss_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_name_label.size = Vector2(panel_width, 20 * UI_SCALE)
	_boss_panel.add_child(_boss_name_label)

	_boss_hp_bg = _make_rect(_boss_panel, BAR_BG_COLOR, Vector2(0, 26 * UI_SCALE), Vector2(panel_width, 18 * UI_SCALE))
	_boss_hp_fill = _make_rect(_boss_hp_bg, BOSS_HP_COLOR, Vector2.ZERO, _boss_hp_bg.size)
	_boss_phase_tick = _make_rect(_boss_panel, PHASE_TICK_COLOR, Vector2.ZERO, Vector2(2 * UI_SCALE, _boss_hp_bg.size.y))


## The pickup selection menu — hidden by default, shown centre-screen by
## _open_overlay(). Two clickable options (built by _make_overlay_option,
## the only Controls in this whole HUD that actually stop mouse input)
## plus a title naming the item and a hint line covering all three input
## methods (keyboard nav+confirm, numeric shortcuts, click).
func _build_overlay(root: Control) -> void:
	_overlay_panel = CenterContainer.new()
	_overlay_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay_panel.visible = false
	root.add_child(_overlay_panel)
	
	var bg_panel := PanelContainer.new()
	bg_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = OVERLAY_BG_COLOR
	style.content_margin_left = int(20 * UI_SCALE)
	style.content_margin_right = int(20 * UI_SCALE)
	style.content_margin_top = int(16 * UI_SCALE)
	style.content_margin_bottom = int(16 * UI_SCALE)
	bg_panel.add_theme_stylebox_override("panel", style)
	_overlay_panel.add_child(bg_panel)
	
	var main_vbox := VBoxContainer.new()
	main_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_vbox.add_theme_constant_override("separation", int(12 * UI_SCALE))
	bg_panel.add_child(main_vbox)
	
	var header_hbox := HBoxContainer.new()
	header_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header_hbox.add_theme_constant_override("separation", int(20 * UI_SCALE))
	main_vbox.add_child(header_hbox)
	
	var ground_label := Label.new()
	ground_label.text = "On Ground"
	ground_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ground_label.custom_minimum_size = Vector2(260, 0)
	ground_label.add_theme_font_size_override("font_size", 18)
	header_hbox.add_child(ground_label)
	
	_overlay_title = Label.new()
	_overlay_title.text = "Current Loadout"
	_overlay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_title.custom_minimum_size = Vector2(260, 0)
	_overlay_title.add_theme_font_size_override("font_size", 18)
	header_hbox.add_child(_overlay_title)
	
	var row1 := HBoxContainer.new()
	row1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row1.add_theme_constant_override("separation", int(20 * UI_SCALE))
	main_vbox.add_child(row1)
	
	_ground_container_1 = CenterContainer.new()
	_ground_container_1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ground_container_1.custom_minimum_size = Vector2(260, 48)
	row1.add_child(_ground_container_1)
	
	_overlay_card_1 = _make_overlay_option(row1, true)
	
	var row2 := HBoxContainer.new()
	row2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row2.add_theme_constant_override("separation", int(20 * UI_SCALE))
	main_vbox.add_child(row2)
	
	_ground_container_2 = CenterContainer.new()
	_ground_container_2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ground_container_2.custom_minimum_size = Vector2(260, 48)
	row2.add_child(_ground_container_2)
	
	_overlay_card_2 = _make_overlay_option(row2, false)
	
	_ground_item_card = preload("res://scenes/ui/swap_card.tscn").instantiate()
	_ground_item_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ground_container_1.add_child(_ground_item_card)
	
	var hint := Label.new()
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.text = "Click / \u2191\u2193 to preview  \u00b7  Click again / F to confirm  \u00b7  Esc to cancel"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 14)
	main_vbox.add_child(hint)
	
	_inspect_pane = preload("res://scenes/ui/swap_card.tscn").instantiate()
	_inspect_pane.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inspect_pane.set_anchors_preset(Control.PRESET_CENTER)
	_inspect_pane.visible = false
	root.add_child(_inspect_pane)


## Builds one clickable slot option. mouse_filter = STOP is deliberate
## and unique to this Control in the whole HUD — everything else stays
## MOUSE_FILTER_IGNORE so the HUD never eats a click meant for gameplay
## (attack is bound to mouse buttons); only these two options, only
## while the overlay itself is visible (Godot skips input on hidden
## Controls entirely), actually need to receive one.
func _make_overlay_option(parent: Control, is_primary: bool) -> PickupCard:
	var option := preload("res://scenes/ui/swap_card.tscn").instantiate()
	option.mouse_filter = Control.MOUSE_FILTER_STOP
	option.gui_input.connect(_on_overlay_option_gui_input.bind(is_primary))
	parent.add_child(option)
	return option


func _make_rect(parent: Control, color: Color, pos: Vector2, size: Vector2) -> ColorRect:
	var rect := ColorRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.color = color
	rect.position = pos
	rect.size = size
	parent.add_child(rect)
	return rect


func _process(_delta: float) -> void:
	_refresh_player_ref()
	_refresh_boss_ref()
	
	self.visible = (_player != null) or _upgrade_menu_active or _overlay_active or _pause_menu_active
	
	_handle_pause_input()
	_refresh_active_pickups()
	_handle_room_clear_upgrade_input()
	_handle_pickup_overlay_input()
	_update_player_hp()
	_update_boss_panel()
	_update_weapon_slots()
	_update_skill_slots()
	_update_pickup_prompts()
	_update_overlay_visuals()
	_update_upgrade_menu_visuals()


func _build_pause_menu(root: Control) -> void:
	_pause_overlay = Control.new()
	_pause_overlay.name = "PauseOverlay"
	_pause_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_pause_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	_pause_overlay.visible = false
	root.add_child(_pause_overlay)

	var backdrop := ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.0, 0.0, 0.0, 0.72)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_pause_overlay.add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560.0, 0.0)
	center.add_child(panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	panel.add_child(content)

	var title := Label.new()
	title.text = "Paused"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	content.add_child(title)

	var equipment_columns := HBoxContainer.new()
	equipment_columns.add_theme_constant_override("separation", 8)
	content.add_child(equipment_columns)
	_pause_weapon_cards = _build_pause_equipment_column(equipment_columns, "Weapons", true)
	_pause_skill_cards = _build_pause_equipment_column(equipment_columns, "Skills", false)

	var continue_button := Button.new()
	continue_button.text = "Continue"
	continue_button.custom_minimum_size.y = 34.0
	continue_button.pressed.connect(_close_pause_menu)
	content.add_child(continue_button)

	var save_exit_button := Button.new()
	save_exit_button.text = "Save and Exit"
	save_exit_button.custom_minimum_size.y = 34.0
	save_exit_button.pressed.connect(_on_pause_save_exit_pressed)
	content.add_child(save_exit_button)

	_pause_status_label = Label.new()
	_pause_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pause_status_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.4))
	content.add_child(_pause_status_label)


func _build_pause_equipment_column(parent: HBoxContainer, heading: String, is_weapon: bool) -> Array[PickupCard]:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	parent.add_child(column)

	var title := Label.new()
	title.text = heading
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	column.add_child(title)

	var cards: Array[PickupCard] = []
	for slot_index in 2:
		var card := preload("res://scenes/ui/swap_card.tscn").instantiate() as PickupCard
		card.custom_minimum_size = Vector2(PickupCard.CARD_WIDTH, PickupCard.CARD_HEIGHT)
		column.add_child(card)
		cards.append(card)
		if is_weapon:
			var weapon: WeaponStats = null
			var rune: RuneData = null
			if _player != null:
				weapon = _player.weapon if slot_index == 0 else _player.secondary_weapon
				rune = _player.weapon_rune if slot_index == 0 else _player.secondary_weapon_rune
			card.set_weapon(weapon, rune, weapon != null)
		else:
			var skill: SkillData = null
			if _player != null:
				skill = _player.skill_1 if slot_index == 0 else _player.skill_2
			card.set_skill(skill)
	return cards


func _handle_pause_input() -> void:
	if _pause_menu_active:
		if Input.is_action_just_pressed("menu_cancel"):
			_close_pause_menu()
		return
	if _overlay_active or _upgrade_menu_active:
		return
	if RunManager != null and RunManager._run_active \
			and Input.is_action_just_pressed("menu_cancel"):
		_open_pause_menu()


func _open_pause_menu() -> void:
	if _pause_menu_active or _overlay_active or _upgrade_menu_active:
		return
	_pause_menu_active = true
	_pause_status_label.text = ""
	_refresh_pause_equipment_cards()
	_pause_overlay.visible = true
	get_tree().paused = true


func _refresh_pause_equipment_cards() -> void:
	if _player == null:
		return
	_pause_weapon_cards[0].set_weapon(_player.weapon, _player.weapon_rune, _player.weapon != null)
	_pause_weapon_cards[1].set_weapon(_player.secondary_weapon, _player.secondary_weapon_rune, _player.secondary_weapon != null)
	_pause_skill_cards[0].set_skill(_player.skill_1)
	_pause_skill_cards[1].set_skill(_player.skill_2)


func _close_pause_menu() -> void:
	_pause_menu_active = false
	_pause_overlay.visible = false
	get_tree().paused = false


func _on_pause_save_exit_pressed() -> void:
	if RunManager == null or not RunManager.save_mid_run():
		_pause_status_label.text = "Save failed. Your run is still open."
		return

	get_tree().paused = false
	RunManager._run_active = false
	RunManager.set_process(false)
	var error := get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
	if error != OK:
		RunManager._run_active = true
		RunManager.set_process(true)
		get_tree().paused = true
		_pause_status_label.text = "Could not return to the main menu."
		push_error("HUD: failed to return to the main menu after saving (error %d)" % error)
		return
	_pause_menu_active = false
	_pause_overlay.visible = false


func _refresh_player_ref() -> void:
	if _player != null and is_instance_valid(_player):
		return
	if RunManager != null and RunManager._player != null and is_instance_valid(RunManager._player):
		_player = RunManager._player
		return
	var tree := get_tree()
	if tree == null:
		return
	_player = tree.get_first_node_in_group("player") as Player


func _refresh_boss_ref() -> void:
	if _boss != null and is_instance_valid(_boss) and not _boss.is_dead():
		return
	var candidates := get_tree().get_nodes_in_group("bosses")
	_boss = candidates[0] as Boss if not candidates.is_empty() else null


## Scans for any WeaponPickup/SkillPickup currently prompting the player
## (i.e. the player is standing in its range — see each pickup's own
## _player_in_range) so the HUD knows what "pickup" (F) should open, and
## can highlight both candidate slots as a preview even before F is
## pressed. Group membership (not a shared static list like SteamCloud/
## ReactionZone use) keeps this simple — no lifetime/eviction
## bookkeeping to duplicate here, just "is anything in this group
## currently prompting."
func _refresh_active_pickups() -> void:
	_active_weapon_pickup = null
	for node in get_tree().get_nodes_in_group("weapon_pickups"):
		var pickup := node as WeaponPickup
		if pickup != null and pickup.get("_player_in_range") != null:
			_active_weapon_pickup = pickup
			break
	_active_skill_pickup = null
	for node in get_tree().get_nodes_in_group("skill_pickups"):
		var pickup := node as SkillPickup
		if pickup != null and pickup.get("_player_in_range") != null:
			_active_skill_pickup = pickup
			break
	_active_rune_pickup = null
	for node in get_tree().get_nodes_in_group("rune_pickups"):
		if node.get("_player_in_range") != null:
			_active_rune_pickup = node
			break
	_active_shop_station = null
	for node in get_tree().get_nodes_in_group("shop_stations"):
		if node.get("_player_in_range") != null:
			_active_shop_station = node
			break
	_active_room_exit = null
	for node in get_tree().get_nodes_in_group("room_exits"):
		var room_exit := node as RoomExit
		if room_exit != null and room_exit.is_prompt_visible():
			_active_room_exit = room_exit
			break


func _update_player_hp() -> void:
	if _player == null:
		if _player_hp_fill is ProgressBar:
			_player_hp_fill.value = 0.0
		elif _player_hp_fill != null:
			_player_hp_fill.size.x = 0.0
		return
	var ratio: float = clampf(_player.current_health / _player.max_health, 0.0, 1.0)
	if _player_hp_fill is ProgressBar:
		_player_hp_fill.value = ratio * 100.0
		if _player_hp_label != null:
			_player_hp_label.text = "%d / %d" % [int(_player.current_health), int(_player.max_health)]
	else:
		_player_hp_fill.size.x = _player_hp_bg.size.x * ratio


func _update_boss_panel() -> void:
	if _boss == null:
		if _boss_panel != null:
			_boss_panel.visible = false
		return
	if _boss_panel != null:
		_boss_panel.visible = true
		_boss_name_label.text = _boss.boss_stats.boss_name
		var ratio: float = _boss.get_health_ratio()
		if _boss_hp_fill is ProgressBar:
			_boss_hp_fill.value = ratio * 100.0
		else:
			_boss_hp_fill.size.x = _boss_hp_bg.size.x * ratio
			if _boss_phase_tick != null:
				_boss_phase_tick.position.x = _boss_hp_bg.size.x * _boss.boss_stats.phase_transition_health_ratio

func _update_weapon_slots() -> void:
	_fill_weapon_slot(_weapon_1_box, _weapon_1_label, _player.weapon if _player != null else null)
	_fill_weapon_slot(_weapon_2_box, _weapon_2_label, _player.secondary_weapon if _player != null else null)


func _update_skill_slots() -> void:
	_fill_skill_slot(_skill_1_box, _skill_1_label, _player.skill_1 if _player != null else null)
	_fill_skill_slot(_skill_2_box, _skill_2_label, _player.skill_2 if _player != null else null)


func _fill_weapon_slot(box: Control, label: Label, weapon: WeaponStats) -> void:
	# Find or create a TextureRect inside the box
	var tex_rect: TextureRect = null
	for child in box.get_children():
		if child is TextureRect:
			tex_rect = child
			break
	if tex_rect == null:
		tex_rect = TextureRect.new()
		tex_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(tex_rect)

	if weapon == null:
		if box is ColorRect: box.color = SLOT_EMPTY_COLOR
		label.text = ""
		tex_rect.texture = null
		return
		
	if box is ColorRect: box.color = ElementIndicator.ELEMENT_COLOR.get(weapon.innate_element, SLOT_EMPTY_COLOR)
	
	var display_tex = weapon.weapon_icon if weapon.weapon_icon != null else weapon.weapon_texture
	if display_tex != null:
		tex_rect.texture = display_tex
		label.text = ""  # Hide the initial if we have an icon
	else:
		tex_rect.texture = null
		label.text = weapon.weapon_name.substr(0, 1)


func _fill_skill_slot(box: Control, label: Label, skill: SkillData) -> void:
	if label.get_parent() != box:
		label.set_anchors_preset(Control.PRESET_FULL_RECT)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		box.add_child(label)
	var tex_rect: TextureRect = box.find_child("SkillIcon", false, false) as TextureRect
	if tex_rect == null:
		tex_rect = TextureRect.new()
		tex_rect.name = "SkillIcon"
		tex_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(tex_rect)
	var cooldown_overlay := box.find_child("SkillCooldownOverlay", false, false) as ColorRect
	if cooldown_overlay == null:
		cooldown_overlay = ColorRect.new()
		cooldown_overlay.name = "SkillCooldownOverlay"
		cooldown_overlay.color = Color(0.02, 0.02, 0.03, 0.72)
		cooldown_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cooldown_overlay.anchor_right = 1.0
		box.add_child(cooldown_overlay)
	var energy_ring := box.find_child("SkillEnergyRing", false, false) as SkillEnergyRing
	if energy_ring == null:
		energy_ring = SKILL_ENERGY_RING_SCRIPT.new()
		energy_ring.name = "SkillEnergyRing"
		energy_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(energy_ring)
	var key_label := box.find_child("SkillKeyLabel", false, false) as Label
	if key_label == null:
		key_label = Label.new()
		key_label.name = "SkillKeyLabel"
		key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		key_label.position = Vector2(2, 0)
		key_label.size = Vector2(SLOT_SIZE - 4, 14 * UI_SCALE)
		key_label.add_theme_font_size_override("font_size", int(10 * UI_SCALE))
		key_label.add_theme_color_override("font_color", PROMPT_TEXT_COLOR)
		key_label.add_theme_color_override("font_outline_color", Color.BLACK)
		key_label.add_theme_constant_override("outline_size", 2)
		box.add_child(key_label)
	var is_primary := box == _skill_1_box
	key_label.text = "Q" if is_primary else "E"
	if skill == null:
		if box is ColorRect: box.color = SLOT_EMPTY_COLOR
		label.text = ""
		tex_rect.texture = null
		cooldown_overlay.visible = false
		energy_ring.ratio = 0.0
		energy_ring.visible = false
		return
	if box is ColorRect: box.color = ElementIndicator.ELEMENT_COLOR.get(skill.element, SLOT_EMPTY_COLOR)
	tex_rect.texture = skill.icon
	label.text = "" if skill.icon != null else skill.skill_name.substr(0, 1)
	var cooldown_ratio := _player.get_skill_cooldown_ratio(skill) if _player != null else 0.0
	cooldown_overlay.position = Vector2.ZERO
	cooldown_overlay.size = Vector2(box.size.x, box.size.y * cooldown_ratio)
	cooldown_overlay.visible = cooldown_ratio > 0.0
	# §7.1 — radial energy fill for energy-gated skills (Maid's Sweep). The
	# ring growing to a full circle is the primary cue; the thicker outline
	# plus complete ring at full is a non-color cue (A.1: color secondary).
	if skill.uses_energy:
		energy_ring.ring_color = ElementIndicator.ELEMENT_COLOR.get(skill.element, energy_ring.ring_color)
		energy_ring.ratio = _player.get_skill_energy_ratio(skill) if _player != null else 0.0
		energy_ring.visible = true
	else:
		energy_ring.ratio = 0.0
		energy_ring.visible = false


func _update_pickup_prompts() -> void:
	_weapon_1_prompt.visible = _active_weapon_pickup != null and not _overlay_active
	_weapon_2_prompt.visible = _active_weapon_pickup != null and not _overlay_active
	_skill_1_prompt.visible = _active_skill_pickup != null and not _overlay_active
	_skill_2_prompt.visible = _active_skill_pickup != null and not _overlay_active


## --- Pickup selection overlay ---

func is_overlay_active() -> bool:
	return _overlay_active


## Owns ALL pickup-related input — WeaponPickup/SkillPickup themselves
## no longer read Input at all (see their own headers). Opening only
## happens from proximity + "pickup" (F) while the player is free to
## act; every other branch only runs while _overlay_active is already
## true.
func _handle_pickup_overlay_input() -> void:
	if _shop_offer_opened_overlay:
		_shop_offer_opened_overlay = false
		return
	if not _overlay_active:
		if _can_open_overlay():
			var pickup = _active_weapon_pickup if _active_weapon_pickup != null else (_active_skill_pickup if _active_skill_pickup != null else _active_rune_pickup)
			if pickup == null:
				if _active_shop_station == null and _active_room_exit != null and Input.is_action_just_pressed("pickup"):
					_active_room_exit.request_enter()
				if _inspect_active and (_active_rune_pickup == null or _active_rune_pickup.get("_player_in_range") == null):
					_inspect_active = false
					_update_inspect_visuals(null)
				return
			if pickup != null:
				var is_weapon = pickup == _active_weapon_pickup
				if Input.is_action_just_pressed("inspect"):
					if pickup is RunePickup:
						_inspect_active = not _inspect_active
						_update_inspect_visuals(pickup)
					return
				elif Input.is_action_just_pressed("pickup"):
					_inspect_active = false
					_update_inspect_visuals(null)
					
					var auto_equip = false
					if is_weapon:
						if pickup.get_script() != SHOP_WEAPON_PICKUP_SCRIPT:
							if _player.weapon == null:
								pickup.call("_do_pickup", _player, true)
								auto_equip = true
							elif _player.secondary_weapon == null:
								pickup.call("_do_pickup", _player, false)
								auto_equip = true
					elif pickup == _active_skill_pickup:
						if _player.skill_1 == null:
							pickup.call("_do_pickup", _player, true)
							auto_equip = true
						elif _player.skill_2 == null:
							pickup.call("_do_pickup", _player, false)
							auto_equip = true
					else:
						var rpickup := pickup as RunePickup
						if rpickup != null and rpickup._can_direct_equip(_player):
							if _player.weapon != null and _player.weapon_rune == null:
								rpickup._do_pickup(_player, true)
								auto_equip = true
							elif _player.secondary_weapon != null and _player.secondary_weapon_rune == null:
								rpickup._do_pickup(_player, false)
								auto_equip = true
					
					if not auto_equip:
						_open_overlay(pickup, is_weapon)
				elif Input.is_action_just_pressed("swap"):
					_inspect_active = false
					_update_inspect_visuals(null)
					_open_overlay(pickup, is_weapon)
					
		if _inspect_active and (_active_rune_pickup == null or _active_rune_pickup.get("_player_in_range") == null):
			_inspect_active = false
			_update_inspect_visuals(null)
		return

	# Auto-close if the target was freed from elsewhere, or the player
	# simply walked out of its range while the menu was open.
	if not is_instance_valid(_overlay_pickup) or _overlay_pickup.get("_player_in_range") == null:
		_close_overlay()
		return

	if Input.is_action_just_pressed("inspect"):
		if _overlay_kind == OverlayKind.RUNE:
			_inspect_active = not _inspect_active
			_update_inspect_visuals(_overlay_pickup)
		return

	if Input.is_action_just_pressed("menu_cancel") or Input.is_action_just_pressed("swap"):
		if _inspect_active and Input.is_action_just_pressed("menu_cancel"):
			_inspect_active = false
			_update_inspect_visuals(_overlay_pickup)
		else:
			_close_overlay()
	elif Input.is_action_just_pressed("menu_up"):
		_overlay_selected_primary = true
		_update_overlay_visuals()
	elif Input.is_action_just_pressed("menu_down"):
		_overlay_selected_primary = false
		_update_overlay_visuals()
	elif Input.is_action_just_pressed("equip_slot_1"):
		_overlay_selected_primary = true
		_confirm_overlay_selection()
	elif Input.is_action_just_pressed("equip_slot_2"):
		_overlay_selected_primary = false
		_confirm_overlay_selection()
	elif Input.is_action_just_pressed("pickup"):
		_confirm_overlay_selection()


## Deliberately excludes ATTACK/DODGE/DISABLED — opening a menu mid-swing,
## mid-dodge, or mid-stagger would freeze the animation in a half-finished
## state (Player's own overlay-freeze branch skips the whole state
## machine, including hitbox.disable()). Simplest fix: don't let the
## overlay open in those states at all.
func _can_open_overlay() -> bool:
	if _player == null:
		return false
	return _player.state not in [Player.State.ATTACK, Player.State.DODGE, Player.State.DISABLED]


## Mouse path — a click on either option selects it, a second click confirms.
func _on_overlay_option_gui_input(event: InputEvent, is_primary: bool) -> void:
	if not _overlay_active:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _overlay_selected_primary == is_primary:
			_confirm_overlay_selection()
		else:
			_overlay_selected_primary = is_primary
			_update_overlay_visuals()

func _build_upgrade_menu(root: Control) -> void:
	_upgrade_panel = CenterContainer.new()
	_upgrade_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_upgrade_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_upgrade_panel.visible = false
	root.add_child(_upgrade_panel)

	var bg_panel := PanelContainer.new()
	bg_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg_panel.custom_minimum_size = Vector2(1040.0 * UI_SCALE, 480.0 * UI_SCALE)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.07, 0.09, 0.97)
	style.border_color = Color(0.55, 0.8, 1.0, 0.85)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.content_margin_left = int(32 * UI_SCALE)
	style.content_margin_right = int(32 * UI_SCALE)
	style.content_margin_top = int(24 * UI_SCALE)
	style.content_margin_bottom = int(20 * UI_SCALE)
	bg_panel.add_theme_stylebox_override("panel", style)
	_upgrade_panel.add_child(bg_panel)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", int(14 * UI_SCALE))
	bg_panel.add_child(vbox)

	_upgrade_title = Label.new()
	_upgrade_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_upgrade_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_upgrade_title.add_theme_font_size_override("font_size", int(32 * UI_SCALE))
	_upgrade_title.text = "Room Clear Upgrade"
	vbox.add_child(_upgrade_title)

	var card_row := HBoxContainer.new()
	card_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_row.alignment = BoxContainer.ALIGNMENT_CENTER
	card_row.add_theme_constant_override("separation", int(16 * UI_SCALE))
	vbox.add_child(card_row)

	_upgrade_card_style = _make_upgrade_card_style(Color(0.12, 0.14, 0.18), Color(0.34, 0.39, 0.46))
	_upgrade_card_selected_style = _make_upgrade_card_style(Color(0.12, 0.22, 0.3), Color(0.45, 0.82, 1.0))
	for index in 3:
		var card = preload("res://scenes/ui/upgrade_card.tscn").instantiate()
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.gui_input.connect(_on_upgrade_option_gui_input.bind(index))
		card_row.add_child(card)
		_upgrade_cards.append(card)
		_upgrade_options.append(card)


	var hint := Label.new()
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", int(20 * UI_SCALE))
	hint.text = "W / S to move  •  F to buy  •  Esc / Tab to close"
	vbox.add_child(hint)

	_update_upgrade_menu_visuals()

func _on_upgrade_option_gui_input(event: InputEvent, card_index: int) -> void:
	if not _upgrade_menu_active:
		return
	var option_index := _upgrade_page_offset + card_index
	if option_index < 0 or option_index >= _all_upgrade_options.size():
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _upgrade_menu_selected_index == option_index:
			_confirm_upgrade_selection()
		else:
			_set_upgrade_selection(option_index)

func _make_upgrade_card_style(background: Color, border: Color) -> StyleBoxFlat:
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = background
	card_style.border_color = border
	card_style.set_border_width_all(2)
	card_style.set_content_margin_all(int(16 * UI_SCALE))
	return card_style

func _handle_room_clear_upgrade_input() -> void:
	if _overlay_active:
		return
	if not _upgrade_menu_active:
		if _active_weapon_pickup != null or _active_skill_pickup != null or _active_rune_pickup != null:
			return
		if _active_shop_station != null and _can_open_upgrade_menu() \
				and Input.is_action_just_pressed("pickup"):
			_open_shop_menu(int(_active_shop_station.get("category")))
			return
		return

	if Input.is_action_just_pressed("menu_cancel") or Input.is_action_just_pressed("swap"):
		_close_upgrade_menu()
		return
	if Input.is_action_just_pressed("menu_up"):
		_set_upgrade_selection(_upgrade_menu_selected_index - 1)
		return
	if Input.is_action_just_pressed("menu_down"):
		_set_upgrade_selection(_upgrade_menu_selected_index + 1)
		return
	if Input.is_action_just_pressed("pickup"):
		_confirm_upgrade_selection()

func _set_debug_room_clear_state(enabled: bool) -> void:
	_debug_room_clear_state = enabled

func _can_open_upgrade_menu() -> bool:
	var player := _player
	if player == null and RunManager != null and RunManager._player != null:
		player = RunManager._player
	if player == null:
		return false
	if player.state in [Player.State.ATTACK, Player.State.DODGE, Player.State.DISABLED]:
		return false
	if _overlay_active:
		return false
	return _is_room_cleared_for_upgrade()

func _is_room_cleared_for_upgrade() -> bool:
	if _debug_room_clear_state:
		return true
	var tree := get_tree()
	if tree == null:
		return false
	return tree.get_nodes_in_group("enemies").is_empty()

func is_upgrade_menu_active() -> bool:
	return _upgrade_menu_active

func _open_upgrade_menu() -> void:
	_open_shop_menu(ShopStation.Category.UPGRADE)


func _open_shop_menu(category: int) -> void:
	_upgrade_menu_active = true
	_upgrade_menu_category = category
	_upgrade_menu_selected_index = 0
	_upgrade_page_offset = 0
	_ensure_shop_stock_session()
	if category == ShopStation.Category.UPGRADE:
		_rebuild_all_upgrade_options()
	else:
		if not _shop_offer_stock.has(category):
			_shop_offer_stock[category] = _roll_shop_offers(category)
		_all_upgrade_options = _shop_offer_stock[category].duplicate()
	PlaytestMode.close_panel()
	if get_tree() != null:
		get_tree().paused = true
	_update_upgrade_menu_visuals()

func _close_upgrade_menu() -> void:
	_upgrade_menu_active = false
	_upgrade_menu_category = ShopStation.Category.UPGRADE
	if get_tree() != null:
		get_tree().paused = false
	_update_upgrade_menu_visuals()

func _set_upgrade_selection(index: int) -> void:
	_upgrade_menu_selected_index = posmod(index, _all_upgrade_options.size())
	# Scroll page so selected option is always visible.
	if _upgrade_menu_selected_index < _upgrade_page_offset:
		_upgrade_page_offset = _upgrade_menu_selected_index
	elif _upgrade_menu_selected_index >= _upgrade_page_offset + UPGRADE_CARDS_VISIBLE:
		_upgrade_page_offset = _upgrade_menu_selected_index - UPGRADE_CARDS_VISIBLE + 1
	_update_upgrade_menu_visuals()

func _confirm_upgrade_selection() -> void:
	if not _upgrade_menu_active or _all_upgrade_options.is_empty():
		return
	var opt := _all_upgrade_options[_upgrade_menu_selected_index]
	if str(opt.get("type", "")).begins_with("shop_"):
		_open_shop_offer(opt)
		_update_upgrade_menu_visuals()
		return
	var purchased := false
	match opt.get("type", ""):
		"weapon":
			purchased = UpgradeManager.purchase_weapon_might()
		"vitality":
			purchased = UpgradeManager.purchase_vitality()
			if purchased and _player != null:
				_player.max_health += 10.0
				_player.current_health = minf(_player.current_health + 10.0, _player.max_health)
		"restore":
			if _player == null or _player.current_health >= _player.max_health:
				return
			purchased = UpgradeManager.purchase_restore()
			if purchased:
				_player.current_health = minf(
						_player.current_health + _player.max_health * UpgradeManager.RESTORE_HEAL_FRACTION,
						_player.max_health)
		"sinh_rank1":
			purchased = UpgradeManager.purchase_sinh_rank1(opt.get("pair", []))
		"sinh_rank2":
			purchased = UpgradeManager.purchase_sinh_rank2(opt.get("pair", []), opt.get("favored", &""))
		"khac_rank1":
			purchased = UpgradeManager.purchase_khac_rank1(opt.get("pair", []))
		"khac_rank2":
			purchased = UpgradeManager.purchase_khac_rank2(opt.get("pair", []))
	if purchased:
		_rebuild_all_upgrade_options()
		_upgrade_menu_selected_index = 0
		_upgrade_page_offset = 0
		if RunManager != null:
			RunManager.save_mid_run()
	_update_upgrade_menu_visuals()


func _ensure_shop_stock_session() -> void:
	var room_id := RunManager._current_room.get_instance_id() if RunManager != null and RunManager._current_room != null else 0
	if room_id != _shop_stock_room_id:
		_shop_stock_room_id = room_id
		_shop_offer_stock.clear()


func _roll_shop_offers(category: int) -> Array[Dictionary]:
	var offers: Array[Dictionary] = []
	if category == ShopStation.Category.WEAPON:
		var paths: Array[String] = LOADOUT_SELECT_SCRIPT.STARTING_WEAPON_PATHS.duplicate()
		for path in SaveManager.get_unlocked_weapon_paths():
			if not paths.has(str(path)):
				paths.append(str(path))
		var held_paths: Array[String] = []
		if _player != null:
			for held in [_player.weapon, _player.secondary_weapon]:
				if held != null and not held.resource_path.is_empty():
					held_paths.append(held.resource_path)
		var candidates: Array[WeaponStats] = []
		for path in paths:
			if held_paths.has(path):
				continue
			var weapon := load(path) as WeaponStats
			if weapon != null:
				candidates.append(weapon)
		candidates.shuffle()
		for index in mini(3, candidates.size()):
			var weapon: WeaponStats = candidates[index]
			var price := _shop_weapon_price(weapon)
			offers.append({
				"type": "shop_weapon", "label": weapon.weapon_name.to_upper(),
				"desc": "Weapon\nCost: %d Qi" % price, "cost": price,
				"weapon": weapon, "purchased": false,
			})
	elif category == ShopStation.Category.SKILL:
		var paths: Array[String] = LOADOUT_SELECT_SCRIPT.STARTING_SKILL_PATHS.duplicate()
		for path in SaveManager.get_unlocked_skill_paths():
			if not paths.has(str(path)):
				paths.append(str(path))
		var held_paths: Array[String] = []
		if _player != null:
			for held in [_player.skill_1, _player.skill_2]:
				if held != null and not held.resource_path.is_empty():
					held_paths.append(held.resource_path)
		var candidates: Array[SkillData] = []
		for path in paths:
			if held_paths.has(path):
				continue
			var skill := load(path) as SkillData
			if skill != null:
				candidates.append(skill)
		candidates.shuffle()
		for index in mini(3, candidates.size()):
			var skill: SkillData = candidates[index]
			offers.append({
				"type": "shop_skill", "label": skill.skill_name.to_upper(),
				"desc": "%s skill\nCost: 60 Qi" % String(skill.element).to_upper(),
				"cost": 60, "skill": skill, "purchased": false,
			})
	elif category == ShopStation.Category.RUNE:
		for _index in 3:
			var element: StringName = Elements.ALL[randi() % Elements.ALL.size()]
			var rune := RuneRoller.default().roll(element, RuneData.Target.WEAPON)
			offers.append({
				"type": "shop_rune", "label": "%s RUNE" % String(element).to_upper(),
				"desc": "%s\nCost: 30 Qi" % "\n".join(rune.describe_lines()),
				"cost": 30, "rune": rune, "purchased": false,
			})
	return offers


func get_shop_stock_save_state() -> Dictionary:
	if _shop_offer_stock.is_empty():
		return {}
	var serialized_stock: Dictionary = {}
	for category_key in _shop_offer_stock:
		var category_int: int = int(category_key)
		var cat_name: String
		match category_int:
			ShopStation.Category.WEAPON:
				cat_name = "weapon"
			ShopStation.Category.SKILL:
				cat_name = "skill"
			ShopStation.Category.RUNE:
				cat_name = "rune"
			_:
				cat_name = str(category_key)
		var raw_offers: Array = _shop_offer_stock[category_key]
		var serialized_offers: Array[Dictionary] = []
		for offer in raw_offers:
			if not offer is Dictionary:
				continue
			var offer_type: String = str(offer.get("type", ""))
			var cost: int = int(offer.get("cost", 0))
			var purchased: bool = bool(offer.get("purchased", false))
			if offer_type == "shop_weapon":
				var weapon = offer.get("weapon")
				var weapon_path: String = weapon.resource_path if weapon != null else ""
				serialized_offers.append({
					"type": "shop_weapon",
					"weapon_path": weapon_path,
					"cost": cost,
					"purchased": purchased,
				})
			elif offer_type == "shop_skill":
				var skill = offer.get("skill")
				var skill_path: String = skill.resource_path if skill != null else ""
				serialized_offers.append({
					"type": "shop_skill",
					"skill_path": skill_path,
					"cost": cost,
					"purchased": purchased,
				})
			elif offer_type == "shop_rune":
				var rune = offer.get("rune")
				var rune_dict: Dictionary = rune.to_dict() if rune is RuneData else {}
				serialized_offers.append({
					"type": "shop_rune",
					"rune": rune_dict,
					"cost": cost,
					"purchased": purchased,
				})
		serialized_stock[cat_name] = serialized_offers
	return {
		"stock": serialized_stock,
		"refresh_counts": {},
	}


func apply_shop_stock_save_state(saved_state: Dictionary) -> void:
	_shop_offer_stock.clear()
	var current_room: Node = RunManager._current_room if RunManager != null else null
	_shop_stock_room_id = current_room.get_instance_id() if current_room != null else 0
	if saved_state.is_empty():
		return

	var raw_stock: Dictionary = saved_state.get("stock", saved_state) if saved_state is Dictionary else {}
	for cat_key in raw_stock:
		var cat_int: int = _category_from_key(cat_key)
		if cat_int < 0:
			continue
		var raw_offers: Variant = raw_stock[cat_key]
		if not raw_offers is Array:
			continue
		var restored_offers: Array[Dictionary] = []
		for item in raw_offers:
			if not item is Dictionary:
				continue
			var item_type := str(item.get("type", ""))
			var cost := int(item.get("cost", 0))
			var purchased := bool(item.get("purchased", false))
			if item_type == "shop_weapon":
				var weapon_path := str(item.get("weapon_path", ""))
				if weapon_path.is_empty() or not ResourceLoader.exists(weapon_path):
					continue
				var weapon := load(weapon_path) as WeaponStats
				if weapon == null:
					continue
				if cost <= 0:
					cost = _shop_weapon_price(weapon)
				restored_offers.append({
					"type": "shop_weapon",
					"label": weapon.weapon_name.to_upper(),
					"desc": "Weapon\nCost: %d Qi" % cost,
					"cost": cost,
					"weapon": weapon,
					"purchased": purchased,
				})
			elif item_type == "shop_skill":
				var skill_path := str(item.get("skill_path", ""))
				if skill_path.is_empty() or not ResourceLoader.exists(skill_path):
					continue
				var skill := load(skill_path) as SkillData
				if skill == null:
					continue
				if cost <= 0:
					cost = 60
				restored_offers.append({
					"type": "shop_skill",
					"label": skill.skill_name.to_upper(),
					"desc": "%s skill\nCost: %d Qi" % [String(skill.element).to_upper(), cost],
					"cost": cost,
					"skill": skill,
					"purchased": purchased,
				})
			elif item_type == "shop_rune":
				var rune_dict: Variant = item.get("rune", {})
				if not rune_dict is Dictionary:
					continue
				var rune := RuneData.from_dict(rune_dict)
				if rune == null:
					continue
				if cost <= 0:
					cost = 30
				restored_offers.append({
					"type": "shop_rune",
					"label": "%s RUNE" % String(rune.element).to_upper(),
					"desc": "%s\nCost: %d Qi" % ["\n".join(rune.describe_lines()), cost],
					"cost": cost,
					"rune": rune,
					"purchased": purchased,
				})
		if not restored_offers.is_empty():
			_shop_offer_stock[cat_int] = restored_offers


func _category_from_key(key: Variant) -> int:
	if key is int:
		return key
	var s := str(key).to_lower()
	match s:
		"upgrade", "0":
			return ShopStation.Category.UPGRADE
		"weapon", "1":
			return ShopStation.Category.WEAPON
		"skill", "2":
			return ShopStation.Category.SKILL
		"rune", "3":
			return ShopStation.Category.RUNE
	return -1


func clear_shop_stock() -> void:
	_shop_offer_stock.clear()
	_shop_stock_room_id = 0


func _shop_weapon_price(weapon: WeaponStats) -> int:
	match weapon.weight:
		WeaponStats.Weight.LIGHT:
			return 35
		WeaponStats.Weight.MEDIUM:
			return 45
		WeaponStats.Weight.HEAVY:
			return 55
	return 45


func _open_shop_offer(offer: Dictionary) -> void:
	if _player == null or bool(offer.get("purchased", false)) or UpgradeManager.qi < float(offer.get("cost", 0)):
		return
	var parent: Node = RunManager._current_room if RunManager != null and RunManager._current_room != null else get_tree().current_scene
	if parent == null:
		return
	var pickup: Node = null
	var is_weapon := false
	match str(offer.get("type", "")):
		"shop_weapon":
			var weapon_pickup := SHOP_WEAPON_PICKUP_SCRIPT.new() as ShopWeaponPickup
			weapon_pickup.weapon = offer.get("weapon")
			weapon_pickup.price = int(offer.get("cost", 0))
			pickup = weapon_pickup
			is_weapon = true
		"shop_skill":
			var skill_pickup := SHOP_SKILL_PICKUP_SCRIPT.new() as ShopSkillPickup
			skill_pickup.skill = offer.get("skill")
			skill_pickup.price = int(offer.get("cost", 0))
			pickup = skill_pickup
		"shop_rune":
			var rune_pickup = SHOP_RUNE_PICKUP_SCRIPT.new()
			rune_pickup.rune = offer.get("rune")
			rune_pickup.price = int(offer.get("cost", 0))
			pickup = rune_pickup
	if pickup == null:
		return
	pickup.global_position = _player.global_position
	parent.add_child(pickup)
	pickup.set("_player_in_range", _player)
	_pending_shop_offer = offer
	_open_overlay(pickup, is_weapon)
	_shop_offer_opened_overlay = true

## Builds and randomizes available upgrades so reaction offers can appear
## alongside the repeatable stat and healing upgrades on the first card page.
func _rebuild_all_upgrade_options() -> void:
	_all_upgrade_options.clear()

	var weapon_rank := int(maxf(0.0, (UpgradeManager.weapon_might_multiplier() - 1.0) * 10.0))
	var weapon_cost := UpgradeManager.weapon_might_cost()
	_all_upgrade_options.append({
		"type": "weapon",
		"label": "WEAPON MIGHT",
		"desc": "+10%% weapon damage\nRank %d → %d\nCost: %d Qi" % [weapon_rank, weapon_rank + 1, int(weapon_cost)],
		"cost": weapon_cost,
	})

	var vitality_rank := int(maxf(0.0, UpgradeManager.vitality_hp_bonus() / 10.0))
	var vitality_cost := UpgradeManager.vitality_cost()
	_all_upgrade_options.append({
		"type": "vitality",
		"label": "VITALITY",
		"desc": "+10 maximum HP\nRank %d → %d\nCost: %d Qi" % [vitality_rank, vitality_rank + 1, int(vitality_cost)],
		"cost": vitality_cost,
	})

	var restore_cost := UpgradeManager.restore_cost()
	var restore_desc := "Heal 30%% maximum HP\nUsed %d times\nCost: %d Qi" % [
		UpgradeManager.restore_uses(), int(restore_cost)]
	if _player == null or _player.current_health >= _player.max_health:
		restore_desc += "\n[Full HP]"
	_all_upgrade_options.append({
		"type": "restore",
		"label": "RESTORE",
		"desc": restore_desc,
		"cost": restore_cost,
	})

	for definition in _reaction_upgrade_definitions():
		var pair: Array = definition["pair"]
		var name: String = definition["name"]
		var branch: String = definition["branch"]
		var rank := UpgradeManager.reaction_rank(pair)
		if branch == "sinh":
			if rank == 0:
				_all_upgrade_options.append({
					"type": "sinh_rank1",
					"label": name.to_upper() + " I",
					"desc": "Always Tier 2 magnitude\nCost: %d Qi" % int(UpgradeManager.SINH_RANK1_COST),
					"cost": UpgradeManager.SINH_RANK1_COST,
					"pair": pair,
				})
			elif rank == 1:
				var typed_pair: Array[StringName] = [StringName(pair[0]), StringName(pair[1])]
				var generated := Elements.sinh_generated_element(typed_pair)
				var other: StringName = typed_pair[0] if typed_pair[1] == generated else typed_pair[1]
				_all_upgrade_options.append({
					"type": "sinh_rank2",
					"label": name.to_upper() + " II (%s)" % generated.to_upper(),
					"desc": "Favor %s bonus\nCost: %d Qi" % [generated.to_upper(), int(UpgradeManager.SINH_RANK2_COST)],
					"cost": UpgradeManager.SINH_RANK2_COST,
					"pair": pair,
					"favored": generated,
				})
				_all_upgrade_options.append({
					"type": "sinh_rank2",
					"label": name.to_upper() + " II (%s)" % other.to_upper(),
					"desc": "Favor %s bonus\nCost: %d Qi" % [other.to_upper(), int(UpgradeManager.SINH_RANK2_COST)],
					"cost": UpgradeManager.SINH_RANK2_COST,
					"pair": pair,
					"favored": other,
				})
		elif rank == 0:
			_all_upgrade_options.append({
				"type": "khac_rank1",
				"label": name.to_upper() + " I",
				"desc": "Partial clears become Full clears\nCost: %d Qi" % int(UpgradeManager.KHAC_RANK1_COST),
				"cost": UpgradeManager.KHAC_RANK1_COST,
				"pair": pair,
			})
		elif rank == 1:
			_all_upgrade_options.append({
				"type": "khac_rank2",
				"label": name.to_upper() + " II",
				"desc": "Always overwhelm magnitude\nCost: %d Qi" % int(UpgradeManager.KHAC_RANK2_COST),
				"cost": UpgradeManager.KHAC_RANK2_COST,
				"pair": pair,
			})

	_randomize_upgrade_options()


func _randomize_upgrade_options() -> void:
	_all_upgrade_options.shuffle()
	if _all_upgrade_options.size() <= UPGRADE_CARDS_VISIBLE:
		return

	var first_page_has_reaction := false
	for index in UPGRADE_CARDS_VISIBLE:
		if _is_reaction_upgrade(_all_upgrade_options[index]):
			first_page_has_reaction = true
			break
	if first_page_has_reaction:
		return

	var reaction_indices: Array[int] = []
	for index in range(UPGRADE_CARDS_VISIBLE, _all_upgrade_options.size()):
		if _is_reaction_upgrade(_all_upgrade_options[index]):
			reaction_indices.append(index)
	if reaction_indices.is_empty():
		return

	var first_page_index := randi_range(0, UPGRADE_CARDS_VISIBLE - 1)
	var reaction_index: int = reaction_indices[randi_range(0, reaction_indices.size() - 1)]
	var displaced_option: Dictionary = _all_upgrade_options[first_page_index]
	_all_upgrade_options[first_page_index] = _all_upgrade_options[reaction_index]
	_all_upgrade_options[reaction_index] = displaced_option


func _is_reaction_upgrade(option: Dictionary) -> bool:
	return str(option.get("type", "")).begins_with("sinh_") \
			or str(option.get("type", "")).begins_with("khac_")


func _reaction_upgrade_definitions() -> Array[Dictionary]:
	var definitions: Array[Dictionary] = []
	var sinh_pairs: Array[Array] = [
		[Elements.KIM, Elements.THUY],
		[Elements.THUY, Elements.MOC],
		[Elements.MOC, Elements.HOA],
		[Elements.HOA, Elements.THO],
		[Elements.THO, Elements.KIM],
	]
	var sinh_names := ["Condensation", "Overgrowth", "Wildfire", "Cinder Bloom", "Ore Surge"]
	for index in sinh_pairs.size():
		definitions.append({
			"branch": "sinh",
			"pair": sinh_pairs[index],
			"name": sinh_names[index],
		})

	var khac_pairs: Array[Array] = [
		[Elements.HOA, Elements.KIM],
		[Elements.THO, Elements.THUY],
		[Elements.MOC, Elements.THO],
		[Elements.KIM, Elements.MOC],
		[Elements.THUY, Elements.HOA],
	]
	var khac_names := ["Molten", "Silt", "Root Break", "Sever", "Douse"]
	for index in khac_pairs.size():
		definitions.append({
			"branch": "khac",
			"pair": khac_pairs[index],
			"name": khac_names[index],
		})
	return definitions


func _update_upgrade_menu_visuals() -> void:
	_upgrade_panel.visible = _upgrade_menu_active and not _overlay_active
	if not _upgrade_menu_active:
		return

	var total := _all_upgrade_options.size()
	var category_label := ShopStation.CATEGORY_LABELS[_upgrade_menu_category]
	_upgrade_title.text = "%s — Qi: %d  (%d/%d offers)" % [category_label,
		int(UpgradeManager.qi), _upgrade_menu_selected_index + 1, total]

	for card_i in UPGRADE_CARDS_VISIBLE:
		var opt_i := _upgrade_page_offset + card_i
		if opt_i >= total or card_i >= _upgrade_cards.size():
			if card_i < _upgrade_cards.size():
				_upgrade_cards[card_i].visible = false
			continue
		var card = _upgrade_cards[card_i]
		card.visible = true
		var opt := _all_upgrade_options[opt_i]
		var affordable: bool = UpgradeManager.qi >= opt.get("cost", 0.0)
		var label: String = opt.get("label", "")
		var desc: String = opt.get("desc", "")
		if bool(opt.get("purchased", false)):
			desc += "\n[PURCHASED]"
		if not affordable:
			desc += "\n[Not enough Qi]"
		if card.has_method("set_upgrade"):
			card.set_upgrade(label, desc)
		if card.has_method("set_reaction_visual"):
			var reaction_rank := 0
			match str(opt.get("type", "")):
				"sinh_rank1", "khac_rank1":
					reaction_rank = 1
				"sinh_rank2", "khac_rank2":
					reaction_rank = 2
			card.set_reaction_visual(
					opt.get("pair", []),
					reaction_rank,
					StringName(opt.get("favored", &"")))
		if card.has_method("set_selected"):
			card.set_selected(opt_i == _upgrade_menu_selected_index)





## If the player is somehow in range of both a weapon AND a skill pickup
## at once (placed too close together), weapon wins — an arbitrary but
## deterministic tie-break, not expected to matter in normal level
## layout.
func _open_overlay(pickup: Node, is_weapon: bool) -> void:
	_overlay_active = true
	_overlay_pickup = pickup
	if _upgrade_panel != null:
		_upgrade_panel.visible = false
	if pickup is RunePickup:
		_overlay_kind = OverlayKind.RUNE
	else:
		_overlay_kind = OverlayKind.WEAPON if is_weapon else OverlayKind.SKILL
	_overlay_selected_primary = pickup.call("_default_target_is_primary", _player) if _player != null else true


func _close_overlay() -> void:
	_overlay_active = false
	_overlay_pickup = null
	_pending_shop_offer = {}
	if _upgrade_panel != null:
		_upgrade_panel.visible = _upgrade_menu_active


func _confirm_overlay_selection() -> void:
	if _player == null or not is_instance_valid(_overlay_pickup):
		_close_overlay()
		return
	if _overlay_pickup is WeaponPickup \
			and _player.would_duplicate_weapon(_overlay_selected_primary, _overlay_pickup.weapon):
		return
	if _overlay_pickup is SkillPickup \
			and _player.would_duplicate_skill(_overlay_selected_primary, _overlay_pickup.skill):
		return
	var is_shop_weapon: bool = _overlay_pickup.get_script() == SHOP_WEAPON_PICKUP_SCRIPT
	var is_shop_skill: bool = _overlay_pickup.get_script() == SHOP_SKILL_PICKUP_SCRIPT
	var is_shop_rune: bool = _overlay_pickup.get_script() == SHOP_RUNE_PICKUP_SCRIPT
	var pickup_result: Variant
	if is_shop_rune:
		pickup_result = _overlay_pickup.call("purchase", _player, _overlay_selected_primary)
	else:
		pickup_result = _overlay_pickup.call("_do_pickup", _player, _overlay_selected_primary)
	if is_shop_weapon and not bool(pickup_result):
		return
	if is_shop_skill and not bool(pickup_result):
		return
	if is_shop_rune and not bool(pickup_result):
		return
	if not _pending_shop_offer.is_empty():
		_pending_shop_offer["purchased"] = true
	if is_shop_weapon or is_shop_skill or is_shop_rune or not _pending_shop_offer.is_empty():
		if RunManager != null:
			RunManager.save_mid_run()
	_close_overlay()


func _update_overlay_visuals() -> void:
	_overlay_panel.visible = _overlay_active
	if not _overlay_active:
		return

	if _overlay_kind == OverlayKind.WEAPON:
		var weapon: WeaponStats = _overlay_pickup.get("weapon")
		var pickup_rune: RuneData = _overlay_pickup.get("rune")
		_ground_item_card.set_weapon(weapon, pickup_rune, false)
		
		if _player != null:
			_overlay_card_1.set_weapon(_player.weapon, _player.weapon_rune, true)
			_overlay_card_2.set_weapon(_player.secondary_weapon, _player.secondary_weapon_rune, true)
	elif _overlay_kind == OverlayKind.RUNE:
		var rune: RuneData = _overlay_pickup.get("rune")
		_ground_item_card.set_rune_inspect(rune, null, null)
		
		if _player != null:
			_overlay_card_1.set_weapon(_player.weapon, _player.weapon_rune, true)
			_overlay_card_2.set_weapon(_player.secondary_weapon, _player.secondary_weapon_rune, true)
	elif _overlay_kind == OverlayKind.SKILL:
		var skill: SkillData = _overlay_pickup.get("skill")
		_ground_item_card.set_skill(skill, null)
			
		if _player != null:
			_overlay_card_1.set_skill(_player.skill_1, null)
			_overlay_card_2.set_skill(_player.skill_2, null)

	if _ground_item_card.get_parent() != null:
		var target_container = _ground_container_1 if _overlay_selected_primary else _ground_container_2
		if _ground_item_card.get_parent() != target_container:
			_ground_item_card.reparent(target_container, false)

	_overlay_card_1.set_selected(_overlay_selected_primary)
	_overlay_card_2.set_selected(not _overlay_selected_primary)
	
	if _inspect_active:
		_update_inspect_visuals(_overlay_pickup)

func _update_inspect_visuals(pickup: Node) -> void:
	if not _inspect_active or pickup == null or not (pickup is RunePickup):
		_inspect_pane.visible = false
		return
	
	var rune_pickup := pickup as RunePickup
	if rune_pickup.rune == null:
		return
		
	_inspect_pane.visible = true
	
	var target_w: WeaponStats = null
	var target_r: RuneData = null
	
	if _player != null:
		if _overlay_active:
			target_w = _player.weapon if _overlay_selected_primary else _player.secondary_weapon
			target_r = _player.weapon_rune if _overlay_selected_primary else _player.secondary_weapon_rune
		else:
			target_w = _player.weapon
			target_r = _player.weapon_rune
			
	_inspect_pane.set_rune_inspect(rune_pickup.rune, target_w, target_r)
	
	if _overlay_active:
		# Dock under the overlay panel
		var panel_width := 300.0 * UI_SCALE
		var panel_height := 180.0 * UI_SCALE
		_inspect_pane.position = Vector2(-PickupCard.CARD_WIDTH / 2.0, panel_height / 2.0 + 8.0)
	else:
		# Centered on screen
		_inspect_pane.position = Vector2(-PickupCard.CARD_WIDTH / 2.0, -PickupCard.CARD_HEIGHT / 2.0)
