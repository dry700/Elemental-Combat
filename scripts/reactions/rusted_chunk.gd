class_name RustedChunk
extends Node2D
## §4.8.5 — Condensation Rank 2 (favor-Kim) drop.
##
## First object that is both a projectile and a pickup — doesn't fit
## BaseProjectile (no LANDED state) or WeaponPickup (no FLYING phase).
## New standalone class following the same "built entirely in code" rule
## every other combat object in this project uses.
##
## State machine: FLYING → LANDED → (picked up | decayed)
##
## FLYING:
##   Travels in the direction opposite the hit's knockback vector (the
##   "knocked loose" feel). Checks Hurtbox Area2Ds every physics frame —
##   same collision_mask = 2 convention as BaseProjectile. On hitting an
##   enemy Hurtbox: emits bonus_damage_dealt(8.0) on that combatant and
##   queue_free()s. Does NOT hit the player (the player triggered this
##   reaction — it's their reward). Lifetime 0.6s; if no hit occurs,
##   transitions to LANDED instead of freeing.
##
## LANDED:
##   Switches to collision_mask = 1 (player body layer, same as
##   WeaponPickup). Auto-pickup on body_entered — no F-press needed
##   (passive proc reward, not an equipment choice). On pickup: calls
##   player.elemental.armor_buff.apply(8.0, 15.0). If the 12s landed
##   timer runs out unpicked, queue_free()s with no effect.

## ── State ─────────────────────────────────────────────────────────────

enum State { FLYING, LANDED }
var _state: State = State.FLYING

## Set by spawn() before add_child — the combatant that triggered the
## reaction. Its player owner is excluded from FLYING hits; the chunk
## travels AWAY from them.
var _origin_combatant: ElementalCombatant = null

## FLYING phase
const SPEED: float = 140.0
const FLYING_LIFETIME: float = 0.6
const HIT_DAMAGE: float = 8.0
var _direction: Vector2 = Vector2.RIGHT
var _flying_timer: float = 0.0

## LANDED phase
const LANDED_LIFETIME: float = 12.0
const ARMOR_BUFF_AMOUNT: float = 8.0
const ARMOR_BUFF_DURATION: float = 15.0
var _landed_timer: float = 0.0

## Collision shape — swapped between phases.
var _collision_shape: CollisionShape2D

## Visual constants (rusted Kim diamond, slightly larger than a fragment).
const CHUNK_RADIUS: float = 5.0
const CHUNK_COLOR := Color(0.55, 0.45, 0.35, 1.0)        ## Rust-brown
const CHUNK_OUTLINE := Color(0.75, 0.65, 0.5, 1.0)        ## Lighter edge
const LANDED_GLOW := Color(0.82, 0.72, 0.45, 0.7)         ## Warm gold hint when pickable


func _ready() -> void:
	# Deferred for the same reason as BaseProjectile._ready() —
	# spawned from within a physics callback (handle_hit), so touching
	# the physics server synchronously throws "Can't change this state
	# while flushing queries".
	call_deferred("_setup_collision_flying")
	queue_redraw()


func _setup_collision_flying() -> void:
	# Area2D child handles Hurtbox detection in FLYING phase.
	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask = 2  # Hurtbox layer — BaseProjectile convention.
	_collision_shape = CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = CHUNK_RADIUS
	_collision_shape.shape = circle
	area.add_child(_collision_shape)
	add_child(area)
	area.area_entered.connect(_on_flying_area_entered)


func _setup_collision_landed() -> void:
	# Remove the old Area2D tree, add a fresh one for body detection.
	for child in get_children():
		child.queue_free()

	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask = 1  # Player body layer — WeaponPickup convention.
	_collision_shape = CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = CHUNK_RADIUS * 1.5  # Slightly forgiving pickup hitbox.
	_collision_shape.shape = circle
	area.add_child(_collision_shape)
	add_child(area)
	area.body_entered.connect(_on_landed_body_entered)


func _physics_process(delta: float) -> void:
	match _state:
		State.FLYING:
			position += _direction * SPEED * delta
			_flying_timer += delta
			if _flying_timer >= FLYING_LIFETIME:
				_transition_to_landed()

		State.LANDED:
			_landed_timer += delta
			if _landed_timer >= LANDED_LIFETIME:
				queue_free()


