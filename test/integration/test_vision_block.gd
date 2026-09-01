extends GutTest
## Integration tests for SteamCloud.blocks_vision() — Douse's vision-block
## (A.2) now gating EnemyCombatAI's own perception, not just VisionBlocker's
## player-screen overlay. Requires real SteamCloud nodes in the tree since
## registration happens in _ready()/_exit_tree() against the shared static
## _active_clouds list; add_child_autofree() frees (and un-registers) each
## cloud at the end of its test, so tests don't leak state into each other.
##
## Isolation note: SteamCloud._active_clouds is a CLASS-level static,
## shared across the whole test run, not per-instance. Earlier tests
## (e.g. Douse reactions in test_elemental_combatant_reactions.gd) can
## spawn a real SteamCloud via ElementalCombatant._spawn_steam_cloud()
## when GUT's own scene tree gives it a non-null current_scene — that
## cloud is added straight to the scene root, NOT via add_child_autofree,
## so it's still alive (5s lifetime vs. the whole suite's ~0.3s runtime)
## and still registered when this file runs. before_each() below clears
## the shared list so each test here starts from a genuinely clean slate
## regardless of what ran before it.

func before_each():
	for cloud in SteamCloud._active_clouds.duplicate():
		if is_instance_valid(cloud):
			cloud.queue_free()
	SteamCloud._active_clouds.clear()

func _make_cloud(radius: float, position: Vector2) -> SteamCloud:
	var cloud := SteamCloud.new()
	cloud.radius = radius
	cloud.lifetime = 100.0  # Long enough not to expire mid-test.
	add_child_autofree(cloud)
	cloud.global_position = position
	return cloud

func test_no_active_clouds_never_blocks_vision():
	assert_false(SteamCloud.blocks_vision(Vector2(500, 0), Vector2(0, 0)))

func test_target_inside_cloud_observer_outside_is_blocked():
	_make_cloud(90.0, Vector2.ZERO)
	assert_true(SteamCloud.blocks_vision(Vector2(500, 0), Vector2(10, 0)))

func test_target_outside_any_cloud_is_never_blocked():
	_make_cloud(90.0, Vector2.ZERO)
	assert_false(SteamCloud.blocks_vision(Vector2(500, 0), Vector2(500, 10)))

func test_observer_inside_the_same_cloud_is_not_blocked():
	_make_cloud(90.0, Vector2.ZERO)
	assert_false(SteamCloud.blocks_vision(Vector2(20, 0), Vector2(-20, 0)), "co-located inside the same cloud should still see each other")
