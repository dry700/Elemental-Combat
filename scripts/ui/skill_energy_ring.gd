class_name SkillEnergyRing
extends Control
## Radial energy-fill ring drawn around a skill icon (plan-shop-and-skills
## §7.1). Code-built (no .tscn) to match Hud's own convention. The ring
## growing to a full circle is the PRIMARY cue; color is secondary (A.1).
## A non-color full cue — a thicker line plus a complete outer ring — is
## drawn at ratio >= 1.0 so "full" isn't color-only.

var ratio: float = 0.0:
	set(value):
		var clamped := clampf(value, 0.0, 1.0)
		if not is_equal_approx(clamped, ratio):
			ratio = clamped
			queue_redraw()

var ring_color: Color = Color(1.0, 0.85, 0.3, 0.95)
var full_color: Color = Color(1.0, 1.0, 0.55, 0.95)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _draw() -> void:
	if ratio <= 0.0:
		return
	var r := minf(size.x, size.y) * 0.46
	if r <= 0.0:
		return
	var center := size * 0.5
	var full := ratio >= 1.0
	var color := full_color if full else ring_color
	# Arc from the top (-PI/2) clockwise, proportional to the fill ratio.
	var width := 3.0 if full else 1.5
	draw_arc(center, r, -PI / 2.0, -PI / 2.0 + ratio * TAU, 48, color, width, true)
	if full:
		# Non-color full cue: a complete, slightly larger ring.
		draw_arc(center, r + 1.5, 0.0, TAU, 48, color, 2.0, true)
