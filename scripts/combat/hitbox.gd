class_name Hitbox
extends Area2D
## Deals damage to any Hurtbox it overlaps while active. Attach to a weapon
## swing and toggle with enable()/disable() for the duration of the active
## animation frames (see WeaponStats.active_window).

@export var damage: float = 10.0
@export var knockback_strength: float = 300.0
@export var weapon_weight: StringName = &"none"
@export var element: StringName = Elements.NONE
@export var charge: int = 0

var _already_hit: Array[Hurtbox] = []


func _ready() -> void:
	monitoring = false
	area_entered.connect(_on_area_entered)


func enable() -> void:
	_already_hit.clear()
	monitoring = true


func disable() -> void:
	monitoring = false


func _on_area_entered(area: Area2D) -> void:
	if not (area is Hurtbox):
		return
	var hurtbox := area as Hurtbox
	if hurtbox.owner == owner:
		# Never hit your own wielder. The player's melee hitbox (a radius-10
		# circle at local offset 14 on a 12-wide body — see Visuals/Hitbox
		# in player.tscn) geometrically overlaps the player's own Hurtbox
		# by a couple of pixels at both facings, which without this guard
		# lets every attack briefly apply its own element/knockback/
		# reaction to the attacker as a side effect of their own swing.
		return
	if hurtbox in _already_hit:
		return  # One hit per active window, even if overlap persists across frames.
	_already_hit.append(hurtbox)

	var direction := (hurtbox.global_position - global_position).normalized()
	if direction.is_zero_approx():
		direction = Vector2.RIGHT

	var hit_data := HitData.new(damage, direction * knockback_strength, owner)
	hit_data.weapon_weight = weapon_weight
	hit_data.element = element
	hit_data.charge = charge
	hurtbox.take_hit(hit_data)
