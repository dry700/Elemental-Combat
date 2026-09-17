class_name DotIndicator
extends Node2D
## Small secondary icon showing WHICH element is behind an active DoT.
## Uses a DEDICATED droplet shape (dot_tick.png) rather than reusing
## ElementIndicator's own status glyphs — those five shapes (diamond,
## spiral, wave, zigzag, dot-grid) already mean "this status is active";
## reusing one here would show the same icon twice whenever a DoT's
## source happens to match the current status (the common case), with
## no visual distinction between "you HAVE this status" and "you're
## TAKING damage from it." The droplet is tinted per-element via the
## same shared shader ElementIndicator/SlashVFX/HitParticles all use, so
## adding this didn't require inventing a second tinting mechanism —
## just a second base shape for that one mechanism to tint.

const TEXTURE_PATH: String = "res://assets/sprites/vfx/dot_tick.png"
const HALF_SCALE: float = 0.75  ## Smaller than the main status glyph — a secondary read, not competing for primary attention.

var _element: StringName = Elements.NONE
var _sprite: Sprite2D = null


func _ready() -> void:
	visible = false
	scale = Vector2(HALF_SCALE, HALF_SCALE)


func set_source_element(element: StringName) -> void:
	if element == _element:
		return
	_element = element
	visible = element != Elements.NONE
	_update_sprite()


func _update_sprite() -> void:
	if _element == Elements.NONE:
		if _sprite != null:
			_sprite.visible = false
		return
	if _sprite == null:
		if not ResourceLoader.exists(TEXTURE_PATH):
			return
		_sprite = Sprite2D.new()
		_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_sprite.texture = load(TEXTURE_PATH)
		add_child(_sprite)
	_sprite.visible = true
	ElementIndicator.apply_element_tint(_sprite, _element)
