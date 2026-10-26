extends GutTest

const PLAYER_SCENE_PATH := "res://scenes/player/player.tscn"
const SEISMIC_SLAM_PATH := "res://scripts/resources/skills/seismic_slam.tres"


func test_seismic_slam_jumps_then_impacts_ground_with_damage_and_shake():
	var floor_body := StaticBody2D.new()
	floor_body.collision_layer = 1
	var floor_shape := CollisionShape2D.new()
	var floor_rect := RectangleShape2D.new()
	floor_rect.size = Vector2(300.0, 20.0)
	floor_shape.shape = floor_rect
	floor_body.add_child(floor_shape)
	floor_body.position = Vector2(0.0, 30.0)
	add_child_autofree(floor_body)

	var player := load(PLAYER_SCENE_PATH).instantiate() as Player
	player.position = Vector2(0.0, 12.0)
	add_child_autofree(player)
	var target_owner := Node2D.new()
	target_owner.position = Vector2(20.0, 12.0)
	add_child_autofree(target_owner)
	var target := ElementalCombatant.new()
	target.show_debug_readout = false
	target_owner.add_child(target)

	var damage_dealt := [0.0]
	target.bonus_damage_dealt.connect(func(amount: float): damage_dealt[0] += amount)
	var slam := load(SEISMIC_SLAM_PATH) as SkillData
	var starting_y := player.global_position.y
	var impact_vfx_count := get_tree().get_nodes_in_group("skill_cast_vfx").size()

	Input.action_release("skill_1")
	Input.action_press("skill_1")
	player._try_cast_skill(slam, "skill_1")
	Input.action_release("skill_1")

	assert_eq(player.state, Player.State.SKILL_SLAM)
	assert_lt(player.velocity.y, 0.0, "cast should launch the player upward")
	await wait_seconds(0.15)
	assert_lt(player.global_position.y, starting_y, "player should visibly rise before descending")

	await wait_seconds(0.4)
	assert_eq(player.state, Player.State.IDLE)
	assert_true(player.is_on_floor(), "slam should finish on the ground")
	assert_almost_eq(damage_dealt[0], slam.damage, 0.01, "damage should resolve on impact")
	assert_eq(get_tree().get_nodes_in_group("skill_cast_vfx").size(), impact_vfx_count + 1)
	assert_gt(ScreenShake._active_until_msec, Time.get_ticks_msec(), "ground impact should trigger screen shake")
	await wait_seconds(0.5)
	assert_eq(get_tree().get_nodes_in_group("skill_cast_vfx").size(), impact_vfx_count, "impact burst should clean itself up")
