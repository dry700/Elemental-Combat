class_name ReactionPairIndicator
extends Control

var reaction_pair: Array[StringName] = []
var reaction_rank: int = 0
var favored_element: StringName = &""


func _ready() -> void:
	custom_minimum_size = Vector2(58.0, 24.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = reaction_rank > 0 and reaction_pair.size() == 2


func set_reaction(pair: Array, rank: int, favored: StringName = &"") -> void:
	reaction_pair.clear()
	if pair.size() == 2:
		reaction_pair = [StringName(pair[0]), StringName(pair[1])]
	reaction_rank = clampi(rank, 0, 2)
	favored_element = favored
	visible = reaction_rank > 0 and reaction_pair.size() == 2
	queue_redraw()


func _draw() -> void:
	if not visible:
		return
	var center_y := size.y * 0.5
	var glyph_half_size := minf(6.0, size.y * 0.28)
	for index in 2:
		var element: StringName = reaction_pair[index]
		var center := Vector2(size.x * (0.25 if index == 0 else 0.58), center_y)
		var color: Color = ElementIndicator.ELEMENT_COLOR.get(element, Color.WHITE)
		draw_circle(center, glyph_half_size + 2.0, Color(0.0, 0.0, 0.0, 0.5))
		if element == favored_element:
			draw_arc(center, glyph_half_size + 2.5, 0.0, TAU, 24, Color(1.0, 0.88, 0.35), 1.5)
		ElementIndicator.draw_glyph(self, element, center, glyph_half_size, 1.4, color)

	var pip_center_x := size.x * 0.86
	for pip_index in 2:
		var pip_color := Color(0.8, 0.95, 1.0) if pip_index < reaction_rank else Color(0.32, 0.36, 0.42)
		draw_circle(Vector2(pip_center_x + float(pip_index - 1) * 5.0, center_y), 1.8, pip_color)
