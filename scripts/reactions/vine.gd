class_name Vine
extends Node2D
## §4.8.6 — Spawned by Overgrowth Rank 2 (both favor branches).
##
## Holds the list of combatants that were rooted by the triggering
## Overgrowth AoE so it can release their roots early when it resolves.
## Has its own Hurtbox child so weapon swings can hit it — the Hitbox's
## existing _already_hit guard naturally paces one response per active
## swing window, so no new debounce is needed here.
##
## Two mutually exclusive resolution paths:
##
## EXPLODE (favor-Mộc / generated element):
##   3rd Mộc-element hit → releases all held roots, spawns a lingering
##   Mộc Zone at this position, queue_free()s.
##
## WATER (favor-Thủy / the other element in the pair):
##   1st Thủy-element hit → releases all held roots, spawns 2
##   FlowerTurrets near this position, queue_free()s.
##
## A non-Mộc, non-Thủy hit still deals normal weapon damage via the
## Hurtbox signal (owner connects it), but never advances either counter.
## The Vine itself has no health — it resolves purely on elemental hits,
## not on being "killed".
##
## branch: true = favor generated (explode path), false = favor other (water path).

## ── Config set at spawn ───────────────────────────────────────────────

## The combatants rooted by the triggering Overgrowth AoE.
var _rooted: Array[ElementalCombatant] = []
## true = favor-Mộc (explode), false = favor-Thủy (water/turret).
var _explode_branch: bool = true

## ── State ─────────────────────────────────────────────────────────────

var _moc_hits: int = 0
const MOC_HITS_TO_EXPLODE: int = 3

## Safety timeout — if never triggered, self-destruct and release roots
## after a reasonable window so combatants don't stay rooted forever.
const TIMEOUT: float = 20.0
var _timer: float = 0.0

## Visual
const VINE_RADIUS: float = 8.0
const VINE_COLOR       := Color(0.25, 0.60, 0.25, 1.0)
const VINE_INNER       := Color(0.45, 0.80, 0.35, 0.85)
const VINE_OUTLINE     := Color(0.15, 0.40, 0.15, 1.0)
const VINE_CHARGED_COL := Color(0.65, 0.95, 0.45, 1.0)  ## Brightens per Mộc hit.

var _hurtbox: Hurtbox


func _ready() -> void:
	# Build the Hurtbox child. Deferred for the same physics-flush reason
	# as BaseProjectile and RustedChunk — spawned from inside handle_hit().
	call_deferred("_setup_hurtbox")
	queue_redraw()


func _setup_hurtbox() -> void:
	_hurtbox = Hurtbox.new()
	_hurtbox.collision_layer = 2   # Hurtbox layer — same as every other Hurtbox.
	_hurtbox.collision_mask  = 0
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = VINE_RADIUS * 1.5   # Slightly generous hit area.
	shape.shape = circle
	_hurtbox.add_child(shape)
	add_child(_hurtbox)
	_hurtbox.hit_received.connect(_on_hit_received)


func _process(delta: float) -> void:
	_timer += delta
	if _timer >= TIMEOUT:
		_release_roots()
		queue_free()


## Called by the Hurtbox whenever a weapon swing lands on the Vine.
## Non-Mộc/Thủy hits are ignored for counter purposes (normal damage
## would go to whatever the owner tracks, but the Vine has no HP so
## the signal fires and nothing happens unless we handle it here).
func _on_hit_received(hit_data: HitData) -> void:
	if _explode_branch:
		# Explode path — only Mộc hits count.
		if hit_data.element == Elements.MOC:
			_moc_hits += 1
			queue_redraw()
			if _moc_hits >= MOC_HITS_TO_EXPLODE:
				_explode()
	else:
		# Water path — first Thủy hit triggers it.
		if hit_data.element == Elements.THUY:
			_water()


## ── Resolution paths ─────────────────────────────────────────────────

func _explode() -> void:
	_release_roots()
	# Spawn a lingering Mộc Zone at this position (default radius/lifetime).
	var scene_root := get_tree().current_scene
	if scene_root != null:
		var zone := ReactionZone.new()
		zone.element = Elements.MOC
		# global_position → local before add, same QiOrb fix.
		if scene_root is Node2D:
			zone.position = (scene_root as Node2D).to_local(global_position)
		else:
			zone.position = global_position
		scene_root.add_child(zone)
	queue_free()


func _water() -> void:
	_release_roots()
	var scene_root := get_tree().current_scene
	if scene_root != null:
		FlowerTurret.spawn_pair(scene_root, global_position)
	queue_free()


## Releases every held root by clearing the disable_effect on each
## still-valid combatant. Safe to call multiple times (timeout + path)
## because queue_free() immediately follows every call site.
func _release_roots() -> void:
	for combatant in _rooted:
		if is_instance_valid(combatant):
			combatant.disable_effect.clear()
	_rooted.clear()


## ── Visual ────────────────────────────────────────────────────────────

func _draw() -> void:
	var charge_t := clampf(float(_moc_hits) / float(MOC_HITS_TO_EXPLODE), 0.0, 1.0)
	var body_color := VINE_COLOR.lerp(VINE_CHARGED_COL, charge_t)
	# Outer ring
	draw_circle(Vector2.ZERO, VINE_RADIUS, body_color)
	draw_circle(Vector2.ZERO, VINE_RADIUS * 0.55, VINE_INNER)
	draw_arc(Vector2.ZERO, VINE_RADIUS, 0, TAU, 24, VINE_OUTLINE, 1.5)

	# Small pip indicators for Mộc hit count (only on explode branch).
	if _explode_branch:
		for i in MOC_HITS_TO_EXPLODE:
			var angle := (TAU / MOC_HITS_TO_EXPLODE) * i - PI * 0.5
			var pip_pos := Vector2(cos(angle), sin(angle)) * (VINE_RADIUS + 4.0)
			var pip_col := VINE_CHARGED_COL if i < _moc_hits else VINE_OUTLINE
			draw_circle(pip_pos, 2.0, pip_col)


## ── Static factory ────────────────────────────────────────────────────

## Spawns a Vine at `origin_combatant`'s world position.
##
## rooted_combatants: the Array[ElementalCombatant] returned by
##   _apply_overgrowth_aoe() — the Vine holds this to release roots early.
## explode_branch: true if the player favored the generated element (Mộc),
##   false if they favored the other element (Thủy / water path).
static func spawn(scene_root: Node, origin_combatant: ElementalCombatant,
		rooted_combatants: Array[ElementalCombatant], explode_branch: bool) -> void:
	if scene_root == null or origin_combatant == null:
		return

	var vine := Vine.new()
	vine._rooted = rooted_combatants.duplicate()
	vine._explode_branch = explode_branch

	if scene_root is Node2D:
		vine.position = (scene_root as Node2D).to_local(origin_combatant.global_position)
	else:
		vine.position = origin_combatant.global_position

	scene_root.add_child(vine)
