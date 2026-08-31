extends GutTest
## Unit tests for Elements — Appendix A.1 vocabulary, A.2 cycle direction.
## Pure static logic, no scene tree required.

func test_sinh_cycle_all_five_pairs_match_both_directions():
	assert_true(Elements.is_sinh_pair(Elements.MOC, Elements.HOA), "Mộc sinh Hỏa")
	assert_true(Elements.is_sinh_pair(Elements.HOA, Elements.MOC), "reverse order still matches")
	assert_true(Elements.is_sinh_pair(Elements.HOA, Elements.THO), "Hỏa sinh Thổ")
	assert_true(Elements.is_sinh_pair(Elements.THO, Elements.KIM), "Thổ sinh Kim")
	assert_true(Elements.is_sinh_pair(Elements.KIM, Elements.THUY), "Kim sinh Thủy")
	assert_true(Elements.is_sinh_pair(Elements.THUY, Elements.MOC), "Thủy sinh Mộc")

func test_sinh_pair_rejects_non_adjacent_elements():
	assert_false(Elements.is_sinh_pair(Elements.MOC, Elements.KIM))
	assert_false(Elements.is_sinh_pair(Elements.HOA, Elements.THUY), "that pair is Khắc, not Sinh")

func test_khac_cycle_all_five_pairs_match_both_directions():
	assert_true(Elements.is_khac_pair(Elements.MOC, Elements.THO), "Mộc khắc Thổ")
	assert_true(Elements.is_khac_pair(Elements.THO, Elements.MOC), "reverse order still matches")
	assert_true(Elements.is_khac_pair(Elements.THO, Elements.THUY), "Thổ khắc Thủy")
	assert_true(Elements.is_khac_pair(Elements.THUY, Elements.HOA), "Thủy khắc Hỏa")
	assert_true(Elements.is_khac_pair(Elements.HOA, Elements.KIM), "Hỏa khắc Kim")
	assert_true(Elements.is_khac_pair(Elements.KIM, Elements.MOC), "Kim khắc Mộc")

func test_sinh_generated_element_is_direction_locked():
	var pair: Array[StringName] = [Elements.THUY, Elements.MOC]
	assert_eq(Elements.sinh_generated_element(pair), Elements.MOC)
	var reversed_pair: Array[StringName] = [Elements.MOC, Elements.THUY]
	assert_eq(Elements.sinh_generated_element(reversed_pair), Elements.MOC, "order-independent input, direction-locked output")

func test_sinh_generated_element_returns_none_for_invalid_pair():
	var pair: Array[StringName] = [Elements.KIM, Elements.HOA]
	assert_eq(Elements.sinh_generated_element(pair), Elements.NONE)

func test_pair_is_matches_either_order():
	var pair: Array[StringName] = [Elements.HOA, Elements.KIM]
	assert_true(Elements.pair_is(pair, Elements.HOA, Elements.KIM))
	assert_true(Elements.pair_is(pair, Elements.KIM, Elements.HOA))
	assert_false(Elements.pair_is(pair, Elements.MOC, Elements.THO))
