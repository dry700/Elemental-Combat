extends Node
## Upgrade Manager — per-run Qi economy and reaction specialization state.
##
## P10a scope: Qi accumulation, reset, and the public getter API that
## ElementalCombatant.handle_hit() reads. No UI purchase flow yet —
## that lands in a later sub-phase once the data layer is verified.
##
## Constraints (§4.8):
##  - Per-run ONLY. Never touches SaveManager. Resets on run start/end.
##  - Never mutates raw Charge. Never touches reaction_resolver.gd.
##  - All upgrade reads happen AFTER Reactions.resolve() returns, as
##    flags/multipliers in ElementalCombatant — not inside the resolver.
##
## Reaction-id mapping: a "reaction pair" is a sorted Array[StringName]
## of the two elements involved (e.g. [&"hoa", &"kim"]).  Sorting both
## before lookup means callers never need to worry about order.

## ── Qi ────────────────────────────────────────────────────────────────
var qi: float = 0.0

## Called by enemy _die() for every kill — EnemyStats.qi_reward is 0.0
## for neutral/training dummies by default, so those never add Qi.
func award_qi(amount: float) -> void:
	if amount <= 0.0:
		return
	qi += amount
	qi_changed.emit(qi)

## Fully reset per-run state (called by RunManager on start and finish).
func reset() -> void:
	qi = 0.0
	_sinh_ranks.clear()
	_sinh_favored_elements.clear()
	_khac_ranks.clear()
	_weapon_might_rank = 0
	_vitality_rank = 0
	qi_changed.emit(qi)

signal qi_changed(new_total: float)

## ── Upgrade costs (§4.8 placeholder values) ──────────────────────────
const SINH_RANK1_COST: float  = 20.0
const SINH_RANK2_COST: float  = 45.0
const KHAC_RANK1_COST: float  = 20.0
const KHAC_RANK2_COST: float  = 45.0
const WEAPON_MIGHT_BASE_COST: float = 15.0
const VITALITY_BASE_COST: float     = 15.0

## ── Reaction Mastery state ────────────────────────────────────────────
## Keyed by sorted element-pair string (e.g. "hoa|kim").
## Value = 0 (unpurchased), 1 (Rank 1), 2 (Rank 2).
var _sinh_ranks: Dictionary = {}
var _khac_ranks: Dictionary = {}

## ── Stat upgrade state ────────────────────────────────────────────────
var _weapon_might_rank: int = 0
var _vitality_rank: int     = 0

## ── Internal helpers ──────────────────────────────────────────────────
static func _pair_key(pair: Array) -> String:
	var sorted: Array = pair.duplicate()
	sorted.sort()
	return "%s|%s" % [sorted[0], sorted[1]]

## ── Public getter API (§4.8.3) ────────────────────────────────────────
## All read sites are in ElementalCombatant.handle_hit() — never in
## reaction_resolver.gd.

## B. Reaction Mastery — Sinh Branching
func sinh_tier2_forced(reaction_pair: Array) -> bool:
	return _sinh_ranks.get(_pair_key(reaction_pair), 0) >= 1

func sinh_favored_element(reaction_pair: Array) -> StringName:
	if _sinh_ranks.get(_pair_key(reaction_pair), 0) < 2:
		return &""
	return _sinh_favored_elements.get(_pair_key(reaction_pair), &"")

## B. Reaction Mastery — Khắc Specialization
func khac_graze_erased(reaction_pair: Array) -> bool:
	return _khac_ranks.get(_pair_key(reaction_pair), 0) >= 1

func khac_overwhelm_forced(reaction_pair: Array) -> bool:
	return _khac_ranks.get(_pair_key(reaction_pair), 0) >= 2

## A. Weapon Might
func weapon_might_multiplier() -> float:
	return 1.0 + _weapon_might_rank * 0.1

## C. Vitality
func vitality_hp_bonus() -> float:
	return _vitality_rank * 10.0

