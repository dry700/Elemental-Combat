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

## Per-swing facts configured by the wielder
var combo_step: int = 1
var is_finisher: bool = false
var wielder_is_airborne: bool = false
var time_since_dodge: float = 999.0
var is_plunge: bool = false
var plunge_intensity: float = 0.0
var attack_origin: Vector2 = Vector2.ZERO
var weapon_reach: float = 0.0

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
	if hurtbox.invulnerable:
		return
	if owner != null and hurtbox.owner == owner:
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
	if perfect_condition == WeaponStats.PerfectCondition.NONE:
		return false

	if owner != null and owner.has_method("_resolve_perfect_for_hit"):
		if owner._resolve_perfect_for_hit(self, hurtbox):
			return true

	var target_node: Node = null
	if hurtbox != null:
		target_node = hurtbox.owner if hurtbox.owner != null else hurtbox.get_parent()
	var elemental: ElementalCombatant = null
	if target_node != null and "elemental" in target_node:
		elemental = target_node.elemental as ElementalCombatant

	match perfect_condition:
		WeaponStats.PerfectCondition.TARGET_SLOWED:
			return elemental != null and elemental.is_slowed()
		WeaponStats.PerfectCondition.TARGET_DISABLED:
			return elemental != null and elemental.is_disabled()
		WeaponStats.PerfectCondition.FINISHER:
			return is_finisher
		WeaponStats.PerfectCondition.PLUNGE:
			return is_plunge and plunge_intensity >= 0.6
		WeaponStats.PerfectCondition.DODGE:
			return time_since_dodge <= 0.5
		WeaponStats.PerfectCondition.AIRBORNE:
			return wielder_is_airborne
		WeaponStats.PerfectCondition.LONG_RANGE:
			var origin: Vector2 = attack_origin if attack_origin != Vector2.ZERO else (owner.global_position if owner != null else global_position)
			return origin.distance_to(hurtbox.global_position) >= 110.0
		WeaponStats.PerfectCondition.CLOSE_RANGE:
			var origin: Vector2 = attack_origin if attack_origin != Vector2.ZERO else (owner.global_position if owner != null else global_position)
			return origin.distance_to(hurtbox.global_position) <= 40.0
		WeaponStats.PerfectCondition.TIP:
			var origin: Vector2 = attack_origin if attack_origin != Vector2.ZERO else (owner.global_position if owner != null else global_position)
			var dist: float = origin.distance_to(hurtbox.global_position)
			var ref_reach: float = weapon_reach if weapon_reach > 0.0 else 16.0
			return dist >= ref_reach * 0.7
		WeaponStats.PerfectCondition.LOW_HEALTH:
			if target_node != null and target_node.has_method("get_health_ratio"):
				return target_node.get_health_ratio() <= 0.30
			return false
		_:
			return false

func _spawn_hit_particles(at_position: Vector2, away_direction: Vector2) -> void:
	var tree := get_tree()
	if tree == null:
		return
	var scene_root := tree.current_scene
	if scene_root == null:
		return
	var particles := HitParticles.new()
	particles.global_position = at_position
	particles.away_direction = away_direction
	particles.element = element
	scene_root.add_child(particles)


func _spawn_hit_spark(at_position: Vector2) -> void:
	var tree := get_tree()
	if tree == null:
		return
	var scene_root := tree.current_scene
	if scene_root == null:
		return
	var spark := HitSpark.new()
	spark.global_position = at_position
	spark.element = element
	scene_root.add_child(spark)
