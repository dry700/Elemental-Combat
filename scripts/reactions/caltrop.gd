class_name Caltrop
extends Node2D
## §4.8.10 — Ore Surge Rank 2 (favor-Thổ) hazard.
##
## Seeded at a fragment's current position when it expires without hitting
## an enemy (leaves_hazard_on_expiry = true). One-shot trigger: the first
## combatant to come within 15px takes SlowEffect.apply(0.6, 2.5) — Silt's
## own numbers reused — then the Caltrop queue_free()s immediately.
## Untriggered, decays after 10s.
##
## Distance-check only in _process against ALL_COMBATANTS_GROUP — no
## physical Area2D, consistent with §1's "no real physics-based AoE".
##
## NOTE: one-shot rather than a repeating zone per §4.8.10 assumption —
## revisit if it reads as too weak in play.

## ── Tuning ────────────────────────────────────────────────────────────

const TRIGGER_RADIUS: float = 15.0
const LIFETIME: float = 10.0
## Silt's own slow numbers reused per §4.8.10.
const SLOW_MULTIPLIER: float = 0.6
const SLOW_DURATION: float = 2.5

## Visual — small Thổ-coloured spike cluster.
const CALTROP_COLOR   := Color(0.55, 0.42, 0.25, 0.95)
const CALTROP_OUTLINE := Color(0.30, 0.20, 0.10, 1.00)
const CALTROP_GLOW    := Color(0.70, 0.55, 0.30, 0.45)

## ── State ─────────────────────────────────────────────────────────────

var _timer: float = 0.0


func _process(delta: float) -> void:
	_timer += delta
	if _timer >= LIFETIME:
		queue_free()
		return

	# Distance-check every frame — cheap, consistent with §1.
	for node in get_tree().get_nodes_in_group(ElementalCombatant.ALL_COMBATANTS_GROUP):
		var combatant := node as ElementalCombatant
		if combatant == null:
			continue
		if global_position.distance_to(combatant.global_position) <= TRIGGER_RADIUS:
			combatant.apply_control_slow(SLOW_MULTIPLIER, SLOW_DURATION)
			queue_free()
			return  # One-shot — stop after first trigger.

	queue_redraw()


## ── Visual ────────────────────────────────────────────────────────────

func _draw() -> void:
	var fade := 1.0 - (_timer / LIFETIME)
	# Blink in the last 2 seconds.
	if _timer > LIFETIME - 2.0:
		if fmod(_timer, 0.3) < 0.15:
			fade *= 0.3

	# Soft glow circle.
	var glow := CALTROP_GLOW
	glow.a *= fade
	draw_circle(Vector2.ZERO, TRIGGER_RADIUS * 0.7, glow)

	# Four spike points radiating outward (classic caltrop silhouette).
	var body := CALTROP_COLOR
	body.a *= fade
	var outline := CALTROP_OUTLINE
	outline.a *= fade
	var r := 4.0
	for i in 4:
		var angle := (TAU / 4.0) * i + PI * 0.25
		var tip := Vector2(cos(angle), sin(angle)) * r
		draw_line(Vector2.ZERO, tip, body, 2.5)
		draw_circle(tip, 1.5, outline)


## ── Static factory ────────────────────────────────────────────────────

## Spawns a Caltrop at the given world position (typically a fragment's
## last position when it expires).
static func spawn(scene_root: Node, world_position: Vector2) -> void:
	if scene_root == null:
		return
	var caltrop := Caltrop.new()
	if scene_root is Node2D:
		caltrop.position = (scene_root as Node2D).to_local(world_position)
	else:
		caltrop.position = world_position
	scene_root.add_child(caltrop)
