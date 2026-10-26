extends GutTest
## Unit tests for TrailVFX — point sampling while the tip moves, the
## taper setup, and self-cleanup once sampling ends and points age out.

func _make_trail(source: Node2D, duration: float) -> TrailVFX:
	var trail := TrailVFX.new()
	trail.tip_source = source
	trail.tip_offset = Vector2(10, 0)
	trail.element = Elements.KIM
	trail.sample_duration = duration
	add_child_autofree(trail)
	return trail

func test_trail_collects_points_while_the_tip_moves():
	var source := Node2D.new()
	add_child_autofree(source)
	var trail := _make_trail(source, 0.5)
	for i in range(5):
		source.position.x += 5.0
		await get_tree().process_frame
	assert_gt(trail.get_point_count(), 2, "moving tip should leave a multi-point trail")

func test_trail_samples_the_tip_in_world_space():
	var source := Node2D.new()
	source.position = Vector2(100, 50)
	add_child_autofree(source)
	var trail := _make_trail(source, 0.5)
	await get_tree().process_frame
	assert_almost_eq(trail.get_point_position(0).x, 110.0, 0.01, "tip = source position + tip_offset, in global coords")

func test_trail_narrows_toward_the_tail():
	var source := Node2D.new()
	add_child_autofree(source)
	var trail := _make_trail(source, 0.5)
	assert_lt(trail.width_curve.sample(0.0), trail.width_curve.sample(1.0), "tail (offset 0) must be narrower than the tip (offset 1)")

func test_trail_frees_itself_after_sampling_ends_and_points_age_out():
	var source := Node2D.new()
	add_child_autofree(source)
	var trail := _make_trail(source, 0.05)
	await wait_seconds(0.5)
	assert_false(is_instance_valid(trail), "trail should free itself once sampling is over and every point has aged out")
