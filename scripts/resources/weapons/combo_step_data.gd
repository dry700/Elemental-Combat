class_name ComboStepData
extends Resource
## One hit within a weapon's combo string (Appendix A.4) — bundles WHICH
## motion this specific hit plays (style) with the numbers that motion
## needs, so a multi-hit combo can alternate direction/reach per hit
## instead of replaying an identical arc or jab every time. A weapon's
## combo_steps array (WeaponStats) is a list of these; its length IS the
## combo length now — no separate number to keep in sync with it by hand.

@export var style: WeaponStats.AttackStyle = WeaponStats.AttackStyle.SWING

## SWING only — degrees, converted to radians at the point of use
## (player.gd). Vary these per step so a combo string reads as
## diagonal-down / diagonal-up / horizontal rather than one slash
## replayed three times.
@export var swing_rotation_start_deg: float = -30.0
@export var swing_rotation_end_deg: float = 70.0

## THRUST only — how far the weapon extends from its rest position at
## the peak of the jab (player.gd's sin(swing_t * PI) curve). A later
## step can lunge further than an earlier one for a "building up" feel.
@export var thrust_extend_distance: float = 3.0
