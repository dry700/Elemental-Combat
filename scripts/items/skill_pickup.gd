class_name SkillPickup
extends Area2D
## A skill lying in the world (A.5's loadout, made physically pickable).
## All pickup INPUT now lives on the Hud autoload (see hud.gd's pickup
## selection overlay) — mirrors WeaponPickup exactly: this script only
## tracks proximity (_player_in_range) and draws the in-world prompt.
## Circle shape with Q/E labels rather than WeaponPickup's square with
## 1/2 — the actual cast keys ARE Q/E (input_setup.gd), so labelling by
## the real key the player will press to USE it (after equipping) is
## more useful here than a slot index, and the shape difference means
## the two pickup types read apart at a glance in the world.

enum Slot { PRIMARY, SECONDARY }

@export var skill: SkillData
@export var slot: Slot = Slot.PRIMARY

const RADIUS: float = 5.0
const PRIMARY_COLOR := Color(0.45, 0.8, 0.75)
const SECONDARY_COLOR := Color(0.75, 0.45, 0.8)
const PROMPT_COLOR := Color(1.0, 1.0, 1.0, 0.9)

var _picked_up: bool = false
var _player_in_range: Player = null


func _ready() -> void:
	add_to_group("skill_pickups")
	monitoring = true
	collision_layer = 0
	collision_mask = 1
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = RADIUS
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	queue_redraw()


func _on_body_entered(body: Node2D) -> void:
	if _picked_up or skill == null:
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
	if player.skill_1 == null:
		return true
	if player.skill_2 == null:
		return false
	return slot == Slot.PRIMARY


func _do_pickup(player: Player, is_primary: bool) -> void:
	_picked_up = true
	var previous := player.swap_skill(is_primary, skill)
	if previous != null:
		_spawn_dropped(previous, is_primary)
	queue_free()


func _spawn_dropped(old_skill: SkillData, from_slot_primary: bool) -> void:
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return
	var dropped := SkillPickup.new()
	dropped.skill = old_skill
	dropped.slot = Slot.PRIMARY if from_slot_primary else Slot.SECONDARY
	dropped.global_position = global_position
	scene_root.add_child(dropped)


func _draw() -> void:
	var color := PRIMARY_COLOR if slot == Slot.PRIMARY else SECONDARY_COLOR
	draw_circle(Vector2.ZERO, RADIUS, color)
	draw_arc(Vector2.ZERO, RADIUS, 0, TAU, 24, Color.BLACK, 1.5)
	var label := "Q" if slot == Slot.PRIMARY else "E"
	draw_string(ThemeDB.fallback_font, Vector2(-4, 5), label, HORIZONTAL_ALIGNMENT_CENTER, -1, 14, Color.BLACK)
	if _player_in_range != null:
		draw_string(ThemeDB.fallback_font, Vector2(-30, -RADIUS - 6), "Press F", HORIZONTAL_ALIGNMENT_CENTER, 60, 12, PROMPT_COLOR)
