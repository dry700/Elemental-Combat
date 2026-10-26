extends GutTest

const PLAYER_SCENE_PATH := "res://scenes/player/player.tscn"
const NORMAL_DASH_SHADOW_TINT := Color(0.72, 0.82, 1.0)

func test_skill_dash_uses_iframes_without_normal_dodge_cooldown():
	var player := load(PLAYER_SCENE_PATH).instantiate() as Player
	add_child_autofree(player)
	var skill := SkillData.new()
	skill.dash_distance = 70.0
	skill.dash_iframes = 0.2
	player._start_skill_dash(skill)
	assert_eq(player._dodge_cooldown_timer, 0.0)
	player._process_dodge(0.01)
	assert_true(player.hurtbox.invulnerable)
	player._process_dodge(0.25)
	assert_false(player.hurtbox.invulnerable)

func test_skill_dash_spawns_an_element_tinted_shader_afterimage():
	var player := load(PLAYER_SCENE_PATH).instantiate() as Player
	add_child_autofree(player)
	var skill := SkillData.new()
	skill.element = Elements.HOA
	skill.dash_distance = 70.0
	skill.dash_iframes = 0.2

	var previous_shadow_count := get_tree().get_nodes_in_group("dash_shadows").size()
	player._start_skill_dash(skill)

	var shadows := get_tree().get_nodes_in_group("dash_shadows")
	assert_eq(shadows.size(), previous_shadow_count + 1)
	var shadow: Node = shadows.back()
	assert_gt(shadow.get_child_count(), 0, "afterimage should capture visible player sprites")
	var materials: Array = shadow.get("_materials")
	var material := materials[0] as ShaderMaterial
	assert_eq(material.get_shader_parameter("shadow_color"), ElementIndicator.ELEMENT_COLOR[Elements.HOA])
	assert_gt(float(material.get_shader_parameter("opacity")), 0.0)
	var source_sprite := player.visuals.get_node("PlayerTorso") as Sprite2D
	var ghost_sprite := shadow.get_child(0) as Sprite2D
	assert_eq(ghost_sprite.global_position, source_sprite.global_position)

	player._process_dodge(0.05)
	assert_eq(get_tree().get_nodes_in_group("dash_shadows").size(), previous_shadow_count + 2)
	await wait_seconds(0.3)
	assert_false(is_instance_valid(shadow), "afterimage should remove itself after fading")

func test_normal_dodge_spawns_neutral_tinted_afterimages():
	var player := load(PLAYER_SCENE_PATH).instantiate() as Player
	add_child_autofree(player)
	var previous_shadow_count := get_tree().get_nodes_in_group("dash_shadows").size()

	player._start_dash_shadows(NORMAL_DASH_SHADOW_TINT)

	var shadows := get_tree().get_nodes_in_group("dash_shadows")
	assert_eq(shadows.size(), previous_shadow_count + 1)
	var materials: Array = shadows.back().get("_materials")
	var material := materials[0] as ShaderMaterial
	assert_eq(material.get_shader_parameter("shadow_color"), NORMAL_DASH_SHADOW_TINT)
