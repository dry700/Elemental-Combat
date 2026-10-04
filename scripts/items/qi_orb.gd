class_name QiOrb
extends Area2D
## A floating Qi orb that drops from enemies on death and gets magnetically
## attracted toward the player once within range — Dead Cells style.
##
## Lifecycle:
##   1. Enemy dies → QiOrb.spawn_burst() creates N orbs at the death position.
##   2. Each orb pops out with a random upward impulse (physics phase).
##   3. Once the orb loses upward momentum and "lands" (or after a brief
##      settle time), it bobs gently in place.
##   4. When the player enters the attraction radius, the orb accelerates
##      toward them. On contact → UpgradeManager.award_qi(), queue_free().
##
## Uses _physics_process for all motion — no RigidBody, keeps it simple
## and deterministic like the rest of the project's pickups.

## ── Tuning ────────────────────────────────────────────────────────────

## How much Qi this single orb is worth.
var qi_value: float = 1.0

## Initial pop velocity — randomized per-orb in spawn_burst().
var _velocity: Vector2 = Vector2.ZERO

## Physics phase: the orb is still bouncing/falling after the initial pop.
var _settled: bool = false
## Gravity applied during the physics (unsettled) phase.
const GRAVITY: float = 400.0
## Friction once the orb lands (decelerates horizontal slide).
const GROUND_FRICTION: float = 600.0
## Below this speed the orb is considered settled.
const SETTLE_SPEED: float = 10.0
## Maximum time before forcing settle (prevents orbs flying forever).
const MAX_UNSETTLE_TIME: float = 1.2

## Attraction phase: the radius starts small and grows over time after
## settling, so distant orbs eventually fly to you even if you don't
## walk over them — same "magnetic vacuum" feel as Dead Cells.
const ATTRACT_RADIUS_START: float = 30.0
const ATTRACT_RADIUS_MAX: float = 300.0
## How many seconds after settling for the radius to reach max.
const ATTRACT_RADIUS_GROW_TIME: float = 6.0
## How fast the orb accelerates toward the player during attraction.
const ATTRACT_ACCELERATION: float = 500.0
## Terminal attraction speed — caps so the orb doesn't overshoot.
const ATTRACT_MAX_SPEED: float = 320.0
## Distance at which the orb is "collected" (triggers award).
const COLLECT_RADIUS: float = 6.0

## Orbital / spiral motion — orbs curve around the player as they
## approach, giving a brief flourish before spiraling in to collect.
## Decays both by distance AND by time so orbs never get stuck in orbit.
const ORBIT_STRENGTH: float = 0.35   ## Fraction of radial accel applied tangentially (initial).
const ORBIT_DECAY_DIST: float = 60.0  ## Below this distance, orbit weakens → orb spirals in.
const ORBIT_FADE_TIME: float = 0.8    ## Seconds after attraction starts before orbit fully fades.

## Bob (settled, waiting for player to come near).
const BOB_SPEED: float = 3.0
const BOB_HEIGHT: float = 2.0

## Visual
const ORB_RADIUS: float = 3.0
const ORB_COLOR := Color(0.3, 0.85, 1.0, 0.9)       ## Cyan-ish glow
const ORB_COLOR_INNER := Color(0.7, 0.95, 1.0, 1.0)  ## Brighter core
const ORB_OUTLINE := Color(0.15, 0.4, 0.55, 0.7)

## ── State ─────────────────────────────────────────────────────────────

var _unsettle_timer: float = 0.0
var _settled_time: float = 0.0   ## Time since settling — drives growing attract radius.
var _bob_base_y: float = 0.0
var _attracting: bool = false
var _attract_time: float = 0.0  ## Time since attraction started — orbit fades over time.
var _player_ref: Player = null
var _orbit_dir: float = 1.0  ## +1 = counter-clockwise, -1 = clockwise (randomized per orb).
## Lifetime self-destruct — if nobody picks this up, remove after a while
## so the scene doesn't accumulate hundreds of stale orbs.
const LIFETIME: float = 30.0
var _lifetime_remaining: float = LIFETIME


func _ready() -> void:
	add_to_group("qi_orbs")
	_orbit_dir = 1.0 if randf() < 0.5 else -1.0
	# Area2D setup — detects player body overlap.
	collision_layer = 0
	collision_mask = 1  # Same mask as other pickups (player is layer 1).
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = COLLECT_RADIUS
	shape.shape = circle
	add_child(shape)

	# Initialize bob baseline from actual local position now that the node
	# is in the scene tree. global_position was set before add_child, so
	# Godot has already converted it to the correct local position here.
	# Setting _bob_base_y at spawn time (before entering the tree) would use
	# raw world-Y, which is wrong when scene_root has a non-zero global Y.
	_bob_base_y = position.y

	body_entered.connect(_on_body_entered)
	queue_redraw()


