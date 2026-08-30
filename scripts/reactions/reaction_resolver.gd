class_name Reactions
extends RefCounted
## Sinh/Khắc resolver (A.3) — pure decision logic. Identifies the outcome
## CATEGORY only, not each of the 10 named reactions' unique effects.
## NOT wired in: rune Charge bonus, ICD, Break-Free, skills.

enum Outcome {
	NO_REACTION,     ## No existing status, or same element re-applied (refresh only).
	SINH_TIER_1,     ## Generating, min(charge) == 1.
	SINH_TIER_2,     ## Generating, min(charge) >= 2.
	KHAC_FULL_CLEAR,
	KHAC_PARTIAL,
	KHAC_THUA, ## Tương Thừa (乘) — overwhelm. incoming = 3, remaining = 1.
	KHAC_VU,   ## Tương Vũ (侮) — rebel. incoming = 1, remaining = 3.
}

class ResolutionResult:
	var outcome: Outcome
	var reaction_pair: Array[StringName]
	func _init(p_outcome: Outcome, p_pair: Array[StringName] = []) -> void:
		outcome = p_outcome
		reaction_pair = p_pair

static func resolve(incoming_element: StringName, incoming_charge: int, target_status: ElementalStatus) -> ResolutionResult:
	if not target_status.has_status():
		return ResolutionResult.new(Outcome.NO_REACTION)
	if target_status.element == incoming_element:
		return ResolutionResult.new(Outcome.NO_REACTION)

	var pair: Array[StringName] = [incoming_element, target_status.element]

	if Elements.is_sinh_pair(incoming_element, target_status.element):
		var tier_charge: int = mini(incoming_charge, target_status.charge)
		var outcome := Outcome.SINH_TIER_1 if tier_charge <= 1 else Outcome.SINH_TIER_2
		return ResolutionResult.new(outcome, pair)

	if Elements.is_khac_pair(incoming_element, target_status.element):
		return ResolutionResult.new(_resolve_khac(incoming_charge, target_status.charge), pair)

	return ResolutionResult.new(Outcome.NO_REACTION)

## The 3x3 grid from A.3.
static func _resolve_khac(incoming: int, remaining: int) -> Outcome:
	if incoming == 3 and remaining == 1:
		return Outcome.KHAC_THUA
	if incoming == 1 and remaining == 3:
		return Outcome.KHAC_VU
	if incoming >= remaining:
		return Outcome.KHAC_FULL_CLEAR
	return Outcome.KHAC_PARTIAL
