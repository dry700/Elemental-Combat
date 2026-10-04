class_name UpgradeCard
extends PanelContainer

@onready var _title_label: Label = $MarginContainer/VBox/Title
@onready var _desc_label: Label = $MarginContainer/VBox/Description
@onready var _icon_tex: TextureRect = $MarginContainer/VBox/IconBackground/Icon

var default_bg_color = Color(0.12, 0.14, 0.18)
var selected_bg_color = Color(0.12, 0.22, 0.3)
var default_border = Color(0.34, 0.39, 0.46)
var selected_border = Color(0.45, 0.82, 1.0)

func set_upgrade(title: String, desc: String, icon: Texture2D = null) -> void:
	_title_label.text = title
	_desc_label.text = desc
	if icon != null:
		_icon_tex.texture = icon
	else:
		_icon_tex.texture = null

func set_selected(selected: bool) -> void:
	if not has_theme_stylebox_override("panel"):
		var base_style = get_theme_stylebox("panel")
		if base_style != null:
			add_theme_stylebox_override("panel", base_style.duplicate())
		else:
			var new_style = StyleBoxFlat.new()
			new_style.set_border_width_all(2)
			add_theme_stylebox_override("panel", new_style)
	
	var style = get_theme_stylebox("panel")
	if style is StyleBoxFlat:
		style.bg_color = selected_bg_color if selected else default_bg_color
		style.border_color = selected_border if selected else default_border
	elif style is StyleBoxTexture:
		style.modulate_color = selected_bg_color if selected else Color.WHITE
