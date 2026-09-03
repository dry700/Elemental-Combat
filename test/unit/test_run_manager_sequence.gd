extends GutTest
## Unit tests for RunManager._generate_sequence() — confirms the boss
## room is always the guaranteed final stage, never part of the random
## normal-room draw. Calls the real RunManager autoload singleton
## directly (same pattern already used for Hud in
## test_hud_pickup_prompts.gd/test_hud_pickup_overlay.gd) rather than
## instancing a second copy — RunManager is script-only with no scene
## state to isolate between calls.

func test_sequence_always_ends_with_the_boss_room():
	var sequence := RunManager._generate_sequence()
	assert_eq(sequence[-1], RunManager.BOSS_ROOM_SCENE_PATH)

func test_sequence_length_is_normal_rooms_plus_one_boss_room():
	var sequence := RunManager._generate_sequence()
	assert_eq(sequence.size(), RunManager.ROOMS_PER_RUN + 1)

func test_normal_room_slots_never_include_the_boss_path():
	var sequence := RunManager._generate_sequence()
	for i in range(sequence.size() - 1):
		assert_true(sequence[i] in RunManager.ROOM_SCENE_PATHS, "only the final slot may be the boss room")

func test_normal_rooms_still_avoid_immediate_repeats():
	# Regression check on the pre-existing shuffle logic — unaffected by
	# this change, but wasn't under test before now.
	for attempt in range(20):  # Run several times since this is randomised.
		var sequence := RunManager._generate_sequence()
		for i in range(1, RunManager.ROOMS_PER_RUN):
			assert_ne(sequence[i], sequence[i - 1], "no two consecutive NORMAL rooms should repeat")
