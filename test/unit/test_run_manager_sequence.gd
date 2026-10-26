extends GutTest
## Unit tests for RunManager._generate_sequence() — confirms each normal
## room is followed by a shop and the boss shop is the final stage. Calls
## the real RunManager autoload singleton
## directly (same pattern already used for Hud in
## test_hud_pickup_prompts.gd/test_hud_pickup_overlay.gd) rather than
## instancing a second copy — RunManager is script-only with no scene
## state to isolate between calls.

func test_sequence_places_boss_before_the_final_boss_shop():
	var sequence := RunManager._generate_sequence()
	assert_eq(sequence[-2], RunManager.BOSS_ROOM_SCENE_PATH)
	assert_eq(sequence[-1], RunManager.BOSS_SHOP_ROOM_SCENE_PATH)

func test_sequence_length_includes_shops_boss_and_boss_shop():
	var sequence := RunManager._generate_sequence()
	assert_eq(sequence.size(), RunManager.ROOMS_PER_RUN * 2 + 2)

func test_every_normal_room_is_followed_by_a_shop():
	var sequence := RunManager._generate_sequence()
	for room_index in range(RunManager.ROOMS_PER_RUN):
		var sequence_index := room_index * 2
		assert_true(sequence[sequence_index] in RunManager.ROOM_SCENE_PATHS)
		assert_eq(sequence[sequence_index + 1], RunManager.SHOP_ROOM_SCENE_PATH)
	assert_eq(sequence[RunManager.ROOMS_PER_RUN * 2], RunManager.BOSS_ROOM_SCENE_PATH)

func test_shop_rooms_do_not_count_as_cleared_combat_rooms():
	var sequence: Array[String] = [
		RunManager.ROOM_SCENE_PATHS[0],
		RunManager.SHOP_ROOM_SCENE_PATH,
		RunManager.ROOM_SCENE_PATHS[0],
		RunManager.SHOP_ROOM_SCENE_PATH,
		RunManager.BOSS_ROOM_SCENE_PATH,
		RunManager.BOSS_SHOP_ROOM_SCENE_PATH,
	]
	assert_eq(RunManager._count_combat_rooms_before(sequence, 2), 1, "first shop should not count as a cleared room")
	assert_eq(RunManager._count_combat_rooms_before(sequence, 4), 2, "second shop should not count as a cleared room")
	assert_eq(RunManager._count_combat_rooms_before(sequence, sequence.size()), 3, "boss shop should not count as a combat room")

func test_normal_rooms_still_avoid_immediate_repeats():
	# Regression check on the pre-existing shuffle logic — unaffected by
	# this change, but wasn't under test before now.
	for attempt in range(20):  # Run several times since this is randomised.
		var sequence := RunManager._generate_sequence()
		if RunManager.ROOM_SCENE_PATHS.size() > 1:
			for i in range(1, RunManager.ROOMS_PER_RUN):
				assert_ne(sequence[i * 2], sequence[(i - 1) * 2], "no two consecutive NORMAL rooms should repeat")
		else:
			for i in range(RunManager.ROOMS_PER_RUN):
				assert_eq(sequence[i * 2], RunManager.ROOM_SCENE_PATHS[0], "all normal rooms must use the only available path")
