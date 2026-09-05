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


var _player_hp_bg: ColorRect
var _player_hp_fill: ColorRect

var _boss_panel: Control
var _boss_name_label: Label
var _boss_hp_bg: ColorRect
var _boss_hp_fill: ColorRect
var _boss_phase_tick: ColorRect

var _weapon_1_box: ColorRect
var _weapon_1_label: Label
var _weapon_1_prompt: Label
var _weapon_2_box: ColorRect
var _weapon_2_label: Label
var _weapon_2_prompt: Label
var _skill_1_box: ColorRect
var _skill_1_label: Label
var _skill_1_prompt: Label
var _skill_2_box: ColorRect
var _skill_2_label: Label
var _skill_2_prompt: Label

var _player: Player
var _boss: Boss

## Whichever WeaponPickup/SkillPickup the player is currently standing
## near, if any — see _refresh_active_pickups().
var _active_weapon_pickup: WeaponPickup = null
var _active_skill_pickup: SkillPickup = null

## --- Pickup selection overlay state ---
var _overlay_panel: Control
var _overlay_title: Label
var _overlay_slot_1_box: ColorRect
var _overlay_slot_1_label: Label
var _overlay_slot_2_box: ColorRect
var _overlay_slot_2_label: Label

var _overlay_active: bool = false
var _overlay_pickup: Node = null  ## A WeaponPickup or SkillPickup — no shared base class, same duck-typing convention as elsewhere in this project.
var _overlay_is_weapon: bool = true
var _overlay_selected_primary: bool = true


func _ready() -> void:
	layer = 110  # Above VisionBlocker's own darkness overlay (layer 100) — HUD chrome stays visible even inside a steam cloud's blackout.

	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Never eats a click by default — attack is bound to mouse buttons (input_setup.gd). Only the overlay's own slot options (below) opt back into receiving clicks.
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	_build_player_hp_bar(root)
	_build_slots(root)
	_build_boss_panel(root)
	_build_overlay(root)


func _build_player_hp_bar(root: Control) -> void:
	var container := Control.new()
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	container.position = Vector2(20, -40) * UI_SCALE
	container.size = Vector2(180, 20) * UI_SCALE
	root.add_child(container)

	_player_hp_bg = _make_rect(container, BAR_BG_COLOR, Vector2.ZERO, container.size)
	_player_hp_fill = _make_rect(container, PLAYER_HP_COLOR, Vector2.ZERO, container.size)


func _build_slots(root: Control) -> void:
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
	var s1 := _make_slot(container, "1")
	_skill_1_box = s1[0]; _skill_1_label = s1[1]; _skill_1_prompt = s1[2]
	var s2 := _make_slot(container, "2")
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
	var panel_width := 300.0 * UI_SCALE
	var panel_height := 150.0 * UI_SCALE
	_overlay_panel = Control.new()
	_overlay_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE  ## The panel itself passes clicks through; only its option Controls below opt in.
	_overlay_panel.set_anchors_preset(Control.PRESET_CENTER)
	_overlay_panel.position = Vector2(-panel_width / 2.0, -panel_height / 2.0)
	_overlay_panel.size = Vector2(panel_width, panel_height)
	_overlay_panel.visible = false
	root.add_child(_overlay_panel)

	_make_rect(_overlay_panel, OVERLAY_BG_COLOR, Vector2.ZERO, Vector2(panel_width, panel_height))

	_overlay_title = Label.new()
	_overlay_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_title.position = Vector2(10 * UI_SCALE, 8 * UI_SCALE)
	_overlay_title.size = Vector2(panel_width - 20 * UI_SCALE, 20 * UI_SCALE)
	_overlay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_title.add_theme_font_size_override("font_size", int(14 * UI_SCALE))
	_overlay_panel.add_child(_overlay_title)

	var options_container := VBoxContainer.new()
	options_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	options_container.position = Vector2((panel_width - 260 * UI_SCALE) / 2.0, 38 * UI_SCALE)
	options_container.size = Vector2(260 * UI_SCALE, 84 * UI_SCALE)
	options_container.add_theme_constant_override("separation", int(8 * UI_SCALE))
	_overlay_panel.add_child(options_container)

	var opt1 := _make_overlay_option(options_container, true)
	_overlay_slot_1_box = opt1[0]; _overlay_slot_1_label = opt1[1]
	var opt2 := _make_overlay_option(options_container, false)
	_overlay_slot_2_box = opt2[0]; _overlay_slot_2_label = opt2[1]

	var hint := Label.new()
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.text = "W/S or \u2191/\u2193 + F to confirm  \u00b7  1/2 or click to pick  \u00b7  Esc to cancel"
	hint.position = Vector2(6 * UI_SCALE, panel_height - 22 * UI_SCALE)
	hint.size = Vector2(panel_width - 12 * UI_SCALE, 16 * UI_SCALE)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 9)
	hint.add_theme_font_size_override("font_size", maxi(5, int(9 * UI_SCALE)))
	_overlay_panel.add_child(hint)


