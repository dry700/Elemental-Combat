class_name ThrustVFX
extends Node2D
## Spear/thrust-style swing-arc VFX — the THRUST counterpart to SlashVFX's
## SWING. Instead of a static arc flashed once, this stretches a directional
## streak forward along local +x, matching the weapon's own jab-and-retract
## motion (see player.gd's THRUST branch in _process_attack) rather than a
## curved sweep, since a spear doesn't rotate through an arc the way a
## bladed weapon does. Same spawn/lifetime contract as SlashVFX: parented
## under Hitbox so it inherits facing-mirror, fires once per swing
## regardless of whether it connects.

const LIFETIME: float = 0.16
const TEXTURE_PATH: String = "res://assets/sprites/vfx/thrust_streak.png"

var element: StringName = Elements.NONE


func _ready() -> void:
	var sprite := Sprite2D.new()
	var texture := load(TEXTURE_PATH) as Texture2D
	if texture != null:
		sprite.texture = texture
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.centered = false
		sprite.offset = Vector2(0, -texture.get_height() / 2.0)
	add_child(sprite)
	ElementIndicator.apply_element_tint(sprite, element)

	sprite.modulate.a = 0.85
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "scale", Vector2(1.6, 1.0), LIFETIME)
	tween.tween_property(sprite, "modulate:a", 0.0, LIFETIME)
	tween.chain().tween_callback(queue_free)
