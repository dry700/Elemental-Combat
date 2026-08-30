class_name ElementIndicator
extends Node2D
## Small pattern-glyph icon shown above a character while it carries an
## elemental status — diamond (Kim) / spiral (Mộc) / wave (Thủy) / zigzag
## (Hỏa) / dot-grid (Thổ), per A.1. Colour is a reinforcing cue layered on
## top of the shape, never the only differentiator — satisfies the same
## WCAG 1.4.1 rationale as the rest of A.1, just moved from concept art
## into actual pixels now instead of waiting for real sprites.
##
## Usage: instantiate, add_child(), then either call set_element()
## directly or (preferred) wire it straight to an ElementalStatus's
## status_applied/status_cleared signals so it never needs manual
## updates scattered through reaction-handling code:
##
##   status.status_applied.connect(func(e, _c): indicator.set_element(e))
##   status.status_cleared.connect(func(_e): indicator.set_element(Elements.NONE))

const HALF_SIZE: float = 6.0
const LINE_WIDTH: float = 1.6
const BG_RADIUS: float = 9.0

## Reinforcing accent colour per element — intentionally secondary to the
## glyph shape above, not a replacement for it (A.1).
const ELEMENT_COLOR := {
	Elements.HOA: Color(0.95, 0.35, 0.25),
	Elements.THUY: Color(0.30, 0.55, 0.95),
	Elements.MOC: Color(0.45, 0.75, 0.45),
	Elements.KIM: Color(0.82, 0.82, 0.88),
	Elements.THO: Color(0.65, 0.50, 0.30),
}

var _element: StringName = Elements.NONE


func _ready() -> void:
	visible = false


## Refresh-only, same spirit as ElementalStatus itself — redraws only on
## an actual change, not every call.
func set_element(element: StringName) -> void:
	if element == _element:
		return
	_element = element
	visible = element != Elements.NONE
	queue_redraw()


func _draw() -> void:
	if _element == Elements.NONE:
		return
	var color: Color = ELEMENT_COLOR.get(_element, Color.WHITE)
	draw_circle(Vector2.ZERO, BG_RADIUS, Color(0.0, 0.0, 0.0, 0.4))
	match _element:
		Elements.KIM:
			_draw_diamond(color)
		Elements.MOC:
			_draw_spiral(color)
		Elements.THUY:
			_draw_wave(color)
		Elements.HOA:
			_draw_zigzag(color)
		Elements.THO:
			_draw_dot_grid(color)


func _draw_diamond(color: Color) -> void:
	var s := HALF_SIZE
	var pts := PackedVector2Array([
		Vector2(0, -s), Vector2(s, 0), Vector2(0, s), Vector2(-s, 0), Vector2(0, -s),
	])
	draw_polyline(pts, color, LINE_WIDTH)


func _draw_spiral(color: Color) -> void:
	var pts := PackedVector2Array()
	var turns := 1.5
	var steps := 20
	for i in range(steps + 1):
		var t := float(i) / steps
		var angle := t * TAU * turns
		var radius := lerpf(0.5, HALF_SIZE, t)
		pts.append(Vector2(cos(angle), sin(angle)) * radius)
	draw_polyline(pts, color, LINE_WIDTH)


func _draw_wave(color: Color) -> void:
	var pts := PackedVector2Array()
	var steps := 14
	for i in range(steps + 1):
		var t := float(i) / steps
		var x := lerpf(-HALF_SIZE, HALF_SIZE, t)
		var y := sin(t * TAU) * (HALF_SIZE * 0.5)
		pts.append(Vector2(x, y))
	draw_polyline(pts, color, LINE_WIDTH)


func _draw_zigzag(color: Color) -> void:
	var s := HALF_SIZE
	var pts := PackedVector2Array([
		Vector2(-s, -s), Vector2(s * 0.15, -s * 0.1), Vector2(-s * 0.15, s * 0.1), Vector2(s, s),
	])
	draw_polyline(pts, color, LINE_WIDTH)


func _draw_dot_grid(color: Color) -> void:
	var offset := HALF_SIZE * 0.55
	for dx in [-offset, offset]:
		for dy in [-offset, offset]:
			draw_circle(Vector2(dx, dy), 1.4, color)
