class_name PickupCard
extends PanelContainer

const CARD_WIDTH := 260.0
const CARD_HEIGHT := 56.0


@onready var _title_label: Label = $MarginContainer/HBox/VBox/Title
@onready var _stats_label: Label = $MarginContainer/HBox/VBox/Stats
@onready var _desc_label: Label = $MarginContainer/HBox/VBox/Description
@onready var _icon_tex: TextureRect = $MarginContainer/HBox/IconBackground/Icon

var default_bg_color = Color(0.12, 0.12, 0.15, 0.9)
var selected_bg_color = Color(0.2, 0.35, 0.6, 0.9)

func set_empty(slot_name: String) -> void:
	_title_label.text = "Empty " + slot_name
	_stats_label.text = ""
	_desc_label.text = "Nothing equipped."
	_icon_tex.texture = null

func set_weapon(weapon, slot_rune = null, is_equipped: bool = false) -> void:
	if weapon == null:
		set_empty("Weapon")
		return
	
	var text: String = weapon.weapon_name
	if is_equipped:
		text += " (EQUIPPED)"
	_title_label.text = text
	
	var active_element: StringName = weapon.innate_element
	if slot_rune != null:
		active_element = slot_rune.element
	
	_stats_label.text = "DPS: %.1f | Elem: %s" % [weapon.get_display_dps(), active_element]
	
	var details := "A weapon."
	if slot_rune != null:
		details += " (+%d mods)" % slot_rune.modifiers.size()
	_desc_label.text = details
	
	if "weapon_icon" in weapon and weapon.weapon_icon != null:
		_icon_tex.texture = weapon.weapon_icon
	elif "weapon_texture" in weapon and weapon.weapon_texture != null:
		_icon_tex.texture = weapon.weapon_texture

func set_skill(skill, slot_rune = null) -> void:
	if skill == null:
		set_empty("Skill")
		return
		
	_title_label.text = skill.skill_name
	
	var active_element: StringName = skill.element
	if slot_rune != null:
		active_element = slot_rune.element
	
	_stats_label.text = "CD: %.1fs | Elem: %s" % [skill.cooldown, active_element]
	_desc_label.text = skill.description
	_icon_tex.texture = null

func set_rune_inspect(rune, target_weapon, target_slot_rune) -> void:
	_title_label.text = "Rune of " + str(rune.element)
	_stats_label.text = "Modifiers: %d" % rune.modifiers.size()
	var details := ""
	if target_weapon == null:
		details += "Target: Empty"
	else:
		details += "Target: " + target_weapon.weapon_name
	_desc_label.text = details
	_icon_tex.texture = null

func set_selected(selected: bool) -> void:
	if not has_theme_stylebox_override("panel"):
		var base_style = get_theme_stylebox("panel")
		if base_style != null:
			add_theme_stylebox_override("panel", base_style.duplicate())
	
	var style = get_theme_stylebox("panel")
	if style is StyleBoxFlat:
		style.bg_color = selected_bg_color if selected else default_bg_color
	elif style is StyleBoxTexture:
		style.modulate_color = selected_bg_color if selected else Color.WHITE
