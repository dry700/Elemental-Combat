class_name WeaponStats
extends Resource
## Describes one weapon's combat stats and weight archetype (Appendix A.4).

enum Weight { LIGHT, MEDIUM, HEAVY }
enum AttackStyle { SWING, THRUST, SHOOT }

enum PerfectCondition {
	NONE,
	STREAK,
	TARGET_SLOWED,
	TARGET_DISABLED,
	FINISHER,
	PLUNGE,
	LONG_RANGE,
	DODGE,
	AIRBORNE,
	CLOSE_RANGE,
	TIP,
	LOW_HEALTH,
}

@export var weapon_name: String = "Training Dagger"
@export var weapon_texture: Texture2D ## Used for the player's attack animation (horizontal).
@export var weapon_icon: Texture2D ## Used for the HUD and item drops (diagonal/square).
@export var weight: Weight = Weight.LIGHT
@export var damage: float = 10.0
@export var perfect_condition: PerfectCondition = PerfectCondition.NONE
@export_range(1.5, 2.0) var perfect_multiplier: float = 1.5
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

@export var projectile_speed: float = 240.0    ## SHOOT only.
@export var projectile_lifetime: float = 0.6   ## SHOOT only. Range ≈ speed × lifetime.
@export_range(1, 12, 1) var projectile_count: int = 1 ## Number of arrows in a SHOOT volley.
@export_range(0.0, 60.0, 0.5) var projectile_spread_degrees: float = 0.0 ## Total cone width for a SHOOT volley.

## Grace period after a swing ends during which another attack press
## still continues the combo instead of restarting at hit 1.
@export var combo_window: float = 0.3
## Multiplies damage per successive hit in the combo, compounding —
## rewards actually following a combo through rather than only ever
## landing hit 1 on cooldown. 1.0 = no scaling.
@export var combo_damage_step_multiplier: float = 1.0



## Each entry is one hit in the combo string. Array size IS the combo
## length — the old standalone combo_length field is gone specifically
## because it could silently drift out of sync with an array of a
## different size; there's now exactly one number to look at, not two
## that have to agree. The single old attack_style field is gone for
## the same reason, one level up: every weapon now defines its combo
## shape explicitly, even single-hit ones (see training_hammer.tres for
## the "just one entry" case).
@export var combo_steps: Array[ComboStepData] = [ComboStepData.new()]

## Different-element rune only: which of the weapon's two elements the
## NEXT swing applies. Runtime-only, not exported/persisted — starts
## fresh each time the game runs. Same-element runes never touch this.
var _next_swing_uses_innate: bool = true
	
func get_display_dps() -> float:
	var total := 0.0
	for i in combo_steps.size():
		total += damage * pow(combo_damage_step_multiplier, i)
	return total / (combo_steps.size() * attack_duration)

func get_perfect_condition_text() -> String:
	match perfect_condition:
		PerfectCondition.STREAK:
			return "6th landed hit in a streak"
		PerfectCondition.TARGET_SLOWED:
			return "Target is slowed"
		PerfectCondition.TARGET_DISABLED:
			return "Target is disabled"
		PerfectCondition.FINISHER:
			return "Combo finisher"
		PerfectCondition.PLUNGE:
			return "Plunge impact from a high apex"
		PerfectCondition.LONG_RANGE:
			return "Long distance hit"
		PerfectCondition.DODGE:
			return "Shortly after dodge"
		PerfectCondition.AIRBORNE:
			return "Attacking while airborne"
		PerfectCondition.CLOSE_RANGE:
			return "Point-blank range"
		PerfectCondition.TIP:
			return "Target near the tip of reach"
		PerfectCondition.LOW_HEALTH:
			return "Target below 30% health"
		_:
			return ""

func get_projectile_angles() -> Array[float]:
	var angles: Array[float] = []
	var count := maxi(1, projectile_count)
	for index in count:
		var angle := 0.0
		if count > 1:
			angle = lerpf(-projectile_spread_degrees * 0.5, projectile_spread_degrees * 0.5, float(index) / float(count - 1))
		angles.append(angle)
	return angles

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
func resolve_swing(slot_rune: RuneData = null) -> Dictionary:
	var base_charge := 2 if weight == Weight.HEAVY else 1
	var effective_rune_element := slot_rune.element if slot_rune != null else rune_element

	if effective_rune_element == &"none" or effective_rune_element == innate_element:
		# No rune, or a same-element rune. Only the latter gets +1 Charge —
		# effective_rune_element == innate_element == "none" (both unset) falls
		# through here too, correctly adding nothing.
		var charge := base_charge
		if effective_rune_element != &"none" and effective_rune_element == innate_element:
			charge += 1
		return {"element": innate_element, "charge": charge}

	# Different-element rune: alternate elements, no Charge bonus — "at
	# the cost of that Charge bonus" (A.4).
	var element := innate_element if _next_swing_uses_innate else effective_rune_element
	_next_swing_uses_innate = not _next_swing_uses_innate
	return {"element": element, "charge": base_charge}
