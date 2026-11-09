extends GutTest

const PLATFORM_SCENE_PATH := "res://scenes/world/one_way_platform.tscn"
const BOSS_ROOM_PATH := "res://scenes/world/rooms/room_boss.tscn"


func test_only_boss_arena_platforms_are_timed() -> void:
	var room := load(BOSS_ROOM_PATH).instantiate() as RoomController
	add_child_autofree(room)
	var platforms := room.find_children("*", "OneWayPlatform", true, false)
	assert_eq(platforms.size(), 3)
	for platform_node in platforms:
		assert_true((platform_node as OneWayPlatform).timed_collapse_enabled)

	var normal_platform := load(PLATFORM_SCENE_PATH).instantiate() as OneWayPlatform
	add_child_autofree(normal_platform)
	assert_false(normal_platform.timed_collapse_enabled)


func test_timed_platform_warns_collapses_and_recovers() -> void:
	var platform := load(PLATFORM_SCENE_PATH).instantiate() as OneWayPlatform
	platform.timed_collapse_enabled = true
	platform.collapse_after_seconds = 3.0
	platform.warning_duration = 1.2
	platform.recovery_duration = 2.0
	add_child_autofree(platform)
	platform.set_process(false)

	var player := Node2D.new()
	player.add_to_group("player")
	add_child_autofree(player)

	var trigger := platform.get_node("TimedPlatformTrigger") as Area2D
	assert_eq(trigger.collision_mask, 1)
	var trigger_shape := trigger.get_child(0) as CollisionShape2D
	assert_eq((trigger_shape.shape as RectangleShape2D).size.x, 48.0)

	platform._on_timed_trigger_body_entered(player)
	assert_eq(platform.get("_timed_state"), OneWayPlatform.TimedState.WARNING)
	platform._process(1.81)
	assert_eq(platform.get("_timed_state"), OneWayPlatform.TimedState.WARNING)
	assert_ne((platform.get_node("Visual") as Polygon2D).modulate, platform._base_visual_modulate)

	platform._process(1.2)
	assert_eq(platform.get("_timed_state"), OneWayPlatform.TimedState.COLLAPSED)
	await get_tree().process_frame
	var collision := platform.get_node("CollisionShape2D") as CollisionShape2D
	assert_true(collision.disabled)

	platform._process(2.0)
	await get_tree().process_frame
	assert_eq(platform.get("_timed_state"), OneWayPlatform.TimedState.IDLE)
	assert_false(collision.disabled)
	assert_eq(platform.collision_layer, 4)


func test_jumping_up_through_platform_does_not_start_collapse_timer() -> void:
	var platform := load(PLATFORM_SCENE_PATH).instantiate() as OneWayPlatform
	platform.timed_collapse_enabled = true
	add_child_autofree(platform)
	platform.set_process(false)

	var player := Node2D.new()
	player.add_to_group("player")
	player.global_position = Vector2(0.0, 10.0)
	add_child_autofree(player)

	platform._on_timed_trigger_body_entered(player)

	assert_eq(platform.get("_timed_state"), OneWayPlatform.TimedState.IDLE)