func _physics_process(delta: float) -> void:
	_lifetime_remaining -= delta
	if _lifetime_remaining <= 0.0:
		queue_free()
		return

	# ── Phase 1: Physics pop ──────────────────────────────────────────
	if not _settled:
		_unsettle_timer += delta
		_velocity.y += GRAVITY * delta
		position += _velocity * delta

		# Simple ground check — don't fall below spawn level + some margin.
		# (Orbs don't need real collision with terrain; they just need to
		# look like they "land" near where they spawned.)
		if _velocity.y > 0.0 and position.y >= _bob_base_y:
			position.y = _bob_base_y
			_velocity.y = -_velocity.y * 0.3  # Small bounce
			_velocity.x *= 0.5
			if absf(_velocity.y) < SETTLE_SPEED:
				_settle()

		if _unsettle_timer >= MAX_UNSETTLE_TIME:
			_settle()
		queue_redraw()
		return

	# ── Phase 2: Settled — bob or attract ─────────────────────────────
	_settled_time += delta

	var player := _find_player()
	if player == null:
		# Bob in place
		position.y = _bob_base_y + sin(Time.get_ticks_msec() / 1000.0 * BOB_SPEED) * BOB_HEIGHT
		queue_redraw()
		return

	var to_player := player.global_position - global_position
	var dist := to_player.length()

	if dist <= COLLECT_RADIUS:
		_collect()
		return

	# Attraction radius grows over time — orbs left behind will
	# eventually pull toward the player no matter how far they walk.
	var grow_t := clampf(_settled_time / ATTRACT_RADIUS_GROW_TIME, 0.0, 1.0)
	var current_attract_radius := lerpf(ATTRACT_RADIUS_START, ATTRACT_RADIUS_MAX, grow_t)

	if dist <= current_attract_radius or _attracting:
		if not _attracting:
			_attracting = true
			# One-time tangential kick for the initial curve flourish.
			var tangent := Vector2(-to_player.normalized().y, to_player.normalized().x) * _orbit_dir
			_velocity += tangent * 60.0

		_attract_time += delta
		var dir := to_player.normalized()

		# Steer existing velocity toward the player — this actively
		# kills any sideways drift instead of letting it accumulate.
		# Steering gets stronger over time: gentle curve at first,
		# then locks on hard so orbs always converge.
		var steer_strength := clampf(_attract_time / 0.5, 0.3, 1.0)
		_velocity = _velocity.lerp(dir * _velocity.length(), steer_strength * 8.0 * delta)

		# Accelerate toward the player on top of the steering.
		_velocity += dir * ATTRACT_ACCELERATION * delta

		if _velocity.length() > ATTRACT_MAX_SPEED:
			_velocity = _velocity.normalized() * ATTRACT_MAX_SPEED
		position += _velocity * delta

		# Re-check after moving
		if global_position.distance_to(player.global_position) <= COLLECT_RADIUS:
			_collect()
			return
	else:
		# Bob in place
		position.y = _bob_base_y + sin(Time.get_ticks_msec() / 1000.0 * BOB_SPEED) * BOB_HEIGHT

	queue_redraw()


func _settle() -> void:
	_settled = true
	_velocity = Vector2.ZERO
	_bob_base_y = position.y


func _collect() -> void:
	UpgradeManager.award_qi(qi_value)
	queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		_collect()


func _find_player() -> Player:
	if _player_ref != null and is_instance_valid(_player_ref):
		return _player_ref
	var p = get_tree().get_first_node_in_group("player")
	if p is Player:
		_player_ref = p
		return _player_ref
	return null


func _draw() -> void:
	# Fade out in the last 5 seconds of lifetime
	var alpha := 1.0
	if _lifetime_remaining < 5.0:
		alpha = clampf(_lifetime_remaining / 5.0, 0.0, 1.0)
		# Blink in the last 2 seconds
		if _lifetime_remaining < 2.0 and fmod(_lifetime_remaining, 0.3) < 0.15:
			alpha *= 0.3

	var outer := ORB_COLOR
	outer.a *= alpha
	var inner := ORB_COLOR_INNER
	inner.a *= alpha
	var outline := ORB_OUTLINE
	outline.a *= alpha

	draw_circle(Vector2.ZERO, ORB_RADIUS, outer)
	draw_circle(Vector2.ZERO, ORB_RADIUS * 0.5, inner)
	draw_arc(Vector2.ZERO, ORB_RADIUS, 0, TAU, 16, outline, 1.0)


## ── Static factory ───────────────────────────────────────────────────
## Spawns a burst of qi orbs at a world position, splitting the total
## reward into individual orbs. Called by every enemy's _die() method.
##
## Usage:
##   QiOrb.spawn_burst(get_parent(), global_position, enemy_stats.qi_reward)
##
## total_qi:  the full reward amount (e.g. 10.0)
## The burst splits into several small orbs (3-7 depending on value),
## each worth total_qi / count. More qi = more orbs = more satisfying.
static func spawn_burst(scene_root: Node, origin: Vector2, total_qi: float) -> void:
	if total_qi <= 0.0 or scene_root == null:
		return

	# Scale orb count with reward size, clamped to a sensible range.
	var count := clampi(int(total_qi / 3.0), 2, 8)
	var per_orb := total_qi / float(count)

	# Convert world-space origin to scene_root's local space so we can assign
	# position (not global_position) before the node enters the tree.
	# global_position has no effect on a node that isn't in the scene tree yet,
	# so we must use local position instead.
	var local_origin: Vector2
	if scene_root is Node2D:
		local_origin = scene_root.to_local(origin)
	else:
		local_origin = origin  # Non-Node2D roots have no canvas transform.

	for i in count:
		var orb := QiOrb.new()
		orb.qi_value = per_orb
		orb.position = local_origin

		# Random upward pop — spread horizontally, always upward.
		var angle := randf_range(-PI * 0.75, -PI * 0.25)  # -135° to -45° (upward arc)
		var speed := randf_range(60.0, 130.0)
		orb._velocity = Vector2(cos(angle), sin(angle)) * speed
		# _bob_base_y is initialized in _ready() from position.y once the node
		# is in the scene tree.

		scene_root.add_child.call_deferred(orb)

