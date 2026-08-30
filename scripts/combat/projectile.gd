class_name Projectile
extends Area2D
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
## No wall/terrain collision — Ground/Platform are physics bodies, not
## Areas, and nothing else in this combat system (Hitbox included)
## interacts with them either. Fragments fly through walls; a known,
## deliberate simplification, not an oversight.

@export var speed: float = 400.0
@export var lifetime: float = 0.8
@export var element: StringName = Elements.NONE
@export var charge: int = 1
@export var shred_amount: float = 2.0
var direction: Vector2 = Vector2.RIGHT
var attacker: Node = null  ## Never hits its own wielder — same guard as Hitbox.

const FRAGMENT_COLOR: Color = Color(0.82, 0.82, 0.88)  ## Kim's tint (ElementIndicator/ReactionZone palette).
const FRAGMENT_SIZE: float = 5.0

var _already_hit: Array[Hurtbox] = []
var _lifetime_timer: float = 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2  ## Hurtbox layer — matches Hitbox's own convention exactly.
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = FRAGMENT_SIZE
	shape.shape = circle
	add_child(shape)
	area_entered.connect(_on_area_entered)
	queue_redraw()


func _process(delta: float) -> void:
	position += direction.normalized() * speed * delta
	_lifetime_timer += delta
	if _lifetime_timer >= lifetime:
		queue_free()


func _on_area_entered(area: Area2D) -> void:
	if not (area is Hurtbox):
		return
	var hurtbox := area as Hurtbox
	if hurtbox.owner == attacker:
		return  # Never hit your own wielder.
	if hurtbox in _already_hit:
		return  # Already pierced this one — keep flying, don't double-apply.
	_already_hit.append(hurtbox)

	var owner_node := hurtbox.owner
	if owner_node == null:
		return
	var combatant := owner_node.get("elemental") as ElementalCombatant
	if combatant == null:
		return
	combatant.armor = maxf(combatant.armor - shred_amount, 0.0)
	combatant.status.apply(element, charge)


func _draw() -> void:
	# Small diamond — Kim's own A.1 pattern glyph, reused here so a
	# fragment reads as "metal" the same way the status indicator does.
	var s := FRAGMENT_SIZE
	var pts := PackedVector2Array([Vector2(0, -s), Vector2(s, 0), Vector2(0, s), Vector2(-s, 0), Vector2(0, -s)])
	draw_colored_polygon(pts, FRAGMENT_COLOR)
