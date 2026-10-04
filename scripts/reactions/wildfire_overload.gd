class_name WildfireOverload
extends RefCounted
## §4.8.7 — Per-target Wildfire Overload state (Wildfire Rank 2, favor-Hỏa).
##
## Lives as a field on ElementalCombatant, ticked alongside the other
## effect components. Only active when the player has purchased
## sinh_favored_element(Moc+Hoa) == HOA (Wildfire favor-Hỏa).
##
## Lifecycle:
##   - A fresh Wildfire Sinh trigger on this target calls reset() — new
##     base application always wins (§1 refresh-only philosophy).
##   - Any Hỏa hit landing while the target already carries Hỏa status
##     calls increment(source). Level caps at 3, sustain timer restarts.
##   - tick(delta) counts down the sustain timer. When it expires,
##     level decrements by 1 and timer restarts at 10s for the new level.
##     Repeats down to 0 (inactive).
##   - Level reaching 3 triggers auto-explode via the `exploded` signal —
##     owner (ElementalCombatant) connects this to run the AoE burst.
##
## DoT scaling: +1.5 per level on top of Wildfire's base (2.5/3.5).
## Call dot_bonus() after incrementing to get the additive amount.

signal exploded(source: Node)  ## Fired when level hits 3. Owner runs the AoE.

const MAX_LEVEL: int = 3
const SUSTAIN_TIME: float = 10.0
const DOT_BONUS_PER_LEVEL: float = 1.5
const EXPLODE_DAMAGE: float = 15.0
const EXPLODE_RADIUS: float = 55.0

var level: int = 0
var _sustain_timer: float = 0.0
var _source: Node = null  ## Last attacker who contributed a hit.
var active: bool = false


## Called by ElementalCombatant.tick(delta).
func tick(delta: float) -> void:
	if not active:
		return
	_sustain_timer -= delta
	if _sustain_timer <= 0.0:
		level -= 1
		if level <= 0:
			level = 0
			active = false
		else:
			_sustain_timer = SUSTAIN_TIME  # Restart at the new (lower) level.


## Called when a Hỏa hit lands on a target that already carries Hỏa status.
## Returns true if the increment triggered an explosion (level reached 3).
func increment(source: Node) -> bool:
	_source = source
	level = mini(level + 1, MAX_LEVEL)
	_sustain_timer = SUSTAIN_TIME
	active = true
	if level >= MAX_LEVEL:
		exploded.emit(_source)
		return true
	return false


## Called when a fresh Wildfire Sinh trigger lands on this target.
## Resets level to 0 per §1's refresh-only philosophy.
func reset() -> void:
	level = 0
	_sustain_timer = 0.0
	_source = null
	active = false


## Additive DoT bonus on top of Wildfire's base numbers.
## Call this after incrementing to get the current bonus.
func dot_bonus() -> float:
	return level * DOT_BONUS_PER_LEVEL
