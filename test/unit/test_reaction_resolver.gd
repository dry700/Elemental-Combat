extends GutTest
## Unit tests for Reactions.resolve() — A.3's Sinh tiering and the full
## 3x3 Khắc Charge grid, all nine combinations.

var target_status: ElementalStatus

func before_each():
	target_status = ElementalStatus.new()

func test_no_reaction_when_target_has_no_status():
	assert_eq(Reactions.resolve(Elements.HOA, 1, target_status).outcome, Reactions.Outcome.NO_REACTION)

func test_no_reaction_when_same_element_reapplied():
	target_status.apply(Elements.HOA, 1)
	assert_eq(Reactions.resolve(Elements.HOA, 2, target_status).outcome, Reactions.Outcome.NO_REACTION)

func test_sinh_tier_1_when_min_charge_is_1():
	target_status.apply(Elements.MOC, 2)
	assert_eq(Reactions.resolve(Elements.HOA, 1, target_status).outcome, Reactions.Outcome.SINH_TIER_1)

func test_sinh_tier_2_when_min_charge_is_2_or_more():
	target_status.apply(Elements.MOC, 3)
	assert_eq(Reactions.resolve(Elements.HOA, 2, target_status).outcome, Reactions.Outcome.SINH_TIER_2)

func test_khac_1v1_is_full_clear():
	target_status.apply(Elements.KIM, 1)
	assert_eq(Reactions.resolve(Elements.HOA, 1, target_status).outcome, Reactions.Outcome.KHAC_FULL_CLEAR)

func test_khac_1v2_is_partial():
	target_status.apply(Elements.KIM, 2)
	assert_eq(Reactions.resolve(Elements.HOA, 1, target_status).outcome, Reactions.Outcome.KHAC_PARTIAL)

func test_khac_1v3_is_vu_rebel():
	target_status.apply(Elements.KIM, 3)
	assert_eq(Reactions.resolve(Elements.HOA, 1, target_status).outcome, Reactions.Outcome.KHAC_VU)

func test_khac_2v1_is_full_clear():
	target_status.apply(Elements.KIM, 1)
	assert_eq(Reactions.resolve(Elements.HOA, 2, target_status).outcome, Reactions.Outcome.KHAC_FULL_CLEAR)

func test_khac_2v2_is_full_clear():
	target_status.apply(Elements.KIM, 2)
	assert_eq(Reactions.resolve(Elements.HOA, 2, target_status).outcome, Reactions.Outcome.KHAC_FULL_CLEAR)

func test_khac_2v3_is_partial():
	target_status.apply(Elements.KIM, 3)
	assert_eq(Reactions.resolve(Elements.HOA, 2, target_status).outcome, Reactions.Outcome.KHAC_PARTIAL)

func test_khac_3v1_is_thua_overwhelm():
	target_status.apply(Elements.KIM, 1)
	assert_eq(Reactions.resolve(Elements.HOA, 3, target_status).outcome, Reactions.Outcome.KHAC_THUA)

func test_khac_3v2_is_full_clear():
	target_status.apply(Elements.KIM, 2)
	assert_eq(Reactions.resolve(Elements.HOA, 3, target_status).outcome, Reactions.Outcome.KHAC_FULL_CLEAR)

func test_khac_3v3_is_full_clear():
	target_status.apply(Elements.KIM, 3)
	assert_eq(Reactions.resolve(Elements.HOA, 3, target_status).outcome, Reactions.Outcome.KHAC_FULL_CLEAR)

func test_resolution_result_carries_the_correct_pair():
	target_status.apply(Elements.KIM, 1)
	var result := Reactions.resolve(Elements.HOA, 1, target_status)
	assert_true(Elements.pair_is(result.reaction_pair, Elements.HOA, Elements.KIM))
