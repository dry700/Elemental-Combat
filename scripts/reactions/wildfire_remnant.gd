class_name WildfireRemnant
extends Node2D
## §4.8.8 — Wildfire Rank 2 (favor-Mộc) world hazard.
##
## Two-state machine, same shape as RustedChunk (§4.8.5):
##   REMNANT → SPIKED_GROUND
##
## REMNANT state:
##   Spawned at an enemy's position when a Mộc hit lands on a target
##   carrying Wildfire's Hỏa status (gated by per-attacker 1.0s cooldown
##   on the target's ElementalCombatant — see _remnant_cooldowns dict).
##   Has its own Hurtbox so a weapon swing can hit it. A Mộc hit on the
##   Remnant's Hurtbox triggers conversion to SPIKED_GROUND (if the local
##   cluster cap allows — see below). Expires after 8s if unconverted.
##   Global cap of 4, oldest evicts (same convention as ReactionZone).
##
## SPIKED_GROUND state:
##   Periodic damage tick every 1.0s (~3.0 damage) to any combatant
##   within the radius, using distance_to against ALL_COMBATANTS_GROUP
##   (no real physics AoE — §1 principle). Own 6s expiry, independent
##   of the Remnant state's 8s timer. Local cluster cap: max 4 within
##   ~60px of each other — if exceeded the conversion is blocked (Remnant
##   stays as Remnant) rather than evicting a neighbor.
##
## Recursion guard: Spiked Ground's damage tick emits bonus_damage_dealt
##   directly — it never calls handle_hit() or routes through the "Mộc
##   hit on Wildfire target" drop-trigger logic.

## ── State ─────────────────────────────────────────────────────────────

enum State { REMNANT, SPIKED_GROUND }
var _state: State = State.REMNANT

## ── Global cap (REMNANT state) ────────────────────────────────────────

const MAX_ACTIVE_REMNANTS: int = 4
static var _active_remnants: Array[WildfireRemnant] = []

## ── Tuning ────────────────────────────────────────────────────────────

const REMNANT_LIFETIME: float = 8.0
const SPIKE_LIFETIME: float = 6.0
const SPIKE_TICK_INTERVAL: float = 1.0
const SPIKE_DAMAGE: float = 3.0
const SPIKE_RADIUS: float = 28.0
## Local cluster cap for SPIKED_GROUND — blocks conversion if already
## this many Spiked Grounds exist within CLUSTER_CHECK_RADIUS.
const MAX_LOCAL_SPIKES: int = 4
const CLUSTER_CHECK_RADIUS: float = 60.0

## ── Timers ────────────────────────────────────────────────────────────

var _remnant_timer: float = 0.0
var _spike_timer: float = 0.0
var _spike_tick_timer: float = 0.0

## ── Collision (Hurtbox child for REMNANT state) ───────────────────────

var _hurtbox: Hurtbox

## ── Visual ────────────────────────────────────────────────────────────

const REMNANT_RADIUS: float = 7.0
const REMNANT_COLOR   := Color(0.85, 0.35, 0.20, 0.85)   ## Hỏa ember glow
const REMNANT_INNER   := Color(1.00, 0.70, 0.30, 0.70)
const REMNANT_OUTLINE := Color(0.50, 0.20, 0.10, 1.00)
const SPIKE_COLOR     := Color(0.35, 0.75, 0.35, 0.80)   ## Mộc green
const SPIKE_OUTLINE   := Color(0.15, 0.45, 0.15, 1.00)
const SPIKE_INNER     := Color(0.55, 0.95, 0.45, 0.60)


func _ready() -> void:
	# Global cap — evict oldest if over limit.
	_active_remnants.append(self)
	if _active_remnants.size() > MAX_ACTIVE_REMNANTS:
		var oldest: WildfireRemnant = _active_remnants.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()

	# Hurtbox for weapon-hit detection in REMNANT state.
	call_deferred("_setup_hurtbox")
	queue_redraw()


func _exit_tree() -> void:
	_active_remnants.erase(self)


func _setup_hurtbox() -> void:
	_hurtbox = Hurtbox.new()
	_hurtbox.collision_layer = 2
	_hurtbox.collision_mask  = 0
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = REMNANT_RADIUS * 1.5
	shape.shape = circle
	_hurtbox.add_child(shape)
	add_child(_hurtbox)
	_hurtbox.hit_received.connect(_on_hit_received)


func _process(delta: float) -> void:
	match _state:
		State.REMNANT:
			_remnant_timer += delta
			if _remnant_timer >= REMNANT_LIFETIME:
				queue_free()

		State.SPIKED_GROUND:
			_spike_timer += delta
			if _spike_timer >= SPIKE_LIFETIME:
				queue_free()
				return
			_spike_tick_timer += delta
			if _spike_tick_timer >= SPIKE_TICK_INTERVAL:
				_spike_tick_timer = 0.0
				_apply_spike_damage()

	queue_redraw()


