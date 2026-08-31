class_name RoomExit
extends Area2D
## The trigger a player walks into to advance to the next room. Locked
## until RoomController confirms the room is cleared. Colour swap on a
## child Polygon2D named "Visual" — same placeholder-art convention as
## everything else here, swapped for real sprites later per A.1.

signal player_entered

@export var locked: bool = true:
	set(value):
		var unlocking := locked and not value
		locked = value
		if _visual != null:
			_visual.color = LOCKED_COLOR if locked else UNLOCKED_COLOR
		if unlocking:
			_check_already_inside()

const LOCKED_COLOR: Color = Color(0.55, 0.2, 0.2, 1)
const UNLOCKED_COLOR: Color = Color(0.25, 0.75, 0.35, 1)

@onready var _visual: Polygon2D = $Visual


func _ready() -> void:
	monitoring = true  ## Only one Area2D here — unlike Hitbox/Hurtbox's split, this must detect the player itself.
	body_entered.connect(_on_body_entered)
	_visual.color = LOCKED_COLOR if locked else UNLOCKED_COLOR


func _on_body_entered(body: Node2D) -> void:
	if locked or not body.is_in_group("player"):
		return
	player_entered.emit()
	
## Covers the case where the player is already standing inside this
## Area2D's shape at the moment it unlocks (e.g. waited at the door while
## killing the last enemy) — body_entered only fires on a fresh ENTER
## transition, so without this, a player who never actually left the
## collision shape would never get a fresh entered event to advance on.
func _check_already_inside() -> void:
	for body in get_overlapping_bodies():
		if body.is_in_group("player"):
			player_entered.emit()
			return
