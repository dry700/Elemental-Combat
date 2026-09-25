extends CanvasLayer
## Douse's actual "blocks vision" effect (A.2) — a full-screen darkness
## overlay with a circular hole revealing whatever's near the player,
## active only while the player is standing inside a SteamCloud. This is
## what limits what the PLAYER can see; SteamCloud's own draw_circle is
## just the cloud's world-space visual and can't affect rendering
## outside its own bounds — that needs a screen-space overlay, hence a
## separate autoload rather than something SteamCloud does itself.
##
## "They can only see inside the cloud and a short distance around it"
## is implemented literally: reveal radius = whichever cloud the player
## is inside + a fixed extra margin, not just the cloud's own radius —
## inside the cloud is fully visible, a bit further out fades to dark.
##
## No line-of-sight/fog-of-war system exists elsewhere in the project;
## this affects the PLAYER's screen only, same as SteamCloud's stun only
## ever affected ElementalCombatants directly, never any AI perception
## (none of which uses vision for anything currently).

const EXTRA_REVEAL_DISTANCE: float = 20.0  ## "A short distance around the cloud" — no number given in A.2, a reasonable pick.
const FALLOFF_DISTANCE: float = 25.0  ## Soft-edge width so the cutoff isn't a hard, unnatural circle.
const DARKNESS: float = 0.92  ## How opaque the blocked-out area gets. 1.0 would be pure black.

var _material: ShaderMaterial


func _ready() -> void:
	layer = 100  # Above everything else in the main viewport.

	var rect := ColorRect.new()
	rect.color = Color.WHITE  # Irrelevant — the shader's fragment() overrides COLOR entirely.
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)

	_material = ShaderMaterial.new()
	_material.shader = load("res://shaders/vision_blocker.gdshader")
	_material.set_shader_parameter("darkness", DARKNESS)
	_material.set_shader_parameter("falloff_px", FALLOFF_DISTANCE)
	_material.set_shader_parameter("active", 0.0)
	rect.material = _material


func _process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		_material.set_shader_parameter("active", 0.0)
		return

	var reveal_radius := _reveal_radius_if_inside_cloud(player.global_position)
	if reveal_radius < 0.0:
		_material.set_shader_parameter("active", 0.0)
		return

	var screen_px: Vector2 = get_viewport().get_canvas_transform() * player.global_position
	_material.set_shader_parameter("reveal_center_px", screen_px)
	_material.set_shader_parameter("reveal_radius_px", reveal_radius)
	_material.set_shader_parameter("active", 1.0)


## Returns the reveal radius (cloud's own radius + the extra margin) if
## the player is inside any currently-active SteamCloud, or -1.0 if they
## aren't inside any. Reuses SteamCloud's own tracking list rather than
## a separate query system.
func _reveal_radius_if_inside_cloud(player_pos: Vector2) -> float:
	for cloud in SteamCloud._active_clouds:
		if not is_instance_valid(cloud):
			continue
		if player_pos.distance_to(cloud.global_position) <= cloud.radius:
			return cloud.radius + EXTRA_REVEAL_DISTANCE
	return -1.0
