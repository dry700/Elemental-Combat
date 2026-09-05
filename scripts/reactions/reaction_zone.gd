class_name ReactionZone
extends Node2D
## A.7's "Zone" footprint, implemented exactly per its own definition:
## "a lingering circular trigger applying its element's Charge, fixed at
## 1, per tick, decaying after ~6-10s." Used by Cinder Bloom (scorched
## terrain, A.2) and Ore Surge (scattered metal debris, A.7's own
## footprint table — separate from Ore Surge's projectile burst, which
## is the delivery mechanism, not the terrain left behind).
##
## Deliberately NOT a physical Area2D — every existing reaction effect in
## this system already resolves "who's nearby" via plain distance checks
## against ElementalCombatant.ALL_COMBATANTS_GROUP rather than real
## collision shapes (see Overgrowth's AoE, Wildfire's chain), so this
## stays consistent with that instead of introducing a new collision
## layer just for terrain. A small side effect: a Zone affects anyone in
## range regardless of which "team" they're on, same as every other AoE
## in this system — there's no faction/ownership filtering anywhere yet.

@export var element: StringName = Elements.NONE
@export var charge: int = 1  ## A.7: "fixed at 1" — never scaled by the triggering hit's Charge.
@export var radius: float = 45.0
@export var tick_interval: float = 1.0
@export var lifetime: float = 8.0  ## A.7: "~6-10s" — 8s is the middle of that range.

## Hard cap on how many Zones can exist AT ONCE, across every element and
## every reaction that spawns one (Cinder Bloom, Ore Surge) — a global
## limit, not per-element or per-spawner. Without this, spamming either
## reaction just keeps piling up 8s-lived Zones indefinitely; ticking and
## drawing dozens of them is wasteful, and visually the battlefield turns
## into a wall of overlapping circles instead of a few readable hazards.
## No number is given in the proposal for this — 4 is a reasonable pick
## for a small test arena, not a design-doc value.
const MAX_ACTIVE_ZONES: int = 4

## Tracked oldest-first (append on spawn) so exceeding the cap always
## evicts whichever Zone has been around longest, not an arbitrary one.
static var _active_zones: Array[ReactionZone] = []

## Reinforcing tint per element — same palette family as ElementIndicator,
## duplicated rather than shared since it's a handful of Color constants,
## not worth cross-class coupling for.
const ZONE_TINT := {
	Elements.HOA: Color(0.95, 0.35, 0.25),
	Elements.THUY: Color(0.30, 0.55, 0.95),
	Elements.MOC: Color(0.35, 0.75, 0.35),
	Elements.KIM: Color(0.82, 0.82, 0.88),
	Elements.THO: Color(0.65, 0.50, 0.30),
}

var _tick_timer: float = 0.0
var _lifetime_timer: float = 0.0


func _ready() -> void:
	_active_zones.append(self)
	if _active_zones.size() > MAX_ACTIVE_ZONES:
		var oldest: ReactionZone = _active_zones.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()
	queue_redraw()


## Keeps _active_zones accurate however a Zone goes away — natural
## lifetime expiry (below) or the eviction above both end here.
func _exit_tree() -> void:
	_active_zones.erase(self)


func _process(delta: float) -> void:
	_lifetime_timer += delta
	if _lifetime_timer >= lifetime:
		queue_free()
		return

	_tick_timer += delta
	if _tick_timer >= tick_interval:
		_tick_timer = 0.0
		_apply_tick()


func _apply_tick() -> void:
	for node in get_tree().get_nodes_in_group(ElementalCombatant.ALL_COMBATANTS_GROUP):
		var combatant := node as ElementalCombatant
		if combatant == null:
			continue
		if global_position.distance_to(combatant.global_position) <= radius:
			# Refresh-only (A.3) — this is exactly the "Environmental
			# tick (Zone)" row in A.3's own Charge Application Source
			# table, which explicitly does not stack.
			combatant.status.apply(element, charge)


func _draw() -> void:
	var color: Color = ZONE_TINT.get(element, Color.WHITE)
	color.a = 0.22
	draw_circle(Vector2.ZERO, radius, color)
	color.a = 0.5
	draw_arc(Vector2.ZERO, radius, 0, TAU, 32, color, 2.0)
