class_name WeaponStats
extends Resource
## Describes one weapon's combat stats and weight archetype (Appendix A.4).

enum Weight { LIGHT, MEDIUM, HEAVY }

@export var weapon_name: String = "Training Dagger"
@export var weight: Weight = Weight.LIGHT
@export var damage: float = 10.0
@export var attack_duration: float = 0.25  ## Total seconds the attack state lasts.
## Start/end of the active hitbox window, in seconds, within attack_duration.
@export var active_window: Vector2 = Vector2(0.08, 0.16)

@export var innate_element: StringName = &"none"
## "none", or a same-/different-element rune (A.4). See resolve_swing()
## for what each does — this field alone doesn't do anything by itself.
@export var rune_element: StringName = &"none"

## --- Lunge, reach, and combo (A.4's "combo style" column, made
## mechanical) — previously a single global lunge value on Player and a
## fixed hitbox size/offset baked into player.tscn, identical across
## every weapon regardless of archetype. ---
@export var lunge_speed: float = 75.0 ## Forward speed during the pre-active-window wind-up.
@export var reach: float = 7.0         ## Local x-offset of the hitbox from the wielder's centre.
@export var hitbox_radius: float = 5.0 ## Size of the hit area itself.

## Dead Cells-style combo string: pressing attack again — mid-swing, or
## in the short grace window right after — chains into the next hit
## instead of resetting. 1 means "no combo," a single swing every time;
## appropriate for a slow, high-impact heavy weapon (A.4: "Slow,
## high-impact" / "Slow, crowd control") rather than a rapid light one.
@export var combo_length: int = 1
## Grace period after a swing ends during which another attack press
## still continues the combo instead of restarting at hit 1.
@export var combo_window: float = 0.3
## Multiplies damage per successive hit in the combo, compounding —
## rewards actually following a combo through rather than only ever
## landing hit 1 on cooldown. 1.0 = no scaling.
@export var combo_damage_step_multiplier: float = 1.0

## Different-element rune only: which of the weapon's two elements the
## NEXT swing applies. Runtime-only, not exported/persisted — starts
## fresh each time the game runs. Same-element runes never touch this.
var _next_swing_uses_innate: bool = true


## Resolves the element and Charge THIS swing actually applies, per A.4's
## rune fork and the Base/+Rune Charge table:
##   Light/Medium (Hỏa/Thủy/Mộc): base 1, +1 with a same-element rune.
##   Heavy (Kim/Thổ):             base 2, +1 with a same-element rune.
## A different-element rune does NOT grant the +1 — instead it lets the
## weapon alternate between its two elements swing-to-swing, which is
## what makes "self-react" (A.2/A.4: reactions from a weapon's own two
## elements, deliberately weaker than cross-source ones) possible from a
## single weapon. Call once per attack (not per frame) — the alternation
## only advances when a swing actually happens.
func resolve_swing() -> Dictionary:
	var base_charge := 2 if weight == Weight.HEAVY else 1

	if rune_element == &"none" or rune_element == innate_element:
		# No rune, or a same-element rune. Only the latter gets +1 Charge —
		# rune_element == innate_element == "none" (both unset) falls
		# through here too, correctly adding nothing.
		var charge := base_charge
		if rune_element != &"none" and rune_element == innate_element:
			charge += 1
		return {"element": innate_element, "charge": charge}

	# Different-element rune: alternate elements, no Charge bonus — "at
	# the cost of that Charge bonus" (A.4).
	var element := innate_element if _next_swing_uses_innate else rune_element
	_next_swing_uses_innate = not _next_swing_uses_innate
	return {"element": element, "charge": base_charge}
