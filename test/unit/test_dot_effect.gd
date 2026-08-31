extends GutTest
## Unit tests for DotEffect — refresh-only DoT ticking.

var dot: DotEffect

func before_each():
	dot = DotEffect.new()

func test_inactive_by_default():
	assert_false(dot.active)

func test_apply_activates_and_sets_parameters():
	dot.apply(3.0, 1.0, 5.0)
	assert_true(dot.active)
	assert_eq(dot.damage_per_tick, 3.0)

func test_tick_returns_zero_damage_before_interval_elapses():
	dot.apply(3.0, 1.0, 5.0)
	assert_eq(dot.tick(0.5), 0.0)

func test_tick_returns_damage_once_interval_elapses():
	dot.apply(3.0, 1.0, 5.0)
	dot.tick(0.9)
	assert_eq(dot.tick(0.2), 3.0)

func test_tick_resets_interval_after_a_tick_lands():
	dot.apply(3.0, 1.0, 5.0)
	dot.tick(1.0)
	assert_eq(dot.tick(0.5), 0.0)

func test_expires_and_emits_after_duration_elapses():
	dot.apply(3.0, 1.0, 1.5)
	watch_signals(dot)
	dot.tick(1.6)
	assert_false(dot.active)
	assert_signal_emitted(dot, "expired")

func test_apply_while_active_is_refresh_not_stack():
	dot.apply(3.0, 1.0, 5.0)
	dot.tick(2.0)
	dot.apply(5.0, 1.0, 3.0)
	assert_eq(dot.damage_per_tick, 5.0, "new application should fully replace the old one")
	assert_almost_eq(dot.get_remaining_duration(), 3.0, 0.01)
