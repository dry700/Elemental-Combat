extends BaseProjectile

var damage: float = 8.0
var knockback_strength: float = 70.0
var spark_spacing: float = 20.0
var _distance_since_spark: float = 0.0
var _hit_target_ids: Dictionary[int, bool] = {}


func _init() -> void:
	radius = 6.0
	lifetime = 2.5


func _process(delta: float) -> void:
	var previous_position := global_position
	super._process(delta)
	if is_queued_for_deletion():
		return

	var movement := global_position - previous_position
	var distance_travelled := movement.length()
	if distance_travelled <= 0.0:
		return

	var movement_direction := movement / distance_travelled
	var next_spark_distance := maxf(spark_spacing, 1.0) - _distance_since_spark
	while distance_travelled >= next_spark_distance:
		previous_position += movement_direction * next_spark_distance
		_spawn_ground_spark(previous_position)
		distance_travelled -= next_spark_distance
		_distance_since_spark = 0.0
		next_spark_distance = maxf(spark_spacing, 1.0)
	_distance_since_spark += distance_travelled


func _resolve_hit(hurtbox: Hurtbox) -> void:
	var target_id := hurtbox.owner.get_instance_id() if is_instance_valid(hurtbox.owner) else hurtbox.get_instance_id()
	if _hit_target_ids.has(target_id):
		return
	_hit_target_ids[target_id] = true

	var safe_attacker := attacker if is_instance_valid(attacker) else null
	var hit_data := HitData.new(damage, direction.normalized() * knockback_strength, safe_attacker)
	hit_data.weapon_weight = &"heavy"
	hit_data.element = element
	hit_data.charge = charge
	hurtbox.take_hit(hit_data)


func _spawn_ground_spark(at_position: Vector2) -> void:
	var particles := HitParticles.new()
	particles.global_position = at_position + Vector2(0.0, 8.0)
	particles.away_direction = Vector2.UP
	particles.element = element
	particles.burst_intensity = 1.4
	particles.add_to_group("boss_shockwave_sparks")

	var scene_root := get_tree().current_scene
	if scene_root == null:
		scene_root = get_parent()
	if scene_root == null:
		push_error("Boss shockwave spark could not find a scene parent")
		particles.free()
		return
	scene_root.add_child(particles)


func _draw() -> void:
	var color: Color = ElementIndicator.ELEMENT_COLOR.get(element, Color(0.75, 0.65, 0.45))
	var sign_x := signf(direction.x)
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(-sign_x * 3.0, -9.0),
			Vector2(sign_x * 13.0, -4.0),
			Vector2(sign_x * 16.0, 0.0),
			Vector2(sign_x * 13.0, 4.0),
			Vector2(-sign_x * 3.0, 9.0),
		]),
		color
	)