## ── REMNANT hit handler ───────────────────────────────────────────────

func _on_hit_received(hit_data: HitData) -> void:
	if _state != State.REMNANT:
		return
	if hit_data.element != Elements.MOC:
		return  # Only Mộc hits trigger conversion.
	_try_convert_to_spike()


func _try_convert_to_spike() -> void:
	# Local cluster cap: count how many SPIKED_GROUND instances exist
	# within CLUSTER_CHECK_RADIUS. If already at cap, block conversion.
	var nearby_spikes := 0
	for remnant in _active_remnants:
		if not is_instance_valid(remnant):
			continue
		if remnant == self:
			continue
		if remnant._state == State.SPIKED_GROUND:
			if global_position.distance_to(remnant.global_position) <= CLUSTER_CHECK_RADIUS:
				nearby_spikes += 1
	if nearby_spikes >= MAX_LOCAL_SPIKES:
		return  # Blocked — stays as Remnant per §4.8.8 assumption.

	_transition_to_spike()


func _transition_to_spike() -> void:
	_state = State.SPIKED_GROUND
	_spike_timer = 0.0
	_spike_tick_timer = 0.0
	# Remove Hurtbox — Spiked Ground is not hittable with weapons.
	if is_instance_valid(_hurtbox):
		_hurtbox.queue_free()
		_hurtbox = null
	queue_redraw()


## ── Spiked Ground damage tick ─────────────────────────────────────────
## Recursion guard: emits bonus_damage_dealt directly on each combatant —
## never calls handle_hit() or any path that could re-trigger the Mộc-on-
## Hỏa drop check. The two code paths are intentionally separate.

func _apply_spike_damage() -> void:
	for node in get_tree().get_nodes_in_group(ElementalCombatant.ALL_COMBATANTS_GROUP):
		var combatant := node as ElementalCombatant
		if combatant == null:
			continue
		if global_position.distance_to(combatant.global_position) <= SPIKE_RADIUS:
			combatant.bonus_damage_dealt.emit(SPIKE_DAMAGE)


## ── Visual ────────────────────────────────────────────────────────────

func _draw() -> void:
	match _state:
		State.REMNANT:
			var fade := 1.0 - (_remnant_timer / REMNANT_LIFETIME)
			var outer := REMNANT_COLOR; outer.a *= fade
			var inner := REMNANT_INNER; inner.a *= fade
			var outline := REMNANT_OUTLINE; outline.a *= fade
			# Pulsing ember — bob the inner circle size slightly.
			var pulse := 0.85 + sin(Time.get_ticks_msec() / 300.0) * 0.15
			draw_circle(Vector2.ZERO, REMNANT_RADIUS, outer)
			draw_circle(Vector2.ZERO, REMNANT_RADIUS * 0.5 * pulse, inner)
			draw_arc(Vector2.ZERO, REMNANT_RADIUS, 0, TAU, 20, outline, 1.5)

		State.SPIKED_GROUND:
			var fade := 1.0 - (_spike_timer / SPIKE_LIFETIME)
			var body := SPIKE_COLOR; body.a *= fade * 0.5
			var outline := SPIKE_OUTLINE; outline.a *= fade
			var inner := SPIKE_INNER; inner.a *= fade * 0.4
			draw_circle(Vector2.ZERO, SPIKE_RADIUS, body)
			draw_circle(Vector2.ZERO, SPIKE_RADIUS * 0.5, inner)
			draw_arc(Vector2.ZERO, SPIKE_RADIUS, 0, TAU, 28, outline, 2.0)
			# Spike glyphs — 4 short lines radiating outward.
			for i in 4:
				var angle := (TAU / 4.0) * i + PI * 0.25
				var tip := Vector2(cos(angle), sin(angle)) * (SPIKE_RADIUS + 4.0)
				var base_pt := Vector2(cos(angle), sin(angle)) * (SPIKE_RADIUS * 0.6)
				draw_line(base_pt, tip, outline, 2.0)


## ── Static factory ────────────────────────────────────────────────────

## Spawns a WildfireRemnant at `origin_combatant`'s world position.
static func spawn(scene_root: Node, origin_combatant: ElementalCombatant) -> void:
	if scene_root == null or origin_combatant == null:
		return
	var remnant := WildfireRemnant.new()
	if scene_root is Node2D:
		remnant.position = (scene_root as Node2D).to_local(origin_combatant.global_position)
	else:
		remnant.position = origin_combatant.global_position
	scene_root.add_child(remnant)
