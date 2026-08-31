extends GutTest
## Unit tests for ElementalStatus — refresh-only application, decay,
## and its two signals.

var status: ElementalStatus

func before_each():
	status = ElementalStatus.new()

func test_starts_empty():
	assert_false(status.has_status())
	assert_eq(status.element, Elements.NONE)

func test_apply_sets_element_and_charge_and_emits_status_applied():
	watch_signals(status)
	status.apply(Elements.HOA, 2)
	assert_eq(status.element, Elements.HOA)
	assert_eq(status.charge, 2)
	assert_signal_emitted(status, "status_applied")

func test_apply_is_refresh_only_not_stacking():
	status.apply(Elements.HOA, 1)
	status.apply(Elements.HOA, 1)
	assert_eq(status.charge, 1, "charge must not stack across repeated applications")

func test_apply_overwrites_a_different_element_entirely():
	status.apply(Elements.HOA, 2)
	status.apply(Elements.KIM, 1)
	assert_eq(status.element, Elements.KIM)
	assert_eq(status.charge, 1)

func test_clear_resets_and_emits_status_cleared():
	status.apply(Elements.HOA, 1)
	watch_signals(status)
	status.clear()
	assert_false(status.has_status())
	assert_eq(status.charge, 0)
	assert_signal_emitted(status, "status_cleared")

func test_clear_on_already_empty_status_does_not_emit():
	watch_signals(status)
	status.clear()
	assert_signal_not_emitted(status, "status_cleared")

func test_tick_decays_to_empty_after_default_duration():
	status.apply(Elements.HOA, 1)
	status.tick(ElementalStatus.DECAY_SECONDS + 0.1)
	assert_false(status.has_status())

func test_tick_does_not_decay_before_duration_elapses():
	status.apply(Elements.HOA, 1)
	status.tick(ElementalStatus.DECAY_SECONDS - 0.5)
	assert_true(status.has_status())

func test_apply_respects_a_custom_duration_override():
	status.apply(Elements.THUY, 1, ElementalStatus.DECAY_SECONDS * 1.6)  # Condensation Tier 2's extension
	status.tick(ElementalStatus.DECAY_SECONDS + 0.1)
	assert_true(status.has_status(), "custom duration should outlast the default decay window")
