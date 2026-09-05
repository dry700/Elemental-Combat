class_name WeaponPickup
extends Area2D
## A weapon lying in the world (A.4's loadout, made physically pickable).
## All pickup INPUT now lives on the Hud autoload (see hud.gd's pickup
## selection overlay) — this script only tracks proximity
## (_player_in_range, via body_entered/body_exited) and draws the
## in-world prompt/visual. Hud reads _player_in_range and calls
## _do_pickup()/_default_target_is_primary() directly once the player
## has chosen a slot through the overlay (keyboard nav, numeric
## shortcut, or a mouse click on one of its two options).
##
## The weapon PREVIOUSLY in the chosen slot is left behind as a new
## pickup at this same spot — a swap is always reversible, never a
## one-way trade the player didn't mean to make.
##
## Built entirely in code (_ready()/_draw()), same convention as
## Projectile/ReactionZone/SteamCloud/ElementIndicator already use in
## this project, rather than depending on a hand-authored .tscn.

enum Slot { PRIMARY, SECONDARY }

@export var weapon: WeaponStats
## Which slot this pickup is visually marked as ("1"/"2" on its sprite),
## and which slot the overlay highlights BY DEFAULT when it opens —
## overridden entirely once the player actually navigates or clicks a
## different option.
@export var slot: Slot = Slot.PRIMARY

const HALF_SIZE: float = 5.0
const PRIMARY_COLOR := Color(0.85, 0.75, 0.3)
const SECONDARY_COLOR := Color(0.4, 0.75, 0.85)
const PROMPT_COLOR := Color(1.0, 1.0, 1.0, 0.9)

var _picked_up: bool = false
var _player_in_range: Player = null


func _ready() -> void:
	add_to_group("weapon_pickups")
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


## The overlay's initial highlight when it opens: prefer whichever slot
## is currently EMPTY (so the common case needs no navigation at all —
## just an immediate confirm), falling back to this pickup's own `slot`
## once both are already full.
func _default_target_is_primary(player: Player) -> bool:
	if player.weapon == null:
		return true
	if player.secondary_weapon == null:
		return false
	return slot == Slot.PRIMARY


## Called by Hud once the player has chosen a slot (keyboard confirm,
## numeric shortcut, or a click on one of the overlay's two options) —
## never called directly from this script's own input handling anymore.
func _do_pickup(player: Player, is_primary: bool) -> void:
	_picked_up = true
	var previous := player.swap_weapon(is_primary, weapon)
	if previous != null:
		_spawn_dropped(previous, is_primary)
	queue_free()


## from_slot_primary marks the dropped replacement pickup with whichever
## slot it just vacated, so its own "1"/"2" visual and its own default
## stay accurate to where it actually came from, not to this pickup's
## original `slot`.
func _spawn_dropped(old_weapon: WeaponStats, from_slot_primary: bool) -> void:
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return
	var dropped := WeaponPickup.new()
	dropped.weapon = old_weapon
	dropped.slot = Slot.PRIMARY if from_slot_primary else Slot.SECONDARY
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
