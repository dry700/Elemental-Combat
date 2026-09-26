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
		_indicator.set_status(rune.element if rune != null else Elements.NONE)
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
		_indicator.set_status(rune.element)
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

func _default_target_is_primary(player: Player) -> bool:
	if rune == null or rune.target != RuneData.Target.WEAPON:
		return true
	if not player.can_apply_rune(rune, true):
		return false
	return true

func _do_pickup(player: Player, is_primary: bool) -> void:
	if rune == null or not player.can_apply_rune(rune, is_primary):
		return
	var previous: RuneData = player.weapon_rune if is_primary else player.secondary_weapon_rune
	player.apply_rune(rune, is_primary)
	if previous != null:
		_spawn_dropped(previous, player.global_position)
	queue_free()

func _spawn_dropped(old_rune: RuneData, pos: Vector2) -> void:
	var scene_root := get_parent()
	if scene_root == null:
		return
	var dropped := RunePickup.new()
	dropped.set_rune(old_rune)
	dropped.global_position = pos
	scene_root.add_child(dropped)

func _can_direct_equip(player: Player) -> bool:
	if rune == null or rune.target != RuneData.Target.WEAPON:
		return false
	if player.weapon != null and player.weapon_rune == null:
		return true
	if player.secondary_weapon != null and player.secondary_weapon_rune == null:
		return true
	return false

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
		draw_string(ThemeDB.fallback_font, Vector2(-30, -RADIUS - 6), "F Pick up", HORIZONTAL_ALIGNMENT_CENTER, 60, 12, PROMPT_COLOR)
