extends GutTest
## Unit tests for CCResistance — shared control count with diminishing returns.

var resistance

func before_each():
	resistance = preload("res://scripts/reactions/cc_resistance.gd").new()
	resistance.configure(3, 2.0)

func test_free_hits_are_full_duration_then_half_then_immune():
	assert_almost_eq(resistance.consume_and_get_multiplier(), 1.0, 0.001)
	assert_almost_eq(resistance.consume_and_get_multiplier(), 1.0, 0.001)
	assert_almost_eq(resistance.consume_and_get_multiplier(), 1.0, 0.001)
	assert_almost_eq(resistance.consume_and_get_multiplier(), 0.5, 0.001)
	assert_almost_eq(resistance.consume_and_get_multiplier(), 0.0, 0.001)

func test_window_reset_clears_the_shared_counter():
	assert_almost_eq(resistance.consume_and_get_multiplier(), 1.0, 0.001)
	assert_almost_eq(resistance.consume_and_get_multiplier(), 1.0, 0.001)
	resistance.tick(2.1)
	assert_almost_eq(resistance.consume_and_get_multiplier(), 1.0, 0.001)
