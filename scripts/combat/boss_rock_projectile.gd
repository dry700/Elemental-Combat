extends BaseProjectile

var damage: float = 6.0
var knockback_strength: float = 90.0


func _init() -> void:
	radius = 5.0
	lifetime = 2.0


func _resolve_hit(hurtbox: Hurtbox) -> void:
	var safe_attacker := attacker if is_instance_valid(attacker) else null
	var hit_data := HitData.new(damage, direction.normalized() * knockback_strength, safe_attacker)
	hit_data.weapon_weight = &"heavy"
	hit_data.element = element
	hit_data.charge = charge
	hurtbox.take_hit(hit_data)
	queue_free()


func _draw() -> void:
	var color: Color = ElementIndicator.ELEMENT_COLOR.get(element, Color(0.65, 0.55, 0.45))
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(-5.0, -3.0),
			Vector2(1.0, -5.0),
			Vector2(5.0, -1.0),
			Vector2(3.0, 4.0),
			Vector2(-3.0, 4.0),
		]),
		color
	)