## ── Purchase API ──────────────────────────────────────────────────────
func purchase_sinh_rank1(reaction_pair: Array) -> bool:
	var key := _pair_key(reaction_pair)
	if _sinh_ranks.get(key, 0) >= 1:
		return false
	if qi < SINH_RANK1_COST:
		return false
	qi -= SINH_RANK1_COST
	_sinh_ranks[key] = 1
	qi_changed.emit(qi)
	return true

func purchase_sinh_rank2(reaction_pair: Array, favored_element: StringName) -> bool:
	var key := _pair_key(reaction_pair)
	if _sinh_ranks.get(key, 0) < 1:
		return false
	if _sinh_ranks.get(key, 0) >= 2:
		return false
	if qi < SINH_RANK2_COST:
		return false
	qi -= SINH_RANK2_COST
	_sinh_ranks[key] = 2
	_sinh_favored_elements[key] = favored_element
	qi_changed.emit(qi)
	return true

func purchase_khac_rank1(reaction_pair: Array) -> bool:
	var key := _pair_key(reaction_pair)
	if _khac_ranks.get(key, 0) >= 1:
		return false
	if qi < KHAC_RANK1_COST:
		return false
	qi -= KHAC_RANK1_COST
	_khac_ranks[key] = 1
	qi_changed.emit(qi)
	return true

func purchase_khac_rank2(reaction_pair: Array) -> bool:
	var key := _pair_key(reaction_pair)
	if _khac_ranks.get(key, 0) < 1:
		return false
	if _khac_ranks.get(key, 0) >= 2:
		return false
	if qi < KHAC_RANK2_COST:
		return false
	qi -= KHAC_RANK2_COST
	_khac_ranks[key] = 2
	qi_changed.emit(qi)
	return true

func purchase_weapon_might() -> bool:
	var cost := WEAPON_MIGHT_BASE_COST + _weapon_might_rank * 10.0
	if qi < cost:
		return false
	qi -= cost
	_weapon_might_rank += 1
	qi_changed.emit(qi)
	return true

func purchase_vitality() -> bool:
	var cost := VITALITY_BASE_COST + _vitality_rank * 10.0
	if qi < cost:
		return false
	qi -= cost
	_vitality_rank += 1
	qi_changed.emit(qi)
	return true

## ── Save / restore (mid-run resume) ──────────────────────────────────
## Captures per-run upgrade state into a plain Dictionary suitable for
## JSON serialization in SaveManager's in_progress_run snapshot.
## Only used for mid-run quit/resume — never for cross-run persistence.
## reset() is still called on run end; this merely survives a quit mid-run.

func to_save_state() -> Dictionary:
	return {
		"qi": qi,
		"weapon_might_rank": _weapon_might_rank,
		"vitality_rank": _vitality_rank,
		"sinh_ranks": _sinh_ranks.duplicate(),
		"sinh_favored_elements": _sinh_favored_elements.duplicate(),
		"khac_ranks": _khac_ranks.duplicate(),
	}


func apply_save_state(saved: Dictionary) -> void:
	if saved.is_empty():
		return
	qi = float(saved.get("qi", 0.0))
	_weapon_might_rank = int(saved.get("weapon_might_rank", 0))
	_vitality_rank = int(saved.get("vitality_rank", 0))
	_sinh_ranks = {}
	for k in saved.get("sinh_ranks", {}):
		_sinh_ranks[str(k)] = int(saved["sinh_ranks"][k])
	_sinh_favored_elements = {}
	for k in saved.get("sinh_favored_elements", {}):
		_sinh_favored_elements[str(k)] = StringName(saved["sinh_favored_elements"][k])
	_khac_ranks = {}
	for k in saved.get("khac_ranks", {}):
		_khac_ranks[str(k)] = int(saved["khac_ranks"][k])
	qi_changed.emit(qi)

## ── Internal favored-element storage ─────────────────────────────────
var _sinh_favored_elements: Dictionary = {}