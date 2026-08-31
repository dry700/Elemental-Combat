class_name EnemyStats
extends Resource
## Describes one enemy's basic combat AI (Appendix A.6). Mirrors
## WeaponStats' role for the player: authored/tuned as .tres assets,
## read by EnemyCombatAI rather than hardcoded per-enemy-script.
##
## A.6 draws exactly two tiers relevant here: "normal" (element = NONE,
## pure combat-skill encounter) and "elemental spirit" (one innate
## element, attacks apply that element to the player) — both are just
## this same resource with element set or left at NONE, no separate
## enemy class needed. Bosses (up to two elements, phase-based) are an
## explicit Sprint 3 stretch goal per A.6 and aren't covered here.

@export var aggro_range: float = 180.0   ## Player within this: enemy notices and engages.
@export var attack_range: float = 26.0   ## Player within this (and aggroed): attacks instead of chasing.
@export var chase_speed: float = 70.0    ## Ignored by stationary enemies (can_chase = false) — see EnemyCombatAI.

@export var damage: float = 8.0
@export var max_health: float = 20.0  ## New: rooms need a real "defeated" trigger — nothing had one before this (README: "TestDummy never attacks back or dies").
@export var knockback_strength: float = 220.0
@export var attack_cooldown: float = 1.2 ## Gap between one attack ending and the next telegraph starting.

## A.6: "Basic enemy attacks apply Charge 1; special/telegraphed attacks
## apply Charge 2 — mirrors the player weapon rules." Every attack here
## already telegraphs (an instant hit isn't fair without player
## counterplay) — "special" means a longer telegraph and the higher
## Charge that comes with it.
@export var element: StringName = Elements.NONE
@export var telegraph_duration: float = 0.35        ## Basic attack — Charge 1.
@export var special_telegraph_duration: float = 0.7 ## Special attack — Charge 2.
@export var active_window: float = 0.15              ## How long the hitbox stays on after telegraph ends.

## Every Nth attack (1-indexed) is a special instead of basic — a fixed
## rhythm, not random chance, so a player fighting the same enemy
## repeatedly can learn and react to it. A.6's "natural tutorial for one
## reaction" only works if the telegraph is learnable, not a coin flip.
@export var special_attack_every: int = 3
