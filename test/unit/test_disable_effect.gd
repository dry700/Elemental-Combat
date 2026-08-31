extends GutTest
## Unit tests for DisableEffect — the Root/Stagger/Stun unifier, and
## specifically Break-Free's floor rule (A.3: "claws an overwhelmed lock
## back to baseline, never removes it entirely").

var disable: DisableEffect

func before_each():
	disable = DisableEffect.new()

func test_inactive_by_default():
	assert_false(disable.is_active())

func test_apply_activates_with_duration():
	disable.apply(1.0, 0.5)
	assert_almost_eq(disable.get_remaining_duration(), 1.0, 0.01)

func test_tick_expires_and_emits_when_duration_runs_out():
	disable.apply(1.0)
	watch_signals(disable)
	disable.tick(1.1)
	assert_false(disable.is_active())
	assert_signal_emitted(disable, "expired")

func test_reduce_duration_removes_a_fixed_chunk():
	disable.apply(2.0, 0.5)
	disable.reduce_duration(0.4)
	assert_almost_eq(disable.get_remaining_duration(), 1.6, 0.01)

func test_reduce_duration_clamps_at_the_floor_not_below():
	disable.apply(1.0, 0.5)
	disable.reduce_duration(0.6)  # would go to 0.4 unclamped — must stop at 0.5
	assert_almost_eq(disable.get_remaining_duration(), 0.5, 0.01)
	assert_true(disable.is_active(), "still active at the floor")

func test_reduce_duration_does_not_snap_upward_once_already_below_floor():
	# Documented edge case in disable_effect.gd: plain tick() decay (not
	# floor-clamped) can carry remaining BELOW the floor on its own. A
	# press after that must keep counting DOWN, not jump back UP.
	disable.apply(1.0, 0.5)
	disable.tick(0.7)  # remaining = 0.3, already below the 0.5 floor
	disable.reduce_duration(0.1)
	assert_almost_eq(disable.get_remaining_duration(), 0.2, 0.01, "must keep decaying toward 0, not snap back to 0.5")

func test_reduce_duration_past_zero_ends_the_lock_and_emits_expired():
	disable.apply(1.0, 0.0)  # floor of 0 — the only case Break-Free alone can end a lock
	watch_signals(disable)
	disable.reduce_duration(1.5)
	assert_false(disable.is_active())
	assert_signal_emitted(disable, "expired")

func test_reduce_duration_on_inactive_effect_is_a_no_op():
	disable.reduce_duration(0.5)
	assert_false(disable.is_active())