## Builds one clickable slot option. mouse_filter = STOP is deliberate
## and unique to this Control in the whole HUD — everything else stays
## MOUSE_FILTER_IGNORE so the HUD never eats a click meant for gameplay
## (attack is bound to mouse buttons); only these two options, only
## while the overlay itself is visible (Godot skips input on hidden
## Controls entirely), actually need to receive one.
func _make_overlay_option(parent: Control, is_primary: bool) -> Array:
	var option := Control.new()
	option.custom_minimum_size = Vector2(260, 36) * UI_SCALE
	option.mouse_filter = Control.MOUSE_FILTER_STOP
	option.gui_input.connect(_on_overlay_option_gui_input.bind(is_primary))
	parent.add_child(option)

	var box := _make_rect(option, SLOT_EMPTY_COLOR, Vector2.ZERO, option.custom_minimum_size)

	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", int(13 * UI_SCALE))
	option.add_child(label)

	return [box, label]


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
	_refresh_active_pickups()
	_handle_pickup_overlay_input()
	_update_player_hp()
	_update_boss_panel()
	_update_weapon_slots()
	_update_skill_slots()
	_update_pickup_prompts()
	_update_overlay_visuals()


func _refresh_player_ref() -> void:
	if _player != null and is_instance_valid(_player):
		return
	_player = get_tree().get_first_node_in_group("player") as Player


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


func _update_player_hp() -> void:
	if _player == null:
		_player_hp_fill.size.x = 0.0
		return
	var ratio: float = clampf(_player.current_health / _player.max_health, 0.0, 1.0)
	_player_hp_fill.size.x = _player_hp_bg.size.x * ratio


func _update_boss_panel() -> void:
	if _boss == null:
		_boss_panel.visible = false
		return
	_boss_panel.visible = true
	_boss_name_label.text = _boss.boss_stats.boss_name
	var ratio := _boss.get_health_ratio()
	_boss_hp_fill.size.x = _boss_hp_bg.size.x * ratio
	_boss_phase_tick.position.x = _boss_hp_bg.size.x * _boss.boss_stats.phase_transition_health_ratio


func _update_weapon_slots() -> void:
	_fill_weapon_slot(_weapon_1_box, _weapon_1_label, _player.weapon if _player != null else null)
	_fill_weapon_slot(_weapon_2_box, _weapon_2_label, _player.secondary_weapon if _player != null else null)


func _update_skill_slots() -> void:
	_fill_skill_slot(_skill_1_box, _skill_1_label, _player.skill_1 if _player != null else null)
	_fill_skill_slot(_skill_2_box, _skill_2_label, _player.skill_2 if _player != null else null)


