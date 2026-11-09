class_name BossStats
extends EnemyStats
## Boss variant of EnemyStats (A.6: "Bosses: up to two elements...
## Recommended default is phase-based (element A in phase 1, B in phase
## 2)"). Everything from EnemyStats still applies to phase 1 — `element`
## IS the phase-1 element; this only adds what phase 2 changes.
##
## Dual-simultaneous attacks and self-reaction punish windows stay an
## explicit stretch goal per A.6 — not implemented here.

@export var boss_name: String = "Boss"
@export var phase_2_element: StringName = Elements.NONE

## Base armor for the boss's ElementalCombatant. Boss-only, so normal
## EnemyStats assets are untouched. Read directly by Boss._ready().
@export var armor: float = 10.0
## Charge of the boss's innate element status (phase 1 and 2).
@export_range(1, 3) var innate_charge: int = 1

## Fraction of max_health remaining at which phase 2 triggers. 0.5 (the
## default) means "below half health" — no number is given in A.2/A.6
## for this, a reasonable mid-point pick.
@export_range(0.0, 1.0) var phase_transition_health_ratio: float = 0.5

## Optional tension escalation for phase 2 — never mutates attack_cooldown
## itself (a shared .tres resource; multiplying it in place would affect
## every instance of this same BossStats asset). Applied at runtime via
## EnemyCombatAI.attack_cooldown_multiplier instead. 1.0 = no change.
@export var phase_2_attack_cooldown_multiplier: float = 1.0

## ── Wave & Crowd Management Settings (plan-boss.md) ────────────────────
## Health fractions at which waves trigger (e.g. [0.75, 0.5, 0.25]).
@export var wave_thresholds: Array[float] = []
## Duration of the boss's invulnerable retreat window per wave.
@export var passive_window_duration: float = 12.0
## Height above the retreat anchor that the boss hovers during the passive window.
@export_range(0.0, 300.0, 1.0) var passive_flight_height: float = 100.0
## Speed used to reach the center anchor and its hover position.
@export_range(1.0, 400.0, 1.0) var passive_flight_speed: float = 120.0
## Duration the boss stays staggered if the player clears the wave early.
@export var early_clear_stagger_duration: float = 2.0
## Damage taken multiplier while staggered from an early clear.
@export var early_clear_damage_multiplier: float = 1.5

## ── Bull Charge Settings ───────────────────────────────────────────────
@export var charge_enabled: bool = false
@export var charge_telegraph_duration: float = 0.8
@export var charge_speed: float = 220.0
@export var charge_max_distance: float = 450.0
@export var charge_damage: float = 14.0
@export var charge_innate_charge: int = 2
@export var charge_cooldown: float = 8.0
@export var charge_wall_stun_duration: float = 1.5
@export var charge_stun_damage_multiplier: float = 1.5

## ── Ground Shockwave Settings ──────────────────────────────────────────
@export var shockwave_enabled: bool = false
@export var shockwave_telegraph_duration: float = 0.6
@export var shockwave_speed: float = 130.0
@export var shockwave_damage: float = 8.0
@export var shockwave_innate_charge: int = 1
@export var shockwave_cooldown: float = 4.0

## ── Ranged Rock Throw Settings ─────────────────────────────────────────
@export var rock_throw_enabled: bool = false
@export var rock_damage: float = 6.0
@export var rock_speed: float = 200.0
@export var rock_cooldown: float = 5.0
@export var rock_telegraph_duration: float = 0.65
@export var rock_aim_distance: float = 190.0
