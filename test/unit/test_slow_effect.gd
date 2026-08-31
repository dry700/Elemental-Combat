extends GutTest
## Unit tests for SlowEffect.

var slow: SlowEffect

func before_each():
	slow = SlowEffect.new()

func test_inactive_by_default_multiplier_is_neutral():
	assert_false(slow.active)
	assert_eq(slow.get_speed_multiplier(), 1.0)

func test_apply_activates_with_given_multiplier():
	slow.apply(0.5, 2.0)
	assert_eq(slow.get_speed_multiplier(), 0.5)

func test_tick_expires_and_returns_multiplier_to_neutral():
	slow.apply(0.5, 1.0)
	watch_signals(slow)
	slow.tick(1.1)
	assert_false(slow.active)
	assert_eq(slow.get_speed_multiplier(), 1.0)
	assert_signal_emitted(slow, "expired")

func test_tick_does_not_expire_before_duration_elapses():
	slow.apply(0.5, 2.0)
	slow.tick(1.0)
	assert_true(slow.active)
