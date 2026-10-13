class_name WildfireOverloadBurst
extends Node2D
## Short-lived visual cue for Wildfire Overload's level-three detonation.

const DURATION: float = 0.38
const MAX_RADIUS: float = 55.0
const SPARK_COUNT: int = 8
const FIRE_COLOR := Color(1.0, 0.28, 0.04)
const CORE_COLOR := Color(1.0, 0.82, 0.2)

var _elapsed: float = 0.0


func _ready() -> void:
	add_to_group("wildfire_overload_bursts")
	z_index = 20
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= DURATION:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var progress := clampf(_elapsed / DURATION, 0.0, 1.0)
	var expansion := 1.0 - pow(1.0 - progress, 2.0)
	var fade := 1.0 - progress
	var radius := lerpf(8.0, MAX_RADIUS, expansion)

	var fill := FIRE_COLOR
	fill.a = 0.28 * fade
	draw_circle(Vector2.ZERO, radius, fill)

	var outer_ring := CORE_COLOR
	outer_ring.a = fade
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, outer_ring, 2.5)

	var inner_ring := FIRE_COLOR
	inner_ring.a = fade * 0.8
	draw_arc(Vector2.ZERO, radius * 0.62, 0.0, TAU, 32, inner_ring, 1.5)

	for i in SPARK_COUNT:
		var angle := TAU * float(i) / SPARK_COUNT
		var direction := Vector2.RIGHT.rotated(angle)
		var spark_start := direction * radius * 0.58
		var spark_end := direction * (radius + 5.0 * fade)
		var spark_color := CORE_COLOR
		spark_color.a = fade
		draw_line(spark_start, spark_end, spark_color, 2.0)

	var core := CORE_COLOR
	core.a = fade * 0.85
	draw_circle(Vector2.ZERO, lerpf(5.0, 1.0, progress), core)
