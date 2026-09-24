extends GutTest

func test_rune_data_round_trips_to_dictionary():
	var rune := RuneData.new(Elements.HOA, RuneData.Target.WEAPON)
	rune.modifiers.append({"id": &"damage", "value": 2.5})
	rune.modifiers.append({"id": &"reach", "value": 1.0})

	var restored := RuneData.from_dict(rune.to_dict())
	assert_not_null(restored)
	assert_eq(restored.element, Elements.HOA)
	assert_eq(restored.target, RuneData.Target.WEAPON)
	assert_eq(restored.modifiers.size(), 2)
	assert_eq(restored.modifiers[0].id, &"damage")
	assert_almost_eq(restored.modifiers[0].value, 2.5, 0.001)

func test_invalid_rune_data_returns_null():
	assert_null(RuneData.from_dict({}))
	assert_null(RuneData.from_dict({"element": "hoa", "target": 0, "modifiers": "invalid"}))
	assert_null(RuneData.from_dict({"element": "hoa", "target": 9, "modifiers": []}))

func test_empty_rune_describes_no_modifiers():
	var rune := RuneData.new(Elements.THO, RuneData.Target.SKILL)
	assert_eq(rune.describe_lines(), ["No modifiers"])
