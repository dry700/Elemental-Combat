class_name DamageNumber
extends RefCounted

static func spawn(parent: Node2D, amount: float, start_pos: Vector2, is_perfect: bool = false) -> void:
	if amount <= 0 or parent == null or not is_instance_valid(parent):
		return
	var lbl := Label.new()
	if is_perfect:
		lbl.text = "%d\nPerfect!" % int(amount)
		lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.25))
		lbl.add_theme_font_size_override("font_size", 14)
	else:
		lbl.text = str(int(amount))
		lbl.add_theme_color_override("font_color", Color.WHITE)
		lbl.add_theme_font_size_override("font_size", 12)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.grow_horizontal = Control.GROW_DIRECTION_BOTH
	
	var offset_x = randf_range(-12, 12)
	var offset_y = randf_range(-20, -10)
	lbl.position = start_pos + Vector2(offset_x, offset_y)
	parent.add_child(lbl)
	
	var tween := parent.create_tween()
	var rise_dist: float = 30.0 if is_perfect else 25.0
	tween.tween_property(lbl, "position:y", lbl.position.y - rise_dist, 0.85).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.parallel().tween_property(lbl, "modulate:a", 0.0, 0.85).set_ease(Tween.EASE_IN).set_delay(0.35)
	tween.tween_callback(lbl.queue_free)
