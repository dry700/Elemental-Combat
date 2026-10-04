class_name Boulder
extends Node2D
## §4.8.9 — Cinder Bloom Rank 2 (favor-Thổ) delayed impact.
##
## Spawns above the specific enemy that triggered the Cinder Bloom Sinh
## reaction (not the wider AoE burn radius — just that one target).
## Waits 0.4s (telegraph), then:
##   1. Emits bonus_damage_dealt(14.0) on the target directly.
##   2. Refreshes the target's Thổ status (charge 1 — Zone convention).
##   3. Spawns 5 Projectile fragments in an even radial spread
##      (same loop _spawn_ore_surge_fragments uses), each:
##        element = THO, shred_amount = 0.0, damage_amount = 3.0.
##
## Built entirely in code, same convention as every other combat object.

const IMPACT_DAMAGE: float = 14.0
const FRAGMENT_COUNT: int = 5
const FRAGMENT_DAMAGE: float = 3.0
const FRAGMENT_SPEED: float = 180.0
const FRAGMENT_LIFETIME: float = 0.7
const DELAY: float = 0.4

## Visual — Thổ brown tone, drawn as a falling circle that shrinks as it "falls".
const BOULDER_COLOR   := Color(0.60, 0.45, 0.28, 0.90)
const BOULDER_OUTLINE := Color(0.35, 0.25, 0.12, 1.00)
const BOULDER_RADIUS_START: float = 12.0
const BOULDER_RADIUS_END:   float = 7.0

var _timer: float = 0.0
var _target: ElementalCombatant = null
var _attacker: Node = null  ## The player — used as attacker on fragments.


func _ready() -> void:
	queue_redraw()


func _process(delta: float) -> void:
	_timer += delta
	queue_redraw()
	if _timer >= DELAY:
		_impact()
		queue_free()


func _impact() -> void:
	if not is_instance_valid(_target):
		return

	# 1. Direct damage on the target.
	_target.bonus_damage_dealt.emit(IMPACT_DAMAGE)

	# 2. Refresh Thổ status (charge 1 — consistent with Zone/terrain convention).
	_target.status.apply(Elements.THO, 1)

	# 3. Radial fragment burst — same even-spread loop as _spawn_ore_surge_fragments.
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return
	for i in FRAGMENT_COUNT:
		var angle := (TAU / FRAGMENT_COUNT) * i
		var frag := Projectile.new()
		frag.direction = Vector2.RIGHT.rotated(angle)
		frag.speed = FRAGMENT_SPEED
		frag.lifetime = FRAGMENT_LIFETIME
		frag.element = Elements.THO
		frag.charge = 1
		frag.shred_amount = 0.0
		frag.damage_amount = FRAGMENT_DAMAGE
		frag.attacker = _attacker
		if scene_root is Node2D:
			frag.position = (scene_root as Node2D).to_local(_target.global_position)
		else:
			frag.position = _target.global_position
		scene_root.add_child(frag)


func _draw() -> void:
	# Shrinks as it "falls" — interpolate radius from start to end over DELAY.
	var t := clampf(_timer / DELAY, 0.0, 1.0)
	var r := lerpf(BOULDER_RADIUS_START, BOULDER_RADIUS_END, t)
	# Also drift downward slightly so it visually "falls" toward the target.
	var drift := Vector2(0.0, t * 6.0)
	draw_circle(drift, r, BOULDER_COLOR)
	draw_arc(drift, r, 0, TAU, 20, BOULDER_OUTLINE, 2.0)
	# Crack lines — simple radiating lines that appear in the last 30% of fall.
	if t > 0.7:
		var crack_alpha := (t - 0.7) / 0.3
		var crack_col := BOULDER_OUTLINE
		crack_col.a = crack_alpha
		for i in 3:
			var angle := (TAU / 3.0) * i + PI * 0.2
			draw_line(drift, drift + Vector2(cos(angle), sin(angle)) * r * 0.9, crack_col, 1.5)


## ── Static factory ────────────────────────────────────────────────────

## Spawns a Boulder above `target` (the direct Cinder Bloom hit target).
## `attacker` is passed through to the fragment Projectiles so they
## don't accidentally hit the player who triggered the reaction.
static func spawn(scene_root: Node, target: ElementalCombatant, attacker: Node) -> void:
	if scene_root == null or target == null:
		return
	var boulder := Boulder.new()
	boulder._target = target
	boulder._attacker = attacker
	# Spawn slightly above the target so the "falling" telegraph reads clearly.
	var spawn_world_pos := target.global_position + Vector2(0.0, -20.0)
	if scene_root is Node2D:
		boulder.position = (scene_root as Node2D).to_local(spawn_world_pos)
	else:
		boulder.position = spawn_world_pos
	scene_root.add_child(boulder)
