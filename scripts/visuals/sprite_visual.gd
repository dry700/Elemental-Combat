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
## Upscaling is now the window's job (project.godot's display/window/stretch
## settings), not this node's — every sprite renders at native 1:1 here.

@export var entity_id: String = ""
@export var fallback_polygon: Polygon2D  ## Kept as a child, only ever hidden, never freed.

var _sprite: Sprite2D
var _using_sprite: bool = false


func _ready() -> void:
	if fallback_polygon == null:
		# Recover from a resaved .tscn silently dropping this NodePath
		# export — same known quirk RoomController.exit already guards
		# against. Actually do what this warning always claimed to do.
		fallback_polygon = get_parent().find_child("PlaceholderVisual", false, false) as Polygon2D
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
	_sprite.offset = _ground_aligned_offset(texture)
	add_child(_sprite)

	fallback_polygon.visible = false
	_using_sprite = true


## Aligns the loaded sprite's bottom edge with the placeholder polygon's
## own bottom edge — see the class-level note on why this reuses the
## placeholder's already-correct bound instead of a per-entity constant.
## No PIXEL_SCALE conversion needed anymore: with global window stretch,
## poly_bottom and the texture's own height are already in the same 1:1
## unit space.
func _ground_aligned_offset(texture: Texture2D) -> Vector2:
	if fallback_polygon == null:
		return Vector2.ZERO
	var poly_bottom := -INF
	for point in fallback_polygon.polygon:
		poly_bottom = maxf(poly_bottom, point.y)
	return Vector2(0, poly_bottom - texture.get_height() / 2.0)


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
