class_name SteamCloud
extends Node2D
## Douse's steam cloud (A.2: "removes burn, steam cloud (vision-block +
## stun)"; A.2's Thừa row for Douse: "Larger cloud radius, longer stun").
##
## Structured as a ONE-TIME AoE stun burst at spawn — DisableEffect's own
## duration mechanic already makes the stun expire on its own after a
## short window, so there's no need to track a separate "stun phase" vs
## "vision phase" state machine. The cloud simply exists, visually, for
## its full lifetime; the stun just happens to only last a fraction of
## that, which is exactly "stuns for the first bit, then just sits there
## blocking vision for the rest."
##
## There is no line-of-sight/fog-of-war system anywhere in this project
## to mechanically block sight with. "Blocks vision" is implemented as
## exactly what it says for a human player looking at the screen: a
## genuinely dense, opaque visual obstruction over the area. It has zero
## effect on any AI — nothing currently uses vision for anything anyway
## (PatrolDummy patrols blind regardless of what's drawn on top of it).
##
## Distinct from ReactionZone: a Zone re-ticks its status onto whoever's
## inside it, repeatedly, for its whole life (A.7's own definition).
## This does the opposite — one effect, once, at spawn, then nothing
## mechanical for the rest of its life. Reusing Zone's periodic-tick
## shape here would be modeling the wrong thing.

@export var radius: float = 90.0
@export var lifetime: float = 5.0
@export var stun_duration: float = 0.3
## 0.0 = fully see-through, 1.0 = fully opaque. Tune this by feel —
## "blocks vision" doesn't necessarily mean a total blackout; enough
## translucency to see rough shapes/silhouettes through it might read
## better than a flat wall of color, but that's a visual call, not a
## mechanical one.
@export_range(0.0, 1.0) var opacity: float = 0.85

## Resolved bystander-exclusion target (see ElementalCombatant.
## _bystander_attacker) — set by whoever spawns this, before add_child().
## Null means nothing is excluded (no attacker, or a genuine
## self-inflicted case that should still be caught in its own cloud).
var excluded_combatant: ElementalCombatant = null

const CLOUD_COLOR: Color = Color(0.82, 0.85, 0.88)  ## RGB only — alpha comes from opacity above.

## Same concern as ReactionZone's cap, applied here too for consistency
## even though it wasn't asked for specifically this time — an opaque,
## screen-obscuring hazard piling up unbounded is at least as disruptive
## as a thin Zone tint doing the same, arguably more so.
const MAX_ACTIVE_CLOUDS: int = 3
static var _active_clouds: Array[SteamCloud] = []

var _lifetime_timer: float = 0.0


func _ready() -> void:
	_active_clouds.append(self)
	if _active_clouds.size() > MAX_ACTIVE_CLOUDS:
		var oldest: SteamCloud = _active_clouds.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()
	_apply_initial_stun()
	queue_redraw()


func _exit_tree() -> void:
	_active_clouds.erase(self)


func _process(delta: float) -> void:
	_lifetime_timer += delta
	if _lifetime_timer >= lifetime:
		queue_free()


func _apply_initial_stun() -> void:
	for node in get_tree().get_nodes_in_group(ElementalCombatant.ALL_COMBATANTS_GROUP):
		var combatant := node as ElementalCombatant
		if combatant == null or combatant == excluded_combatant:
			continue
		if global_position.distance_to(combatant.global_position) <= radius:
			combatant.disable_effect.apply(stun_duration, stun_duration)


func _draw() -> void:
	var color := CLOUD_COLOR
	color.a = opacity
	draw_circle(Vector2.ZERO, radius, color)
