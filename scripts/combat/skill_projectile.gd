class_name SkillProjectile
extends BaseProjectile
## Ignite Dart's projectile (A.5) — replaces the skill's former instant
## hitscan resolution (Player picked a target within cast_range,
## ElementalCombatant.cast_apply_enemy() resolved against it the same
## frame) with an actual traveling shot. Distinct from Projectile
## (Ore Surge's fragments): that class deliberately BYPASSES
## handle_hit()'s full Sinh/Khắc resolution and pierces multiple
## targets, per A.2's own "spreads Metal status to each hit" wording —
## Ignite Dart is a single-target apply meant to behave "through the
## full Sinh/Khắc pipeline, same as a weapon hit" (SkillData.Function's
## own doc comment for APPLY_SINGLE_TARGET), so this stops at its first
## hit and calls the real handle_hit(), exactly like cast_apply_enemy
## already did — just delayed by travel time, and now capable of
## missing if nothing's in its path.
##
## ICD is bypassed on hit, same as cast_apply_enemy always bypassed it
## (A.3: "skills... self-limit via their own cooldowns").
##
## Travel/lifetime/collision plumbing lives in BaseProjectile now — this
## class only owns what's specific to Ignite Dart: single-hit resolution
## through the real reaction pipeline, and its own zigzag (Hỏa) visual.


const DART_COLOR: Color = Color(0.95, 0.35, 0.25)  ## Hỏa's tint (ElementIndicator/ReactionZone palette) — Ignite Dart is always Hỏa.
const GLYPH_HALF_SIZE: float = 5.0

var _spent: bool = false  ## Guards against resolving a second hit once this dart has already connected.


func _init() -> void:
	radius = 4.0  ## Was DART_RADIUS — kept as this class's own default; still overridable per spawn call.

func _resolve_hit(hurtbox: Hurtbox) -> void:
	if _spent:
		return

	var owner_node := hurtbox.owner
	if owner_node == null:
		return
	var combatant := owner_node.get("elemental") as ElementalCombatant
	if combatant == null:
		return

	_spent = true
	var hit_data := HitData.new(0.0, Vector2.ZERO, attacker)
	hit_data.element = element
	hit_data.charge = charge
	combatant.handle_hit(hit_data, true)  ## ICD bypassed — same as cast_apply_enemy.
	queue_free()


func _draw() -> void:
	# Hỏa's own zigzag pattern glyph (A.1), same shape ElementIndicator
	# draws for the status icon — kept upright regardless of travel
	# direction, same reasoning ElementIndicator never rotates: the
	# glyph's job is accessible identification, not directional framing.
	var s := GLYPH_HALF_SIZE
	var pts := PackedVector2Array([
		Vector2(-s, -s), Vector2(s * 0.15, -s * 0.1), Vector2(-s * 0.15, s * 0.1), Vector2(s, s),
	])
	draw_polyline(pts, DART_COLOR, 1.6)
