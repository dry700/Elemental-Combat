class_name RunePickup
extends Area2D

## A rolled rune lying in the world. Hud owns all chooser input; this node
## only tracks proximity and renders the target-specific pickup shape.

const HALF_SIZE: float = 5.0
const RADIUS: float = 5.0
const WEAPON_COLOR := Color(0.85, 0.75, 0.3)
const SKILL_COLOR := Color(0.45, 0.8, 0.75)
const PROMPT_COLOR := Color(1.0, 1.0, 1.0, 0.9)

var rune: RuneData
var _player_in_range: Player = null
var _indicator: ElementIndicator

static func roll_spirit_element(own_element: StringName) -> StringName:
	if own_element == Elements.NONE:
		return Elements.ALL[randi() % Elements.ALL.size()]
	if randf() < 0.6:
		return own_element
	var others := Elements.ALL.duplicate()
	others.erase(own_element)
	return others[randi() % others.size()]

func set_rune(value: RuneData) -> void:
	rune = value
	if _indicator != null:
		_indicator.set_element(rune.element if rune != null else Elements.NONE)
	queue_redraw()

func _ready() -> void:
	add_to_group("rune_pickups")
	monitoring = true
	collision_layer = 0
	collision_mask = 1
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = RADIUS
	shape.shape = circle
	add_child(shape)
	_indicator = ElementIndicator.new()
	_indicator.scale = Vector2.ONE * 2.0
	add_child(_indicator)
	if rune != null:
		_indicator.set_element(rune.element)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	queue_redraw()

func _on_body_entered(body: Node2D) -> void:
	if rune == null:
		return
	var player := body as Player
	if player == null:
		return
	_player_in_range = player
	queue_redraw()

func _on_body_exited(body: Node2D) -> void:
	if body == _player_in_range:
		_player_in_range = null
		queue_redraw()

func _draw() -> void:
	var target := RuneData.Target.WEAPON if rune == null else rune.target
	var color := WEAPON_COLOR if target == RuneData.Target.WEAPON else SKILL_COLOR
	if target == RuneData.Target.WEAPON:
		var s := HALF_SIZE
		draw_rect(Rect2(Vector2(-s, -s), Vector2(s, s) * 2.0), color)
		draw_rect(Rect2(Vector2(-s, -s), Vector2(s, s) * 2.0), Color.BLACK, false, 1.5)
	else:
		draw_circle(Vector2.ZERO, RADIUS, color)
		draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 24, Color.BLACK, 1.5)
	if _player_in_range != null:
		draw_string(ThemeDB.fallback_font, Vector2(-30, -RADIUS - 6), "Press F", HORIZONTAL_ALIGNMENT_CENTER, 60, 12, PROMPT_COLOR)
