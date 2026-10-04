class_name FlowerTurret
extends Node2D
## §4.8.6 — Spawned by The Vine's water branch (Overgrowth Rank 2, favor-Thủy).
##
## First non-hostile autonomous combatant in the project. Targets the
## nearest non-player combatant in ALL_COMBATANTS_GROUP within ~90px and
## fires at it, dealing ~5 damage per shot via bonus_damage_dealt (same
## philosophy as Wildfire chain and Ore Surge fragments — flat bonus
## damage, bypasses full reaction resolution). Does NOT join
## ALL_COMBATANTS_GROUP itself — it's an ally, not a target.
##
## NOTE: "nearest, excluding the player" is correct TODAY because every
## ALL_COMBATANTS_GROUP member is either the player or hostile. This is
## the first place that assumption is load-bearing. If allied NPCs are
## ever added, this targeting logic needs a real faction filter.
##
## Lifetime: 10–15s (randomized at spawn).
## Attack cooldown: ramps linearly from 1.2s down to 0.4s over lifetime
## (slower at first while it "wakes up", faster as it matures).
##
## Firing model: instant distance-check hit (same "no real physics AoE"
## principle as ReactionZone — consistent with §1). A short visual tracer
## is drawn for one frame to show the shot.

## ── Tuning ────────────────────────────────────────────────────────────

const LIFETIME_MIN: float = 10.0
const LIFETIME_MAX: float = 15.0
const ATTACK_RANGE: float = 90.0
const SHOT_DAMAGE: float = 5.0
const COOLDOWN_START: float = 1.2
const COOLDOWN_END: float = 0.4
const TRACER_DURATION: float = 0.08  ## How long the visual shot-line persists.

## Visual
const TURRET_RADIUS: float = 6.0
const TURRET_COLOR      := Color(0.35, 0.75, 0.35, 1.0)
const TURRET_PETAL      := Color(0.65, 0.95, 0.55, 0.9)
const TURRET_OUTLINE    := Color(0.20, 0.50, 0.20, 1.0)
const TRACER_COLOR      := Color(0.55, 0.95, 0.45, 0.75)

## ── State ─────────────────────────────────────────────────────────────

var _lifetime: float = 0.0
var _lifetime_elapsed: float = 0.0
var _cooldown_elapsed: float = 0.0

## Tracer visual — world position of last shot target, cleared after
## TRACER_DURATION seconds.
var _tracer_target: Vector2 = Vector2.ZERO
var _tracer_timer: float = 0.0
var _tracer_active: bool = false


func _ready() -> void:
	_lifetime = randf_range(LIFETIME_MIN, LIFETIME_MAX)
	# Stagger first shots when two spawn together.
	_cooldown_elapsed = randf_range(0.0, COOLDOWN_START * 0.5)
	queue_redraw()


func _process(delta: float) -> void:
	_lifetime_elapsed += delta
	if _lifetime_elapsed >= _lifetime:
		queue_free()
		return

	# Tick tracer
	if _tracer_active:
		_tracer_timer -= delta
		if _tracer_timer <= 0.0:
			_tracer_active = false
			queue_redraw()

	_cooldown_elapsed += delta
	if _cooldown_elapsed >= _current_cooldown():
		_cooldown_elapsed = 0.0
		_try_fire()


## Attack cooldown ramps linearly from COOLDOWN_START → COOLDOWN_END
## over the full lifetime.
func _current_cooldown() -> float:
	var t := clampf(_lifetime_elapsed / _lifetime, 0.0, 1.0)
	return lerpf(COOLDOWN_START, COOLDOWN_END, t)


func _try_fire() -> void:
	var target := _find_nearest_target()
	if target == null:
		return
	# Instant hit — bonus_damage_dealt, same as Wildfire chain / Rusted Chunk.
	target.bonus_damage_dealt.emit(SHOT_DAMAGE)
	# Show a one-frame tracer line toward the target.
	_tracer_target = target.global_position
	_tracer_timer = TRACER_DURATION
	_tracer_active = true
	queue_redraw()


## Finds the nearest ElementalCombatant within ATTACK_RANGE that is not
## owned by the player. Returns null if nothing is in range.
## NOTE: load-bearing assumption — "owner is not Player" is today's proxy
## for "hostile target". See class doc.
func _find_nearest_target() -> ElementalCombatant:
	var best: ElementalCombatant = null
	var best_dist := ATTACK_RANGE + 1.0
	for node in get_tree().get_nodes_in_group(ElementalCombatant.ALL_COMBATANTS_GROUP):
		var combatant := node as ElementalCombatant
		if combatant == null:
			continue
		if combatant.get_parent() is Player:
			continue
		var d := global_position.distance_to(combatant.global_position)
		if d < best_dist:
			best_dist = d
			best = combatant
	return best


## ── Visual ────────────────────────────────────────────────────────────

func _draw() -> void:
	var t := clampf(_lifetime_elapsed / _lifetime, 0.0, 1.0)
	var alpha := 1.0
	if t > 0.8:
		alpha = 1.0 - ((t - 0.8) / 0.2)

	# Stem
	var stem_col := TURRET_COLOR
	stem_col.a *= alpha
	draw_line(Vector2.ZERO, Vector2(0, -TURRET_RADIUS * 1.5), stem_col, 2.0)

	# Petals — 5 circles around the head
	var petal_col := TURRET_PETAL
	petal_col.a *= alpha
	var pr := TURRET_RADIUS * 0.45
	var head := Vector2(0, -TURRET_RADIUS * 1.5)
	for i in 5:
		var angle := (TAU / 5.0) * i - PI * 0.5
		var petal_pos := head + Vector2(cos(angle), sin(angle)) * (TURRET_RADIUS * 0.65)
		draw_circle(petal_pos, pr, petal_col)

	# Center core
	var core_col := TURRET_OUTLINE
	core_col.a *= alpha
	draw_circle(head, pr * 0.7, core_col)

	# Tracer line toward last shot target
	if _tracer_active:
		var tracer_col := TRACER_COLOR
		var fade := clampf(_tracer_timer / TRACER_DURATION, 0.0, 1.0)
		tracer_col.a = fade * alpha
		# to_local so the line is in this node's own coordinate space.
		draw_line(head, to_local(_tracer_target), tracer_col, 1.5)


## ── Static factory ────────────────────────────────────────────────────

## Spawns 2 turrets near `origin` with small random offsets so they don't
## perfectly overlap.
static func spawn_pair(scene_root: Node, origin: Vector2) -> void:
	if scene_root == null:
		return
	for i in 2:
		var turret := FlowerTurret.new()
		var offset := Vector2(randf_range(-18.0, 18.0), randf_range(-8.0, 8.0))
		if scene_root is Node2D:
			turret.position = (scene_root as Node2D).to_local(origin) + offset
		else:
			turret.position = origin + offset
		scene_root.add_child(turret)
