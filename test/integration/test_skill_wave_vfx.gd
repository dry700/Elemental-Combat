extends GutTest

const PLAYER_SCENE_PATH := "res://scenes/player/player.tscn"
const UNDERTOW_PATH := "res://scripts/resources/skills/undertow.tres"
const WAVE_VFX_LIFETIME: float = 0.52


func test_undertow_cast_spawns_directional_water_wave():
	var player := load(PLAYER_SCENE_PATH).instantiate() as Player
	player.facing = -1
	player.position = Vector2(120.0, 80.0)
	add_child_autofree(player)
	var undertow := load(UNDERTOW_PATH) as SkillData
	var previous_wave_count := get_tree().get_nodes_in_group("skill_wave_vfx").size()
	var previous_burst_count := get_tree().get_nodes_in_group("skill_cast_vfx").size()

	Input.action_release("skill_1")
	Input.action_press("skill_1")
	player._try_cast_skill(undertow, "skill_1")
	Input.action_release("skill_1")

	var waves := get_tree().get_nodes_in_group("skill_wave_vfx")
	assert_eq(waves.size(), previous_wave_count + 1)
	assert_eq(get_tree().get_nodes_in_group("skill_cast_vfx").size(), previous_burst_count)
	var wave := waves.back() as Node2D
	assert_eq(wave.global_position, player.global_position)
	assert_eq(wave.get("element"), Elements.THUY)
	assert_eq(wave.get("wave_direction"), -1)
	assert_almost_eq(float(wave.get("wave_distance")), undertow.radius * 1.5, 0.01)

	await wait_seconds(WAVE_VFX_LIFETIME + 0.1)
	assert_false(is_instance_valid(wave), "wave visual should clean itself up")