func _fill_weapon_slot(box: ColorRect, label: Label, weapon: WeaponStats) -> void:
	if weapon == null:
		box.color = SLOT_EMPTY_COLOR
		label.text = ""
		return
	box.color = ElementIndicator.ELEMENT_COLOR.get(weapon.innate_element, SLOT_EMPTY_COLOR)
	label.text = weapon.weapon_name.substr(0, 1)


func _fill_skill_slot(box: ColorRect, label: Label, skill: SkillData) -> void:
	if skill == null:
		box.color = SLOT_EMPTY_COLOR
		label.text = ""
		return
	box.color = ElementIndicator.ELEMENT_COLOR.get(skill.element, SLOT_EMPTY_COLOR)
	label.text = skill.skill_name.substr(0, 1)


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
	if not _overlay_active:
		if Input.is_action_just_pressed("pickup") and _can_open_overlay():
			if _active_weapon_pickup != null:
				_open_overlay(_active_weapon_pickup, true)
			elif _active_skill_pickup != null:
				_open_overlay(_active_skill_pickup, false)
		return

	# Auto-close if the target was freed from elsewhere, or the player
	# simply walked out of its range while the menu was open.
	if not is_instance_valid(_overlay_pickup) or _overlay_pickup.get("_player_in_range") == null:
		_close_overlay()
		return

	if Input.is_action_just_pressed("menu_cancel"):
		_close_overlay()
	elif Input.is_action_just_pressed("menu_up"):
		_overlay_selected_primary = true
	elif Input.is_action_just_pressed("menu_down"):
		_overlay_selected_primary = false
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


## Mouse path — a click on either option selects AND confirms in one
## step, independent of whatever the keyboard had highlighted.
func _on_overlay_option_gui_input(event: InputEvent, is_primary: bool) -> void:
	if not _overlay_active:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_overlay_selected_primary = is_primary
		_confirm_overlay_selection()


## If the player is somehow in range of both a weapon AND a skill pickup
## at once (placed too close together), weapon wins — an arbitrary but
## deterministic tie-break, not expected to matter in normal level
## layout.
func _open_overlay(pickup: Node, is_weapon: bool) -> void:
	_overlay_active = true
	_overlay_pickup = pickup
	_overlay_is_weapon = is_weapon
	_overlay_selected_primary = pickup.call("_default_target_is_primary", _player) if _player != null else true


func _close_overlay() -> void:
	_overlay_active = false
	_overlay_pickup = null


func _confirm_overlay_selection() -> void:
	if _player == null or not is_instance_valid(_overlay_pickup):
		_close_overlay()
		return
	_overlay_pickup.call("_do_pickup", _player, _overlay_selected_primary)
	_close_overlay()


func _update_overlay_visuals() -> void:
	_overlay_panel.visible = _overlay_active
	if not _overlay_active:
		return

	var item_name := "Item"
	if _overlay_is_weapon:
		var weapon: WeaponStats = _overlay_pickup.get("weapon")
		if weapon != null:
			item_name = weapon.weapon_name
	else:
		var skill: SkillData = _overlay_pickup.get("skill")
		if skill != null:
			item_name = skill.skill_name
	_overlay_title.text = "Equip %s into:" % item_name

	_overlay_slot_1_label.text = "1 \u2014 %s" % _current_slot_name(true)
	_overlay_slot_2_label.text = "2 \u2014 %s" % _current_slot_name(false)
	_overlay_slot_1_box.color = OVERLAY_SELECTED_COLOR if _overlay_selected_primary else SLOT_EMPTY_COLOR
	_overlay_slot_2_box.color = OVERLAY_SELECTED_COLOR if not _overlay_selected_primary else SLOT_EMPTY_COLOR


func _current_slot_name(is_primary: bool) -> String:
	if _player == null:
		return "Empty"
	if _overlay_is_weapon:
		var w: WeaponStats = _player.weapon if is_primary else _player.secondary_weapon
		return w.weapon_name if w != null else "Empty"
	var s: SkillData = _player.skill_1 if is_primary else _player.skill_2
	return s.skill_name if s != null else "Empty"
