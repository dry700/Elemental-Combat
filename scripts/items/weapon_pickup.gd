class_name WeaponPickup
extends Area2D
## A weapon lying in the world (A.4's loadout, made physically pickable).
## Standing near it and pressing F swaps whichever of the player's two
## weapon slots this pickup targets — a deliberate manual prompt rather
## than an automatic walk-over swap, so a player mid-fight doesn't
## accidentally re-equip by brushing past a pickup at the wrong moment.
## The weapon PREVIOUSLY in that slot is left behind as a new pickup at
## this same spot — a swap is always reversible, never a one-way trade
## the player didn't mean to make.
##
## body_entered/body_exited here ONLY track proximity (_player_in_range)
## — they never mutate monitoring or free anything, so this sidesteps
## the "Can't change this state while flushing queries" class of bug
## RoomExit/RunManager and the earlier walk-over version of this same
## script both hit. The actual pickup (_do_pickup: queue_free + spawning
## a replacement pickup) now runs from _process() on an F press, a
## normal frame, not from inside a physics-engine callback — nothing to
## defer here at all.
##
## Built entirely in code (_ready()/_draw()), same convention as
## Projectile/ReactionZone/SteamCloud/ElementIndicator already use in
## this project, rather than depending on a hand-authored .tscn.

enum Slot { PRIMARY, SECONDARY }

@export var weapon: WeaponStats
@export var slot: Slot = Slot.PRIMARY

const HALF_SIZE: float = 10.0
const PRIMARY_COLOR := Color(0.85, 0.75, 0.3)
const SECONDARY_COLOR := Color(0.4, 0.75, 0.85)
const PROMPT_COLOR := Color(1.0, 1.0, 1.0, 0.9)

var _picked_up: bool = false
var _player_in_range: Player = null


func _ready() -> void:
	monitoring = true
	collision_layer = 0
	collision_mask = 1  ## Player's own body layer — CharacterBody2D, not an Area2D, so this side must do the watching.
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(HALF_SIZE, HALF_SIZE) * 2.0
	shape.shape = rect
	add_child(shape)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	queue_redraw()


func _process(_delta: float) -> void:
	if _picked_up or _player_in_range == null:
		return
	if Input.is_action_just_pressed("pickup"):
		_do_pickup(_player_in_range)


func _on_body_entered(body: Node2D) -> void:
	if _picked_up or weapon == null:
		return
	var player := body as Player
	if player == null:
		return
	_player_in_range = player
	queue_redraw()  ## Draws the "Press F" prompt.


func _on_body_exited(body: Node2D) -> void:
	if body == _player_in_range:
		_player_in_range = null
		queue_redraw()  ## Hides the prompt again.


func _do_pickup(player: Player) -> void:
	_picked_up = true
	var previous := player.swap_weapon(slot == Slot.PRIMARY, weapon)
	if previous != null:
		_spawn_dropped(previous)
	queue_free()


func _spawn_dropped(old_weapon: WeaponStats) -> void:
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return
	var dropped := WeaponPickup.new()
	dropped.weapon = old_weapon
	dropped.slot = slot
	dropped.global_position = global_position
	scene_root.add_child(dropped)


func _draw() -> void:
	var color := PRIMARY_COLOR if slot == Slot.PRIMARY else SECONDARY_COLOR
	var s := HALF_SIZE
	draw_rect(Rect2(Vector2(-s, -s), Vector2(s, s) * 2.0), color)
	draw_rect(Rect2(Vector2(-s, -s), Vector2(s, s) * 2.0), Color.BLACK, false, 1.5)
	var label := "1" if slot == Slot.PRIMARY else "2"
	draw_string(ThemeDB.fallback_font, Vector2(-4, 5), label, HORIZONTAL_ALIGNMENT_CENTER, -1, 14, Color.BLACK)
	if _player_in_range != null:
		draw_string(ThemeDB.fallback_font, Vector2(-30, -s - 6), "Press F", HORIZONTAL_ALIGNMENT_CENTER, 60, 12, PROMPT_COLOR)
