class_name OneWayPlatform
extends StaticBody2D

@export var width_tiles: int = 3:
	set(value):
		width_tiles = value
		_update_shape()
@export var timed_collapse_enabled: bool = false
@export var collapse_after_seconds: float = 3.0
@export var warning_duration: float = 1.2
@export var recovery_duration: float = 2.0

enum TimedState { IDLE, WARNING, COLLAPSED }

var _timed_state: TimedState = TimedState.IDLE
var _collapse_timer: float = 0.0
var _recovery_timer: float = 0.0
var _flash_timer: float = 0.0
var _platform_collision_shape: CollisionShape2D
var _platform_visual: Polygon2D
var _timed_trigger: Area2D
var _base_visual_modulate: Color
var _base_collision_layer: int = 4


func _ready() -> void:
	_update_shape()
	_platform_collision_shape = get_node_or_null("CollisionShape2D") as CollisionShape2D
	_platform_visual = get_node_or_null("Visual") as Polygon2D
	_base_collision_layer = collision_layer
	if _platform_visual != null:
		_base_visual_modulate = _platform_visual.modulate
	if timed_collapse_enabled:
		_setup_timed_trigger()
	set_process(timed_collapse_enabled)


func _process(delta: float) -> void:
	match _timed_state:
		TimedState.WARNING:
			_collapse_timer -= delta
			_flash_timer -= delta
			if _platform_visual != null and _flash_timer <= 0.0:
				_flash_timer = 0.12
				var warning_color := Color(1.0, 0.3, 0.18, 1.0)
				_platform_visual.modulate = warning_color if _platform_visual.modulate == _base_visual_modulate else _base_visual_modulate
			if _collapse_timer <= 0.0:
				_collapse_platform()
		TimedState.COLLAPSED:
			_recovery_timer -= delta
			if _recovery_timer <= 0.0:
				_restore_platform()


func _setup_timed_trigger() -> void:
	_timed_trigger = Area2D.new()
	_timed_trigger.name = "TimedPlatformTrigger"
	_timed_trigger.collision_layer = 0
	_timed_trigger.collision_mask = 1
	_timed_trigger.monitoring = true
	_timed_trigger.monitorable = false
	var trigger_shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(width_tiles * 16.0, 16.0)
	trigger_shape.shape = rectangle
	trigger_shape.position = Vector2(width_tiles * 8.0, -4.0)
	_timed_trigger.add_child(trigger_shape)
	add_child(_timed_trigger)
	_timed_trigger.body_entered.connect(_on_timed_trigger_body_entered)


func _on_timed_trigger_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player") or _timed_state != TimedState.IDLE:
		return
	if body.global_position.y > global_position.y:
		return
	var total_duration := maxf(collapse_after_seconds, 0.1)
	var warning_time := clampf(warning_duration, 0.0, total_duration)
	_collapse_timer = total_duration
	_timed_state = TimedState.WARNING
	_flash_timer = maxf(total_duration - warning_time, 0.0)
	if _platform_visual != null and warning_time >= total_duration:
		_platform_visual.modulate = Color(1.0, 0.65, 0.25, 1.0)


func _collapse_platform() -> void:
	_timed_state = TimedState.COLLAPSED
	_recovery_timer = maxf(recovery_duration, 0.1)
	if _platform_collision_shape != null:
		_platform_collision_shape.set_deferred("disabled", true)
	set_deferred("collision_layer", 0)
	if _platform_visual != null:
		_platform_visual.modulate = Color(1.0, 0.3, 0.18, 0.35)


func _restore_platform() -> void:
	_timed_state = TimedState.IDLE
	if _platform_collision_shape != null:
		_platform_collision_shape.set_deferred("disabled", false)
	set_deferred("collision_layer", _base_collision_layer)
	if _platform_visual != null:
		_platform_visual.modulate = _base_visual_modulate


func _update_shape() -> void:
	var col := get_node_or_null("CollisionShape2D") as CollisionShape2D
	var vis := get_node_or_null("Visual") as Polygon2D
	if col == null or vis == null:
		return
	var w := width_tiles * 16.0
	var rect := col.shape as RectangleShape2D
	if rect != null:
		# Important: Duplicate the shape so modifying one platform's size
		# doesn't change the collision size of every other platform in the level!
		rect = rect.duplicate()
		col.shape = rect
		rect.size = Vector2(w, 8.0)
	col.position = Vector2(w / 2.0, 4.0)
	vis.polygon = PackedVector2Array([Vector2(0,0), Vector2(w,0), Vector2(w,8), Vector2(0,8)])
	if _timed_trigger != null:
		var trigger_shape := _timed_trigger.get_child(0) as CollisionShape2D
		var trigger_rectangle := trigger_shape.shape as RectangleShape2D
		trigger_rectangle.size = Vector2(w, 16.0)
		trigger_shape.position = Vector2(w / 2.0, -4.0)
