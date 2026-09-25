class_name RuneRoller
extends RefCounted
## Rolls a RuneData with one or two distinct modifiers drawn from a
## filtered catalogue. Instantiate and call set_catalogue() before roll().
## Production code uses the shared RuneRoller.default() singleton; tests
## create their own instance so catalogue state stays isolated.

const TWO_MODIFIER_CHANCE: float = 0.25

## Shared instance used by gameplay code (boss, patrol_dummy, room_controller, etc.)
## so they don't need to manage their own instance or catalogue.
static var _default_instance: RuneRoller = null

static func default() -> RuneRoller:
	if _default_instance == null:
		_default_instance = RuneRoller.new()
	return _default_instance

var _catalogue: Array[RuneModifierDef] = []

func set_catalogue(definitions: Array[RuneModifierDef]) -> void:
	_catalogue = definitions.duplicate()

func roll(element: StringName, target: RuneData.Target, rng: RandomNumberGenerator = null) -> RuneData:
	var rune := RuneData.new(element, target)
	var candidates: Array[RuneModifierDef] = []
	for definition in _catalogue:
		if definition != null and definition.applies_to_rune(target, element):
			candidates.append(definition)
	if candidates.is_empty():
		push_warning("No rune modifiers available for %s/%s" % [String(element), target])
		return rune

	var random := rng if rng != null else _default_rng()
	var count := 2 if candidates.size() > 1 and random.randf() < TWO_MODIFIER_CHANCE else 1
	while not candidates.is_empty() and rune.modifiers.size() < count:
		var index := random.randi_range(0, candidates.size() - 1)
		var definition: RuneModifierDef = candidates.pop_at(index)
		rune.modifiers.append({
			"id": definition.id,
			"value": _roll_value(definition, random),
		})
	return rune

static func _default_rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return rng

static func _roll_value(definition: RuneModifierDef, rng: RandomNumberGenerator) -> float:
	var minimum := minf(definition.value_min, definition.value_max)
	var maximum := maxf(definition.value_min, definition.value_max)
	if is_zero_approx(maximum - minimum):
		return minimum
	var value := rng.randf_range(minimum, maximum)
	if definition.value_step > 0.0:
		value = minimum + round((value - minimum) / definition.value_step) * definition.value_step
		value = clampf(value, minimum, maximum)
	return value
