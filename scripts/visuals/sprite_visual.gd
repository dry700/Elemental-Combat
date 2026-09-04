class_name SpriteVisual
extends Node2D
## Drop-in swap for the flat-colour Polygon2D placeholders used
## everywhere (PlaceholderVisual) — the "swapped for actual 16×16
## Aseprite sprites later" promise from A.1/README, wired rather than
## rewritten: every caller that used to touch visual.color directly now
## calls set_tint(), and this decides whether that tints a real Sprite2D
## or falls back to the same Polygon2D when no art exists yet.
##
## Convention over configuration: sprite_path is derived from entity_id
## ("res://assets/sprites/<entity_id>.png"), never hand-wired per scene.
## Missing file -> silently keeps the placeholder, so art can land
## entity-by-entity (R05, Section 9.3) without breaking anything.

const SPRITE_DIR: String = "res://assets/sprites/"
const PIXEL_SCALE: float = 2.0  ## Upscales 16x16 art to sit at the placeholders' existing visual scale.

@export var entity_id: String = ""
@export var fallback_polygon: Polygon2D  ## Kept as a child, only ever hidden, never freed.

var _sprite: Sprite2D
var _using_sprite: bool = false


func _ready() -> void:
	if fallback_polygon == null:
		# Not fatal — same "fails safe, doesn't crash" convention as the
		# rest of this project's null-guards (EnemySpawnPoint.spawn(),
		# RoomController's own missing-Exit case uses push_error since
		# THAT one breaks room progression; a visual with no fallback
		# just means nothing is drawn, which is recoverable at runtime).
		push_warning("SpriteVisual on %s has no fallback_polygon (and no sibling named \"PlaceholderVisual\" to recover it from)" % get_parent())
		return
	if fallback_polygon == null:
		push_error("SpriteVisual on %s has no fallback_polygon (and no sibling named \"PlaceholderVisual\" to recover it from)" % get_parent())
		return
	_try_load_sprite()	


func _try_load_sprite() -> void:
	if entity_id.is_empty():
		return
	var path := "%s%s.png" % [SPRITE_DIR, entity_id]
	if not ResourceLoader.exists(path):
		return  ## No art yet for this entity — stay on the placeholder.
	var texture := load(path) as Texture2D
	if texture == null:
		return

	_sprite = Sprite2D.new()
	_sprite.texture = texture
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.scale = Vector2(PIXEL_SCALE, PIXEL_SCALE)
	add_child(_sprite)

	fallback_polygon.visible = false
	_using_sprite = true


## Single entry point every caller uses instead of Polygon2D.color /
## Sprite2D.modulate directly.
func set_tint(color: Color) -> void:
	if _using_sprite:
		_sprite.modulate = color
	elif fallback_polygon != null:
		fallback_polygon.color = color


func get_tint() -> Color:
	if _using_sprite:
		return _sprite.modulate
	return fallback_polygon.color if fallback_polygon != null else Color.WHITE


func is_using_sprite() -> bool:
	return _using_sprite
