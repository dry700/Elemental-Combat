class_name SlashVFX
extends Node2D
## Weapon swing-arc VFX — spawned once per swing the instant its hitbox
## becomes active, regardless of whether it actually connects (that's
## HitSpark's job, on-hit only). Deliberately parented under Hitbox
## itself (see player.gd's _spawn_slash_vfx) rather than the scene root
## like HitSpark: this SHOULD inherit Visuals' facing-mirror
## (scale.x flip) so the sweep automatically points the right way, and
## _start_attack() already resets Visuals.rotation to 0 before any swing
## begins, so it always starts from a known-upright frame rather than
## picking up a leftover run-lean angle.

const LIFETIME: float = 0.18
const TEXTURE_PATH: String = "res://assets/sprites/vfx/slash.png"


## Which element to tint toward — Elements.NONE keeps the sprite's own
## neutral white/orange palette untouched (a weapon with no element,
## e.g. the debug/fallback WeaponStats.new()).
var element: StringName = Elements.NONE


func _ready() -> void:
	var sprite := Sprite2D.new()
	var texture := load(TEXTURE_PATH) as Texture2D
	if texture != null:
		sprite.texture = texture
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)
	ElementIndicator.apply_element_tint(sprite, element)

	sprite.modulate.a = 0.9
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "scale", Vector2(1.15, 1.15), LIFETIME)
	tween.tween_property(sprite, "modulate:a", 0.0, LIFETIME)
	tween.chain().tween_callback(queue_free)
