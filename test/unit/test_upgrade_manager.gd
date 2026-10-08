extends GutTest
## Unit tests for UpgradeManager (P10a).
## Verifies Qi earning/reset, stat upgrade logic, and Reaction Mastery getters.

const UMScript := preload("res://autoloads/upgrade_manager.gd")

func _make_um() -> Node:
	var um: Node = UMScript.new()
	add_child_autofree(um)
	return um

func test_award_qi_accumulates():
	var um := _make_um()
	um.award_qi(10.0)
	assert_eq(um.qi, 10.0)
	assert_eq(um.qi_earned_total, 10.0)
	um.award_qi(15.0)
	assert_eq(um.qi, 25.0)
	assert_eq(um.qi_earned_total, 25.0)

func test_award_qi_ignores_zero_or_negative():
	var um := _make_um()
	um.award_qi(0.0)
	um.award_qi(-5.0)
	assert_eq(um.qi, 0.0)
	assert_eq(um.qi_earned_total, 0.0)

func test_spend_qi_tracks_total_and_rejects_shortfalls():
	var um := _make_um()
	um.qi = 25.0
	assert_true(um.spend_qi(10.0))
	assert_eq(um.qi, 15.0)
	assert_eq(um.qi_spent_total, 10.0)
	assert_false(um.spend_qi(20.0), "Should fail with insufficient Qi")
	assert_eq(um.qi, 15.0)

func test_restore_cost_escalates_and_purchase_restore_tracks_uses():
	var um := _make_um()
	um.qi = 100.0
	assert_eq(um.restore_cost(), 20.0)
	assert_true(um.purchase_restore())
	assert_eq(um._restore_uses, 1)
	assert_eq(um.qi, 80.0)
	assert_eq(um.restore_cost(), 30.0)

func test_reset_clears_all_per_run_state():
	var um := _make_um()
	um.qi = 100.0
	um.purchase_vitality()
	um.purchase_restore()
	var pair := [Elements.HOA, Elements.THUY]
	um.purchase_sinh_rank1(pair)
	um.purchase_sinh_rank2(pair, Elements.HOA)
	um.reset()
	assert_eq(um.qi, 0.0)
	assert_eq(um.qi_earned_total, 0.0)
	assert_eq(um.qi_spent_total, 0.0)
	assert_eq(um._restore_uses, 0)
	assert_eq(um.vitality_hp_bonus(), 0.0)
	assert_false(um.sinh_tier2_forced(pair))
	assert_eq(um.sinh_favored_element(pair), &"")

func test_weapon_might_multiplier_scales_with_purchases():
	var um := _make_um()
	assert_eq(um.weapon_might_multiplier(), 1.0)
	um.qi = 50.0
	var success: bool = um.purchase_weapon_might()
	assert_true(success)
	assert_eq(um.weapon_might_multiplier(), 1.1)
	assert_eq(um.qi, 35.0)
	success = um.purchase_weapon_might()
	assert_true(success)
	assert_eq(um.weapon_might_multiplier(), 1.2)
	assert_eq(um.qi, 10.0)
	success = um.purchase_weapon_might()
	assert_false(success, "Should fail with insufficient Qi")

func test_vitality_hp_bonus_scales_with_purchases():
	var um := _make_um()
	assert_eq(um.vitality_hp_bonus(), 0.0)
	um.qi = 15.0
	var success: bool = um.purchase_vitality()
	assert_true(success)
	assert_eq(um.vitality_hp_bonus(), 10.0)
	assert_eq(um.qi, 0.0)

func test_reaction_mastery_sorting_ensures_order_independence():
	var um := _make_um()
	um.qi = 100.0
	um.purchase_khac_rank1([Elements.THUY, Elements.MOC])
	assert_true(um.khac_graze_erased([Elements.MOC, Elements.THUY]))

func test_sinh_mastery_ranks_and_favored_element():
	var um := _make_um()
	var pair := [Elements.KIM, Elements.THUY]
	assert_false(um.sinh_tier2_forced(pair))
	assert_eq(um.sinh_favored_element(pair), &"")
	um.qi = 100.0
	var success: bool = um.purchase_sinh_rank1(pair)
	assert_true(success)
	assert_true(um.sinh_tier2_forced(pair))
	assert_eq(um.sinh_favored_element(pair), &"")
	success = um.purchase_sinh_rank2(pair, Elements.THUY)
	assert_true(success)
	assert_eq(um.sinh_favored_element(pair), Elements.THUY)

func test_khac_mastery_ranks():
	var um := _make_um()
	var pair := [Elements.HOA, Elements.KIM]
	assert_false(um.khac_graze_erased(pair))
	assert_false(um.khac_overwhelm_forced(pair))
	um.qi = 100.0
	um.purchase_khac_rank1(pair)
	assert_true(um.khac_graze_erased(pair))
	assert_false(um.khac_overwhelm_forced(pair))
	um.purchase_khac_rank2(pair)
	assert_true(um.khac_graze_erased(pair))
	assert_true(um.khac_overwhelm_forced(pair))

func test_purchase_checks_fail_if_already_purchased():
	var um := _make_um()
	um.qi = 500.0
	var pair := [Elements.THO, Elements.THUY]
	assert_true(um.purchase_khac_rank1(pair))
	assert_false(um.purchase_khac_rank1(pair), "Cannot buy rank 1 twice")
	assert_true(um.purchase_khac_rank2(pair))
	assert_false(um.purchase_khac_rank2(pair), "Cannot buy rank 2 twice")

func test_purchase_rank2_fails_if_rank1_not_owned():
	var um := _make_um()
	um.qi = 100.0
	var pair := [Elements.MOC, Elements.HOA]
	assert_false(um.purchase_sinh_rank2(pair, Elements.HOA), "Must buy rank 1 first")
	um.purchase_sinh_rank1(pair)
	assert_true(um.purchase_sinh_rank2(pair, Elements.HOA))

func test_save_state_round_trips_restore_uses_and_qi_totals():
	var um := _make_um()
	um.award_qi(100.0)
	um.purchase_restore()
	um.purchase_vitality()
	var saved: Dictionary = um.to_save_state()
	var restored := _make_um()
	restored.apply_save_state(saved)
	assert_eq(restored._restore_uses, 1)
	assert_eq(restored.qi_earned_total, 100.0)
	assert_eq(restored.qi_spent_total, 35.0)
	assert_eq(restored.qi, 65.0)
	assert_eq(restored.vitality_hp_bonus(), 10.0)