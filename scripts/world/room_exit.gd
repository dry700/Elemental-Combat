class_name RoomExit
extends Area2D
## The room transition trigger. The player must stand in range and press
## the HUD's pickup action (F). Locked until RoomController clears the room.
## A child Polygon2D named "Visual" swaps colour for its lock state — the
## same placeholder-art convention as
## everything else here, swapped for real sprites later per A.1.

signal player_entered

enum ExitKind { NEXT, STOP, DEEPER }

@export var locked: bool = true:
	set(value):
		locked = value
		if _visual != null:
			_visual.color = LOCKED_COLOR if locked else UNLOCKED_COLOR
		queue_redraw()

@export var label: String = "Next"
@export var exit_kind: ExitKind = ExitKind.NEXT

const LOCKED_COLOR: Color = Color(0.55, 0.2, 0.2, 1)
const UNLOCKED_COLOR: Color = Color(0.25, 0.75, 0.35, 1)

@onready var _visual: Polygon2D = get_node_or_null("Visual") as Polygon2D
var _player_in_range: Player = null


func _ready() -> void:
	add_to_group("room_exits")
	monitoring = true  ## Only one Area2D here — unlike Hitbox/Hurtbox's split, this must detect the player itself.
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if _visual != null:
		_visual.color = LOCKED_COLOR if locked else UNLOCKED_COLOR


func _on_body_entered(body: Node2D) -> void:
	var player := body as Player
	if player == null:
		return
	_player_in_range = player
	queue_redraw()

func _on_body_exited(body: Node2D) -> void:
	if body == _player_in_range:
		_player_in_range = null
		queue_redraw()

func is_prompt_visible() -> bool:
	return not locked and _player_in_range != null and is_instance_valid(_player_in_range)

func request_enter() -> bool:
	if not is_prompt_visible():
		return false
	player_entered.emit()
	return true

func _draw() -> void:
	if is_prompt_visible():
		draw_string(ThemeDB.fallback_font, Vector2(-42.0, -22.0), "F " + label, HORIZONTAL_ALIGNMENT_CENTER, 84.0, 12, Color.WHITE)
