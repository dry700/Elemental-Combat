class_name Elements
extends RefCounted
## Ngũ Hành element vocabulary (Appendix A.1) — single source of truth for
## element StringNames. Static-only; never instantiated.

const NONE: StringName = &"none"
const HOA: StringName = &"hoa"    # Fire
const THUY: StringName = &"thuy"  # Water
const MOC: StringName = &"moc"    # Wood
const KIM: StringName = &"kim"    # Metal
const THO: StringName = &"tho"    # Earth

const ALL: Array[StringName] = [HOA, THUY, MOC, KIM, THO]

## Sinh (Generating): key generates value. Mộc→Hỏa→Thổ→Kim→Thủy→Mộc.
const SINH_CYCLE: Dictionary = {
	MOC: HOA, HOA: THO, THO: KIM, KIM: THUY, THUY: MOC,
}

## Khắc (Overcoming): key overcomes value. Mộc→Thổ→Thủy→Hỏa→Kim→Mộc.
const KHAC_CYCLE: Dictionary = {
	MOC: THO, THO: THUY, THUY: HOA, HOA: KIM, KIM: MOC,
}

## Checked both directions — the reaction table (A.2) lists each pair once,
## unordered, with one named reaction regardless of which element landed
## first. Worth confirming that matches your intent: Hỏa-on-Thủy and
## Thủy-on-Hỏa both resolve as the same "Douse" pairing.
static func is_sinh_pair(a: StringName, b: StringName) -> bool:
	return SINH_CYCLE.get(a) == b or SINH_CYCLE.get(b) == a

static func is_khac_pair(a: StringName, b: StringName) -> bool:
	return KHAC_CYCLE.get(a) == b or KHAC_CYCLE.get(b) == a


## For a Sinh pair (order-independent, e.g. from Reactions.ResolutionResult),
## returns the SPECIFIC element the generation produces, per the fixed
## Ngũ Hành cycle direction — e.g. {Thủy, Mộc} always returns Mộc (Thủy
## sinh Mộc), regardless of which one was the incoming hit vs. already on
## the target. The pair itself is unordered (is_sinh_pair matches either
## direction), but the cycle direction it represents is not — Thủy never
## generates from Mộc, only the other way. Returns NONE if the pair isn't
## a valid Sinh pair at all.
static func sinh_generated_element(pair: Array[StringName]) -> StringName:
	if pair.size() != 2:
		return NONE
	if SINH_CYCLE.get(pair[0]) == pair[1]:
		return pair[1]
	if SINH_CYCLE.get(pair[1]) == pair[0]:
		return pair[0]
	return NONE
	
## Order-independent check against a [a, b]-shaped reaction_pair, e.g. from
## Reactions.ResolutionResult — used to identify which specific named
## reaction (A.2) a resolved outcome corresponds to.
static func pair_is(pair: Array[StringName], a: StringName, b: StringName) -> bool:
	return pair.size() == 2 and ((pair[0] == a and pair[1] == b) or (pair[0] == b and pair[1] == a))
