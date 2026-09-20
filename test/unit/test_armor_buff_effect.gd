extends GutTest
## Unit tests for ArmorBuffEffect.

var armor_buff: ArmorBuffEffect

func before_each():
	armor_buff = ArmorBuffEffect.new()

func test_inactive_by_default_bonus_is_zero():
	assert_false(armor_buff.active)
	assert_eq(armor_buff.get_bonus_armor(), 0.0)

func test_apply_activates_with_given_bonus():
	armor_buff.apply(8.0, 2.0)
	assert_eq(armor_buff.get_bonus_armor(), 8.0)

func test_tick_expires_and_returns_bonus_to_zero():
	armor_buff.apply(8.0, 1.0)
	watch_signals(armor_buff)
	armor_buff.tick(1.1)
	assert_false(armor_buff.active)
	assert_eq(armor_buff.get_bonus_armor(), 0.0)
	assert_signal_emitted(armor_buff, "expired")

func test_apply_refreshes_without_stacking():
	armor_buff.apply(8.0, 2.0)
	armor_buff.apply(12.0, 3.0)
	assert_true(armor_buff.active)
	assert_eq(armor_buff.get_bonus_armor(), 12.0)
	assert_eq(armor_buff.get_remaining_duration(), 3.0)

func test_tick_does_not_expire_before_duration_elapses():
	armor_buff.apply(8.0, 2.0)
	armor_buff.tick(1.0)
	assert_true(armor_buff.active)
	assert_eq(armor_buff.get_bonus_armor(), 8.0)
