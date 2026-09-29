class_name ArrowProjectile
extends BaseProjectile
## Bow arrow. Unlike SkillProjectile (zero-damage, calls handle_hit directly)
## this builds a full HitData and goes through Hurtbox.take_hit(), so damage,
## knockback, hit-stop, screen shake, ICD and reactions behave exactly like a
## melee Hitbox hit. Single-target: consumed on first hit.

const SHAFT_LENGTH: float = 8.0
const HEAD_SIZE: float = 2.5

var damage: float = 10.0
var knockback_strength: float = 80.0
var weapon_weight: StringName = &"medium"

var _spent: bool = false


func _init() -> void:
	radius = 2.0
	speed = 240.0
	lifetime = 0.6


func _resolve_hit(hurtbox: Hurtbox) -> void:
	if _spent:
		return
	_spent = true
	var hit_data := HitData.new(damage, direction.normalized() * knockback_strength, attacker)
	hit_data.weapon_weight = weapon_weight
	hit_data.element = element
	hit_data.charge = charge
	hurtbox.take_hit(hit_data)
	queue_free()


func _draw() -> void:
	var color: Color = ElementIndicator.ELEMENT_COLOR.get(element, Color(0.9, 0.85, 0.7))
	var dir := direction.normalized()
	var perp := Vector2(-dir.y, dir.x)
	var tip := dir * SHAFT_LENGTH * 0.5
	var tail := -dir * SHAFT_LENGTH * 0.5
	draw_line(tail, tip, color, 1.2)
	draw_colored_polygon(PackedVector2Array([
		tip + dir * HEAD_SIZE,
		tip + perp * HEAD_SIZE * 0.6,
		tip - perp * HEAD_SIZE * 0.6,
	]), color)