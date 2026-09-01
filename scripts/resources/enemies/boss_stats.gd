class_name BossStats
extends EnemyStats
## Boss variant of EnemyStats (A.6: "Bosses: up to two elements...
## Recommended default is phase-based (element A in phase 1, B in phase
## 2)"). Everything from EnemyStats still applies to phase 1 — `element`
## IS the phase-1 element; this only adds what phase 2 changes.
##
## Dual-simultaneous attacks and self-reaction punish windows stay an
## explicit stretch goal per A.6 — not implemented here.

@export var boss_name: String = "Boss"  ## Read by the HUD's boss panel.
@export var phase_2_element: StringName = Elements.NONE

## Fraction of max_health remaining at which phase 2 triggers. 0.5 (the
## default) means "below half health" — no number is given in A.2/A.6
## for this, a reasonable mid-point pick.
@export_range(0.0, 1.0) var phase_transition_health_ratio: float = 0.5

## Optional tension escalation for phase 2 — never mutates attack_cooldown
## itself (a shared .tres resource; multiplying it in place would affect
## every instance of this same BossStats asset). Applied at runtime via
## EnemyCombatAI.attack_cooldown_multiplier instead. 1.0 = no change.
@export var phase_2_attack_cooldown_multiplier: float = 1.0