func _transition_to_landed() -> void:
	_state = State.LANDED
	# Swap collision setup on next deferred frame — same flushing-queries
	# guard as _setup_collision_flying().
	call_deferred("_setup_collision_landed")
	queue_redraw()


# ── FLYING hit ────────────────────────────────────────────────────────

func _on_flying_area_entered(area: Area2D) -> void:
	if _state != State.FLYING:
		return
	if not (area is Hurtbox):
		return
	var hurtbox := area as Hurtbox
	if hurtbox.owner == null:
		return

	# Never hit the player — this is their reward.
	var owner_node := hurtbox.owner
	if owner_node is Player:
		return

	# Never hit the combatant that triggered the reaction (its attacker).
	if _origin_combatant != null and is_instance_valid(_origin_combatant):
		if owner_node == _origin_combatant.get_parent():
			return

	var combatant := owner_node.get("elemental") as ElementalCombatant
	if combatant == null:
		return

	# Flat bonus damage — bypasses full reaction resolution, same as
	# Ore Surge fragments and Wildfire chain.
	combatant.bonus_damage_dealt.emit(HIT_DAMAGE)
	queue_free()


# ── LANDED pickup ─────────────────────────────────────────────────────

func _on_landed_body_entered(body: Node2D) -> void:
	if _state != State.LANDED:
		return
	var player := body as Player
	if player == null:
		return
	if player.get("elemental") == null:
		return
	var elemental := player.elemental as ElementalCombatant
	if elemental == null:
		return
	# Refresh-only per §1: a second pickup while one is active resets
	# the duration to 15s, does not stack the +8 magnitude.
	elemental.armor_buff.apply(ARMOR_BUFF_AMOUNT, ARMOR_BUFF_DURATION)
	queue_free()


# ── Visual ────────────────────────────────────────────────────────────

func _draw() -> void:
	var s := CHUNK_RADIUS
	# Diamond shape (Kim glyph, same as Projectile._draw()) but bigger
	# and rust-colored to read as "metal scrap" rather than a fragment.
	var pts := PackedVector2Array([
		Vector2(0, -s), Vector2(s * 0.7, -s * 0.3),
		Vector2(s, 0), Vector2(s * 0.7, s * 0.3),
		Vector2(0, s), Vector2(-s * 0.7, s * 0.3),
		Vector2(-s, 0), Vector2(-s * 0.7, -s * 0.3),
		Vector2(0, -s),
	])
	draw_colored_polygon(pts, CHUNK_COLOR)
	# Outline
	for i in pts.size() - 1:
		draw_line(pts[i], pts[i + 1], CHUNK_OUTLINE, 1.5)

	# Warm glow when landed and pickable.
	if _state == State.LANDED:
		var fade := 1.0 - (_landed_timer / LANDED_LIFETIME)
		var glow := LANDED_GLOW
		glow.a *= fade
		draw_circle(Vector2.ZERO, s * 1.8, glow)


# ── Static factory ────────────────────────────────────────────────────

## Spawns a RustedChunk at `origin_combatant`'s world position.
## Direction is derived from hit_data.knockback (knocked loose in the
## opposite direction of the blow); falls back to Vector2.RIGHT if
## knockback is zero-length, same guard Hitbox._on_area_entered uses.
static func spawn(scene_root: Node, origin_combatant: ElementalCombatant, hit_data: HitData) -> void:
	if scene_root == null or origin_combatant == null:
		return

	var chunk := RustedChunk.new()
	chunk._origin_combatant = origin_combatant

	# Direction = away from the knockback vector (the "knocked loose" feel).
	if hit_data.knockback.length_squared() > 0.01:
		chunk._direction = -hit_data.knockback.normalized()
	else:
		chunk._direction = Vector2.RIGHT

	# Position set via local coords (same fix as QiOrb.spawn_burst — see
	# that method's comment; global_position before entering the tree is
	# silently ignored in Godot 4).
	if scene_root is Node2D:
		chunk.position = (scene_root as Node2D).to_local(origin_combatant.global_position)
	else:
		chunk.position = origin_combatant.global_position

	scene_root.add_child(chunk)
