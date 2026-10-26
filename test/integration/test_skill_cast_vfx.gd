extends GutTest

const PLAYER_SCENE_PATH := "res://scenes/player/player.tscn"
const CAST_VFX_LIFETIME: float = 0.38


func test_skill_cast_spawns_element_tinted_burst_at_player_and_cleans_it_up():
	var player := load(PLAYER_SCENE_PATH).instantiate() as Player
	player.position = Vector2(120.0, 80.0)
	add_child_autofree(player)
	var skill := SkillData.new()
	skill.skill_name = "Test Cast"
	skill.element = Elements.HOA

	var previous_vfx_count := get_tree().get_nodes_in_group("skill_cast_vfx").size()
	Input.action_release("skill_1")
	Input.action_press("skill_1")
	player._try_cast_skill(skill, "skill_1")
	Input.action_release("skill_1")

	var vfx_nodes := get_tree().get_nodes_in_group("skill_cast_vfx")
	assert_eq(vfx_nodes.size(), previous_vfx_count + 1)
	var vfx := vfx_nodes.back() as Node2D
	assert_not_null(vfx)
	assert_eq(vfx.get("element"), Elements.HOA)
	assert_eq(vfx.global_position, player.global_position)

	await wait_seconds(CAST_VFX_LIFETIME + 0.1)
	assert_false(is_instance_valid(vfx), "cast burst should clean itself up")
