class_name Projectile
extends BaseProjectile
## Ore Surge's "armor-shredding projectiles pierce multiple enemies" (A.2)
## — a genuinely traveling, piercing hit. Unlike Hitbox (one swing, one
## resolved reaction, then disabled), a Projectile keeps flying after its
## first hit and can strike several different combatants along its path,
## applying an armor shred + the generated element to each one exactly
## once. Deliberately bypasses HitData/handle_hit()'s full reaction
## resolution (ICD, Sinh/Khắc matching) — Ore Surge already resolved as
## its OWN Sinh reaction on the primary target; each pierced enemy just
## receives that reaction's stated "spreads Metal status to each hit"
## clause directly, not a second independent reaction check.
##
## Travel/lifetime/collision plumbing lives in BaseProjectile now — this
## class only owns what's specific to Ore Surge: the pierce-and-shred
## hit resolution, and its own diamond (Kim) visual.

@export var shred_amount: float = 2.0
## §4.8.9 — flat bonus damage emitted after the shred/status apply.
## Default 0 means normal Ore Surge fragments are completely unaffected.
@export var damage_amount: float = 0.0
## §4.8.10 Armor Sunder — bonus damage emitted when hitting a target whose
## armor is already <= 0 (shred would be wasted). Default 0 = inactive.
@export var sunder_bonus_damage: float = 0.0
## §4.8.10 Caltrops — spawn a Caltrop hazard at current position on expiry.
## Default false = normal behavior, fragment simply queue_free()s.
@export var leaves_hazard_on_expiry: bool = false

const FRAGMENT_COLOR: Color = Color(0.82, 0.82, 0.88)  ## Kim's tint (ElementIndicator/ReactionZone palette).
const FRAGMENT_SIZE: float = 5.0

var _already_hit: Array[Hurtbox] = []


func _init() -> void:
	radius = 2.5  ## Was FRAGMENT_SIZE — kept as this class's own default; still overridable per spawn call.	

func _resolve_hit(hurtbox: Hurtbox) -> void:
	if hurtbox in _already_hit:
		return  # Already pierced this one — keep flying, don't double-apply.
	_already_hit.append(hurtbox)

	var owner_node := hurtbox.owner
	if owner_node == null:
		return
	var combatant := owner_node.get("elemental") as ElementalCombatant
	if combatant == null:
		return

	# §4.8.10 Armor Sunder: check armor BEFORE applying shred.
	# If already at zero, skip the wasted shred and emit sunder bonus instead.
	# Status applies either way. Only a fragment landing on an *already*-zero-
	# armor target gets the bonus — the one that brought it to 0 does not.
	if sunder_bonus_damage > 0.0 and combatant.armor <= 0.0:
		combatant.bonus_damage_dealt.emit(sunder_bonus_damage)
	else:
		combatant.armor = maxf(combatant.armor - shred_amount, 0.0)

	combatant.status.apply(element, charge)
	if damage_amount > 0.0:
		combatant.bonus_damage_dealt.emit(damage_amount)


## §4.8.10 Caltrops — if leaves_hazard_on_expiry is set, drop a Caltrop at
## current position before freeing. Falls back to queue_free() either way.
func _on_expired() -> void:
	if leaves_hazard_on_expiry:
		var CaltropScript := load("res://scripts/reactions/caltrop.gd")
		if CaltropScript:
			var scene_root := get_tree().current_scene
			if scene_root != null:
				CaltropScript.spawn(scene_root, global_position)
	queue_free()


func _draw() -> void:
	# Small diamond — Kim's own A.1 pattern glyph, reused here so a
	# fragment reads as "metal" the same way the status indicator does.
	var s := radius
	var pts := PackedVector2Array([Vector2(0, -s), Vector2(s, 0), Vector2(0, s), Vector2(-s, 0), Vector2(0, -s)])
	draw_colored_polygon(pts, FRAGMENT_COLOR)
