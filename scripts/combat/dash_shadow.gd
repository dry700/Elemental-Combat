extends Node2D
## Short-lived, element-tinted afterimage captured from the player's visible sprites.

const SHADER := preload("res://shaders/dash_shadow.gdshader")
const LIFETIME: float = 0.24
const INITIAL_OPACITY: float = 0.42

var _elapsed: float = 0.0
var _materials: Array[ShaderMaterial] = []


func capture(player: Node2D, tint: Color) -> void:
	if player == null:
		return
	global_position = player.global_position
	add_to_group("dash_shadows")
	var visuals := player.get_node_or_null("Visuals")
	if visuals == null:
		return
	for source in _collect_sprites(visuals):
		var ghost := Sprite2D.new()
		ghost.texture = source.texture
		ghost.region_enabled = source.region_enabled
		ghost.region_rect = source.region_rect
		ghost.frame = source.frame
		ghost.hframes = source.hframes
		ghost.vframes = source.vframes
		ghost.offset = source.offset
		ghost.flip_h = source.flip_h
		ghost.flip_v = source.flip_v
		ghost.centered = source.centered
		ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var shadow_material := ShaderMaterial.new()
		shadow_material.shader = SHADER
		shadow_material.set_shader_parameter("shadow_color", tint)
		shadow_material.set_shader_parameter("opacity", INITIAL_OPACITY)
		ghost.material = shadow_material
		_materials.append(shadow_material)
		add_child(ghost)
		ghost.global_transform = source.global_transform


func _process(delta: float) -> void:
	_elapsed += delta
	var fade := clampf(1.0 - _elapsed / LIFETIME, 0.0, 1.0)
	for shadow_material in _materials:
		shadow_material.set_shader_parameter("opacity", INITIAL_OPACITY * fade)
	if _elapsed >= LIFETIME:
		queue_free()


func _collect_sprites(node: Node) -> Array[Sprite2D]:
	var sprites: Array[Sprite2D] = []
	for child in node.get_children():
		if child is Sprite2D and child.visible and child.texture != null:
			sprites.append(child)
		sprites.append_array(_collect_sprites(child))
	return sprites
