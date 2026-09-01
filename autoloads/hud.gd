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
## phase_transition_health_ratio — the exact health fraction at which
## Boss._enter_phase_2() fires (see boss.gd), made visible to the player
## rather than a number only the code knows about.
##
## Polls each frame rather than being fully signal-driven: health drains
## via DoT ticks, not just discrete hits, so a light _process poll is
## simpler here than wiring a listener for every source of change —
## consistent with ElementalCombatant's own debug readout doing the same.

const SLOT_SIZE: float = 40.0
const SLOT_SEPARATION: float = 8.0
const SLOT_EMPTY_COLOR := Color(0.2, 0.2, 0.24, 0.9)
const BAR_BG_COLOR := Color(0.15, 0.15, 0.18, 0.9)
const PLAYER_HP_COLOR := Color(0.35, 0.85, 0.4)
const BOSS_HP_COLOR := Color(0.85, 0.3, 0.3)
const PHASE_TICK_COLOR := Color(1.0, 1.0, 1.0, 0.85)

var _player_hp_bg: ColorRect
var _player_hp_fill: ColorRect

var _boss_panel: Control
var _boss_name_label: Label
var _boss_hp_bg: ColorRect
var _boss_hp_fill: ColorRect
var _boss_phase_tick: ColorRect

var _weapon_1_box: ColorRect
var _weapon_1_label: Label
var _weapon_2_box: ColorRect
var _weapon_2_label: Label
var _skill_1_box: ColorRect
var _skill_1_label: Label
var _skill_2_box: ColorRect
var _skill_2_label: Label

var _player: Player
var _boss: Boss


func _ready() -> void:
	layer = 110  # Above VisionBlocker's own darkness overlay (layer 100) — HUD chrome stays visible even inside a steam cloud's blackout.

	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Never eats a click — attack is bound to mouse buttons (input_setup.gd).
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	_build_player_hp_bar(root)
	_build_slots(root)
	_build_boss_panel(root)


func _build_player_hp_bar(root: Control) -> void:
	var container := Control.new()
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	container.position = Vector2(20, -40)
	container.size = Vector2(180, 20)
	root.add_child(container)

	_player_hp_bg = _make_rect(container, BAR_BG_COLOR, Vector2.ZERO, container.size)
	_player_hp_fill = _make_rect(container, PLAYER_HP_COLOR, Vector2.ZERO, container.size)


func _build_slots(root: Control) -> void:
	var total_width := SLOT_SIZE * 4 + SLOT_SEPARATION * 3
	var container := HBoxContainer.new()
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	container.position = Vector2(-total_width - 20, -SLOT_SIZE - 20)
	container.size = Vector2(total_width, SLOT_SIZE)
	container.add_theme_constant_override("separation", int(SLOT_SEPARATION))
	root.add_child(container)

	var w1 := _make_slot(container)
	_weapon_1_box = w1[0]; _weapon_1_label = w1[1]
	var w2 := _make_slot(container)
	_weapon_2_box = w2[0]; _weapon_2_label = w2[1]
	var s1 := _make_slot(container)
	_skill_1_box = s1[0]; _skill_1_label = s1[1]
	var s2 := _make_slot(container)
	_skill_2_box = s2[0]; _skill_2_label = s2[1]


func _make_slot(parent: Control) -> Array:
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
	label.add_theme_font_size_override("font_size", 18)
	slot.add_child(label)

	return [box, label]


func _build_boss_panel(root: Control) -> void:
	var panel_width := 440.0
	_boss_panel = Control.new()
	_boss_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_boss_panel.position = Vector2(-panel_width / 2.0, 16)
	_boss_panel.size = Vector2(panel_width, 44)
	_boss_panel.visible = false
	root.add_child(_boss_panel)

	_boss_name_label = Label.new()
	_boss_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_name_label.size = Vector2(panel_width, 20)
	_boss_panel.add_child(_boss_name_label)

	_boss_hp_bg = _make_rect(_boss_panel, BAR_BG_COLOR, Vector2(0, 26), Vector2(panel_width, 18))
	_boss_hp_fill = _make_rect(_boss_hp_bg, BOSS_HP_COLOR, Vector2.ZERO, _boss_hp_bg.size)
	_boss_phase_tick = _make_rect(_boss_hp_bg, PHASE_TICK_COLOR, Vector2.ZERO, Vector2(2, _boss_hp_bg.size.y))


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
	_update_player_hp()
	_update_boss_panel()
	_update_weapon_slots()
	_update_skill_slots()


func _refresh_player_ref() -> void:
	if _player != null and is_instance_valid(_player):
		return
	_player = get_tree().get_first_node_in_group("player") as Player


func _refresh_boss_ref() -> void:
	if _boss != null and is_instance_valid(_boss) and not _boss.is_dead():
		return
	var candidates := get_tree().get_nodes_in_group("bosses")
	_boss = candidates[0] as Boss if not candidates.is_empty() else null


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
