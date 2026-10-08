class_name Hitbox
extends Area2D
## Deals damage to any Hurtbox it overlaps while active. Attach to a weapon
## swing and toggle with enable()/disable() for the duration of the active
## animation frames (see WeaponStats.active_window).

@export var damage: float = 10.0
@export var knockback_strength: float = 150.0
@export var weapon_weight: StringName = &"none"
@export var element: StringName = Elements.NONE
@export var charge: int = 0
@export var perfect_condition: WeaponStats.PerfectCondition = WeaponStats.PerfectCondition.NONE
@export_range(1.5, 2.0) var perfect_multiplier: float = 1.5

signal hit_landed(hurtbox: Hurtbox)

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
		# Never hit your own wielder.
		return
		
	# Friendly fire prevention: enemies shouldn't hit other enemies
	if owner != null and hurtbox.owner != null:
		if owner.is_in_group("enemies") and hurtbox.owner.is_in_group("enemies"):
			return

	if hurtbox in _already_hit:
		return  # One hit per active window, even if overlap persists across frames.
	_already_hit.append(hurtbox)

	var direction := (hurtbox.global_position - global_position).normalized()
	if direction.is_zero_approx():
		direction = Vector2.RIGHT

	var perfect := _resolve_perfect_hit(hurtbox)
	var hit_data := HitData.new(damage, direction * knockback_strength, owner, perfect)
	hit_data.weapon_weight = weapon_weight
	hit_data.element = element
	hit_data.charge = charge
	if perfect:
		hit_data.damage *= perfect_multiplier
	hurtbox.take_hit(hit_data)
	hit_landed.emit(hurtbox)

	_spawn_hit_spark(hurtbox.global_position)
	_spawn_hit_particles(hurtbox.global_position, direction)


func _resolve_perfect_hit(hurtbox: Hurtbox) -> bool:
	if owner == null:
		return false
	if owner.has_method("_resolve_perfect_for_hit"):
		return owner._resolve_perfect_for_hit(self, hurtbox)
	return false

func _spawn_hit_particles(at_position: Vector2, away_direction: Vector2) -> void:
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return
	var particles := HitParticles.new()
	particles.global_position = at_position
	particles.away_direction = away_direction
	particles.element = element
	scene_root.add_child(particles)


func _spawn_hit_spark(at_position: Vector2) -> void:
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return
	var spark := HitSpark.new()
	spark.global_position = at_position
	spark.element = element
	scene_root.add_child(spark)
