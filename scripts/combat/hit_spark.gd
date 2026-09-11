class_name HitSpark
extends Node2D
## Generic weapon-impact VFX — spawned once per landed hit (Hitbox),
## regardless of element. The elemental-specific bursts (Zones,
## SteamCloud) already exist separately for reaction effects, so this
## stays neutral rather than tinting per element. Same self-contained
## convention as every other one-shot world effect here (Projectile,
## ReactionZone, SteamCloud): plain Node2D, queue_free()s itself once
## its short animation finishes.

const LIFETIME: float = 0.15
const TEXTURE_PATH: String = "res://assets/sprites/vfx/hit_spark.png"

var element: StringName = Elements.NONE


func _ready() -> void:
	var sprite := Sprite2D.new()
	var texture := load(TEXTURE_PATH) as Texture2D
	if texture != null:
		sprite.texture = texture
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)
	ElementIndicator.apply_element_tint(sprite, element)

	sprite.scale = Vector2(0.6, 0.6)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "scale", Vector2(1.3, 1.3), LIFETIME)
	tween.tween_property(sprite, "modulate:a", 0.0, LIFETIME)
	tween.chain().tween_callback(queue_free)
