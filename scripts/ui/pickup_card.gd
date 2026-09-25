class_name PickupCard
extends MarginContainer

## A code-built UI component for displaying Weapon, Skill, or Rune data in 
## the HUD overlay and inspect panes.

const CARD_WIDTH := 260.0
const CARD_HEIGHT := 48.0
const CARD_BG_COLOR := Color(0.12, 0.12, 0.15, 0.9)

var _bg: ColorRect
var _vbox: VBoxContainer
var _title_label: Label
var _details_label: Label
var _dps_label: Label

func _init() -> void:
	custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	
	_bg = ColorRect.new()
	_bg.color = CARD_BG_COLOR
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_bg)
	
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 4)
	add_child(margin)
	
	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", 2)
	margin.add_child(_vbox)
	
	var header := HBoxContainer.new()
	_vbox.add_child(header)
	
	_title_label = Label.new()
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.add_theme_color_override("font_color", Color.WHITE)
	header.add_child(_title_label)
	
	_dps_label = Label.new()
	_dps_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	header.add_child(_dps_label)
	
	_details_label = Label.new()
	_details_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	_details_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_vbox.add_child(_details_label)

func set_empty(slot_name: String) -> void:
	_title_label.text = "Empty %s" % slot_name
	_details_label.text = "Nothing equipped."
	_dps_label.text = ""

func set_weapon(weapon: WeaponStats, slot_rune: RuneData = null, is_equipped: bool = false) -> void:
	if weapon == null:
		set_empty("Weapon")
		return
	
	var text := weapon.weapon_name
	if is_equipped:
		text += " (EQUIPPED)"
	_title_label.text = text
	
	_dps_label.text = "%.1f DPS" % weapon.get_display_dps()
	
	# Badges (element)
	var active_element: StringName = weapon.innate_element
	if slot_rune != null:
		active_element = slot_rune.element
	
	var details := "Weight: Medium  ·  Elem: %s" % active_element
	if slot_rune != null:
		details += " (+%d mods)" % slot_rune.modifiers.size()
	_details_label.text = details

func set_skill(skill: SkillData, slot_rune: RuneData = null) -> void:
	if skill == null:
		set_empty("Skill")
		return
		
	_title_label.text = skill.skill_name
	_dps_label.text = "%.1fs CD" % skill.cooldown
	
	var active_element: StringName = skill.element
	if slot_rune != null and slot_rune.element != Elements.NONE:
		active_element = slot_rune.element
	
	_details_label.text = "Elem: %s  ·  %s" % [active_element, skill.description]

func set_rune_inspect(rune: RuneData, target_weapon: WeaponStats, target_slot_rune: RuneData) -> void:
	_title_label.text = "Rune of %s" % rune.element
	_dps_label.text = ""
	var details := "Modifiers: %d\n" % rune.modifiers.size()
	if target_weapon == null:
		details += "Target: Empty"
	else:
		details += "Target: %s" % target_weapon.weapon_name
	_details_label.text = details

func set_selected(selected: bool) -> void:
	if selected:
		_bg.color = Color(0.2, 0.35, 0.6, 0.9)
	else:
		_bg.color = CARD_BG_COLOR
